package executor

import (
	"testing"

	"github.com/google/uuid"
	"github.com/tidwall/gjson"
)

func TestEnsureCodexClientMetadataAddsOfficialIdentityFields(t *testing.T) {
	body := ensureCodexClientMetadata([]byte(`{"model":"gpt-5.6-sol","client_metadata":{"custom":"keep"}}`))

	metadata := gjson.GetBytes(body, "client_metadata")
	if metadata.Get("custom").String() != "keep" {
		t.Fatalf("existing client metadata was not preserved: %s", body)
	}

	installationID := metadata.Get("x-codex-installation-id").String()
	sessionID := metadata.Get("session_id").String()
	threadID := metadata.Get("thread_id").String()
	turnID := metadata.Get("turn_id").String()
	for name, value := range map[string]string{
		"installation_id": installationID,
		"session_id":      sessionID,
		"thread_id":       threadID,
		"turn_id":         turnID,
	} {
		if _, err := uuid.Parse(value); err != nil {
			t.Fatalf("%s = %q, want UUID: %v; body=%s", name, value, err, body)
		}
	}

	wantWindowID := sessionID + ":0"
	if got := metadata.Get("x-codex-window-id").String(); got != wantWindowID {
		t.Fatalf("x-codex-window-id = %q, want %q; body=%s", got, wantWindowID, body)
	}

	turnMetadata := metadata.Get("x-codex-turn-metadata").String()
	for path, want := range map[string]string{
		"installation_id": installationID,
		"session_id":      sessionID,
		"thread_id":       threadID,
		"turn_id":         turnID,
		"window_id":       wantWindowID,
		"request_kind":    "turn",
		"thread_source":   "user",
		"sandbox":         "none",
	} {
		if got := gjson.Get(turnMetadata, path).String(); got != want {
			t.Fatalf("turn metadata %s = %q, want %q; metadata=%s", path, got, want, turnMetadata)
		}
	}
	if got := gjson.Get(turnMetadata, "turn_started_at_unix_ms").Int(); got <= 0 {
		t.Fatalf("turn_started_at_unix_ms = %d, want positive; metadata=%s", got, turnMetadata)
	}
}

func TestEnsureCodexClientMetadataPreservesExistingOfficialFields(t *testing.T) {
	body := ensureCodexClientMetadata([]byte(`{"client_metadata":{"x-codex-installation-id":"install-existing","session_id":"session-existing","thread_id":"thread-existing","turn_id":"turn-existing","x-codex-window-id":"window-existing","x-codex-turn-metadata":"{\"turn_id\":\"turn-existing\"}"}}`))

	metadata := gjson.GetBytes(body, "client_metadata")
	for path, want := range map[string]string{
		"x-codex-installation-id": "install-existing",
		"session_id":              "session-existing",
		"thread_id":               "thread-existing",
		"turn_id":                 "turn-existing",
		"x-codex-window-id":       "window-existing",
		"x-codex-turn-metadata":   `{"turn_id":"turn-existing"}`,
	} {
		if got := metadata.Get(path).String(); got != want {
			t.Fatalf("%s = %q, want %q; body=%s", path, got, want, body)
		}
	}
}
