# CLIProxyAPI Plus

[English](README.md) | 中文 | [日本語](README_JA.md)

CLIProxyAPI Plus 不是单一项目的简单 fork，而是一个组合发行版：

- `router-for-me/CLIProxyAPI`：上游代理服务核心。
- `Tonkic/CLIProxyAPIPlus`：Plus 分支，增加额外 provider、登录能力和部署打包。
- `seakee/CPA-Manager-Plus`：外部管理和用量看板，在 release 包中以二进制形式随包发布。
- 本仓库的集成代码：把代理运行时的用量事件输出成 Redis 兼容队列，让主代理和 manager 可以作为一个产品一起运行。

目标是在保持上游 CLIProxyAPI 兼容性的基础上，提供 Plus provider、多账号管理、用量统计和更省心的部署体验。

## 功能

- OpenAI、Gemini、Claude、Codex、Grok、Responses 兼容接口。
- 支持 Codex、Claude、Gemini、Kimi、Antigravity、xAI/Grok、GitHub Copilot、Kiro、Cursor、CodeBuddy、Kilo、iFlow、GitLab Duo 等登录或 token 接入。
- 支持 round-robin / fill-first 账号选择、模型别名和热重载。
- 支持 Amp CLI 和 Amp IDE 扩展的 provider 路由。
- 支持部分 provider 的 WebSocket。
- 提供请求日志、Management API 和管理面板。
- 提供 Redis 兼容用量队列，可供外部 collector 消费。
- release 包可同时启动 CLIProxyAPI Plus 和 CPA-Manager-Plus。

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
manager/                     CPA-Manager-Plus 二进制和持久化数据
docs/                        SDK 和 provider 文档
```

## 用量统计

CLIProxyAPI Plus 在运行时生成 usage record，并通过 `sdk/cliproxy/usage` 发布。`internal/redisqueue` 插件会把这些记录序列化为 JSON，放入内存队列。

API server 会在代理端口上同时接受 Redis RESP 协议连接。消费者使用 management key 认证后，可以用 `LPOP` 或 `RPOP` 读取事件。

CPA-Manager-Plus 负责消费这个队列，并提供持久化、服务管理和可视化。

默认链路：

```text
client -> CLIProxyAPI Plus :8317 -> Redis-compatible usage queue
                              |
                              v
                         CPA-Manager-Plus :18317
```

代理配置示例：

```yaml
remote-management:
  secret-key: "change-me"

usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 60
```

首次启动后，打开 `http://服务器IP:18317/management.html`。使用自动生成的 CPA-Manager-Plus 管理密钥登录，然后添加 CLIProxyAPI Plus：地址填写 `http://127.0.0.1:8317`，密钥填写 CPA 配置中的 management key。manager 默认使用 `USAGE_COLLECTOR_MODE=auto`。

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

## 与 CPA-Manager-Plus 一起运行

release 包包含简短的 Linux 辅助脚本和 CPA-Manager-Plus 二进制：

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

首次配置：

```bash
cp config.example.yaml config.yaml
./start.sh
```

服务控制：

```bash
./start.sh
./stop.sh
./restart.sh
```

脚本会启动：

- CLIProxyAPI Plus：`http://127.0.0.1:8317`
- CPA-Manager-Plus：`http://127.0.0.1:18317`

CPA-Manager-Plus 首次运行时会输出自动生成的 `cpamp_...` 管理密钥，可这样查看：

```bash
tail -n 200 logs/cpa-manager-plus.out.log
tail -n 200 logs/cpa-manager-plus.err.log
```

manager 的持久化文件位于 `manager/data/` 和 `manager/config.json`。建议备份 `manager/data/usage.sqlite*` 与 `manager/data/data.key`。更新脚本只替换 manager 二进制，不会覆盖这些文件。

从旧 Keeper 版本升级时，`restart.sh` 会停止旧的 `keeper` tmux 会话，但完整保留 `keeper/` 目录。不要同时运行 Keeper 和 CPA-Manager-Plus，因为二者会消费同一个内存用量队列。两者的 SQLite 结构不兼容，历史 Keeper 数据需要先导出再导入，不能直接复制数据库文件。

Keeper 版本使用的是旧 updater。首次迁移前，先从 GitHub Release 换成独立发布的新 updater：

```bash
curl -fL \
  https://github.com/Tonkic/CLIProxyAPIPlus/releases/download/v7.2.91.1/update.sh \
  -o ./update.sh.new
chmod +x ./update.sh.new
mv -f ./update.sh.new ./update.sh
```

## 更新部署

默认直接从 GitHub Release 下载：

```bash
./update.sh --tag v7.2.91.1
```

只更新不重启，然后手动重启：

```bash
./update.sh \
  --tag v7.2.91.1 \
  --no-restart

./restart.sh
```

阿里云 OSS 仍可作为可选镜像，显式传入 `--bucket` 和 `--endpoint` 即可：

```bash
./update.sh \
  --tag v7.2.91.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
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
- CPA-Manager-Plus：`https://github.com/seakee/CPA-Manager-Plus`

## 许可证

本项目使用 MIT License。详见 [LICENSE](LICENSE)。
