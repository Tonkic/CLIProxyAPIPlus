package management

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/router-for-me/CLIProxyAPI/v6/internal/usage"
)

type usageExportPayload struct {
	Version    int                      `json:"version"`
	ExportedAt time.Time                `json:"exported_at"`
	Usage      usage.StatisticsSnapshot `json:"usage"`
}

type usageImportPayload struct {
	Version int                      `json:"version"`
	Usage   usage.StatisticsSnapshot `json:"usage"`
}

// GetUsageStatistics returns usage statistics while preserving the legacy response wrapper.
func (h *Handler) GetUsageStatistics(c *gin.Context) {
	var snapshot usage.StatisticsSnapshot
	query, hasRange, err := parseUsageQuery(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if hasRange {
		store := usage.DefaultStore()
		if store == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "usage store unavailable"})
			return
		}
		records, err := store.Query(c.Request.Context(), query)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to query usage"})
			return
		}
		snapshot = usage.SnapshotFromPersistentRecords(records)
	} else if h != nil && h.usageStats != nil {
		snapshot = h.usageStats.Snapshot()
	}
	c.JSON(http.StatusOK, gin.H{
		"usage":           snapshot,
		"failed_requests": snapshot.FailureCount,
	})
}

func (h *Handler) DeleteUsageStatistics(c *gin.Context) {
	store := usage.DefaultStore()
	if store == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "usage store unavailable"})
		return
	}
	var payload struct {
		IDs []int64 `json:"ids"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	result, err := store.Delete(c.Request.Context(), payload.IDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete usage records"})
		return
	}
	c.JSON(http.StatusOK, result)
}

func parseUsageQuery(c *gin.Context) (usage.QueryRange, bool, error) {
	var query usage.QueryRange
	var filtered bool
	if start := strings.TrimSpace(c.Query("start")); start != "" {
		parsed, err := parseUsageTime(start)
		if err != nil {
			return query, false, err
		}
		query.Start = parsed
		filtered = true
	}
	if end := strings.TrimSpace(c.Query("end")); end != "" {
		parsed, err := parseUsageTime(end)
		if err != nil {
			return query, false, err
		}
		query.End = parsed
		filtered = true
	}
	query.APIKey = strings.TrimSpace(c.Query("api_key"))
	query.Source = strings.TrimSpace(c.Query("source"))
	query.Provider = strings.TrimSpace(c.Query("provider"))
	query.Model = strings.TrimSpace(c.Query("model"))
	if query.APIKey != "" || query.Source != "" || query.Provider != "" || query.Model != "" {
		filtered = true
	}
	return query, filtered, nil
}

func parseUsageTime(value string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339Nano, value); err == nil {
		return parsed, nil
	}
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed, nil
	}
	if unix, err := strconv.ParseInt(value, 10, 64); err == nil {
		if unix > 1_000_000_000_000 {
			return time.UnixMilli(unix), nil
		}
		return time.Unix(unix, 0), nil
	}
	return time.Time{}, &usageTimeParseError{value: value}
}

type usageTimeParseError struct {
	value string
}

func (e *usageTimeParseError) Error() string {
	return "invalid usage time: " + e.value
}

// ExportUsageStatistics returns a complete usage snapshot for backup/migration.
func (h *Handler) ExportUsageStatistics(c *gin.Context) {
	var snapshot usage.StatisticsSnapshot
	if h != nil && h.usageStats != nil {
		snapshot = h.usageStats.Snapshot()
	}
	c.JSON(http.StatusOK, usageExportPayload{
		Version:    1,
		ExportedAt: time.Now().UTC(),
		Usage:      snapshot,
	})
}

// ImportUsageStatistics merges a previously exported usage snapshot into memory.
func (h *Handler) ImportUsageStatistics(c *gin.Context) {
	if h == nil || h.usageStats == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "usage statistics unavailable"})
		return
	}

	data, err := c.GetRawData()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read request body"})
		return
	}

	var payload usageImportPayload
	if err := json.Unmarshal(data, &payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	if payload.Version != 0 && payload.Version != 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported version"})
		return
	}

	result := h.usageStats.MergeSnapshot(payload.Usage)
	snapshot := h.usageStats.Snapshot()
	c.JSON(http.StatusOK, gin.H{
		"added":           result.Added,
		"skipped":         result.Skipped,
		"total_requests":  snapshot.TotalRequests,
		"failed_requests": snapshot.FailureCount,
	})
}
