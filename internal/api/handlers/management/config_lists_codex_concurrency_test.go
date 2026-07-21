package management

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/router-for-me/CLIProxyAPI/v7/internal/config"
)

func TestPatchCodexKeyMaxConcurrency(t *testing.T) {
	h := &Handler{
		cfg: &config.Config{CodexKey: []config.CodexKey{{
			APIKey:  "sharedchat-key",
			BaseURL: "https://new.sharedchat.cc/codex",
		}}},
		configFilePath: writeTestConfigFile(t),
	}

	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = httptest.NewRequest(http.MethodPatch, "/v0/management/codex-api-key", strings.NewReader(`{"index":0,"value":{"max-concurrency":1}}`))
	c.Request.Header.Set("Content-Type", "application/json")

	h.PatchCodexKey(c)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	if got := h.cfg.CodexKey[0].MaxConcurrency; got != 1 {
		t.Fatalf("MaxConcurrency = %d, want 1", got)
	}
}
