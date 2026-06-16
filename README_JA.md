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

<table>
<tbody>
<tr>
<td width="180"><a href="https://www.aicodemirror.com/register?invitecode=TJNAIF"><img src="./assets/aicodemirror.png" alt="AICodeMirror" width="150"></a></td>
<td>AICodeMirrorのスポンサーシップに感謝します！AICodeMirrorはClaude Code / Codex / Gemini CLI向けの公式高安定性リレーサービスを提供しており、エンタープライズグレードの同時接続、迅速な請求書発行、24時間365日の専任技術サポートを備えています。Claude Code / Codex / Geminiの公式チャネルが元の価格の38% / 2% / 9%で利用でき、チャージ時にはさらに割引があります！CLIProxyAPIユーザー向けの特別特典：<a href="https://www.aicodemirror.com/register?invitecode=TJNAIF">こちらのリンク</a>から登録すると、初回チャージが20%割引になり、エンタープライズのお客様は最大25%割引を受けられます！</td>
</tr>
<tr>
<td width="180"><a href="https://shop.bmoplus.com/?utm_source=github"><img src="./assets/bmoplus.png" alt="BmoPlus" width="150"></a></td>
<td>本プロジェクトにご支援いただいた BmoPlus に感謝いたします！BmoPlusは、AIサブスクリプションのヘビーユーザー向けに特化した信頼性の高いAIアカウントサービスプロバイダーであり、安定した ChatGPT Plus / ChatGPT Pro (完全保証) / Claude Pro / Super Grok / Gemini Pro の公式代行チャージおよび即納アカウントを提供しています。こちらの<a href="https://shop.bmoplus.com/?utm_source=github">BmoPlus AIアカウント専門店/代行チャージ</a>経由でご登録・ご注文いただいたユーザー様は、GPTを <b>公式サイト価格の約1割（90% OFF）</b> という驚異的な価格でご利用いただけます！</td>
</tr>
<tr>
<td width="180"><a href="https://coder.visioncoder.cn"><img src="./assets/visioncoder.png" alt="VisionCoder" width="150"></a></td>
<td>VisionCoderのご支援に感謝します。<a href="https://coder.visioncoder.cn">VisionCoder 開発プラットフォーム</a> は、信頼性が高く効率的なAPIリレーサービスプロバイダーで、Claude Code、Codex、Geminiなどの主要AIモデルを提供し、開発者やチームがより簡単にAI機能を統合して生産性を向上できるよう支援します。さらに、VisionCoderは <b>Claude Max 200 と GPT Pro 200 高級即納アカウント</b> の独占販売チャネルを提供しており、最高クラスのAI算力と体験を手軽に体験できます。</td>
</tr>
<tr>
<td width="180"><a href="https://apikey.fun/register?aff=CLIProxyAPI"><img src="./assets/apikey.png" alt="APIKEY.FUN" width="150"></a></td>
<td>APIKEY.FUNのスポンサーシップに感謝します！APIKEY.FUNはプロフェッショナルなエンタープライズ向けAIリレーサービスで、企業および個人開発者に安定・高効率・低コストなAIモデルAPI接続サービスを提供しています。Claude、OpenAI、Geminiなどの主要人気モデルに対応し、価格は公式価格の7%から利用できます。本プロジェクトの<a href="https://apikey.fun/register?aff=CLIProxyAPI">専用リンク</a>から登録すると、さらに<b>チャージが永続的に5%割引</b>となる特別優待を受けられます。</td>
</tr>
<tr>
<td width="180"><a href="https://runapi.co/register?aff=FivD"><img src="./assets/runapi.png" alt="RunAPI" width="150"></a></td>
<td>RunAPIは高効率で安定したAPIプラットフォームで、OpenRouterの代替として利用できます。1つのAPI KeyでOpenAI、Claude、Gemini、DeepSeek、Grokなど150以上の主要モデルにアクセスでき、価格は公式価格の10%から、非常に安定しており、Claude Code、OpenClawなどのツールとシームレスに互換性があります。RunAPIはCPAユーザー向けに特別特典を提供しています：<a href="https://runapi.co/register?aff=FivD">登録</a>後に管理者へ連絡すると、7元分の無料クレジットを受け取れます。</td>
</tr>
<tr>
<td width="180"><a href="https://unity2.ai/register?source=cliproxyapi"><img src="./assets/unity2.jpg" alt="Unity2" width="150"></a></td>
<td>Unity2.aiのスポンサーシップに感謝します！Unity2.aiは、個人開発者、チーム、企業向けの高性能AIモデルAPIリレープラットフォームです。国内の大手企業に長期的にサービスを提供し、1日あたり300億tokenを超える呼び出しを処理し、5000 RPM級の高同時実行に対応しています。残高課金、初回チャージ特典、組み合わせサブスクリプション、企業向け請求書発行、専任サポートに対応しています。<a href="https://unity2.ai/register?source=cliproxyapi">こちらのリンク</a>から登録すると$2の残高を受け取れ、公式グループに参加するとさらに$10の残高が付与され、最大$12の無料クレジットを受け取れます。</td>
</tr>
<tr>
<td width="180"><a href="https://catapi.ai/sign-up"><img src="./assets/catapi.png" alt="CatAPI" width="150"></a></td>
<td>Cat APIは、個人開発者やチーム向けのAI大規模モデル集約プラットフォームです。主要な大規模モデルの機能を、シンプルで安定した使いやすい入口に統合することを目指しています。OpenAI、Claude、Geminiと完全互換のAPIを提供し、Claude Code、Cursor、Windsurf、Cline、Roo Code、Continue、Codex、Traeなどの主要なAI IDEやプログラミングツールへシームレスに接続できます。また、CN2高速回線を主な特徴としており、低遅延で高安定なアクセス体験を提供します。<a href="https://catapi.ai/sign-up">登録</a>すると、1$の無料クレジットを受け取れます。</td>
</tr>
</tbody>
</table>

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
