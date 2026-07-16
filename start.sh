#!/usr/bin/env sh
set -eu

ROOT=${ROOT:-}
CLI_SESSION=${CLI_SESSION:-cli}
MANAGER_SESSION=${MANAGER_SESSION:-manager}
CONFIG=${CONFIG:-}
MANAGER_DATA_DIR=${MANAGER_DATA_DIR:-}
MANAGER_ADDR=${MANAGER_ADDR:-0.0.0.0:18317}
MANAGER_COLLECTOR_MODE=${MANAGER_COLLECTOR_MODE:-auto}
LOG_DIR=${LOG_DIR:-}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: start.sh [options]

Start CLIProxyAPI Plus and CPA-Manager-Plus in tmux.

Options:
  --root PATH                 Install directory. Defaults to this script's directory.
  --config PATH               Proxy config. Defaults to ROOT/config.yaml.
  --cli-session NAME          Proxy tmux session. Defaults to cli.
  --manager-session NAME      Manager tmux session. Defaults to manager.
  --manager-data-dir PATH     Manager data directory. Defaults to ROOT/manager/data.
  --manager-addr ADDR         Manager listen address. Defaults to 0.0.0.0:18317.
  --manager-collector-mode M  Usage collector mode. Defaults to auto.
  --log-dir PATH              Log directory. Defaults to ROOT/logs.
  --dry-run                   Print commands only.
  --help                      Show this help.
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
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --manager-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_SESSION=$2; shift 2 ;;
    --manager-data-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_DATA_DIR=$2; shift 2 ;;
    --manager-addr) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_ADDR=$2; shift 2 ;;
    --manager-collector-mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_COLLECTOR_MODE=$2; shift 2 ;;
    --log-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; LOG_DIR=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[ -n "$ROOT" ] || ROOT=$(script_dir)
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)
CONFIG=${CONFIG:-"$ROOT/config.yaml"}
MANAGER_DATA_DIR=${MANAGER_DATA_DIR:-"$ROOT/manager/data"}
LOG_DIR=${LOG_DIR:-"$ROOT/logs"}
BIN="$ROOT/cli-proxy-api-plus"
MANAGER_DIR="$ROOT/manager"
MANAGER_BIN="$MANAGER_DIR/cpa-manager-plus"
STAGED_MANAGER_BIN="$ROOT/.update/staging/manager/cpa-manager-plus"

need_cmd tmux
[ -x "$BIN" ] || fail "binary not found or not executable: $BIN"
[ -f "$CONFIG" ] || fail "config not found: $CONFIG"
if [ ! -x "$MANAGER_BIN" ]; then
  [ -f "$STAGED_MANAGER_BIN" ] || fail "manager binary not found or not executable: $MANAGER_BIN"
  log "Installing CPA-Manager-Plus from the staged release..."
  manager_tmp="${MANAGER_BIN}.new.$$"
  run mkdir -p "$MANAGER_DIR"
  run cp "$STAGED_MANAGER_BIN" "$manager_tmp"
  run chmod +x "$manager_tmp"
  run mv -f "$manager_tmp" "$MANAGER_BIN"
fi
tmux has-session -t "$CLI_SESSION" 2>/dev/null && fail "tmux session already exists: $CLI_SESSION"
tmux has-session -t "$MANAGER_SESSION" 2>/dev/null && fail "tmux session already exists: $MANAGER_SESSION"

run mkdir -p "$LOG_DIR" "$MANAGER_DATA_DIR"

root_q=$(quote_squote "$ROOT")
bin_q=$(quote_squote "$BIN")
config_q=$(quote_squote "$CONFIG")
manager_dir_q=$(quote_squote "$MANAGER_DIR")
manager_bin_q=$(quote_squote "$MANAGER_BIN")
manager_data_dir_q=$(quote_squote "$MANAGER_DATA_DIR")
manager_addr_q=$(quote_squote "$MANAGER_ADDR")
manager_collector_mode_q=$(quote_squote "$MANAGER_COLLECTOR_MODE")
runtime_log_q=$(quote_squote "$LOG_DIR/runtime.log")
manager_out_q=$(quote_squote "$LOG_DIR/cpa-manager-plus.out.log")
manager_err_q=$(quote_squote "$LOG_DIR/cpa-manager-plus.err.log")

run tmux new-session -d -s "$CLI_SESSION" "cd '$root_q' && '$bin_q' -config '$config_q' >> '$runtime_log_q' 2>&1"
run tmux new-session -d -s "$MANAGER_SESSION" "cd '$manager_dir_q' && HTTP_ADDR='$manager_addr_q' USAGE_DATA_DIR='$manager_data_dir_q' USAGE_COLLECTOR_MODE='$manager_collector_mode_q' '$manager_bin_q' >> '$manager_out_q' 2>> '$manager_err_q'"

log "Started: $CLI_SESSION, $MANAGER_SESSION"
log "Status: tmux ls"
log "Logs: $LOG_DIR"
