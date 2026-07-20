#!/usr/bin/env sh
set -eu

ROOT=${ROOT:-}
MODE=${RUN_MODE:-auto}
CPA_SERVICE=${CPA_SERVICE:-cpa.service}
CPAMP_SERVICE=${CPAMP_SERVICE:-cpamp.service}
CLI_SESSION=${CLI_SESSION:-cli}
MANAGER_SESSION=${MANAGER_SESSION:-manager}
CONFIG=${CONFIG:-}
MANAGER_DATA_DIR=${MANAGER_DATA_DIR:-}
MANAGER_ADDR=${MANAGER_ADDR:-127.0.0.1:18317}
MANAGER_COLLECTOR_MODE=${MANAGER_COLLECTOR_MODE:-auto}
LOG_DIR=${LOG_DIR:-}
CPA_HEALTH_URL=${CPA_HEALTH_URL:-http://127.0.0.1:8317/}
CPAMP_HEALTH_URL=${CPAMP_HEALTH_URL:-http://127.0.0.1:18317/health}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-30}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: start.sh [options]

Start CLIProxyAPI Plus and CPA-Manager-Plus using systemd or tmux.

Options:
  --mode MODE                 auto, systemd, or tmux. Defaults to auto.
  --root PATH                 Install directory. Defaults to this script's directory.
  --config PATH               Proxy config. Defaults to ROOT/config.yaml.
  --cpa-service UNIT          CPA systemd unit. Defaults to cpa.service.
  --cpamp-service UNIT        CPAMP systemd unit. Defaults to cpamp.service.
  --cli-session NAME          Proxy tmux session. Defaults to cli.
  --manager-session NAME      Manager tmux session. Defaults to manager.
  --manager-data-dir PATH     Manager data directory. Defaults to ROOT/manager/data.
  --manager-addr ADDR         Manager listen address. Defaults to 127.0.0.1:18317.
  --manager-collector-mode M  Usage collector mode. Defaults to auto.
  --log-dir PATH              Log directory. Defaults to ROOT/logs.
  --health-timeout SECONDS    Health check timeout. Defaults to 30.
  --dry-run                   Print commands only.
  --help                      Show this help.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
script_dir() { CDPATH= cd -- "$(dirname -- "$0")" && pwd; }
quote_squote() { printf '%s' "$1" | sed "s/'/'\\''/g"; }
systemd_units_available() {
  command -v systemctl >/dev/null 2>&1 &&
    systemctl cat "$CPA_SERVICE" >/dev/null 2>&1 &&
    systemctl cat "$CPAMP_SERVICE" >/dev/null 2>&1
}
resolve_mode() {
  case "$MODE" in
    auto) if systemd_units_available; then MODE=systemd; else MODE=tmux; fi ;;
    systemd) systemd_units_available || fail "systemd units not found: $CPA_SERVICE, $CPAMP_SERVICE" ;;
    tmux) ;;
    *) fail "invalid mode: $MODE (expected auto, systemd, or tmux)" ;;
  esac
}
wait_healthy() {
  name=$1
  url=$2
  elapsed=0
  while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      log "Healthy: $name ($url)"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  fail "$name health check failed after ${HEALTH_TIMEOUT}s: $url"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MODE=$2; shift 2 ;;
    --root|--install-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; ROOT=$2; shift 2 ;;
    --config) [ "$#" -ge 2 ] || fail "$1 requires a value"; CONFIG=$2; shift 2 ;;
    --cpa-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPA_SERVICE=$2; shift 2 ;;
    --cpamp-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPAMP_SERVICE=$2; shift 2 ;;
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --manager-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_SESSION=$2; shift 2 ;;
    --legacy-keeper-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; shift 2 ;;
    --manager-data-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_DATA_DIR=$2; shift 2 ;;
    --manager-addr) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_ADDR=$2; shift 2 ;;
    --manager-collector-mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_COLLECTOR_MODE=$2; shift 2 ;;
    --log-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; LOG_DIR=$2; shift 2 ;;
    --health-timeout) [ "$#" -ge 2 ] || fail "$1 requires a value"; HEALTH_TIMEOUT=$2; shift 2 ;;
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

[ -x "$BIN" ] || fail "binary not found or not executable: $BIN"
[ -x "$MANAGER_BIN" ] || fail "manager binary not found or not executable: $MANAGER_BIN"
[ -f "$CONFIG" ] || fail "config not found: $CONFIG"
need_cmd curl
resolve_mode
run mkdir -p "$LOG_DIR" "$MANAGER_DATA_DIR"

if [ "$MODE" = systemd ]; then
  run systemctl start "$CPA_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || systemctl is-active --quiet "$CPA_SERVICE" || fail "service failed to start: $CPA_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || wait_healthy CPA "$CPA_HEALTH_URL"
  run systemctl start "$CPAMP_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || systemctl is-active --quiet "$CPAMP_SERVICE" || fail "service failed to start: $CPAMP_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || wait_healthy CPAMP "$CPAMP_HEALTH_URL"
  log "Started with systemd: $CPA_SERVICE, $CPAMP_SERVICE"
  exit 0
fi

need_cmd tmux
tmux has-session -t "$CLI_SESSION" 2>/dev/null && fail "tmux session already exists: $CLI_SESSION"
tmux has-session -t "$MANAGER_SESSION" 2>/dev/null && fail "tmux session already exists: $MANAGER_SESSION"
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
[ "$DRY_RUN" -eq 1 ] || wait_healthy CPA "$CPA_HEALTH_URL"
[ "$DRY_RUN" -eq 1 ] || wait_healthy CPAMP "$CPAMP_HEALTH_URL"
log "Started with tmux: $CLI_SESSION, $MANAGER_SESSION"
