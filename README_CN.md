# CLIProxyAPI Plus

[English](README.md) | 中文 | [日本語](README_JA.md)

CLIProxyAPI Plus 是 `router-for-me/CLIProxyAPI` 的 fork，由 `https://github.com/Tonkic/CLIProxyAPIPlus` 维护。

本 fork 保留 CLIProxyAPI 的核心代理行为，并聚焦 Plus 版本的平台支持和发布部署体验。

## 功能特性

- 为 CLI 工具提供 OpenAI/Gemini/Claude/Codex 兼容 API 端点
- 支持 OpenAI Codex 和 Claude Code OAuth 登录
- Plus 平台支持：GitHub Copilot、Kiro
- 支持 Amp CLI 和 IDE 扩展的 provider routing
- 支持流式、非流式响应，以及受支持场景下的 WebSocket 响应
- 支持函数调用/工具调用
- 支持文本和图片多模态输入
- 支持 Gemini、OpenAI、Claude 兼容 provider 的多账户轮询负载均衡
- 支持 Generative Language API Key
- 支持通过配置接入 OpenAI 兼容上游 provider
- 提供可复用 Go SDK，便于嵌入代理能力
- 提供 Redis 兼容 usage queue，可对接 CPA Usage Keeper 等外部使用量采集器

## 快速开始

复制示例配置并按需填写账号和 provider：

```bash
cp config.example.yaml config.yaml
```

本地运行：

```bash
./cli-proxy-api-plus -config ./config.yaml
```

或从源码运行：

```bash
go run ./cmd/server --config ./config.yaml
```

## Linux release 目录部署与更新

Release 压缩包使用以下布局：

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

可以从 release 目录用 tmux 运行代理：

```bash
tmux new-session -d -s "cli" "cd '/opt/CLIProxyAPIPlus' && './cli-proxy-api-plus' -config './config.yaml' >> './runtime.log' 2>&1"
```

查看状态和日志：

```bash
tmux ls
tail -n 50 /opt/CLIProxyAPIPlus/runtime.log
```

停止服务：

```bash
tmux kill-session -t cli
```

更新到最新 GitHub Release 并重启 tmux 会话：

```bash
cd /opt/CLIProxyAPIPlus
./update-linux.sh
```

安装指定版本，或只更新不重启：

```bash
./update-linux.sh --tag v6.10.9.1
./update-linux.sh --no-restart
```

如果你的部署目录、配置路径、日志路径或 tmux session 名不同，可以显式传参：

```bash
./update-linux.sh --install-dir /opt/CLIProxyAPIPlus --session cli --config /opt/CLIProxyAPIPlus/config.yaml --log /opt/CLIProxyAPIPlus/runtime.log
```

Windows 可以在 release 目录使用 PowerShell updater：

```powershell
.\update-windows.ps1
.\update-windows.ps1 -Tag v6.10.9.1
.\update-windows.ps1 -NoRestart
```

## 使用量统计

CLIProxyAPI Plus 提供 Redis 兼容 usage queue，可供外部采集器消费。

如果需要持久化使用量存储和可视化，使用 CPA Usage Keeper：

- `https://github.com/Willxup/cpa-usage-keeper`

Release 压缩包包含同时运行 CLIProxyAPI Plus 和 CPA Usage Keeper 的辅助文件：

```bash
cp keeper/.env.example keeper/.env
./start-plus-with-keeper.sh
```

## Amp CLI 支持

CLIProxyAPI Plus 内置 Amp CLI 和 Amp IDE 扩展支持：

- Amp API 路径模式的 provider route alias：`/api/provider/{provider}/v1...`
- 用于 OAuth 认证和账号功能的 management proxy
- 自动路由和智能模型 fallback
- 不可用模型的 model mapping
- management 敏感端点限制为 localhost

当你需要特定后端协议形态时，优先使用 provider-specific 路径：

- messages 风格后端：`/api/provider/{provider}/v1/messages`
- model-scoped generate 端点：`/api/provider/{provider}/v1beta/models/...`
- chat-completions 风格后端：`/api/provider/{provider}/v1/chat/completions`

## SDK 文档

- 使用文档：[docs/sdk-usage_CN.md](docs/sdk-usage_CN.md)
- 高级执行器和转换器：[docs/sdk-advanced_CN.md](docs/sdk-advanced_CN.md)
- 访问控制：[docs/sdk-access_CN.md](docs/sdk-access_CN.md)
- 凭据监听：[docs/sdk-watcher_CN.md](docs/sdk-watcher_CN.md)
- 自定义 Provider 示例：`examples/custom-provider`

## 构建

构建服务端二进制：

```bash
go build -o cli-proxy-api-plus ./cmd/server
```

运行测试：

```bash
go test ./...
```

## Release

版本化 release 使用“上游版本 + Plus 发布计数”的 tag，例如 `v6.10.9.1`、`v6.10.9.2`。当上游版本更新时，Plus 计数重新从 1 开始，例如 `v6.10.10.1`。

Release workflow 会构建 Linux 和 Windows 的 amd64/arm64 压缩包，并包含 updater 脚本和 CPA Usage Keeper 辅助文件。

## 许可证

本项目使用 MIT 许可证。详情见 [LICENSE](LICENSE)。
