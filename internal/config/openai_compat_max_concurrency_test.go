package config

import "testing"

func TestSanitizeOpenAICompatibilityNormalizesNegativeMaxConcurrency(t *testing.T) {
	cfg := &Config{OpenAICompatibility: []OpenAICompatibility{{
		Name:    "test",
		BaseURL: "https://example.invalid/v1",
		APIKeyEntries: []OpenAICompatibilityAPIKey{{
			APIKey:         "key",
			MaxConcurrency: -1,
		}},
	}}}
	cfg.SanitizeOpenAICompatibility()
	if got := cfg.OpenAICompatibility[0].APIKeyEntries[0].MaxConcurrency; got != 0 {
		t.Fatalf("MaxConcurrency = %d, want 0", got)
	}
}
