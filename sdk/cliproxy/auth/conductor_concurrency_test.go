package auth

import (
	"context"
	"net/http"
	"testing"

	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

type concurrencyTestExecutor struct {
	started chan string
	release chan struct{}
}

func (e *concurrencyTestExecutor) Identifier() string { return "test" }

func (e *concurrencyTestExecutor) Execute(ctx context.Context, auth *Auth, _ cliproxyexecutor.Request, _ cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	e.started <- auth.ID
	select {
	case <-ctx.Done():
		return cliproxyexecutor.Response{}, ctx.Err()
	case <-e.release:
		return cliproxyexecutor.Response{Payload: []byte(auth.ID)}, nil
	}
}

func (e *concurrencyTestExecutor) ExecuteStream(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (*cliproxyexecutor.StreamResult, error) {
	return nil, nil
}
func (e *concurrencyTestExecutor) Refresh(_ context.Context, auth *Auth) (*Auth, error) {
	return auth, nil
}
func (e *concurrencyTestExecutor) CountTokens(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	return cliproxyexecutor.Response{}, nil
}
func (e *concurrencyTestExecutor) HttpRequest(context.Context, *Auth, *http.Request) (*http.Response, error) {
	return nil, nil
}

func TestManagerAuthConcurrencyFallsBackToAnotherCredential(t *testing.T) {
	m := NewManager(nil, nil, nil)
	m.SetRetryConfig(0, 0, 1)
	executor := &concurrencyTestExecutor{started: make(chan string, 2), release: make(chan struct{}, 2)}
	m.RegisterExecutor(executor)
	limited := &Auth{ID: "limited", Provider: "test", Attributes: map[string]string{AttributeMaxConcurrency: "1"}}
	unlimited := &Auth{ID: "unlimited", Provider: "test"}
	for _, auth := range []*Auth{limited, unlimited} {
		if _, err := m.Register(context.Background(), auth); err != nil {
			t.Fatalf("Register(%s): %v", auth.ID, err)
		}
	}

	firstDone := make(chan error, 1)
	go func() {
		_, err := m.Execute(context.Background(), []string{"test"}, cliproxyexecutor.Request{}, cliproxyexecutor.Options{})
		firstDone <- err
	}()
	if got := <-executor.started; got != limited.ID {
		t.Fatalf("first auth = %q, want %q", got, limited.ID)
	}

	secondDone := make(chan error, 1)
	go func() {
		_, err := m.Execute(context.Background(), []string{"test"}, cliproxyexecutor.Request{}, cliproxyexecutor.Options{})
		secondDone <- err
	}()
	if got := <-executor.started; got != unlimited.ID {
		t.Fatalf("second auth = %q, want %q", got, unlimited.ID)
	}

	executor.release <- struct{}{}
	executor.release <- struct{}{}
	if err := <-firstDone; err != nil {
		t.Fatalf("first execute: %v", err)
	}
	if err := <-secondDone; err != nil {
		t.Fatalf("second execute: %v", err)
	}
}

func TestManagerAuthConcurrencyReturnsRetryable429(t *testing.T) {
	m := NewManager(nil, nil, nil)
	executor := &concurrencyTestExecutor{started: make(chan string, 1), release: make(chan struct{}, 1)}
	m.RegisterExecutor(executor)
	auth := &Auth{ID: "limited", Provider: "test", Attributes: map[string]string{AttributeMaxConcurrency: "1"}}
	if _, err := m.Register(context.Background(), auth); err != nil {
		t.Fatalf("Register: %v", err)
	}
	release, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("initial acquire failed")
	}
	defer release()

	_, ok = m.tryAcquireAuthConcurrency(auth)
	if ok {
		t.Fatal("second acquire succeeded")
	}
	_, errExecute := m.Execute(context.Background(), []string{"test"}, cliproxyexecutor.Request{}, cliproxyexecutor.Options{})
	err, ok := errExecute.(*Error)
	if !ok || err.HTTPStatus != http.StatusTooManyRequests || !err.Retryable || err.Code != "auth_concurrency_exceeded" {
		t.Fatalf("error = %#v", errExecute)
	}
}

func TestWrapStreamWithAuthConcurrencyReleasesOnClose(t *testing.T) {
	m := NewManager(nil, nil, nil)
	auth := &Auth{ID: "limited", Attributes: map[string]string{AttributeMaxConcurrency: "1"}}
	release, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("initial acquire failed")
	}
	chunks := make(chan cliproxyexecutor.StreamChunk, 1)
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("ok")}
	close(chunks)
	wrapped := wrapStreamWithAuthConcurrency(context.Background(), &cliproxyexecutor.StreamResult{Chunks: chunks}, release)
	for range wrapped.Chunks {
	}

	releaseAgain, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("slot was not released after stream close")
	}
	releaseAgain()
}

func TestWrapStreamWithAuthConcurrencyReleasesOnCancel(t *testing.T) {
	m := NewManager(nil, nil, nil)
	auth := &Auth{ID: "limited", Attributes: map[string]string{AttributeMaxConcurrency: "1"}}
	release, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("initial acquire failed")
	}
	ctx, cancel := context.WithCancel(context.Background())
	chunks := make(chan cliproxyexecutor.StreamChunk)
	wrapped := wrapStreamWithAuthConcurrency(ctx, &cliproxyexecutor.StreamResult{Chunks: chunks}, release)
	cancel()
	for range wrapped.Chunks {
	}

	releaseAgain, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("slot was not released after stream cancellation")
	}
	releaseAgain()
}

func TestAuthConcurrencyUsesUpdatedLimitForStableAuthID(t *testing.T) {
	m := NewManager(nil, nil, nil)
	auth := &Auth{ID: "stable", Attributes: map[string]string{AttributeMaxConcurrency: "1"}}
	releaseFirst, ok := m.tryAcquireAuthConcurrency(auth)
	if !ok {
		t.Fatal("initial acquire failed")
	}
	updated := auth.Clone()
	updated.Attributes[AttributeMaxConcurrency] = "2"
	releaseSecond, ok := m.tryAcquireAuthConcurrency(updated)
	if !ok {
		t.Fatal("updated limit was not applied")
	}
	releaseSecond()
	releaseFirst()
}
