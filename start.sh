#!/usr/bin/env sh
set -eu

ROOT=${ROOT:-}
CLI_SESSION=${CLI_SESSION:-cli}
KEEPER_SESSION=${KEEPER_SESSION:-keeper}
CONFIG=${CONFIG:-}
KEEPER_ENV=${KEEPER_ENV:-}
LOG_DIR=${LOG_DIR:-}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: start.sh [options]

Start CLIProxyAPI Plus and CPA Usage Keeper in tmux.

Options:
  --root PATH             Install directory. Defaults to this script's directory.
  --config PATH           Proxy config. Defaults to ROOT/config.yaml.
  --keeper-env PATH       Keeper env file. Defaults to ROOT/keeper/.env.
  --cli-session NAME      Proxy tmux session. Defaults to cli.
  --keeper-session NAME   Keeper tmux session. Defaults to keeper.
  --log-dir PATH          Log directory. Defaults to ROOT/logs.
  --dry-run               Print commands only.
  --help                  Show this help.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
script_dir() { CDPATH= cd -- "$(dirname -- "$0")" && pwd; }
quote_squote() { printf "%s" "$1" | sed "s/'/'\\''/g"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root|--install-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; ROOT=$2; shift 2 ;;
    --config) [ "$#" -ge 2 ] || fail "$1 requires a value"; CONFIG=$2; shift 2 ;;
    --keeper-env) [ "$#" -ge 2 ] || fail "$1 requires a value"; KEEPER_ENV=$2; shift 2 ;;
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --keeper-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; KEEPER_SESSION=$2; shift 2 ;;
    --log-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; LOG_DIR=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[ -n "$ROOT" ] || ROOT=$(script_dir)
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)
CONFIG=${CONFIG:-"$ROOT/config.yaml"}
KEEPER_ENV=${KEEPER_ENV:-"$ROOT/keeper/.env"}
LOG_DIR=${LOG_DIR:-"$ROOT/logs"}
BIN="$ROOT/cli-proxy-api-plus"
KEEPER_DIR="$ROOT/keeper"
KEEPER_BIN="$KEEPER_DIR/cpa-usage-keeper"

need_cmd tmux
[ -x "$BIN" ] || fail "binary not found or not executable: $BIN"
[ -f "$CONFIG" ] || fail "config not found: $CONFIG"
[ -x "$KEEPER_BIN" ] || fail "keeper binary not found or not executable: $KEEPER_BIN"
[ -f "$KEEPER_ENV" ] || fail "keeper env not found: $KEEPER_ENV"
tmux has-session -t "$CLI_SESSION" 2>/dev/null && fail "tmux session already exists: $CLI_SESSION"
tmux has-session -t "$KEEPER_SESSION" 2>/dev/null && fail "tmux session already exists: $KEEPER_SESSION"

run mkdir -p "$LOG_DIR"

root_q=$(quote_squote "$ROOT")
bin_q=$(quote_squote "$BIN")
config_q=$(quote_squote "$CONFIG")
keeper_dir_q=$(quote_squote "$KEEPER_DIR")
keeper_bin_q=$(quote_squote "$KEEPER_BIN")
keeper_env_q=$(quote_squote "$KEEPER_ENV")
runtime_log_q=$(quote_squote "$LOG_DIR/runtime.log")
keeper_out_q=$(quote_squote "$LOG_DIR/cpa-usage-keeper.out.log")
keeper_err_q=$(quote_squote "$LOG_DIR/cpa-usage-keeper.err.log")

run tmux new-session -d -s "$CLI_SESSION" "cd '$root_q' && '$bin_q' -config '$config_q' >> '$runtime_log_q' 2>&1"
run tmux new-session -d -s "$KEEPER_SESSION" "cd '$keeper_dir_q' && '$keeper_bin_q' --env '$keeper_env_q' >> '$keeper_out_q' 2>> '$keeper_err_q'"

log "Started: $CLI_SESSION, $KEEPER_SESSION"
log "Status: tmux ls"
log "Logs: $LOG_DIR"