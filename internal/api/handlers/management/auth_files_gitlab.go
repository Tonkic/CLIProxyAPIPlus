package management

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	gitlabauth "github.com/router-for-me/CLIProxyAPI/v7/internal/auth/gitlab"
	coreauth "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/auth"
)

func mergeGitLabDirectAccessMetadata(metadata map[string]any, direct *gitlabauth.DirectAccessResponse) {
	if metadata == nil || direct == nil {
		return
	}
	if base := strings.TrimSpace(direct.BaseURL); base != "" {
		metadata["duo_gateway_base_url"] = base
	}
	if token := strings.TrimSpace(direct.Token); token != "" {
		metadata["duo_gateway_token"] = token
	}
	if direct.ExpiresAt > 0 {
		metadata["duo_gateway_expires_at"] = time.Unix(direct.ExpiresAt, 0).UTC().Format(time.RFC3339)
	}
	if len(direct.Headers) > 0 {
		metadata["duo_gateway_headers"] = direct.Headers
	}
	if direct.ModelDetails != nil {
		if provider := strings.TrimSpace(direct.ModelDetails.ModelProvider); provider != "" {
			metadata["model_provider"] = provider
		}
		if model := strings.TrimSpace(direct.ModelDetails.ModelName); model != "" {
			metadata["model_name"] = model
		}
	}
}

func primaryGitLabEmail(user *gitlabauth.User) string {
	if user == nil {
		return ""
	}
	if email := strings.TrimSpace(user.Email); email != "" {
		return email
	}
	return strings.TrimSpace(user.PublicEmail)
}

func gitLabAccountIdentifier(user *gitlabauth.User) string {
	if user != nil {
		for _, value := range []string{user.Username, primaryGitLabEmail(user), user.Name} {
			if value = strings.TrimSpace(value); value != "" {
				return value
			}
		}
	}
	return "user"
}

func sanitizeGitLabFileName(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	var builder strings.Builder
	lastDash := false
	for _, r := range value {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '-' || r == '_' || r == '.' {
			builder.WriteRune(r)
			lastDash = false
		} else if !lastDash {
			builder.WriteByte('-')
			lastDash = true
		}
	}
	if result := strings.Trim(builder.String(), "-"); result != "" {
		return result
	}
	return "user"
}

func maskGitLabToken(token string) string {
	token = strings.TrimSpace(token)
	if len(token) <= 8 {
		return token
	}
	return token[:4] + "..." + token[len(token)-4:]
}

// RequestGitLabPATToken validates and stores a GitLab personal access token.
func (h *Handler) RequestGitLabPATToken(c *gin.Context) {
	ctx := PopulateAuthContext(context.Background(), c)
	var payload struct {
		BaseURL             string `json:"base_url"`
		PersonalAccessToken string `json:"personal_access_token"`
		Token               string `json:"token"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "error": "invalid body"})
		return
	}
	baseURL := gitlabauth.NormalizeBaseURL(payload.BaseURL)
	pat := strings.TrimSpace(payload.PersonalAccessToken)
	if pat == "" {
		pat = strings.TrimSpace(payload.Token)
	}
	if pat == "" {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "error": "personal_access_token is required"})
		return
	}
	client := gitlabauth.NewAuthClient(h.cfg)
	user, err := client.GetCurrentUser(ctx, baseURL, pat)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "error": err.Error()})
		return
	}
	patSelf, err := client.GetPersonalAccessTokenSelf(ctx, baseURL, pat)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "error": err.Error()})
		return
	}
	direct, err := client.FetchDirectAccess(ctx, baseURL, pat)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": "error", "error": err.Error()})
		return
	}
	identifier := gitLabAccountIdentifier(user)
	fileName := fmt.Sprintf("gitlab-%s-pat.json", sanitizeGitLabFileName(identifier))
	metadata := map[string]any{
		"type": "gitlab", "auth_method": "pat", "auth_kind": "personal_access_token",
		"base_url": baseURL, "personal_access_token": pat, "token_preview": maskGitLabToken(pat),
		"username": strings.TrimSpace(user.Username), "name": strings.TrimSpace(user.Name),
		"last_refresh": time.Now().UTC().Format(time.RFC3339), "refresh_interval_seconds": 240,
	}
	if email := primaryGitLabEmail(user); email != "" {
		metadata["email"] = email
	}
	if patSelf != nil {
		metadata["pat_name"] = strings.TrimSpace(patSelf.Name)
		metadata["pat_scopes"] = append([]string(nil), patSelf.Scopes...)
	}
	mergeGitLabDirectAccessMetadata(metadata, direct)
	record := &coreauth.Auth{ID: fileName, Provider: "gitlab", FileName: fileName, Label: identifier + " (PAT)", Metadata: metadata}
	savedPath, err := h.saveTokenRecord(ctx, record)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": "error", "error": "failed to save authentication tokens"})
		return
	}
	response := gin.H{"status": "ok", "saved_path": savedPath, "username": strings.TrimSpace(user.Username), "email": primaryGitLabEmail(user), "token_label": identifier}
	if direct != nil && direct.ModelDetails != nil {
		response["model_provider"] = strings.TrimSpace(direct.ModelDetails.ModelProvider)
		response["model_name"] = strings.TrimSpace(direct.ModelDetails.ModelName)
	}
	c.JSON(http.StatusOK, response)
}
