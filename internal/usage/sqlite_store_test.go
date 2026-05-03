package usage

import (
	"context"
	"path/filepath"
	"testing"
	"time"
)

func TestSQLiteStoreInsertQueryDelete(t *testing.T) {
	store, err := NewSQLiteStore(filepath.Join(t.TempDir(), "usage.sqlite"))
	if err != nil {
		t.Fatalf("NewSQLiteStore error: %v", err)
	}
	defer store.Close()

	ctx := context.Background()
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	record := PersistentRecord{
		Provider:           "github-copilot",
		Model:              "gpt-5",
		APIKey:             "local-key",
		AuthID:             "auth-1",
		AuthIndex:          "1",
		AuthType:           "oauth",
		Source:             "user@example.com",
		RequestedAt:        now,
		LatencyMs:          123,
		FirstByteLatencyMs: 45,
		ThinkingEffort:     "medium",
		Tokens: TokenStats{
			InputTokens:     10,
			OutputTokens:    20,
			ReasoningTokens: 5,
		},
	}
	if err := store.Insert(ctx, record); err != nil {
		t.Fatalf("Insert error: %v", err)
	}

	records, err := store.Query(ctx, QueryRange{Start: now.Add(-time.Minute), End: now.Add(time.Minute), APIKey: "local-key"})
	if err != nil {
		t.Fatalf("Query error: %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("records len = %d, want 1", len(records))
	}
	got := records[0]
	if got.ID == 0 {
		t.Fatalf("record ID was not populated")
	}
	if got.Tokens.TotalTokens != 35 {
		t.Fatalf("total tokens = %d, want 35", got.Tokens.TotalTokens)
	}
	if got.FirstByteLatencyMs != 45 || got.ThinkingEffort != "medium" {
		t.Fatalf("metadata = (%d, %q), want (45, medium)", got.FirstByteLatencyMs, got.ThinkingEffort)
	}

	snapshot := SnapshotFromPersistentRecords(records)
	if snapshot.TotalRequests != 1 || snapshot.TotalTokens != 35 {
		t.Fatalf("snapshot totals = (%d, %d), want (1, 35)", snapshot.TotalRequests, snapshot.TotalTokens)
	}
	apiSnapshot, ok := snapshot.APIs["local-key"]
	if !ok {
		t.Fatalf("snapshot missing api key")
	}
	if apiSnapshot.Models["gpt-5"].Details[0].ID != got.ID {
		t.Fatalf("snapshot detail ID was not preserved")
	}

	result, err := store.Delete(ctx, []int64{got.ID})
	if err != nil {
		t.Fatalf("Delete error: %v", err)
	}
	if result.Deleted != 1 {
		t.Fatalf("deleted = %d, want 1", result.Deleted)
	}
	records, err = store.Query(ctx, QueryRange{})
	if err != nil {
		t.Fatalf("Query after delete error: %v", err)
	}
	if len(records) != 0 {
		t.Fatalf("records after delete len = %d, want 0", len(records))
	}
}
