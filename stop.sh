#!/usr/bin/env sh
set -eu

CLI_SESSION=${CLI_SESSION:-cli}
KEEPER_SESSION=${KEEPER_SESSION:-keeper}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: stop.sh [options]

Stop CLIProxyAPI Plus and CPA Usage Keeper tmux sessions.

Options:
  --cli-session NAME      Proxy tmux session. Defaults to cli.
  --keeper-session NAME   Keeper tmux session. Defaults to keeper.
  --dry-run               Print commands only.
  --help                  Show this help.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --keeper-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; KEEPER_SESSION=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

need_cmd tmux
tmux has-session -t "$CLI_SESSION" 2>/dev/null && run tmux kill-session -t "$CLI_SESSION" || true
tmux has-session -t "$KEEPER_SESSION" 2>/dev/null && run tmux kill-session -t "$KEEPER_SESSION" || true
log "Stopped: $CLI_SESSION, $KEEPER_SESSION"