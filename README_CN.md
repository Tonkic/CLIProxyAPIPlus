# CLIProxyAPI Plus

[English](README.md) | 中文 | [日本語](README_JA.md)

CLIProxyAPI Plus 不是单一项目的简单 fork，而是一个组合发行版：

- `router-for-me/CLIProxyAPI`：上游代理服务核心。
- `Tonkic/CLIProxyAPIPlus`：Plus 分支，增加额外 provider、登录能力和部署打包。
- `Willxup/cpa-usage-keeper`：外部用量采集与可视化程序，在 release 包中以二进制形式随包发布。
- 本仓库的集成代码：把代理运行时的用量事件输出成 Redis 兼容队列，让主代理和 keeper 可以作为一个产品一起运行。

目标是在保持上游 CLIProxyAPI 兼容性的基础上，提供 Plus provider、多账号管理、用量统计和更省心的部署体验。

## 功能

- OpenAI、Gemini、Claude、Codex、Grok、Responses 兼容接口。
- 支持 Codex、Claude、Gemini、Kimi、Antigravity、xAI/Grok、GitHub Copilot、Kiro、Cursor、CodeBuddy、Kilo、iFlow、GitLab Duo 等登录或 token 接入。
- 支持 round-robin / fill-first 账号选择、模型别名和热重载。
- 支持 Amp CLI 和 Amp IDE 扩展的 provider 路由。
- 支持部分 provider 的 WebSocket。
- 提供请求日志、Management API 和管理面板。
- 提供 Redis 兼容用量队列，可供外部 collector 消费。
- release 包可同时启动 CLIProxyAPI Plus 和 CPA Usage Keeper。

## 项目结构

```text
cmd/server/                  CLI 入口
internal/api/                Gin server、路由、中间件、Management API
internal/api/modules/amp/    Amp 路由和反向代理
internal/runtime/executor/   provider executor
internal/translator/         协议转换器
internal/redisqueue/         Redis 兼容用量队列插件
sdk/cliproxy/                可嵌入的代理服务
sdk/cliproxy/usage/          用量事件管理器和插件接口
keeper/                      CPA Usage Keeper 的 release 辅助文件
docs/                        SDK 和 provider 文档
```

## 用量统计

CLIProxyAPI Plus 在运行时生成 usage record，并通过 `sdk/cliproxy/usage` 发布。`internal/redisqueue` 插件会把这些记录序列化为 JSON，放入内存队列。

API server 会在代理端口上同时接受 Redis RESP 协议连接。消费者使用 management key 认证后，可以用 `LPOP` 或 `RPOP` 读取事件。

CPA Usage Keeper 负责消费这个队列，并提供持久化和可视化。

默认链路：

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA Usage Keeper :8080
```

代理配置示例：

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

keeper 配置：

```bash
cp keeper/.env.example keeper/.env
```

关键环境变量：

```env
CPA_BASE_URL=http://127.0.0.1:8317
CPA_MANAGEMENT_KEY=change-me
REDIS_QUEUE_ADDR=127.0.0.1:8317
APP_PORT=8080
```

## 快速开始

复制配置模板并按需填写账号和 provider：

```bash
cp config.example.yaml config.yaml
```

源码运行：

```bash
go run ./cmd/server --config ./config.yaml
```

构建并运行：

```bash
go build -o cli-proxy-api-plus ./cmd/server
./cli-proxy-api-plus --config ./config.yaml
```

## 与 CPA Usage Keeper 一起运行

Linux：

```bash
cp config.example.yaml config.yaml
cp keeper/.env.example keeper/.env
./start-plus-with-keeper.sh
```

Windows PowerShell：

```powershell
Copy-Item config.example.yaml config.yaml
Copy-Item keeper\.env.example keeper\.env
.\start-plus-with-keeper.ps1
```

脚本会启动：

- CLIProxyAPI Plus：`http://127.0.0.1:8317`
- CPA Usage Keeper：`http://127.0.0.1:8080`

## 更新部署

Linux：

```bash
./update-linux.sh
./update-linux.sh --tag v7.0.6.1
./update-linux.sh --no-restart
```

私有阿里云 OSS 镜像更新：先在服务器安装并配置 `ossutil`，再从 OSS 下载到本地文件并更新：

```bash
./update-linux-oss.sh \
  --tag v7.1.1.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen-internal.aliyuncs.com
```

也可以用环境变量保存 OSS 配置：

```bash
export ALIYUN_OSS_BUCKET=update-cpa-plus
export ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen-internal.aliyuncs.com
export ALIYUN_OSS_PREFIX=CLIProxyAPIPlus
./update-linux-oss.sh --tag v7.1.1.1
```

Windows：

```powershell
.\update-windows.ps1
.\update-windows.ps1 -Tag v7.0.6.1
.\update-windows.ps1 -NoRestart
```

## Amp CLI 支持

常用 provider 路由：

- `/api/provider/{provider}/v1/messages`
- `/api/provider/{provider}/v1beta/models/...`
- `/api/provider/{provider}/v1/chat/completions`

同时支持 management proxy、模型 fallback、模型映射，以及敏感 Amp 管理接口的 localhost 限制。

## 构建和测试

```bash
gofmt -w .
go build -o test-output ./cmd/server
rm -f test-output
go test ./...
```

## 上游项目

- CLIProxyAPI：`https://github.com/router-for-me/CLIProxyAPI`
- CLIProxyAPI Plus：`https://github.com/Tonkic/CLIProxyAPIPlus`
- CPA Usage Keeper：`https://github.com/Willxup/cpa-usage-keeper`

## 许可证

本项目使用 MIT License。详见 [LICENSE](LICENSE)。
