package executor

import (
	"time"

	"github.com/google/uuid"
	"github.com/tidwall/gjson"
	"github.com/tidwall/sjson"
)

// ensureCodexClientMetadata fills the client identity fields emitted by the
// official Codex client while preserving metadata supplied by the caller.
func ensureCodexClientMetadata(body []byte) []byte {
	installationID := codexClientMetadataValue(body, "x-codex-installation-id", uuid.NewString())
	sessionID := codexClientMetadataValue(body, "session_id", uuid.NewString())
	threadID := codexClientMetadataValue(body, "thread_id", sessionID)
	turnID := codexClientMetadataValue(body, "turn_id", uuid.NewString())
	windowID := codexClientMetadataValue(body, "x-codex-window-id", sessionID+":0")

	turnMetadata := gjson.GetBytes(body, "client_metadata.x-codex-turn-metadata").String()
	if turnMetadata == "" {
		turnMetadata = `{}`
		turnMetadata, _ = sjson.Set(turnMetadata, "installation_id", installationID)
		turnMetadata, _ = sjson.Set(turnMetadata, "session_id", sessionID)
		turnMetadata, _ = sjson.Set(turnMetadata, "thread_id", threadID)
		turnMetadata, _ = sjson.Set(turnMetadata, "turn_id", turnID)
		turnMetadata, _ = sjson.Set(turnMetadata, "window_id", windowID)
		turnMetadata, _ = sjson.Set(turnMetadata, "request_kind", "turn")
		turnMetadata, _ = sjson.Set(turnMetadata, "thread_source", "user")
		turnMetadata, _ = sjson.Set(turnMetadata, "sandbox", "none")
		turnMetadata, _ = sjson.Set(turnMetadata, "turn_started_at_unix_ms", time.Now().UnixMilli())
		body, _ = sjson.SetBytes(body, "client_metadata.x-codex-turn-metadata", turnMetadata)
	}

	body = setCodexClientMetadataIfMissing(body, "x-codex-installation-id", installationID)
	body = setCodexClientMetadataIfMissing(body, "session_id", sessionID)
	body = setCodexClientMetadataIfMissing(body, "thread_id", threadID)
	body = setCodexClientMetadataIfMissing(body, "turn_id", turnID)
	body = setCodexClientMetadataIfMissing(body, "x-codex-window-id", windowID)
	return body
}

func codexClientMetadataValue(body []byte, key, fallback string) string {
	if value := gjson.GetBytes(body, "client_metadata."+key).String(); value != "" {
		return value
	}
	return fallback
}

func setCodexClientMetadataIfMissing(body []byte, key, value string) []byte {
	path := "client_metadata." + key
	if gjson.GetBytes(body, path).Exists() {
		return body
	}
	body, _ = sjson.SetBytes(body, path, value)
	return body
}
