# CLIProxyAPI Plus

[English](README.md) | 中文

这是 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 的 Plus 版本，维护在 [Tonkic/CLIProxyAPIPlus](https://github.com/Tonkic/CLIProxyAPIPlus)。本仓库在保留主线 CLIProxyAPI 行为的基础上，加入 Plus 专属能力。

所有 Plus 功能都由社区维护者提供，CLIProxyAPI 不提供技术支持。如需取得支持，请与对应的社区维护者联系。

Plus 版本目标是在跟进主线能力的同时保留以下扩展：

- 第三方平台支持，包括 GitHub Copilot、Kiro 等。
- 管理端 usage 统计的持久化存储。

## Plus 实现路径

- GitHub Copilot 授权与 token 交换：`internal/auth/copilot/`、`sdk/auth/github_copilot.go`、`internal/cmd/github_copilot_login.go`
- GitHub Copilot 执行器与请求转换：`internal/runtime/executor/github_copilot_executor.go`
- Kiro 授权、刷新与 Web OAuth 流程：`internal/auth/kiro/`、`sdk/auth/kiro.go`、`internal/cmd/kiro_login.go`
- Kiro 执行器与协议转换：`internal/runtime/executor/kiro_executor.go`、`internal/translator/kiro/`
- Plus 平台 OAuth 模型别名：`internal/config/oauth_model_alias_defaults.go`、`sdk/cliproxy/auth/oauth_model_alias.go`
- usage 持久化统计：`sdk/cliproxy/usage/`、`internal/usage/`、`internal/runtime/executor/helps/usage_helpers.go`
- 管理端 usage API：`internal/api/handlers/management/usage.go`、`internal/api/handlers/management/api_key_usage.go`、`internal/api/server.go`

## 贡献

该项目仅接受第三方供应商支持的 Pull Request。任何非第三方供应商支持的 Pull Request 都将被拒绝。

如果需要提交任何非第三方供应商支持的 Pull Request，请提交到[主线](https://github.com/router-for-me/CLIProxyAPI)版本。

## 许可证

此项目根据 MIT 许可证授权 - 有关详细信息，请参阅 [LICENSE](LICENSE) 文件。
