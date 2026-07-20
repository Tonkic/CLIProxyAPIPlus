#!/usr/bin/env sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${RUN_MODE:-auto}
CPA_SERVICE=${CPA_SERVICE:-cpa.service}
CPAMP_SERVICE=${CPAMP_SERVICE:-cpamp.service}
CPA_HEALTH_URL=${CPA_HEALTH_URL:-http://127.0.0.1:8317/}
CPAMP_HEALTH_URL=${CPAMP_HEALTH_URL:-http://127.0.0.1:18317/health}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-30}
DRY_RUN=0
FORWARD_ARGS=""

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
quote_squote() { printf '%s' "$1" | sed "s/'/'\\''/g"; }
append_arg() { FORWARD_ARGS="$FORWARD_ARGS '$(quote_squote "$1")'"; }
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
wait_healthy() {
  name=$1; url=$2; elapsed=0
  while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then log "Healthy: $name ($url)"; return 0; fi
    sleep 1; elapsed=$((elapsed + 1))
  done
  fail "$name health check failed after ${HEALTH_TIMEOUT}s: $url"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MODE=$2; shift 2 ;;
    --cpa-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPA_SERVICE=$2; shift 2 ;;
    --cpamp-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPAMP_SERVICE=$2; shift 2 ;;
    --health-timeout) [ "$#" -ge 2 ] || fail "$1 requires a value"; HEALTH_TIMEOUT=$2; append_arg "$1"; append_arg "$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) sh "$DIR/start.sh" --help; exit 0 ;;
    *)
      append_arg "$1"
      case "$1" in
        --root|--install-dir|--config|--cli-session|--manager-session|--manager-data-dir|--manager-addr|--manager-collector-mode|--log-dir|--legacy-keeper-session)
          [ "$#" -ge 2 ] || fail "$1 requires a value"; append_arg "$2"; shift 2 ;;
        *) fail "unknown option: $1" ;;
      esac ;;
  esac
done

resolve_mode
if [ "$MODE" = systemd ]; then
  command -v curl >/dev/null 2>&1 || fail "required command not found: curl"
  run systemctl restart "$CPA_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || systemctl is-active --quiet "$CPA_SERVICE" || fail "service failed to restart: $CPA_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || wait_healthy CPA "$CPA_HEALTH_URL"
  run systemctl restart "$CPAMP_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || systemctl is-active --quiet "$CPAMP_SERVICE" || fail "service failed to restart: $CPAMP_SERVICE"
  [ "$DRY_RUN" -eq 1 ] || wait_healthy CPAMP "$CPAMP_HEALTH_URL"
  log "Restarted with systemd: $CPA_SERVICE, $CPAMP_SERVICE"
  exit 0
fi

dry_arg=""
[ "$DRY_RUN" -eq 1 ] && dry_arg=" --dry-run"
eval "sh '$(quote_squote "$DIR/stop.sh")' --mode tmux $FORWARD_ARGS$dry_arg"
eval "sh '$(quote_squote "$DIR/start.sh")' --mode tmux $FORWARD_ARGS$dry_arg"
