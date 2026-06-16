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

<table>
<tbody>
<tr>
<td width="180"><a href="https://www.aicodemirror.com/register?invitecode=TJNAIF"><img src="./assets/aicodemirror.png" alt="AICodeMirror" width="150"></a></td>
<td>Thanks to AICodeMirror for sponsoring this project! AICodeMirror provides official high-stability relay services for Claude Code / Codex / Gemini CLI, with enterprise-grade concurrency, fast invoicing, and 24/7 dedicated technical support. Claude Code / Codex / Gemini official channels at 38% / 2% / 9% of original price, with extra discounts on top-ups! AICodeMirror offers special benefits for CLIProxyAPI users: register via <a href="https://www.aicodemirror.com/register?invitecode=TJNAIF">this link</a> to enjoy 20% off your first top-up, and enterprise customers can get up to 25% off!</td>
</tr>
<tr>
<td width="180"><a href="https://shop.bmoplus.com/?utm_source=github"><img src="./assets/bmoplus.png" alt="BmoPlus" width="150"></a></td>
<td>Huge thanks to BmoPlus for sponsoring this project! BmoPlus is a highly reliable AI account provider built strictly for heavy AI users and developers. They offer rock-solid, ready-to-use accounts and official top-up services for ChatGPT Plus / ChatGPT Pro (Full Warranty) / Claude Pro / Super Grok / Gemini Pro. By registering and ordering through <a href="https://shop.bmoplus.com/?utm_source=github">BmoPlus - Premium AI Accounts & Top-ups</a>, users can unlock the mind-blowing rate of <b>10% of the official GPT subscription price (90% OFF)</b>!</td>
</tr>
<tr>
<td width="180"><a href="https://coder.visioncoder.cn"><img src="./assets/visioncoder.png" alt="VisionCoder" width="150"></a></td>
<td>Thanks to VisionCoder for supporting this project. <a href="https://coder.visioncoder.cn">VisionCoder Developer Platform</a> is a reliable and efficient API relay service provider, offering access to mainstream AI models such as Claude Code, Codex, and Gemini. It helps developers and teams integrate AI capabilities more easily and improve productivity. Additionally, VisionCoder now offers retail channels for <b>Claude Max 200 and GPT Pro 200 premium accounts</b>, providing users with instant access to top-tier AI computing power and features.</td>
</tr>
<tr>
<td width="180"><a href="https://apikey.fun/register?aff=CLIProxyAPI"><img src="./assets/apikey.png" alt="APIKEY.FUN" width="150"></a></td>
<td>Thanks to APIKEY.FUN for sponsoring this project! APIKEY.FUN is a professional enterprise-grade AI relay platform dedicated to providing stable, efficient, and low-cost AI model API access for enterprises and individual developers. The platform supports popular mainstream models such as Claude, OpenAI, and Gemini, with prices as low as 7% of the official price. Register through this project's <a href="https://apikey.fun/register?aff=CLIProxyAPI">exclusive link</a> to enjoy a special <b>permanent 5% top-up discount</b>.</td>
</tr>
<tr>
<td width="180"><a href="https://runapi.co/register?aff=FivD"><img src="./assets/runapi.png" alt="RunAPI" width="150"></a></td>
<td>RunAPI is an efficient and stable API platform—an alternative to OpenRouter. A single API Key gives you access to 150+ leading models, including OpenAI, Claude, Gemini, DeepSeek, Grok, and more, at prices as low as 10% of the original (up to 90% off), with exceptional stability. It's seamlessly compatible with tools like Claude Code, OpenClaw, and others. RunAPI offers an exclusive perk for CPA users: <a href="https://runapi.co/register?aff=FivD">register</a> and contact an administrator to claim ¥7 in free credit.</td>
</tr>
<tr>
<td width="180"><a href="https://unity2.ai/register?source=cliproxyapi"><img src="./assets/unity2.jpg" alt="Unity2" width="150"></a></td>
<td>Thanks to Unity2.ai for sponsoring this project! Unity2.ai is a high-performance AI model API relay platform for individual developers, teams, and enterprises. It has long served leading domestic enterprises, handles more than 30 billion token calls per day, and supports high concurrency at the 5000 RPM level. It supports balance billing, first top-up bonuses, bundled subscriptions, enterprise invoicing, and dedicated integration support. Register through <a href="https://unity2.ai/register?source=cliproxyapi">this link</a> to receive a $2 balance, then join the official group to get another $10 balance, for up to $12 in free credit.</td>
</tr>
<tr>
<td width="180"><a href="https://catapi.ai/sign-up"><img src="./assets/catapi.png" alt="CatAPI" width="150"></a></td>
<td>Cat API is an AI model aggregation platform built for individual developers and teams, integrating leading large language models into a single simple, stable, and easy-to-use entry point. It provides an API fully compatible with OpenAI, Claude, and Gemini that plugs seamlessly into mainstream AI IDEs and coding tools such as Claude Code, Cursor, Windsurf, Cline, Roo Code, Continue, Codex, and Trae, and features dedicated CN2 high-speed routing for low-latency, highly reliable access. <a href="https://catapi.ai/sign-up">Sign up</a> to claim 1$ in free credits.</td>
</tr>
</tbody>
</table>

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
