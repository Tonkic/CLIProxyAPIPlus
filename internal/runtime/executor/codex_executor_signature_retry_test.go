package executor

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	internalcache "github.com/router-for-me/CLIProxyAPI/v7/internal/cache"
	"github.com/router-for-me/CLIProxyAPI/v7/internal/config"
	_ "github.com/router-for-me/CLIProxyAPI/v7/internal/translator"
	cliproxyauth "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/auth"
	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
	sdktranslator "github.com/router-for-me/CLIProxyAPI/v7/sdk/translator"
	"github.com/tidwall/gjson"
)

func TestCodexExecutorRetriesInvalidReasoningSignatureOnce(t *testing.T) {
	bodies, server := newCodexSignatureRetryServer(t, false)
	defer server.Close()

	seedCodexSignatureRetryCache(t, "session-signature-retry")
	executor := NewCodexExecutor(&config.Config{})
	_, err := executor.Execute(context.Background(), codexSignatureRetryAuth(server.URL), codexSignatureRetryRequest("session-signature-retry"), cliproxyexecutor.Options{
		SourceFormat: sdktranslator.FromString("claude"),
		Stream:       false,
	})
	if err != nil {
		t.Fatalf("Execute error: %v", err)
	}

	assertCodexSignatureRetryBodies(t, bodies())
}

func TestCodexExecutorStreamRetriesInvalidReasoningSignatureHTTPErrorOnce(t *testing.T) {
	bodies, server := newCodexSignatureRetryServer(t, false)
	defer server.Close()

	seedCodexSignatureRetryCache(t, "session-signature-stream-retry")
	executor := NewCodexExecutor(&config.Config{})
	result, err := executor.ExecuteStream(context.Background(), codexSignatureRetryAuth(server.URL), codexSignatureRetryRequest("session-signature-stream-retry"), cliproxyexecutor.Options{
		SourceFormat: sdktranslator.FromString("claude"),
		Stream:       true,
	})
	if err != nil {
		t.Fatalf("ExecuteStream error: %v", err)
	}
	for chunk := range result.Chunks {
		if chunk.Err != nil {
			t.Fatalf("stream chunk error: %v", chunk.Err)
		}
	}

	assertCodexSignatureRetryBodies(t, bodies())
}

func TestCodexExecutorInvalidReasoningSignatureRetriesOnlyOnce(t *testing.T) {
	bodies, server := newCodexSignatureRetryServer(t, true)
	defer server.Close()

	seedCodexSignatureRetryCache(t, "session-signature-retry-limit")
	executor := NewCodexExecutor(&config.Config{})
	_, err := executor.Execute(context.Background(), codexSignatureRetryAuth(server.URL), codexSignatureRetryRequest("session-signature-retry-limit"), cliproxyexecutor.Options{
		SourceFormat: sdktranslator.FromString("claude"),
		Stream:       false,
	})
	if err == nil {
		t.Fatal("expected invalid signature error after one retry")
	}
	if got := len(bodies()); got != 2 {
		t.Fatalf("upstream request count = %d, want 2", got)
	}
}

func TestCodexExecutorDoesNotRetryOtherBadRequests(t *testing.T) {
	var mu sync.Mutex
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		mu.Lock()
		requests++
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":{"message":"context length exceeded","type":"invalid_request_error","code":"context_length_exceeded"}}`))
	}))
	defer server.Close()

	seedCodexSignatureRetryCache(t, "session-no-signature-retry")
	executor := NewCodexExecutor(&config.Config{})
	_, err := executor.Execute(context.Background(), codexSignatureRetryAuth(server.URL), codexSignatureRetryRequest("session-no-signature-retry"), cliproxyexecutor.Options{
		SourceFormat: sdktranslator.FromString("claude"),
		Stream:       false,
	})
	if err == nil {
		t.Fatal("expected context length error")
	}
	mu.Lock()
	gotRequests := requests
	mu.Unlock()
	if gotRequests != 1 {
		t.Fatalf("upstream request count = %d, want 1", gotRequests)
	}
}

func newCodexSignatureRetryServer(t *testing.T, alwaysFail bool) (func() [][]byte, *httptest.Server) {
	t.Helper()
	var mu sync.Mutex
	var bodies [][]byte
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Errorf("read request body: %v", err)
			return
		}
		mu.Lock()
		bodies = append(bodies, body)
		attempt := len(bodies)
		mu.Unlock()

		if attempt == 1 || alwaysFail {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"error":{"message":"The encrypted content could not be decrypted or parsed.","type":"invalid_request_error","code":"thinking_signature_invalid"}}`))
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = w.Write([]byte("data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_retry\",\"object\":\"response\",\"created_at\":0,\"status\":\"completed\",\"model\":\"gpt-5.4\",\"output\":[]}}\n\n"))
	}))
	return func() [][]byte {
		mu.Lock()
		defer mu.Unlock()
		return append([][]byte(nil), bodies...)
	}, server
}

func seedCodexSignatureRetryCache(t *testing.T, sessionID string) {
	t.Helper()
	internalcache.ClearCodexReasoningReplayCache()
	t.Cleanup(internalcache.ClearCodexReasoningReplayCache)
	encryptedContent := validCodexReasoningEncryptedContentForTestSeed(42)
	internalcache.CacheCodexReasoningReplayItem("gpt-5.4", "claude:"+sessionID+":agent:main", []byte(`{"id":"rs_provider_a","type":"reasoning","summary":[{"type":"summary_text","text":"cached"}],"encrypted_content":"`+encryptedContent+`"}`))
}

func codexSignatureRetryAuth(baseURL string) *cliproxyauth.Auth {
	return &cliproxyauth.Auth{ID: "auth-signature-retry", Attributes: map[string]string{"base_url": baseURL, "api_key": "test"}}
}

func codexSignatureRetryRequest(sessionID string) cliproxyexecutor.Request {
	return cliproxyexecutor.Request{
		Model:   "gpt-5.4",
		Payload: []byte(`{"model":"gpt-5.4","metadata":{"user_id":"{\"device_id\":\"device-test\",\"account_uuid\":\"\",\"session_id\":\"` + sessionID + `\"}"},"messages":[{"role":"user","content":[{"type":"text","text":"continue"}]}]}`),
	}
}

func assertCodexSignatureRetryBodies(t *testing.T, bodies [][]byte) {
	t.Helper()
	if len(bodies) != 2 {
		t.Fatalf("upstream request count = %d, want 2", len(bodies))
	}
	if got := gjson.GetBytes(bodies[0], "input.0.type").String(); got != "reasoning" {
		t.Fatalf("first request input.0.type = %q, want reasoning; body=%s", got, bodies[0])
	}
	if got := gjson.GetBytes(bodies[0], "input.0.encrypted_content").String(); got == "" {
		t.Fatalf("first request should contain encrypted_content; body=%s", bodies[0])
	}
	if gjson.GetBytes(bodies[1], "input.0.encrypted_content").Exists() {
		t.Fatalf("retry request still contains encrypted_content; body=%s", bodies[1])
	}
	if gjson.GetBytes(bodies[1], "input.0.id").Exists() {
		t.Fatalf("retry request still contains reasoning id; body=%s", bodies[1])
	}
	if got := gjson.GetBytes(bodies[1], "input.0.type").String(); got != "reasoning" {
		t.Fatalf("retry request input.0.type = %q, want reasoning; body=%s", got, bodies[1])
	}
	if got := gjson.GetBytes(bodies[1], "input.1.role").String(); got != "user" {
		t.Fatalf("retry request input.1.role = %q, want user; body=%s", got, bodies[1])
	}
}

func TestStripOpenAIResponsesReasoningStatePreservesRequestShape(t *testing.T) {
	body := []byte(`{"store":false,"include":["reasoning.encrypted_content"],"input":[{"id":"rs_test","type":"reasoning","encrypted_content":"provider-a-ciphertext","summary":[{"type":"summary_text","text":"summary"}]},{"type":"message","role":"user","content":"continue"}]}`)

	got, changed := stripOpenAIResponsesReasoningState(body)
	if !changed {
		t.Fatal("expected reasoning state to be stripped")
	}
	if gjson.GetBytes(got, "input.0.encrypted_content").Exists() || gjson.GetBytes(got, "input.0.id").Exists() {
		t.Fatalf("reasoning state was not removed: %s", got)
	}
	if value := gjson.GetBytes(got, "input.0.summary.0.text").String(); value != "summary" {
		t.Fatalf("summary = %q, want summary; body=%s", value, got)
	}
	if value := gjson.GetBytes(got, "include.0").String(); value != "reasoning.encrypted_content" {
		t.Fatalf("include = %q, want reasoning.encrypted_content; body=%s", value, got)
	}
	if gjson.GetBytes(got, "store").Bool() {
		t.Fatalf("store changed from false: %s", got)
	}
	if value := gjson.GetBytes(got, "input.1.role").String(); value != "user" {
		t.Fatalf("message role = %q, want user; body=%s", value, got)
	}
}

func TestStripOpenAIResponsesReasoningStateLeavesStoredRequestUnchanged(t *testing.T) {
	body := []byte(`{"store":true,"input":[{"id":"rs_test","type":"reasoning","encrypted_content":"provider-a-ciphertext"}]}`)
	got, changed := stripOpenAIResponsesReasoningState(body)
	if changed || string(got) != string(body) {
		t.Fatalf("store=true request changed: changed=%v body=%s", changed, got)
	}
}
