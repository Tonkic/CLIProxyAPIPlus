# CLIProxyAPI Plus

English | [中文](README_CN.md) | [日本語](README_JA.md)

CLIProxyAPI Plus is a combined distribution built from:

- `router-for-me/CLIProxyAPI`, the upstream proxy server.
- `Tonkic/CLIProxyAPIPlus`, the Plus fork with extra providers and deployment packaging.
- `seakee/CPA-Manager-Plus`, an external management and usage dashboard bundled in release archives.
- Local integration code that exposes usage events through a Redis-compatible queue so the proxy and manager can run together as one product.

The goal is to keep the upstream CLIProxyAPI runtime compatible while adding Plus-specific providers, account management, usage collection, and easy deployment scripts.

## What Is Included

- OpenAI, Gemini, Claude, Codex, Grok, and Responses-compatible HTTP APIs.
- OAuth and token login flows for Codex, Claude, Gemini, Kimi, Antigravity, xAI/Grok, GitHub Copilot, Kiro, Cursor, CodeBuddy, Kilo, iFlow, and GitLab Duo.
- Round-robin and fill-first account selection with model aliases and hot reload.
- Amp CLI and Amp IDE extension routing through provider-specific API paths.
- WebSocket support where supported by the upstream provider.
- Request logging, management APIs, and a browser-based management panel.
- Redis-compatible usage queue for external collectors.
- Release packaging that can run CLIProxyAPI Plus and CPA-Manager-Plus together.

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
manager/                     CPA-Manager-Plus binary and persistent data
docs/                        SDK and provider documentation
```

## Usage Collection

CLIProxyAPI Plus records usage events in the runtime and publishes them through `sdk/cliproxy/usage`. The `internal/redisqueue` plugin serializes each usage record and stores it in an in-memory queue.

The API server accepts Redis RESP connections on the same listening port as the proxy. Consumers authenticate with the management key and read events with `LPOP` or `RPOP`.

CPA-Manager-Plus consumes that queue and provides persistent storage, service management, and visualization.

Default release wiring:

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA-Manager-Plus :18317
```

Configure the proxy:

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

After the first start, open `http://SERVER_IP:18317/management.html`. Use the generated CPA-Manager-Plus admin key, then add CLIProxyAPI Plus with URL `http://127.0.0.1:8317` and the configured management key. The manager defaults to `USAGE_COLLECTOR_MODE=auto`.

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

## Running With CPA-Manager-Plus

Release archives include short Linux helper scripts and the CPA-Manager-Plus binary:

```text
CLIProxyAPIPlus_<version>_linux_<arch>/
|-- cli-proxy-api-plus
|-- config.example.yaml
|-- start.sh
|-- stop.sh
|-- restart.sh
|-- update.sh
`-- manager/
    `-- cpa-manager-plus
```

Initial setup:

```bash
cp config.example.yaml config.yaml
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
- CPA-Manager-Plus at `http://127.0.0.1:18317`

On its first run, CPA-Manager-Plus prints a generated `cpamp_...` admin key. Read it from:

```bash
tail -n 200 logs/cpa-manager-plus.out.log
tail -n 200 logs/cpa-manager-plus.err.log
```

The manager keeps persistent state in `manager/data/` and `manager/config.json`. Back up `manager/data/usage.sqlite*` and `manager/data/data.key`. Updates replace only the manager binary and preserve these files.

When upgrading from a Keeper-based release, `restart.sh` stops the legacy `keeper` tmux session but leaves the entire `keeper/` directory untouched. Do not run Keeper and CPA-Manager-Plus at the same time because both consume the same in-memory usage queue. Their SQLite schemas are incompatible, so historical Keeper data must be exported and imported rather than copied over the manager database.

Keeper-based releases use an older updater. Before the first migration, replace it with the standalone updater mirrored to OSS:

```bash
ossutil cp \
  oss://update-cpa-plus/CLIProxyAPIPlus/v7.2.80.2/update.sh \
  ./update.sh.new \
  -f -e oss-cn-shenzhen.aliyuncs.com
chmod +x ./update.sh.new
mv -f ./update.sh.new ./update.sh
```

## Deployment Updates

For private Aliyun OSS mirrors, install and configure `ossutil`, then update with:

```bash
./update.sh \
  --tag v7.2.80.2 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
```

To install only and restart manually:

```bash
./update.sh \
  --tag v7.2.80.2 \
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
./update.sh --tag v7.2.80.2
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

Releases use the upstream CLIProxyAPI version plus a Plus counter, for example `v7.0.6.1`. The release workflow builds Linux and Windows archives for amd64 and arm64 and includes the updater scripts plus the matching CPA-Manager-Plus binary.

## Upstream Projects

- CLIProxyAPI: `https://github.com/router-for-me/CLIProxyAPI`
- CLIProxyAPI Plus: `https://github.com/Tonkic/CLIProxyAPIPlus`
- CPA-Manager-Plus: `https://github.com/seakee/CPA-Manager-Plus`

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
