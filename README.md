# CLIProxyAPI Plus

English | [Chinese](README_CN.md)

This is the Plus version of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), maintained at [Tonkic/CLIProxyAPIPlus](https://github.com/Tonkic/CLIProxyAPIPlus). It keeps the mainline CLIProxyAPI behavior while adding Plus-specific capabilities.

All Plus features are maintained by community contributors; CLIProxyAPI does not provide technical support. Please contact the corresponding community maintainer if you need assistance.

The Plus release aims to stay in lockstep with mainline features while preserving these additions:

- Third-party platform support, including GitHub Copilot and Kiro.
- Persistent usage storage for management usage statistics.

## Plus implementation paths

- GitHub Copilot auth and token exchange: `internal/auth/copilot/`, `sdk/auth/github_copilot.go`, `internal/cmd/github_copilot_login.go`
- GitHub Copilot executor and request conversion: `internal/runtime/executor/github_copilot_executor.go`
- Kiro auth, refresh, and web OAuth flow: `internal/auth/kiro/`, `sdk/auth/kiro.go`, `internal/cmd/kiro_login.go`
- Kiro executor and translators: `internal/runtime/executor/kiro_executor.go`, `internal/translator/kiro/`
- OAuth model aliases for Plus providers: `internal/config/oauth_model_alias_defaults.go`, `sdk/cliproxy/auth/oauth_model_alias.go`
- Persistent usage tracking: `sdk/cliproxy/usage/`, `internal/usage/`, `internal/runtime/executor/helps/usage_helpers.go`
- Management usage APIs: `internal/api/handlers/management/usage.go`, `internal/api/handlers/management/api_key_usage.go`, `internal/api/server.go`

## Contributing

This project only accepts pull requests that relate to third-party provider support. Any pull requests unrelated to third-party provider support will be rejected.

If you need to submit any non-third-party provider changes, please open them against the [mainline](https://github.com/router-for-me/CLIProxyAPI) repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
