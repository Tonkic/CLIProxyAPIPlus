# CLIProxyAPI Plus

[English](README.md) | [中文](README_CN.md) | 日本語

CLIProxyAPI Plus は `router-for-me/CLIProxyAPI` の fork で、`https://github.com/Tonkic/CLIProxyAPIPlus` でメンテナンスされています。

この fork は CLIProxyAPI のコアプロキシ動作を維持しつつ、Plus 固有のプラットフォーム対応とリリース配布を中心にしています。

## 機能

- CLI ツール向けの OpenAI/Gemini/Claude/Codex 互換 API エンドポイント
- OpenAI Codex と Claude Code の OAuth ログイン対応
- Plus プラットフォーム対応: GitHub Copilot、Kiro
- Amp CLI と IDE 拡張向けの provider routing 対応
- 対応環境での streaming、non-streaming、WebSocket レスポンス
- function calling / tool calling 対応
- テキストと画像のマルチモーダル入力対応
- Gemini、OpenAI、Claude 互換 provider の複数アカウント round-robin 負荷分散
- Generative Language API Key 対応
- 設定による OpenAI 互換 upstream provider 対応
- プロキシを埋め込むための再利用可能な Go SDK
- CPA Usage Keeper など外部 collector 用の Redis 互換 usage queue

## クイックスタート

サンプル設定をコピーし、アカウントと provider を設定します。

```bash
cp config.example.yaml config.yaml
```

ローカルで実行します。

```bash
./cli-proxy-api-plus -config ./config.yaml
```

ソースから実行する場合:

```bash
go run ./cmd/server --config ./config.yaml
```

## Linux release ディレクトリでのデプロイと更新

Release archive は次のレイアウトです。

```text
CLIProxyAPIPlus_<version>_linux_<arch>/
├─ cli-proxy-api-plus
├─ config.example.yaml
├─ start-plus-with-keeper.sh
├─ update-linux.sh
├─ update-windows.ps1
└─ keeper/
   ├─ cpa-usage-keeper
   └─ .env.example
```

release ディレクトリから tmux で proxy を実行できます。

```bash
tmux new-session -d -s "cli" "cd '/opt/CLIProxyAPIPlus' && './cli-proxy-api-plus' -config './config.yaml' >> './runtime.log' 2>&1"
```

状態とログを確認します。

```bash
tmux ls
tail -n 50 /opt/CLIProxyAPIPlus/runtime.log
```

停止します。

```bash
tmux kill-session -t cli
```

最新の GitHub Release に更新し、tmux session を再起動します。

```bash
cd /opt/CLIProxyAPIPlus
./update-linux.sh
```

特定バージョンをインストール、または再起動せずに更新します。

```bash
./update-linux.sh --tag v6.10.9.1
./update-linux.sh --no-restart
```

デプロイ先ディレクトリ、設定パス、ログパス、tmux session 名が異なる場合は明示的に指定できます。

```bash
./update-linux.sh --install-dir /opt/CLIProxyAPIPlus --session cli --config /opt/CLIProxyAPIPlus/config.yaml --log /opt/CLIProxyAPIPlus/runtime.log
```

Windows では release ディレクトリから PowerShell updater を使用できます。

```powershell
.\update-windows.ps1
.\update-windows.ps1 -Tag v6.10.9.1
.\update-windows.ps1 -NoRestart
```

## 使用量統計

CLIProxyAPI Plus は Redis 互換 usage queue を提供し、外部 collector が消費できます。

永続的な使用量保存と可視化には CPA Usage Keeper を使用してください。

- `https://github.com/Willxup/cpa-usage-keeper`

Release archive には CLIProxyAPI Plus と CPA Usage Keeper を一緒に起動する helper が含まれています。

```bash
cp keeper/.env.example keeper/.env
./start-plus-with-keeper.sh
```

## Amp CLI 対応

CLIProxyAPI Plus は Amp CLI と Amp IDE 拡張に対応しています。

- Amp API パス形式用の provider route alias: `/api/provider/{provider}/v1...`
- OAuth 認証とアカウント機能用の management proxy
- 自動ルーティングと smart model fallback
- 利用できないモデル向けの model mapping
- management sensitive endpoint は localhost のみに制限

特定 backend の protocol shape が必要な場合は provider-specific path を使ってください。

- messages 系 backend: `/api/provider/{provider}/v1/messages`
- model-scoped generate endpoint: `/api/provider/{provider}/v1beta/models/...`
- chat-completions 系 backend: `/api/provider/{provider}/v1/chat/completions`

## SDK ドキュメント

- Usage: [docs/sdk-usage.md](docs/sdk-usage.md)
- Advanced executors and translators: [docs/sdk-advanced.md](docs/sdk-advanced.md)
- Access control: [docs/sdk-access.md](docs/sdk-access.md)
- Credential watcher: [docs/sdk-watcher.md](docs/sdk-watcher.md)
- Custom provider example: `examples/custom-provider`

## ビルド

server binary をビルドします。

```bash
go build -o cli-proxy-api-plus ./cmd/server
```

テストを実行します。

```bash
go test ./...
```

## Release

Versioned release は upstream version に Plus release counter を追加した tag を使います。例: `v6.10.9.1`、`v6.10.9.2`。upstream version が変わると Plus counter はリセットされ、例: `v6.10.10.1` になります。

Release workflow は Linux と Windows の amd64/arm64 archive を作成し、updater scripts と CPA Usage Keeper helper files を含めます。

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
