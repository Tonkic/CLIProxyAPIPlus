# SDK Access Reference

The `github.com/router-for-me/CLIProxyAPI/v7/sdk/access` package centralizes inbound request authentication. It chains credential providers so embedded servers can reuse the same access control logic as the CLI runtime.

## Importing

```go
import (
    sdkaccess "github.com/router-for-me/CLIProxyAPI/v7/sdk/access"
)
```

Install with:

```bash
go get github.com/router-for-me/CLIProxyAPI/v7/sdk/access
```

## Provider Registry

- `RegisterProvider(type, provider)` installs a provider instance.
- Registration order is preserved.
- `RegisteredProviders()` returns providers in registration order.

## Manager Lifecycle

```go
manager := sdkaccess.NewManager()
manager.SetProviders(sdkaccess.RegisteredProviders())
```

If the manager is nil or has no providers, authentication is treated as disabled.

## Authenticating Requests

```go
result, authErr := manager.Authenticate(ctx, req)
switch {
case authErr == nil:
    _ = result
case sdkaccess.IsAuthErrorCode(authErr, sdkaccess.AuthErrorCodeNoCredentials):
    // no recognizable credentials
case sdkaccess.IsAuthErrorCode(authErr, sdkaccess.AuthErrorCodeInvalidCredential):
    // credentials were rejected
default:
    // internal auth failure
}
```

## Built-In Provider

`config-api-key` validates API keys declared under top-level `api-keys`.

Accepted credential sources include:

- `Authorization: Bearer`
- `X-Goog-Api-Key`
- `X-Api-Key`
- `?key=`
- `?auth_token=`

```yaml
api-keys:
  - sk-test-123
  - sk-prod-456
```

## Custom Providers

```go
type customProvider struct{}

func (p *customProvider) Identifier() string { return "my-provider" }

func (p *customProvider) Authenticate(ctx context.Context, r *http.Request) (*sdkaccess.Result, *sdkaccess.AuthError) {
    token := r.Header.Get("X-Custom")
    if token == "" {
        return nil, sdkaccess.NewNotHandledError()
    }
    if token != "expected" {
        return nil, sdkaccess.NewInvalidCredentialError()
    }
    return &sdkaccess.Result{Provider: p.Identifier(), Principal: "service-user"}, nil
}

func init() {
    sdkaccess.RegisterProvider("custom", &customProvider{})
}
```

## Hot Reload

When config changes, refresh config-backed providers and reset the manager chain. This mirrors `internal/access.ApplyAccessProviders`.
