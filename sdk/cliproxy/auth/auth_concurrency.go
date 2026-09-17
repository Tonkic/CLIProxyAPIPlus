package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"

	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

type authConcurrencyState struct {
	mu     sync.Mutex
	active int
}

// authMaxConcurrency returns the live per-auth limit. Auth file metadata is
// read on every acquire so watcher updates take effect without restarting.
func authMaxConcurrency(auth *Auth) int {
	if auth == nil {
		return 0
	}
	if raw := strings.TrimSpace(auth.Attributes[AttributeMaxConcurrency]); raw != "" {
		if value, err := strconv.Atoi(raw); err == nil && value > 0 {
			return value
		}
	}
	if auth.Metadata == nil {
		return 0
	}
	raw, ok := auth.Metadata[AttributeMaxConcurrency]
	if !ok {
		raw = auth.Metadata["max-concurrency"]
	}
	switch value := raw.(type) {
	case float64:
		if value > 0 {
			return int(value)
		}
	case float32:
		if value > 0 {
			return int(value)
		}
	case int:
		if value > 0 {
			return value
		}
	case int64:
		if value > 0 {
			return int(value)
		}
	case json.Number:
		if parsed, err := strconv.Atoi(value.String()); err == nil && parsed > 0 {
			return parsed
		}
	case string:
		if parsed, err := strconv.Atoi(strings.TrimSpace(value)); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 0
}

// ApplyAuthMaxConcurrencyMetadata copies the normalized auth-file limit into
// immutable runtime attributes. The original metadata remains persisted.
func ApplyAuthMaxConcurrencyMetadata(auth *Auth, metadata map[string]any) {
	if auth == nil {
		return
	}
	if auth.Metadata == nil && metadata != nil {
		auth.Metadata = metadata
	}
	limit := authMaxConcurrency(&Auth{Metadata: metadata})
	if limit <= 0 {
		return
	}
	if auth.Attributes == nil {
		auth.Attributes = make(map[string]string)
	}
	auth.Attributes[AttributeMaxConcurrency] = strconv.Itoa(limit)
}

func (m *Manager) tryAcquireAuthConcurrency(auth *Auth) (func(), bool) {
	limit := authMaxConcurrency(auth)
	if m == nil || auth == nil || limit <= 0 || strings.TrimSpace(auth.ID) == "" {
		return func() {}, true
	}
	value, _ := m.authConcurrency.LoadOrStore(auth.ID, &authConcurrencyState{})
	state, ok := value.(*authConcurrencyState)
	if !ok || state == nil {
		return func() {}, true
	}
	state.mu.Lock()
	if state.active >= limit {
		state.mu.Unlock()
		return nil, false
	}
	state.active++
	state.mu.Unlock()

	var once sync.Once
	return func() {
		once.Do(func() {
			state.mu.Lock()
			if state.active > 0 {
				state.active--
			}
			state.mu.Unlock()
		})
	}, true
}

type authConcurrencyBusyError struct {
	authID   string
	provider string
	limit    int
}

func (e *authConcurrencyBusyError) Error() string {
	return fmt.Sprintf("credential %s (%s) is at its concurrency limit (%d)", e.authID, e.provider, e.limit)
}

func (e *authConcurrencyBusyError) StatusCode() int { return http.StatusTooManyRequests }

func newAuthConcurrencyBusyError(auth *Auth) error {
	if auth == nil {
		return &authConcurrencyBusyError{authID: "unknown", provider: "credential"}
	}
	return &authConcurrencyBusyError{
		authID:   strings.TrimSpace(auth.ID),
		provider: strings.TrimSpace(auth.Provider),
		limit:    authMaxConcurrency(auth),
	}
}

func isAuthConcurrencyBusyError(err error) bool {
	_, ok := err.(*authConcurrencyBusyError)
	return ok
}

func (m *Manager) executeWithAuthConcurrency(auth *Auth, execute func() (cliproxyexecutor.Response, error)) (cliproxyexecutor.Response, error) {
	release, acquired := m.tryAcquireAuthConcurrency(auth)
	if !acquired {
		return cliproxyexecutor.Response{}, newAuthConcurrencyBusyError(auth)
	}
	defer release()
	return execute()
}

func wrapStreamWithAuthConcurrency(ctx context.Context, result *cliproxyexecutor.StreamResult, release func()) *cliproxyexecutor.StreamResult {
	if result == nil || release == nil {
		return result
	}
	if result.Chunks == nil {
		release()
		return result
	}
	out := make(chan cliproxyexecutor.StreamChunk)
	go func() {
		defer close(out)
		defer release()
		for {
			select {
			case <-ctx.Done():
				discardStreamChunks(result.Chunks)
				return
			case chunk, ok := <-result.Chunks:
				if !ok {
					return
				}
				select {
				case <-ctx.Done():
					discardStreamChunks(result.Chunks)
					return
				case out <- chunk:
				}
			}
		}
	}()
	return &cliproxyexecutor.StreamResult{Headers: result.Headers, Chunks: out}
}
