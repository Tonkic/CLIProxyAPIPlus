package config

import "testing"

func TestSanitizeCodexKeysNormalizesNegativeMaxConcurrency(t *testing.T) {
	cfg := &Config{CodexKey: []CodexKey{{
		APIKey:         "test-key",
		BaseURL:        "https://example.com",
		MaxConcurrency: -1,
	}}}
	cfg.SanitizeCodexKeys()
	if got := cfg.CodexKey[0].MaxConcurrency; got != 0 {
		t.Fatalf("MaxConcurrency = %d, want 0", got)
	}
}
