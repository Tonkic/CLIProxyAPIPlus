package auth

import (
	"context"
	"net/http"
	"testing"
	"time"

	cliproxyexecutor "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

func TestSessionAffinityPerCredentialOptOutDoesNotBind(t *testing.T) {
	selector := NewSessionAffinitySelectorWithConfig(SessionAffinityConfig{
		Fallback:       &RoundRobinSelector{},
		TTL:            time.Minute,
		DefaultEnabled: boolPointer(true),
	})
	defer selector.Stop()

	auths := []*Auth{
		{ID: "opt-out", Attributes: map[string]string{AttributeSessionAffinity: "false"}},
		{ID: "sticky"},
	}
	opts := cliproxyexecutor.Options{Headers: http.Header{"X-Session-Id": []string{"per-key-opt-out"}}, Metadata: map[string]any{}}

	first, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("first Pick: %v", err)
	}
	second, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("second Pick: %v", err)
	}
	third, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("third Pick: %v", err)
	}
	if first.ID != "opt-out" || second.ID != "sticky" || third.ID != "sticky" {
		t.Fatalf("selection sequence = %q, %q, %q; want opt-out, sticky, sticky", first.ID, second.ID, third.ID)
	}
}

func TestSessionAffinityPerCredentialOptInOverridesGlobalDisabled(t *testing.T) {
	selector := NewSessionAffinitySelectorWithConfig(SessionAffinityConfig{
		Fallback:       &RoundRobinSelector{},
		TTL:            time.Minute,
		DefaultEnabled: boolPointer(false),
	})
	defer selector.Stop()

	auths := []*Auth{
		{ID: "a-opt-in", Attributes: map[string]string{AttributeSessionAffinity: "true"}},
		{ID: "z-inherits-disabled"},
	}
	opts := cliproxyexecutor.Options{Headers: http.Header{"X-Session-Id": []string{"per-key-opt-in"}}, Metadata: map[string]any{}}

	first, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("first Pick: %v", err)
	}
	second, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("second Pick: %v", err)
	}
	if first.ID != "a-opt-in" || second.ID != "a-opt-in" {
		t.Fatalf("selection sequence = %q, %q; want opt-in twice", first.ID, second.ID)
	}
}

func TestSessionAffinityHotOptOutInvalidatesExistingBinding(t *testing.T) {
	selector := NewSessionAffinitySelector(&RoundRobinSelector{})
	defer selector.Stop()

	authA := &Auth{ID: "auth-a"}
	authB := &Auth{ID: "auth-b"}
	auths := []*Auth{authA, authB}
	opts := cliproxyexecutor.Options{Headers: http.Header{"X-Session-Id": []string{"hot-opt-out"}}, Metadata: map[string]any{}}

	first, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil || first.ID != authA.ID {
		t.Fatalf("first Pick = %#v, %v; want auth-a", first, err)
	}
	authA.Attributes = map[string]string{AttributeSessionAffinity: "false"}
	second, err := selector.Pick(context.Background(), "test", "model", opts, auths)
	if err != nil {
		t.Fatalf("second Pick: %v", err)
	}
	if second.ID != authB.ID {
		t.Fatalf("second Pick = %q, want auth-b after hot opt-out", second.ID)
	}
}
