# CLIProxyAPI Plus

[English](README.md) | [中文](README_CN.md) | 日本語

CLIProxyAPI Plus は、単一プロジェクトの単純な fork ではなく、複数のプロジェクトとローカル統合コードを組み合わせた配布版です。

- `router-for-me/CLIProxyAPI`: 上流のプロキシサーバー本体。
- `Tonkic/CLIProxyAPIPlus`: 追加 provider、ログイン機能、配布パッケージを含む Plus fork。
- `Willxup/cpa-usage-keeper`: 使用量の保存と可視化を行う外部 collector。release パッケージではバイナリとして同梱されます。
- このリポジトリの統合コード: proxy の usage event を Redis 互換 queue として公開し、proxy と keeper を一緒に動かせるようにします。

目的は、上流 CLIProxyAPI との互換性を保ちながら、Plus 固有の provider、多アカウント管理、使用量収集、簡単なデプロイを提供することです。

## 機能

- OpenAI、Gemini、Claude、Codex、Grok、Responses 互換 API。
- Codex、Claude、Gemini、Kimi、Antigravity、xAI/Grok、GitHub Copilot、Kiro、Cursor、CodeBuddy、Kilo、iFlow、GitLab Duo などのログインまたは token 接続。
- round-robin / fill-first のアカウント選択、model alias、hot reload。
- Amp CLI と Amp IDE extension 用の provider route。
- 対応 provider での WebSocket。
- request log、Management API、管理パネル。
- 外部 collector が消費できる Redis 互換 usage queue。
- CLIProxyAPI Plus と CPA Usage Keeper をまとめて起動できる release helper。

## 構成

```text
cmd/server/                  CLI entrypoint
internal/api/                Gin server, routes, middleware, Management API
internal/api/modules/amp/    Amp routes and reverse proxy helpers
internal/runtime/executor/   provider executors
internal/translator/         protocol translators
internal/redisqueue/         Redis-compatible usage queue plugin
sdk/cliproxy/                embeddable proxy service
sdk/cliproxy/usage/          usage event manager and plugin interface
keeper/                      CPA Usage Keeper release helper files
docs/                        SDK and provider documentation
```

## 使用量収集

CLIProxyAPI Plus は runtime で usage record を生成し、`sdk/cliproxy/usage` から publish します。`internal/redisqueue` plugin は record を JSON に変換し、memory queue に保存します。

API server は proxy と同じ port で Redis RESP 接続も受け付けます。consumer は management key で認証し、`LPOP` または `RPOP` で event を読み取ります。


CPA Usage Keeper はこの queue を消費し、永続化と可視化を行います。

既定の構成:

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA Usage Keeper :8080
```

proxy config:

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

keeper config:

```bash
cp keeper/.env.example keeper/.env
```

重要な環境変数:

```env
CPA_BASE_URL=http://127.0.0.1:8317
CPA_MANAGEMENT_KEY=change-me
REDIS_QUEUE_ADDR=127.0.0.1:8317
APP_PORT=8080
```

## Quick Start

```bash
cp config.example.yaml config.yaml
go run ./cmd/server --config ./config.yaml
```

Build:

```bash
go build -o cli-proxy-api-plus ./cmd/server
./cli-proxy-api-plus --config ./config.yaml
```

## CPA Usage Keeper と一緒に起動

release archive には短い Linux helper scripts と keeper env template が含まれます。

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

起動されるサービス:

- CLIProxyAPI Plus: `http://127.0.0.1:8317`
- CPA Usage Keeper: `http://127.0.0.1:8080`

## Update

Private Aliyun OSS mirror から更新する場合は、server に `ossutil` を設定してから実行します。

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
```

Install only, then restart manually:

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com \
  --no-restart

./restart.sh
```

## Amp CLI Support

- `/api/provider/{provider}/v1/messages`
- `/api/provider/{provider}/v1beta/models/...`
- `/api/provider/{provider}/v1/chat/completions`

management proxy、model fallback、model mapping、sensitive Amp management route の localhost 制限も含まれます。

## Build And Test

```bash
gofmt -w .
go build -o test-output ./cmd/server
rm -f test-output
go test ./...
```

## Upstream Projects

- CLIProxyAPI: `https://github.com/router-for-me/CLIProxyAPI`
- CLIProxyAPI Plus: `https://github.com/Tonkic/CLIProxyAPIPlus`
- CPA Usage Keeper: `https://github.com/Willxup/cpa-usage-keeper`

## License

MIT License。詳細は [LICENSE](LICENSE) を参照してください。
