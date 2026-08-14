package auth

import (
	"context"
	"net/http"
	"reflect"
	"sync"
	"testing"

	"github.com/router-for-me/CLIProxyAPI/v7/internal/registry"
	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

type codexLifecycleBootstrapExecutor struct {
	mu              sync.Mutex
	calls           []string
	failAfterOutput bool
}

func (*codexLifecycleBootstrapExecutor) Identifier() string { return "codex" }

func (*codexLifecycleBootstrapExecutor) Execute(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	return cliproxyexecutor.Response{}, &Error{Code: "not_implemented", HTTPStatus: http.StatusNotImplemented}
}

func (e *codexLifecycleBootstrapExecutor) ExecuteStream(_ context.Context, auth *Auth, _ cliproxyexecutor.Request, _ cliproxyexecutor.Options) (*cliproxyexecutor.StreamResult, error) {
	e.mu.Lock()
	e.calls = append(e.calls, auth.ID)
	e.mu.Unlock()

	chunks := make(chan cliproxyexecutor.StreamChunk, 8)
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("event: response.created\n")}
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp-" + auth.ID + "\"}}\n\n")}
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("event: response.in_progress\n")}
	chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("data: {\"type\":\"response.in_progress\",\"response\":{\"id\":\"resp-" + auth.ID + "\"}}\n\n")}
	if auth.ID == "auth-a" {
		if e.failAfterOutput {
			chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("event: response.output_text.delta\n")}
			chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}\n\n")}
		}
		chunks <- cliproxyexecutor.StreamChunk{Err: &Error{HTTPStatus: http.StatusServiceUnavailable, Message: `{"error":{"code":"server_is_overloaded","type":"service_unavailable_error"}}`}}
	} else {
		chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("event: response.output_text.delta\n")}
		chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("data: {\"type\":\"response.output_text.delta\",\"delta\":\"ok\"}\n\n")}
		chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("event: response.completed\n")}
		chunks <- cliproxyexecutor.StreamChunk{Payload: []byte("data: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}\n\n")}
	}
	close(chunks)
	return &cliproxyexecutor.StreamResult{Chunks: chunks}, nil
}

func TestManagerExecuteStreamDoesNotRetryCodexFailureAfterOutput(t *testing.T) {
	executor := &codexLifecycleBootstrapExecutor{failAfterOutput: true}
	manager := NewManager(nil, nil, nil)
	manager.RegisterExecutor(executor)
	for _, id := range []string{"auth-a", "auth-b"} {
		if _, err := manager.Register(context.Background(), &Auth{ID: id, Provider: "codex", Status: StatusActive}); err != nil {
			t.Fatalf("Register(%s): %v", id, err)
		}
		registry.GetGlobalRegistry().RegisterClient(id, "codex", []*registry.ModelInfo{{ID: "gpt-test"}})
		t.Cleanup(func() { registry.GetGlobalRegistry().UnregisterClient(id) })
	}

	result, err := manager.ExecuteStream(context.Background(), []string{"codex"}, cliproxyexecutor.Request{Model: "gpt-test"}, cliproxyexecutor.Options{Stream: true})
	if err != nil {
		t.Fatalf("ExecuteStream(): %v", err)
	}
	var payloads []string
	var streamErr error
	for chunk := range result.Chunks {
		if chunk.Err != nil {
			streamErr = chunk.Err
			continue
		}
		payloads = append(payloads, string(chunk.Payload))
	}

	want := []string{
		"event: response.created\n",
		"data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp-auth-a\"}}\n\n",
		"event: response.in_progress\n",
		"data: {\"type\":\"response.in_progress\",\"response\":{\"id\":\"resp-auth-a\"}}\n\n",
		"event: response.output_text.delta\n",
		"data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}\n\n",
	}
	if !reflect.DeepEqual(payloads, want) {
		t.Fatalf("payloads = %#v, want %#v", payloads, want)
	}
	if streamErr == nil {
		t.Fatal("stream error = nil, want terminal overload")
	}
	if got := executor.Calls(); !reflect.DeepEqual(got, []string{"auth-a"}) {
		t.Fatalf("credential attempts = %v, want [auth-a]", got)
	}
}

func (*codexLifecycleBootstrapExecutor) Refresh(_ context.Context, auth *Auth) (*Auth, error) {
	return auth, nil
}

func (*codexLifecycleBootstrapExecutor) CountTokens(context.Context, *Auth, cliproxyexecutor.Request, cliproxyexecutor.Options) (cliproxyexecutor.Response, error) {
	return cliproxyexecutor.Response{}, &Error{Code: "not_implemented", HTTPStatus: http.StatusNotImplemented}
}

func (*codexLifecycleBootstrapExecutor) HttpRequest(context.Context, *Auth, *http.Request) (*http.Response, error) {
	return nil, &Error{Code: "not_implemented", HTTPStatus: http.StatusNotImplemented}
}

func (e *codexLifecycleBootstrapExecutor) Calls() []string {
	e.mu.Lock()
	defer e.mu.Unlock()
	return append([]string(nil), e.calls...)
}

func TestCodexLifecycleBootstrapPayloadRecognizesSSEFraming(t *testing.T) {
	for _, payload := range [][]byte{
		[]byte("event: response.created\n"),
		[]byte("event: response.in_progress\r\n"),
		[]byte("event: response.created\ndata: {\"type\":\"response.created\"}\n\n"),
		[]byte("data: {\"type\":\"response.in_progress\"}\n\n"),
	} {
		if !isCodexLifecycleBootstrapPayload(payload) {
			t.Fatalf("payload not recognized as lifecycle bootstrap: %q", payload)
		}
	}
	for _, payload := range [][]byte{
		[]byte("event: response.output_text.delta\n"),
		[]byte("data: {\"type\":\"response.output_text.delta\",\"delta\":\"ok\"}\n\n"),
	} {
		if isCodexLifecycleBootstrapPayload(payload) {
			t.Fatalf("real output misclassified as lifecycle bootstrap: %q", payload)
		}
	}
}

func TestManagerExecuteStreamRetriesCodexFailureBeforeOutput(t *testing.T) {
	executor := &codexLifecycleBootstrapExecutor{}
	manager := NewManager(nil, nil, nil)
	manager.RegisterExecutor(executor)
	for _, id := range []string{"auth-a", "auth-b"} {
		if _, err := manager.Register(context.Background(), &Auth{ID: id, Provider: "codex", Status: StatusActive}); err != nil {
			t.Fatalf("Register(%s): %v", id, err)
		}
		registry.GetGlobalRegistry().RegisterClient(id, "codex", []*registry.ModelInfo{{ID: "gpt-test"}})
		t.Cleanup(func() { registry.GetGlobalRegistry().UnregisterClient(id) })
	}

	result, err := manager.ExecuteStream(context.Background(), []string{"codex"}, cliproxyexecutor.Request{Model: "gpt-test"}, cliproxyexecutor.Options{Stream: true})
	if err != nil {
		t.Fatalf("ExecuteStream(): %v", err)
	}
	var payloads []string
	for chunk := range result.Chunks {
		if chunk.Err != nil {
			t.Fatalf("unexpected stream error: %v", chunk.Err)
		}
		payloads = append(payloads, string(chunk.Payload))
	}

	want := []string{
		"event: response.created\n",
		"data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp-auth-b\"}}\n\n",
		"event: response.in_progress\n",
		"data: {\"type\":\"response.in_progress\",\"response\":{\"id\":\"resp-auth-b\"}}\n\n",
		"event: response.output_text.delta\n",
		"data: {\"type\":\"response.output_text.delta\",\"delta\":\"ok\"}\n\n",
		"event: response.completed\n",
		"data: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}\n\n",
	}
	if !reflect.DeepEqual(payloads, want) {
		t.Fatalf("payloads = %#v, want %#v", payloads, want)
	}
	if got := executor.Calls(); !reflect.DeepEqual(got, []string{"auth-a", "auth-b"}) {
		t.Fatalf("credential attempts = %v, want [auth-a auth-b]", got)
	}
}
