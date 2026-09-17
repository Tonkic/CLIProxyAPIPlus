package auth

import (
	"context"
	"net/http"
	"testing"

	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

type authConcurrencyTestExecutor struct {
	started chan string
	release chan struct{}
}

func (e *authConcurrencyTestExecutor) Identifier() string { return "auth-concurrency-test" }
func (e *authConcurrencyTestExecutor) Execute(ctx context.Context, auth *Auth, _ cliproxyexecutor.Request, _ cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	e.started <- auth.ID
	select {
	case <-ctx.Done():
		return cliproxyexecutor.Response{}, ctx.Err()
	case <-e.release:
		return cliproxyexecutor.Response{Payload: []byte(auth.ID)}, nil
	}
}
func (e *authConcurrencyTestExecutor) ExecuteStream(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (*cliproxyexecutor.StreamResult, error) {
	return nil, nil
}
func (e *authConcurrencyTestExecutor) Refresh(_ context.Context, auth *Auth) (*Auth, error) {
	return auth, nil
}
func (e *authConcurrencyTestExecutor) CountTokens(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	return cliproxyexecutor.Response{}, nil
}
func (e *authConcurrencyTestExecutor) HttpRequest(context.Context, *Auth, *http.Request) (*http.Response, error) {
	return nil, nil
}

func TestAuthMaxConcurrencyReadsAuthFileMetadata(t *testing.T) {
	tests := []struct {
		name string
		raw  any
		want int
	}{
		{name: "json number", raw: float64(2), want: 2},
		{name: "string", raw: "3", want: 3},
		{name: "zero unlimited", raw: float64(0), want: 0},
		{name: "invalid unlimited", raw: "bad", want: 0},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			auth := &Auth{Metadata: map[string]any{AttributeMaxConcurrency: test.raw}}
			if got := authMaxConcurrency(auth); got != test.want {
				t.Fatalf("authMaxConcurrency() = %d, want %d", got, test.want)
			}
		})
	}
}

func TestAuthConcurrencyLimitUsesHotReloadedValue(t *testing.T) {
	manager := NewManager(nil, nil, nil)
	auth := &Auth{ID: "auth-a", Provider: "codex", Metadata: map[string]any{AttributeMaxConcurrency: float64(1)}}
	releaseFirst, ok := manager.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("first acquire failed")
	}
	defer releaseFirst()
	if _, ok = manager.tryAcquireAuthConcurrency(auth); ok {
		t.Fatal("second acquire unexpectedly succeeded at limit 1")
	}

	updated := auth.Clone()
	updated.Metadata[AttributeMaxConcurrency] = float64(2)
	releaseSecond, ok := manager.tryAcquireAuthConcurrency(updated)
	if !ok {
		t.Fatal("updated hot-reload limit was not observed")
	}
	releaseSecond()
}

func TestWrapStreamWithAuthConcurrencyReleasesOnClose(t *testing.T) {
	manager := NewManager(nil, nil, nil)
	auth := &Auth{ID: "auth-a", Metadata: map[string]any{AttributeMaxConcurrency: float64(1)}}
	release, ok := manager.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("initial acquire failed")
	}
	chunks := make(chan cliproxyexecutor.StreamChunk, 1)
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("ok")}
	close(chunks)
	wrapped := wrapStreamWithAuthConcurrency(context.Background(), &cliproxyexecutor.StreamResult{Chunks: chunks}, release)
	for range wrapped.Chunks {
	}
	releaseAgain, ok := manager.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("stream close did not release concurrency slot")
	}
	releaseAgain()
}

func TestAuthConcurrencyBusyCredentialFallsThrough(t *testing.T) {
	manager := NewManager(nil, nil, nil)
	manager.SetRetryConfig(0, 0, 1)
	executor := &authConcurrencyTestExecutor{started: make(chan string, 2), release: make(chan struct{}, 2)}
	manager.RegisterExecutor(executor)
	limited := &Auth{ID: "a-limited", Provider: executor.Identifier(), Status: StatusActive, Attributes: map[string]string{"priority": "10"}, Metadata: map[string]any{AttributeMaxConcurrency: float64(1)}}
	fallback := &Auth{ID: "z-fallback", Provider: executor.Identifier(), Status: StatusActive}
	for _, auth := range []*Auth{limited, fallback} {
		if _, err := manager.Register(context.Background(), auth); err != nil {
			t.Fatalf("Register(%s): %v", auth.ID, err)
		}
	}

	firstDone := make(chan error, 1)
	go func() {
		_, err := manager.Execute(context.Background(), []string{executor.Identifier()}, cliproxyexecutor.Request{}, cliproxyexecutor.Options{})
		firstDone <- err
	}()
	if got := <-executor.started; got != limited.ID {
		t.Fatalf("first auth = %q, want %q", got, limited.ID)
	}

	secondDone := make(chan error, 1)
	go func() {
		_, err := manager.Execute(context.Background(), []string{executor.Identifier()}, cliproxyexecutor.Request{}, cliproxyexecutor.Options{})
		secondDone <- err
	}()
	if got := <-executor.started; got != fallback.ID {
		t.Fatalf("second auth = %q, want fallback %q", got, fallback.ID)
	}

	executor.release <- struct{}{}
	executor.release <- struct{}{}
	if err := <-firstDone; err != nil {
		t.Fatalf("first Execute(): %v", err)
	}
	if err := <-secondDone; err != nil {
		t.Fatalf("second Execute(): %v", err)
	}
}
