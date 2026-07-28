package auth

import (
	"fmt"
	"strings"

	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

func authAllowedByClientPolicy(authID string, meta map[string]any) bool {
	authID = strings.TrimSpace(authID)
	if authID == "" {
		return false
	}
	if allowed, present := stringSetMetadata(meta, cliproxyexecutor.AllowedAuthIDsMetadataKey); present {
		_, ok := allowed[authID]
		return ok
	}
	excluded, _ := stringSetMetadata(meta, cliproxyexecutor.ExcludedAuthIDsMetadataKey)
	_, blocked := excluded[authID]
	return !blocked
}

// AuthAllowedByClientPolicy reports whether authID satisfies the request-scoped policy.
func (m *Manager) AuthAllowedByClientPolicy(authID string, meta map[string]any) bool {
	return authAllowedByClientPolicy(authID, meta)
}

func stringSetMetadata(meta map[string]any, key string) (map[string]struct{}, bool) {
	if meta == nil {
		return nil, false
	}
	raw, present := meta[key]
	if !present {
		return nil, false
	}
	out := make(map[string]struct{})
	add := func(value string) {
		if value = strings.TrimSpace(value); value != "" {
			out[value] = struct{}{}
		}
	}
	switch values := raw.(type) {
	case []string:
		for _, value := range values {
			add(value)
		}
	case []any:
		for _, value := range values {
			add(fmt.Sprint(value))
		}
	case string:
		add(values)
	case []byte:
		add(string(values))
	}
	return out, true
}
