#!/usr/bin/env sh
set -eu

MODE=${RUN_MODE:-auto}
CPA_SERVICE=${CPA_SERVICE:-cpa.service}
CPAMP_SERVICE=${CPAMP_SERVICE:-cpamp.service}
CLI_SESSION=${CLI_SESSION:-cli}
MANAGER_SESSION=${MANAGER_SESSION:-manager}
LEGACY_KEEPER_SESSION=${LEGACY_KEEPER_SESSION:-keeper}
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: stop.sh [options]

Stop CLIProxyAPI Plus and CPA-Manager-Plus using systemd or tmux.

Options:
  --mode MODE                    auto, systemd, or tmux. Defaults to auto.
  --cpa-service UNIT             CPA systemd unit. Defaults to cpa.service.
  --cpamp-service UNIT           CPAMP systemd unit. Defaults to cpamp.service.
  --cli-session NAME             Proxy tmux session. Defaults to cli.
  --manager-session NAME         Manager tmux session. Defaults to manager.
  --legacy-keeper-session NAME   Old Keeper tmux session. Defaults to keeper.
  --dry-run                      Print commands only.
  --help                         Show this help.
EOF
}
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
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
    *) fail "invalid mode: $MODE" ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MODE=$2; shift 2 ;;
    --cpa-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPA_SERVICE=$2; shift 2 ;;
    --cpamp-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPAMP_SERVICE=$2; shift 2 ;;
    --root|--install-dir|--config|--manager-data-dir|--manager-addr|--manager-collector-mode|--log-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; shift 2 ;;
    --health-timeout) [ "$#" -ge 2 ] || fail "$1 requires a value"; shift 2 ;;
    --cli-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; CLI_SESSION=$2; shift 2 ;;
    --manager-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; MANAGER_SESSION=$2; shift 2 ;;
    --legacy-keeper-session) [ "$#" -ge 2 ] || fail "$1 requires a value"; LEGACY_KEEPER_SESSION=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

resolve_mode
if [ "$MODE" = systemd ]; then
  run systemctl stop "$CPAMP_SERVICE"
  run systemctl stop "$CPA_SERVICE"
  log "Stopped with systemd: $CPAMP_SERVICE, $CPA_SERVICE"
  exit 0
fi

command -v tmux >/dev/null 2>&1 || fail "required command not found: tmux"
tmux has-session -t "$MANAGER_SESSION" 2>/dev/null && run tmux kill-session -t "$MANAGER_SESSION" || true
tmux has-session -t "$CLI_SESSION" 2>/dev/null && run tmux kill-session -t "$CLI_SESSION" || true
tmux has-session -t "$LEGACY_KEEPER_SESSION" 2>/dev/null && run tmux kill-session -t "$LEGACY_KEEPER_SESSION" || true
log "Stopped with tmux: $MANAGER_SESSION, $CLI_SESSION, $LEGACY_KEEPER_SESSION (legacy)"
