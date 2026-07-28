package auth

import (
	"context"
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

func (m *Manager) tryAcquireAuthConcurrency(auth *Auth) (func(), bool) {
	if m == nil || auth == nil || auth.Attributes == nil {
		return func() {}, true
	}
	limit, err := strconv.Atoi(strings.TrimSpace(auth.Attributes[AttributeMaxConcurrency]))
	if err != nil || limit <= 0 {
		return func() {}, true
	}
	authID := strings.TrimSpace(auth.ID)
	if authID == "" {
		return func() {}, true
	}
	value, _ := m.authConcurrency.LoadOrStore(authID, &authConcurrencyState{})
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

func authConcurrencyError(auth *Auth) *Error {
	provider := "credential"
	if auth != nil && strings.TrimSpace(auth.Provider) != "" {
		provider = strings.TrimSpace(auth.Provider) + " credential"
	}
	return &Error{
		Code:       "auth_concurrency_exceeded",
		Message:    provider + " is at its concurrency limit",
		Retryable:  true,
		HTTPStatus: http.StatusTooManyRequests,
	}
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
			var (
				chunk cliproxyexecutor.StreamChunk
				ok    bool
			)
			if ctx == nil {
				chunk, ok = <-result.Chunks
			} else {
				select {
				case <-ctx.Done():
					discardStreamChunks(result.Chunks)
					return
				case chunk, ok = <-result.Chunks:
				}
			}
			if !ok {
				return
			}
			if ctx == nil {
				out <- chunk
				continue
			}
			select {
			case <-ctx.Done():
				discardStreamChunks(result.Chunks)
				return
			case out <- chunk:
			}
		}
	}()
	return &cliproxyexecutor.StreamResult{Headers: result.Headers, Chunks: out}
}
