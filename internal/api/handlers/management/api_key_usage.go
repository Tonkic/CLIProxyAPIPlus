package management

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/router-for-me/CLIProxyAPI/v6/internal/usage"
)

func (h *Handler) GetAPIKeyUsage(c *gin.Context) {
	query, _, err := parseUsageQuery(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
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
	c.JSON(http.StatusOK, usage.APIKeyUsageFromPersistentRecords(records))
}
