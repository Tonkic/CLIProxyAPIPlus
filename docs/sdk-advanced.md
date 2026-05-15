# SDK Advanced: Executors And Translators

This guide explains how to extend the embedded proxy with custom providers and schemas using the SDK.

The examples use Go 1.26+ and the `/v7` module path.

## Concepts

- Provider executor: a runtime component implementing `auth.ProviderExecutor` that performs outbound calls for a provider key such as `gemini`, `claude`, or `codex`.
- Request preparer: an optional executor capability used to inject credentials into raw HTTP requests.
- Translator registry: schema conversion functions routed by `sdk/translator`.
- Model registry: model metadata used by `/v1/models` and routing hints.

## Implement A Provider Executor

```go
package myprov

import (
    "context"
    "net/http"

    coreauth "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/auth"
    clipexec "github.com/router-for-me/CLIProxyAPI/v7/sdk/cliproxy/executor"
)

type Executor struct{}

func (Executor) Identifier() string { return "myprov" }

func (Executor) PrepareRequest(req *http.Request, a *coreauth.Auth) error {
    req.Header.Set("Authorization", "Bearer "+a.APIKey)
    return nil
}

func (Executor) Execute(ctx context.Context, a *coreauth.Auth, req clipexec.Request, opts clipexec.Options) (clipexec.Response, error) {
    return clipexec.Response{Payload: []byte(`{"ok":true}`)}, nil
}

func (Executor) ExecuteStream(ctx context.Context, a *coreauth.Auth, req clipexec.Request, opts clipexec.Options) (<-chan clipexec.StreamChunk, error) {
    ch := make(chan clipexec.StreamChunk, 1)
    go func() {
        defer close(ch)
        ch <- clipexec.StreamChunk{Payload: []byte("data: {\"done\":true}\n\n")}
    }()
    return ch, nil
}

func (Executor) Refresh(ctx context.Context, a *coreauth.Auth) (*coreauth.Auth, error) {
    return a, nil
}
```

Register the executor before starting the service:

```go
core := coreauth.NewManager(coreauth.NewFileStore(cfg.AuthDir), nil, nil)
core.RegisterExecutor(myprov.Executor{})
svc, _ := cliproxy.NewBuilder().WithConfig(cfg).WithConfigPath(cfgPath).WithCoreAuthManager(core).Build()
```

## Register Translators

Direction matters: requests convert from inbound schema to provider schema, and responses convert from provider schema back to inbound schema.

```go
package myprov

import (
    "context"
    sdktr "github.com/router-for-me/CLIProxyAPI/v7/sdk/translator"
)

const (
    FOpenAI = sdktr.Format("openai.chat")
    FMyProv = sdktr.Format("myprov.chat")
)

func init() {
    sdktr.Register(FOpenAI, FMyProv,
        func(model string, raw []byte, stream bool) []byte { return convertOpenAIToMyProv(model, raw, stream) },
        sdktr.ResponseTransform{
            Stream: func(ctx context.Context, model string, originalReq, translatedReq, raw []byte, param *any) []string {
                return convertStreamMyProvToOpenAI(model, originalReq, translatedReq, raw)
            },
            NonStream: func(ctx context.Context, model string, originalReq, translatedReq, raw []byte, param *any) string {
                return convertMyProvToOpenAI(model, originalReq, translatedReq, raw)
            },
        },
    )
}
```

## Register Models

```go
models := []*cliproxy.ModelInfo{
    {ID: "myprov-pro-1", Object: "model", Type: "myprov", DisplayName: "MyProv Pro 1"},
}
cliproxy.GlobalModelRegistry().RegisterClient(authID, "myprov", models)
```

## Testing Tips

- Enable request logging through the Management API.
- Toggle debug logs through the Management API.
- Verify hot reload by editing `config.yaml` or files under `auths/`.
