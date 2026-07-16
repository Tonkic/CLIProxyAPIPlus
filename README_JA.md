# CLIProxyAPI Plus

[English](README.md) | [中文](README_CN.md) | 日本語

CLIProxyAPI Plus は、単一プロジェクトの単純な fork ではなく、複数のプロジェクトとローカル統合コードを組み合わせた配布版です。

- `router-for-me/CLIProxyAPI`: 上流のプロキシサーバー本体。
- `Tonkic/CLIProxyAPIPlus`: 追加 provider、ログイン機能、配布パッケージを含む Plus fork。
- `seakee/CPA-Manager-Plus`: 管理機能と使用量 dashboard を提供する外部アプリケーション。release パッケージではバイナリとして同梱されます。
- このリポジトリの統合コード: proxy の usage event を Redis 互換 queue として公開し、proxy と manager を一緒に動かせるようにします。

目的は、上流 CLIProxyAPI との互換性を保ちながら、Plus 固有の provider、多アカウント管理、使用量収集、簡単なデプロイを提供することです。

## 機能

- OpenAI、Gemini、Claude、Codex、Grok、Responses 互換 API。
- Codex、Claude、Gemini、Kimi、Antigravity、xAI/Grok、GitHub Copilot、Kiro、Cursor、CodeBuddy、Kilo、iFlow、GitLab Duo などのログインまたは token 接続。
- round-robin / fill-first のアカウント選択、model alias、hot reload。
- Amp CLI と Amp IDE extension 用の provider route。
- 対応 provider での WebSocket。
- request log、Management API、管理パネル。
- 外部 collector が消費できる Redis 互換 usage queue。
- CLIProxyAPI Plus と CPA-Manager-Plus をまとめて起動できる release helper。

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
manager/                     CPA-Manager-Plus binary and persistent data
docs/                        SDK and provider documentation
```

## 使用量収集

CLIProxyAPI Plus は runtime で usage record を生成し、`sdk/cliproxy/usage` から publish します。`internal/redisqueue` plugin は record を JSON に変換し、memory queue に保存します。

API server は proxy と同じ port で Redis RESP 接続も受け付けます。consumer は management key で認証し、`LPOP` または `RPOP` で event を読み取ります。

CPA-Manager-Plus はこの queue を消費し、永続化、service management、可視化を行います。

既定の構成:

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA-Manager-Plus :18317
```

proxy config:

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

初回起動後、`http://SERVER_IP:18317/management.html` を開きます。自動生成された CPA-Manager-Plus admin key でログインし、CLIProxyAPI Plus の URL に `http://127.0.0.1:8317`、key に CPA の management key を設定します。manager は既定で `USAGE_COLLECTOR_MODE=auto` を使用します。

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

## CPA-Manager-Plus と一緒に起動

release archive には短い Linux helper scripts と CPA-Manager-Plus binary が含まれます。

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

起動されるサービス:

- CLIProxyAPI Plus: `http://127.0.0.1:8317`
- CPA-Manager-Plus: `http://127.0.0.1:18317`

CPA-Manager-Plus は初回起動時に `cpamp_...` admin key を生成します。次の log で確認できます。

```bash
tail -n 200 logs/cpa-manager-plus.out.log
tail -n 200 logs/cpa-manager-plus.err.log
```

manager の永続データは `manager/data/` と `manager/config.json` に保存されます。`manager/data/usage.sqlite*` と `manager/data/data.key` を backup してください。update script は manager binary のみを置き換え、これらのファイルを保持します。

Keeper を含む旧 release から更新する場合、`restart.sh` は旧 `keeper` tmux session を停止しますが、`keeper/` directory は削除しません。同じ usage queue を消費するため、Keeper と CPA-Manager-Plus を同時に実行しないでください。SQLite schema は互換性がないため、履歴データは database file のコピーではなく export/import が必要です。

## Update

Private Aliyun OSS mirror から更新する場合は、server に `ossutil` を設定してから実行します。

```bash
./update.sh \
  --tag v7.2.80.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
```

Install only, then restart manually:

```bash
./update.sh \
  --tag v7.2.80.1 \
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
- CPA-Manager-Plus: `https://github.com/seakee/CPA-Manager-Plus`

## License

MIT License。詳細は [LICENSE](LICENSE) を参照してください。
