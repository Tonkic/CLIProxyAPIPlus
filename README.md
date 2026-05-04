# CLIProxyAPI Plus

English | [中文](README_CN.md) | [日本語](README_JA.md)

CLIProxyAPI Plus is a fork of `router-for-me/CLIProxyAPI` maintained at `https://github.com/Tonkic/CLIProxyAPIPlus`.

This fork keeps the core CLIProxyAPI proxy behavior and focuses on Plus-specific platform support and deployment packaging.

## Features

- OpenAI/Gemini/Claude/Codex compatible API endpoints for CLI tools
- OAuth login support for OpenAI Codex and Claude Code
- Plus platform support for GitHub Copilot and Kiro
- Amp CLI and IDE extension provider routing support
- Streaming, non-streaming, and WebSocket responses where supported
- Function calling/tools support
- Multimodal input support with text and images
- Multiple accounts with round-robin load balancing for Gemini, OpenAI, and Claude-compatible providers
- Generative Language API key support
- OpenAI-compatible upstream providers via config
- Reusable Go SDK for embedding the proxy
- Redis-compatible usage queue for external usage collectors such as CPA Usage Keeper

## Getting started

Copy the example config and edit it for your accounts and providers:

```bash
cp config.example.yaml config.yaml
```

Run locally:

```bash
./cli-proxy-api-plus -config ./config.yaml
```

Or from source:

```bash
go run ./cmd/server --config ./config.yaml
```

## Linux release-directory deployment and updates

A release archive uses this layout:

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

A simple tmux deployment can run the proxy from the release directory:

```bash
tmux new-session -d -s "cli" "cd '/opt/CLIProxyAPIPlus' && './cli-proxy-api-plus' -config './config.yaml' >> './runtime.log' 2>&1"
```

Check status and logs:

```bash
tmux ls
tail -n 50 /opt/CLIProxyAPIPlus/runtime.log
```

Stop the service:

```bash
tmux kill-session -t cli
```

Update to the latest GitHub Release and restart the tmux session:

```bash
cd /opt/CLIProxyAPIPlus
./update-linux.sh
```

Install a specific version, or update without restarting:

```bash
./update-linux.sh --tag v6.10.9.1
./update-linux.sh --no-restart
```

If your deployment uses a different directory, config path, log path, or tmux session name, pass explicit options:

```bash
./update-linux.sh --install-dir /opt/CLIProxyAPIPlus --session cli --config /opt/CLIProxyAPIPlus/config.yaml --log /opt/CLIProxyAPIPlus/runtime.log
```

On Windows, use the PowerShell updater from the release directory:

```powershell
.\update-windows.ps1
.\update-windows.ps1 -Tag v6.10.9.1
.\update-windows.ps1 -NoRestart
```

## Usage statistics

CLIProxyAPI Plus exposes a Redis-compatible usage queue that can be consumed by external collectors.

For persistent usage storage and visualization, use CPA Usage Keeper:

- `https://github.com/Willxup/cpa-usage-keeper`

The release archive includes helper files for running CLIProxyAPI Plus together with CPA Usage Keeper:

```bash
cp keeper/.env.example keeper/.env
./start-plus-with-keeper.sh
```

## Amp CLI support

CLIProxyAPI Plus includes integrated support for Amp CLI and Amp IDE extensions:

- Provider route aliases for Amp API patterns: `/api/provider/{provider}/v1...`
- Management proxy for OAuth authentication and account features
- Smart model fallback with automatic routing
- Model mapping for unavailable models
- Localhost-only management endpoints for management-sensitive routes

Use provider-specific paths when you need a specific backend protocol shape:

- `/api/provider/{provider}/v1/messages` for messages-style backends
- `/api/provider/{provider}/v1beta/models/...` for model-scoped generate endpoints
- `/api/provider/{provider}/v1/chat/completions` for chat-completions backends

## SDK docs

- Usage: [docs/sdk-usage.md](docs/sdk-usage.md)
- Advanced executors and translators: [docs/sdk-advanced.md](docs/sdk-advanced.md)
- Access control: [docs/sdk-access.md](docs/sdk-access.md)
- Credential watcher: [docs/sdk-watcher.md](docs/sdk-watcher.md)
- Custom provider example: `examples/custom-provider`

## Build

Build the server binary:

```bash
go build -o cli-proxy-api-plus ./cmd/server
```

Run tests:

```bash
go test ./...
```

## Release

Versioned releases use the upstream version plus a Plus release counter, for example `v6.10.9.1` and `v6.10.9.2`. When the upstream version changes, the Plus counter resets, for example `v6.10.10.1`.

The release workflow builds Linux and Windows archives for amd64 and arm64, and includes the updater scripts plus CPA Usage Keeper helper files.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
