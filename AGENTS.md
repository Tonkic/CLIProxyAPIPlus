# AGENTS.md

Go 1.26+ proxy server providing OpenAI/Gemini/Claude/Codex-compatible APIs with OAuth, multi-provider routing, round-robin load balancing, and Redis-compatible usage export for CPA Usage Keeper.

## Repository

- Upstream core: https://github.com/router-for-me/CLIProxyAPI
- Plus fork: https://github.com/Tonkic/CLIProxyAPIPlus
- Usage collector bundled in releases: https://github.com/Willxup/cpa-usage-keeper

## Commands

```bash
gofmt -w .
go build -o cli-proxy-api ./cmd/server
go run ./cmd/server --config ./config.yaml
go test ./...
go test -v -run TestName ./path/to/pkg
go build -o test-output ./cmd/server && rm test-output
```

Common flags: `--config <path>`, `--tui`, `--standalone`, `--local-model`, `--no-browser`, `--oauth-callback-port <port>`.

## Config

- Default config: `config.yaml`; template: `config.example.yaml`.
- `.env` is auto-loaded from the working directory.
- Auth material defaults under `auths/` or the configured `auth-dir`.
- Optional storage backends: Postgres, git, object store via `PGSTORE_*`, `GITSTORE_*`, `OBJECTSTORE_*`.
- Usage export is controlled by `usage-statistics-enabled` and `redis-usage-queue-retention-seconds`.

## Architecture

- `cmd/server/`: CLI entrypoint and login/server mode selection.
- `internal/api/`: Gin HTTP API, middleware, management API, protocol multiplexer.
- `internal/api/modules/amp/`: Amp route aliases and reverse proxy support.
- `internal/redisqueue/`: Redis-compatible in-memory usage queue consumed by CPA Usage Keeper.
- `internal/runtime/executor/`: provider executors and executor tests.
- `internal/runtime/executor/helps/`: shared executor helpers, including usage reporting.
- `internal/thinking/`: canonical thinking config pipeline. Keep the architecture as canonical representation to provider-specific translation.
- `internal/translator/`: provider protocol translators and shared translator infrastructure.
- `internal/registry/`: model registry and remote model updater.
- `internal/store/`: storage implementations and secret resolution.
- `internal/managementasset/`: management panel assets and config snapshots.
- `internal/watcher/`: config/auth hot reload and granular auth update dispatch.
- `internal/wsrelay/`: WebSocket relay sessions.
- `sdk/cliproxy/`: embeddable proxy service, builder, watchers, and runtime pipeline.
- `sdk/cliproxy/usage/`: usage event manager and plugin interface.
- `keeper/`: release helper files for CPA Usage Keeper.
- `test/`: cross-module integration tests.

## Code Conventions

- Keep changes small and simple.
- Comments in Go code should be English. If editing code that contains non-English comments, translate them.
- For user-visible strings, keep the language already used in that file or area.
- New Markdown docs should be English unless the file is explicitly language-specific, such as `README_CN.md`.
- Do not use `log.Fatal` or `log.Fatalf`; return errors or log through logrus.
- Use logrus structured logging and avoid leaking secrets or tokens.
- Avoid panics in HTTP handlers; prefer logged errors and meaningful HTTP status codes.
- Run `gofmt` after Go changes.
- Verify compile after changes with `go build -o test-output ./cmd/server`, then remove `test-output`.

## Sensitive Areas

- Avoid standalone changes to `internal/translator/` unless required as part of broader runtime changes.
- `internal/runtime/executor/` should contain executors and tests only; put shared helpers under `internal/runtime/executor/helps/`.
- Timeouts are allowed during credential acquisition. After an upstream connection is established, avoid adding network timeouts except for the documented WebSocket/session/management utility exceptions already in the codebase.
