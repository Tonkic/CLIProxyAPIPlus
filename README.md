# CLIProxyAPI Plus

English | [中文](README_CN.md) | [日本語](README_JA.md)

CLIProxyAPI Plus is a combined distribution built from:

- `router-for-me/CLIProxyAPI`, the upstream proxy server.
- `Tonkic/CLIProxyAPIPlus`, the Plus fork with extra providers and deployment packaging.
- `Willxup/cpa-usage-keeper`, an external usage collector bundled in release archives.
- Local integration code that exposes usage events through a Redis-compatible queue so the proxy and keeper can run together as one product.

The goal is to keep the upstream CLIProxyAPI runtime compatible while adding Plus-specific providers, account management, usage collection, and easy deployment scripts.

## What Is Included

- OpenAI, Gemini, Claude, Codex, Grok, and Responses-compatible HTTP APIs.
- OAuth and token login flows for Codex, Claude, Gemini, Kimi, Antigravity, xAI/Grok, GitHub Copilot, Kiro, Cursor, CodeBuddy, Kilo, iFlow, and GitLab Duo.
- Round-robin and fill-first account selection with model aliases and hot reload.
- Amp CLI and Amp IDE extension routing through provider-specific API paths.
- WebSocket support where supported by the upstream provider.
- Request logging, management APIs, and a browser-based management panel.
- Redis-compatible usage queue for external collectors.
- Release packaging that can run CLIProxyAPI Plus and CPA Usage Keeper together.

## Project Layout

```text
cmd/server/                  CLI entrypoint
internal/api/                Gin server, routes, middleware, management API
internal/api/modules/amp/    Amp-specific routes and reverse proxy helpers
internal/runtime/executor/   Provider executors
internal/translator/         Protocol translators
internal/redisqueue/         Redis-compatible usage queue plugin
sdk/cliproxy/                Embeddable proxy service
sdk/cliproxy/usage/          Usage event manager and plugin interface
keeper/                      CPA Usage Keeper release helper files
docs/                        SDK and provider documentation
```

## Usage Collection

CLIProxyAPI Plus records usage events in the runtime and publishes them through `sdk/cliproxy/usage`. The `internal/redisqueue` plugin serializes each usage record and stores it in an in-memory queue.

The API server accepts Redis RESP connections on the same listening port as the proxy. Consumers authenticate with the management key and read events with `LPOP` or `RPOP`.

CPA Usage Keeper consumes that queue and provides persistent storage and visualization.

Default release wiring:

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA Usage Keeper :8080
```

Configure the proxy:

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

Configure the keeper by copying the sample environment:

```bash
cp keeper/.env.example keeper/.env
```

Important keeper settings:

```env
CPA_BASE_URL=http://127.0.0.1:8317
CPA_MANAGEMENT_KEY=change-me
REDIS_QUEUE_ADDR=127.0.0.1:8317
APP_PORT=8080
```

## Getting Started

Copy the example config and edit it for your accounts and providers:

```bash
cp config.example.yaml config.yaml
```

Run from source:

```bash
go run ./cmd/server --config ./config.yaml
```

Build a local binary:

```bash
go build -o cli-proxy-api-plus ./cmd/server
```

Run the built binary:

```bash
./cli-proxy-api-plus --config ./config.yaml
```

## Running With CPA Usage Keeper

Release archives include short Linux helper scripts and the keeper environment template:

```text
CLIProxyAPIPlus_<version>_linux_<arch>/
|-- cli-proxy-api-plus
|-- config.example.yaml
|-- start.sh
|-- stop.sh
|-- restart.sh
|-- update.sh
`-- keeper/
    |-- cpa-usage-keeper
    `-- .env.example
```

Initial setup:

```bash
cp config.example.yaml config.yaml
cp keeper/.env.example keeper/.env
./start.sh
```

Service control:

```bash
./start.sh
./stop.sh
./restart.sh
```

The helper starts:

- CLIProxyAPI Plus at `http://127.0.0.1:8317`
- CPA Usage Keeper at `http://127.0.0.1:8080`

## Deployment Updates

For private Aliyun OSS mirrors, install and configure `ossutil`, then update with:

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
```

To install only and restart manually:

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com \
  --no-restart

./restart.sh
```

You can also provide OSS settings through environment variables:

```bash
export ALIYUN_OSS_BUCKET=update-cpa-plus
export ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen.aliyuncs.com
export ALIYUN_OSS_PREFIX=CLIProxyAPIPlus
./update.sh --tag v7.1.19.1
```

## Amp CLI Support

CLIProxyAPI Plus supports Amp CLI and Amp IDE extension route shapes:

- `/api/provider/{provider}/v1/messages`
- `/api/provider/{provider}/v1beta/models/...`
- `/api/provider/{provider}/v1/chat/completions`

It also provides management proxy support, model fallback, model mappings, and localhost restrictions for sensitive Amp management routes.

## SDK Docs

- Usage: [docs/sdk-usage.md](docs/sdk-usage.md)
- Advanced executors and translators: [docs/sdk-advanced.md](docs/sdk-advanced.md)
- Access control: [docs/sdk-access.md](docs/sdk-access.md)
- Credential watcher: [docs/sdk-watcher.md](docs/sdk-watcher.md)
- Custom provider example: `examples/custom-provider`

## Build And Test

```bash
gofmt -w .
go build -o test-output ./cmd/server
rm -f test-output
go test ./...
```

## Release

Releases use the upstream CLIProxyAPI version plus a Plus counter, for example `v7.0.6.1`. The release workflow builds Linux and Windows archives for amd64 and arm64 and includes the updater scripts plus CPA Usage Keeper helper files.

## Upstream Projects

- CLIProxyAPI: `https://github.com/router-for-me/CLIProxyAPI`
- CLIProxyAPI Plus: `https://github.com/Tonkic/CLIProxyAPIPlus`
- CPA Usage Keeper: `https://github.com/Willxup/cpa-usage-keeper`

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
