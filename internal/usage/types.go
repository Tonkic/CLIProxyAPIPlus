package usage

import (
	"context"
	"time"
)

type PersistentRecord struct {
	ID                 int64      `json:"id"`
	Provider           string     `json:"provider"`
	Model              string     `json:"model"`
	APIKey             string     `json:"api_key"`
	AuthID             string     `json:"auth_id,omitempty"`
	AuthIndex          string     `json:"auth_index,omitempty"`
	AuthType           string     `json:"auth_type,omitempty"`
	Source             string     `json:"source"`
	RequestedAt        time.Time  `json:"requested_at"`
	LatencyMs          int64      `json:"latency_ms"`
	FirstByteLatencyMs int64      `json:"first_byte_latency_ms,omitempty"`
	ThinkingEffort     string     `json:"thinking_effort,omitempty"`
	Failed             bool       `json:"failed"`
	Tokens             TokenStats `json:"tokens"`
}

type QueryRange struct {
	Start    time.Time
	End      time.Time
	APIKey   string
	Source   string
	Provider string
	Model    string
}

type DeleteResult struct {
	Deleted int64   `json:"deleted"`
	IDs     []int64 `json:"ids"`
}

type APIUsage map[string]map[string][]RequestDetail

type APIKeyUsageSnapshot struct {
	APIKeys map[string]APIKeyUsage `json:"api_keys"`
}

type APIKeyUsage struct {
	TotalRequests int64                    `json:"total_requests"`
	SuccessCount  int64                    `json:"success_count"`
	FailureCount  int64                    `json:"failure_count"`
	TotalTokens   int64                    `json:"total_tokens"`
	Models        map[string]ModelSnapshot `json:"models"`
}

type Store interface {
	Insert(ctx context.Context, record PersistentRecord) error
	Query(ctx context.Context, query QueryRange) ([]PersistentRecord, error)
	Delete(ctx context.Context, ids []int64) (DeleteResult, error)
	Close() error
}
