package usage

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

const usageSchema = `
CREATE TABLE IF NOT EXISTS usage_records (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	provider TEXT NOT NULL,
	model TEXT NOT NULL,
	api_key TEXT NOT NULL,
	auth_id TEXT NOT NULL,
	auth_index TEXT NOT NULL,
	auth_type TEXT NOT NULL,
	source TEXT NOT NULL,
	requested_at TEXT NOT NULL,
	latency_ms INTEGER NOT NULL,
	first_byte_latency_ms INTEGER NOT NULL,
	thinking_effort TEXT NOT NULL,
	failed INTEGER NOT NULL,
	input_tokens INTEGER NOT NULL,
	output_tokens INTEGER NOT NULL,
	reasoning_tokens INTEGER NOT NULL,
	cached_tokens INTEGER NOT NULL,
	total_tokens INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_usage_records_requested_at ON usage_records(requested_at);
CREATE INDEX IF NOT EXISTS idx_usage_records_api_key ON usage_records(api_key);
CREATE INDEX IF NOT EXISTS idx_usage_records_source ON usage_records(source);
CREATE INDEX IF NOT EXISTS idx_usage_records_provider_model ON usage_records(provider, model);
`

type SQLiteStore struct {
	db *sql.DB
}

func NewSQLiteStore(path string) (*SQLiteStore, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil, errors.New("usage store path is empty")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	store := &SQLiteStore{db: db}
	if err := store.init(); err != nil {
		_ = db.Close()
		return nil, err
	}
	return store, nil
}

func (s *SQLiteStore) init() error {
	if s == nil || s.db == nil {
		return errors.New("usage store is nil")
	}
	_, err := s.db.Exec(usageSchema)
	return err
}

func (s *SQLiteStore) Insert(ctx context.Context, record PersistentRecord) error {
	if s == nil || s.db == nil {
		return errors.New("usage store is nil")
	}
	if record.RequestedAt.IsZero() {
		record.RequestedAt = time.Now()
	}
	record.Tokens = normaliseTokenStats(record.Tokens)
	_, err := s.db.ExecContext(ctx, `
INSERT INTO usage_records (
	provider, model, api_key, auth_id, auth_index, auth_type, source, requested_at,
	latency_ms, first_byte_latency_ms, thinking_effort, failed,
	input_tokens, output_tokens, reasoning_tokens, cached_tokens, total_tokens
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		record.Provider,
		record.Model,
		record.APIKey,
		record.AuthID,
		record.AuthIndex,
		record.AuthType,
		record.Source,
		record.RequestedAt.UTC().Format(time.RFC3339Nano),
		record.LatencyMs,
		record.FirstByteLatencyMs,
		record.ThinkingEffort,
		boolToInt(record.Failed),
		record.Tokens.InputTokens,
		record.Tokens.OutputTokens,
		record.Tokens.ReasoningTokens,
		record.Tokens.CachedTokens,
		record.Tokens.TotalTokens,
	)
	return err
}

func (s *SQLiteStore) Query(ctx context.Context, query QueryRange) ([]PersistentRecord, error) {
	if s == nil || s.db == nil {
		return nil, errors.New("usage store is nil")
	}
	clauses := []string{"1=1"}
	args := make([]any, 0, 8)
	if !query.Start.IsZero() {
		clauses = append(clauses, "requested_at >= ?")
		args = append(args, query.Start.UTC().Format(time.RFC3339Nano))
	}
	if !query.End.IsZero() {
		clauses = append(clauses, "requested_at <= ?")
		args = append(args, query.End.UTC().Format(time.RFC3339Nano))
	}
	if query.APIKey != "" {
		clauses = append(clauses, "api_key = ?")
		args = append(args, query.APIKey)
	}
	if query.Source != "" {
		clauses = append(clauses, "source = ?")
		args = append(args, query.Source)
	}
	if query.Provider != "" {
		clauses = append(clauses, "provider = ?")
		args = append(args, query.Provider)
	}
	if query.Model != "" {
		clauses = append(clauses, "model = ?")
		args = append(args, query.Model)
	}
	stmt := fmt.Sprintf(`
SELECT id, provider, model, api_key, auth_id, auth_index, auth_type, source, requested_at,
	latency_ms, first_byte_latency_ms, thinking_effort, failed,
	input_tokens, output_tokens, reasoning_tokens, cached_tokens, total_tokens
FROM usage_records
WHERE %s
ORDER BY requested_at ASC, id ASC`, strings.Join(clauses, " AND "))
	rows, err := s.db.QueryContext(ctx, stmt, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []PersistentRecord
	for rows.Next() {
		var record PersistentRecord
		var requestedAt string
		var failed int
		if err := rows.Scan(
			&record.ID,
			&record.Provider,
			&record.Model,
			&record.APIKey,
			&record.AuthID,
			&record.AuthIndex,
			&record.AuthType,
			&record.Source,
			&requestedAt,
			&record.LatencyMs,
			&record.FirstByteLatencyMs,
			&record.ThinkingEffort,
			&failed,
			&record.Tokens.InputTokens,
			&record.Tokens.OutputTokens,
			&record.Tokens.ReasoningTokens,
			&record.Tokens.CachedTokens,
			&record.Tokens.TotalTokens,
		); err != nil {
			return nil, err
		}
		timestamp, err := time.Parse(time.RFC3339Nano, requestedAt)
		if err != nil {
			return nil, err
		}
		record.RequestedAt = timestamp
		record.Failed = failed != 0
		record.Tokens = normaliseTokenStats(record.Tokens)
		records = append(records, record)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return records, nil
}

func (s *SQLiteStore) Delete(ctx context.Context, ids []int64) (DeleteResult, error) {
	result := DeleteResult{IDs: sanitizeIDs(ids)}
	if s == nil || s.db == nil {
		return result, errors.New("usage store is nil")
	}
	if len(result.IDs) == 0 {
		return result, nil
	}
	placeholders := make([]string, len(result.IDs))
	args := make([]any, len(result.IDs))
	for i, id := range result.IDs {
		placeholders[i] = "?"
		args[i] = id
	}
	stmt := fmt.Sprintf("DELETE FROM usage_records WHERE id IN (%s)", strings.Join(placeholders, ","))
	execResult, err := s.db.ExecContext(ctx, stmt, args...)
	if err != nil {
		return result, err
	}
	deleted, err := execResult.RowsAffected()
	if err != nil {
		return result, err
	}
	result.Deleted = deleted
	return result, nil
}

func (s *SQLiteStore) Close() error {
	if s == nil || s.db == nil {
		return nil
	}
	return s.db.Close()
}

var defaultStore struct {
	mu    sync.RWMutex
	store Store
}

func InitDefaultStore(path string) error {
	store, err := NewSQLiteStore(path)
	if err != nil {
		return err
	}
	defaultStore.mu.Lock()
	previous := defaultStore.store
	defaultStore.store = store
	defaultStore.mu.Unlock()
	if previous != nil {
		_ = previous.Close()
	}
	return nil
}

func InitDefaultStoreInLogDir(logDir string) error {
	logDir = strings.TrimSpace(logDir)
	if logDir == "" {
		return errors.New("log directory is empty")
	}
	return InitDefaultStore(filepath.Join(logDir, "usage.sqlite"))
}

func SetDefaultStore(store Store) {
	defaultStore.mu.Lock()
	previous := defaultStore.store
	defaultStore.store = store
	defaultStore.mu.Unlock()
	if previous != nil && previous != store {
		_ = previous.Close()
	}
}

func DefaultStore() Store {
	defaultStore.mu.RLock()
	defer defaultStore.mu.RUnlock()
	return defaultStore.store
}

func CloseDefaultStore() error {
	defaultStore.mu.Lock()
	store := defaultStore.store
	defaultStore.store = nil
	defaultStore.mu.Unlock()
	if store == nil {
		return nil
	}
	return store.Close()
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func sanitizeIDs(ids []int64) []int64 {
	seen := make(map[int64]struct{}, len(ids))
	out := make([]int64, 0, len(ids))
	for _, id := range ids {
		if id <= 0 {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}
