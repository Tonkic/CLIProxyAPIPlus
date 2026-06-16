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

<table>
<tbody>
<tr>
<td width="180"><a href="https://www.aicodemirror.com/register?invitecode=TJNAIF"><img src="./assets/aicodemirror.png" alt="AICodeMirror" width="150"></a></td>
<td>感谢 AICodeMirror 赞助了本项目！AICodeMirror 提供 Claude Code / Codex / Gemini CLI 官方高稳定中转服务，支持企业级高并发、极速开票、7×24 专属技术支持。 Claude Code / Codex / Gemini 官方渠道低至 3.8 / 0.2 / 0.9 折，充值更有折上折！AICodeMirror 为 CLIProxyAPI 的用户提供了特别福利，通过<a href="https://www.aicodemirror.com/register?invitecode=TJNAIF" target="_blank">此链接</a>注册的用户，可享受首充8折，企业客户最高可享 7.5 折！</td>
</tr>
<tr>
<td width="180"><a href="https://shop.bmoplus.com/?utm_source=github"><img src="./assets/bmoplus.png" alt="BmoPlus" width="150"></a></td>
<td>感谢 BmoPlus 赞助了本项目！BmoPlus 是一家专为AI订阅重度用户打造的可靠 AI 账号代充服务商，提供稳定的 ChatGPT Plus / ChatGPT Pro(全程质保) / Claude Pro / Super Grok / Gemini Pro 的官方代充&成品账号。 通过<a href="https://shop.bmoplus.com/?utm_source=github" target="_blank">BmoPlus AI成品号专卖/代充</a>注册下单的用户，可享GPT <b>官网订阅一折</b> 的震撼价格！</td>
</tr>
<tr>
<td width="180"><a href="https://coder.visioncoder.cn"><img src="./assets/visioncoder.png" alt="VisionCoder" width="150"></a></td>
<td>感谢 VisionCoder 对本项目的支持。<a href="https://coder.visioncoder.cn">VisionCoder 开发平台</a> 是一个可靠高效的 API 中继服务提供商，提供 Claude Code、Codex、Gemini 等主流 AI 模型，帮助开发者和团队更轻松地集成 AI 功能，提升工作效率。此外，VisionCoder 还提供 <b>Claude Max 200 与 GPT Pro 200 高级成品号</b>的独家售卖渠道，助力体验全网顶配 AI 的算力与体验。</td>
</tr>
<tr>
<td width="180"><a href="https://apikey.fun/register?aff=CLIProxyAPI"><img src="./assets/apikey.png" alt="APIKEY.FUN" width="150"></a></td>
<td>感谢 APIKEY.FUN 赞助本项目！APIKEY.FUN 是一家专业的企业级 AI 中转站，致力于为企业和个人开发者提供稳定、高效、低成本的 AI 模型 API 接入服务。平台支持 Claude、OpenAI、Gemini 等主流热门模型，价格低至官方原价的 7%。通过本项目<a href="https://apikey.fun/register?aff=CLIProxyAPI">专属链接</a>注册，还可享受最高 <b>充值永久 95 折</b> 专属优惠。</td>
</tr>
<tr>
<td width="180"><a href="https://runapi.co/register?aff=FivD"><img src="./assets/runapi.png" alt="RunAPI" width="150"></a></td>
<td>RunAPI 是高效稳定的API OpenRouter平替平台，一个 API Key 即可访问 OpenAI、Claude、Gemini、DeepSeek、Grok 等 150+ 主流模型，低至 1 折，极其稳定，可以无缝兼容 Claude Code、OpenClaw 等工具。RunAPI 为 CPA的用户提供专属福利：<a href="https://runapi.co/register?aff=FivD">注册</a>联系管理员即可领取￥7的免费额度</td>
</tr>
<tr>
<td width="180"><a href="https://unity2.ai/register?source=cliproxyapi"><img src="./assets/unity2.jpg" alt="Unity2" width="150"></a></td>
<td>感谢 Unity2.ai 赞助了本项目！Unity2.ai 是面向个人开发者、团队和企业的高性能 AI 模型 API 中转平台，长期服务国内头部企业，日均承载超 300 亿 token 调用，支持 5000 RPM 级高并发。支持余额计费、首充赠额、组合订阅、企业开票和专属对接。通过<a href="https://unity2.ai/register?source=cliproxyapi">此链接</a>注册可领取 $2 余额，加入官方群再送 $10 余额，最高可领 $12 免费额度。</td>
</tr>
<tr>
<td width="180"><a href="https://catapi.ai/sign-up"><img src="./assets/catapi.png" alt="CatAPI" width="150"></a></td>
<td>Cat API 是一家面向个人开发者与团队的 AI 大模型聚合平台，致力于将主流大模型能力整合到一个简单、稳定、易用的入口中。平台提供完全兼容 OpenAI、Claude、Gemini 的 API，可无缝接入 Claude Code、Cursor、Windsurf、Cline、Roo Code、Continue、Codex、Trae 等主流 AI IDE 与编程工具，并主打 CN2 高速线路，为用户带来低延迟、高稳定的访问体验。<a href="https://catapi.ai/sign-up">注册</a>即可领取 1$ 的免费额度。</td>
</tr>
</tbody>
</table>

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

release 包包含简短的 Linux 辅助脚本和 keeper 环境变量模板：

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

首次配置：

```bash
cp config.example.yaml config.yaml
cp keeper/.env.example keeper/.env
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
- CPA Usage Keeper：`http://127.0.0.1:8080`

## 更新部署

私有阿里云 OSS 镜像更新：先在服务器安装并配置 `ossutil`，然后执行：

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com
```

只更新不重启，然后手动重启：

```bash
./update.sh \
  --tag v7.1.19.1 \
  --bucket update-cpa-plus \
  --endpoint oss-cn-shenzhen.aliyuncs.com \
  --no-restart

./restart.sh
```

也可以用环境变量保存 OSS 配置：

```bash
export ALIYUN_OSS_BUCKET=update-cpa-plus
export ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen.aliyuncs.com
export ALIYUN_OSS_PREFIX=CLIProxyAPIPlus
./update.sh --tag v7.1.19.1
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
