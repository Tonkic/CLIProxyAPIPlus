package config

import "testing"

func TestParseConfigBytesAPIKeyAuthBindings(t *testing.T) {
	cfg, err := ParseConfigBytes([]byte(`
api-keys:
  - sk-public
  - sk-team
api-key-auth-bindings:
  - api-keys:
      - sk-team
    auth-ids:
      - team-a.json
      - team-b.json
`))
	if err != nil {
		t.Fatalf("ParseConfigBytes() error = %v", err)
	}
	if len(cfg.APIKeyAuthBindings) != 1 {
		t.Fatalf("binding count = %d, want 1", len(cfg.APIKeyAuthBindings))
	}
	binding := cfg.APIKeyAuthBindings[0]
	if len(binding.APIKeys) != 1 || binding.APIKeys[0] != "sk-team" {
		t.Fatalf("binding API keys = %#v", binding.APIKeys)
	}
	if len(binding.AuthIDs) != 2 || binding.AuthIDs[0] != "team-a.json" || binding.AuthIDs[1] != "team-b.json" {
		t.Fatalf("binding auth IDs = %#v", binding.AuthIDs)
	}
}

func TestCloneForRuntimeDeepCopiesAPIKeyAuthBindings(t *testing.T) {
	cfg := &Config{SDKConfig: SDKConfig{APIKeyAuthBindings: []APIKeyAuthBinding{{
		APIKeys: []string{"sk-team"},
		AuthIDs: []string{"team-a.json"},
	}}}}
	clone := cfg.CloneForRuntime()
	clone.APIKeyAuthBindings[0].APIKeys[0] = "changed"
	clone.APIKeyAuthBindings[0].AuthIDs[0] = "changed.json"
	if cfg.APIKeyAuthBindings[0].APIKeys[0] != "sk-team" || cfg.APIKeyAuthBindings[0].AuthIDs[0] != "team-a.json" {
		t.Fatalf("CloneForRuntime shared binding slices with source: %#v", cfg.APIKeyAuthBindings)
	}
}
