# CLI Proxy SDK Guide

The `sdk/cliproxy` module exposes CLIProxyAPI Plus as a reusable Go library. External programs can embed routing, authentication, hot-reload, translators, provider executors, and usage publishing without shelling out to the CLI binary.

## Install And Import

```bash
go get github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy
```

```go
import (
    "context"
    "errors"

    "github.com/router-for-me/CLIProxyAPI/v7/internal/config"
    "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy"
)
```

Note the `/v7` module path.

## Minimal Embed

```go
cfg, err := config.LoadConfig("config.yaml")
if err != nil { panic(err) }

svc, err := cliproxy.NewBuilder().
    WithConfig(cfg).
    WithConfigPath("config.yaml").
    Build()
if err != nil { panic(err) }

ctx, cancel := context.WithCancel(context.Background())
defer cancel()

if err := svc.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
    panic(err)
}
```

The service manages config/auth watching, background token refresh, usage publishing, and graceful shutdown.

## Server Options

Use `WithServerOptions` to add middleware, mutate the Gin engine, add routes, or override request logging:

```go
svc, _ := cliproxy.NewBuilder().
    WithConfig(cfg).
    WithConfigPath("config.yaml").
    WithServerOptions(
        cliproxy.WithMiddleware(func(c *gin.Context) { c.Header("X-Embed", "1"); c.Next() }),
        cliproxy.WithRouterConfigurator(func(e *gin.Engine, _ *handlers.BaseAPIHandler, _ *config.Config) {
            e.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })
        }),
    ).
    Build()
```

## Management API

Management endpoints are mounted only when `remote-management.secret-key` is set. Remote access additionally requires `remote-management.allow-remote: true`. The API is served under `/v0/management`.

## Usage Publishing

Runtime usage records are published through `sdk/cliproxy/usage`. The built-in `internal/redisqueue` plugin consumes those records and exposes them through the Redis-compatible queue used by CPA Usage Keeper.

## Custom Client Sources

You can replace credential loaders if your auth material lives outside the local filesystem:

```go
type memoryTokenProvider struct{}
func (p *memoryTokenProvider) Load(ctx context.Context, cfg *config.Config) (*cliproxy.TokenClientResult, error) {
    return &cliproxy.TokenClientResult{}, nil
}

svc, _ := cliproxy.NewBuilder().
    WithConfig(cfg).
    WithConfigPath("config.yaml").
    WithTokenClientProvider(&memoryTokenProvider{}).
    Build()
```

## Shutdown

`Run` defers `Shutdown`, so cancelling the parent context is enough. To stop manually, call `svc.Shutdown(ctx)` with a bounded context.
