#!/usr/bin/env sh
set -eu

CLI_SESSION=${CLI_SESSION:-cli}
MANAGER_SESSION=${MANAGER_SESSION:-manager}
LEGACY_KEEPER_SESSION=${LEGACY_KEEPER_SESSION:-keeper}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: stop.sh [options]

Stop CLIProxyAPI Plus and CPA-Manager-Plus tmux sessions.

Options:
  --cli-session NAME              Proxy tmux session. Defaults to cli.
  --manager-session NAME          Manager tmux session. Defaults to manager.
  --legacy-keeper-session NAME    Old Keeper session to stop. Defaults to keeper.
  --dry-run                       Print commands only.
  --help                          Show this help.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --manager-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_SESSION=$2; shift 2 ;;
    --legacy-keeper-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; LEGACY_KEEPER_SESSION=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

need_cmd tmux
tmux has-session -t "$CLI_SESSION" 2>/dev/null && run tmux kill-session -t "$CLI_SESSION" || true
tmux has-session -t "$MANAGER_SESSION" 2>/dev/null && run tmux kill-session -t "$MANAGER_SESSION" || true
tmux has-session -t "$LEGACY_KEEPER_SESSION" 2>/dev/null && run tmux kill-session -t "$LEGACY_KEEPER_SESSION" || true
log "Stopped: $CLI_SESSION, $MANAGER_SESSION, $LEGACY_KEEPER_SESSION (legacy)"
