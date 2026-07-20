#!/usr/bin/env sh
set -eu

TAG=${UPDATE_TAG:-}
REPOSITORY=${UPDATE_REPOSITORY:-Tonkic/CLIProxyAPIPlus}
BUCKET=${ALIYUN_OSS_BUCKET:-}
PREFIX=${ALIYUN_OSS_PREFIX:-CLIProxyAPIPlus}
ENDPOINT=${ALIYUN_OSS_ENDPOINT:-}
OSSUTIL=${OSSUTIL_BIN:-ossutil}
ARCHIVE=${UPDATE_ARCHIVE:-}
CHECKSUMS=${UPDATE_CHECKSUMS:-}
ROOT=""
DOWNLOAD_DIR=""
MODE=${RUN_MODE:-auto}
CPA_SERVICE=${CPA_SERVICE:-cpa.service}
CPAMP_SERVICE=${CPAMP_SERVICE:-cpamp.service}
CPA_HEALTH_URL=${CPA_HEALTH_URL:-http://127.0.0.1:8317/}
CPAMP_HEALTH_URL=${CPAMP_HEALTH_URL:-http://127.0.0.1:18317/health}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-30}
NO_RESTART=0
DRY_RUN=0
INSTALLED=0
ROLLING_BACK=0
BACKUP_DIR=""

usage() {
  cat <<'EOF'
Usage: update.sh --tag VERSION [options]

Update CLIProxyAPI Plus and bundled CPA-Manager-Plus, then restart safely.

Options:
  --tag VERSION             Release tag, for example v7.2.92.2.
  --repository OWNER/REPO   GitHub repository. Defaults to Tonkic/CLIProxyAPIPlus.
  --bucket NAME             OSS bucket. Can also be set with ALIYUN_OSS_BUCKET.
  --prefix PREFIX           OSS prefix. Defaults to CLIProxyAPIPlus.
  --endpoint ENDPOINT       OSS endpoint. Can also be set with ALIYUN_OSS_ENDPOINT.
  --archive PATH            Local release archive instead of downloading.
  --checksums PATH          Local checksums.txt.
  --download-dir PATH       Download directory. Defaults to ROOT/.update/downloads/TAG.
  --root PATH               Install directory. Defaults to this script's directory.
  --mode MODE               auto, systemd, or tmux. Defaults to auto.
  --cpa-service UNIT        CPA systemd unit. Defaults to cpa.service.
  --cpamp-service UNIT      CPAMP systemd unit. Defaults to cpamp.service.
  --health-timeout SECONDS  Health check timeout. Defaults to 30.
  --no-restart              Install only; do not validate running process hashes.
  --dry-run                 Print commands only.
  --help                    Show this help.

Example:
  ./update.sh --tag v7.2.92.2
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
script_dir() { CDPATH= cd -- "$(dirname -- "$0")" && pwd; }
strip_v() { case "$1" in v*) printf '%s' "${1#v}" ;; *) printf '%s' "$1" ;; esac; }
trim_slashes() { value=${1#/}; value=${value%/}; printf '%s' "$value"; }
normalize_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *) fail "unsupported architecture: $arch" ;;
  esac
}
install_executable() {
  src=$1; dst=$2; tmp="${dst}.new.$$"
  run cp "$src" "$tmp"
  run chmod +x "$tmp"
  run mv -f "$tmp" "$dst"
}
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
restore_file() {
  backup=$1; destination=$2
  [ -f "$backup" ] || return 0
  install_executable "$backup" "$destination"
}
restart_services() {
  run sh "$ROOT/restart.sh" --root "$ROOT" --mode "$MODE" --cpa-service "$CPA_SERVICE" --cpamp-service "$CPAMP_SERVICE" --health-timeout "$HEALTH_TIMEOUT"
}
rollback() {
  status=$?
  [ "$INSTALLED" -eq 1 ] || exit "$status"
  [ "$ROLLING_BACK" -eq 0 ] || exit "$status"
  ROLLING_BACK=1
  trap - EXIT INT TERM
  log "Update failed; restoring previous binaries and scripts..." >&2
  restore_file "$BACKUP_DIR/cli-proxy-api-plus" "$ROOT/cli-proxy-api-plus" || true
  restore_file "$BACKUP_DIR/manager/cpa-manager-plus" "$ROOT/manager/cpa-manager-plus" || true
  if [ "$NO_RESTART" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    sh "$STAGING_DIR/restart.sh" --root "$ROOT" --mode "$MODE" --cpa-service "$CPA_SERVICE" --cpamp-service "$CPAMP_SERVICE" --health-timeout "$HEALTH_TIMEOUT" || true
  fi
  for file in start.sh stop.sh restart.sh update.sh; do
    [ -f "$BACKUP_DIR/$file" ] && cp "$BACKUP_DIR/$file" "$ROOT/$file" || true
  done
  chmod +x "$ROOT/start.sh" "$ROOT/stop.sh" "$ROOT/restart.sh" "$ROOT/update.sh" 2>/dev/null || true
  exit "$status"
}
verify_running_binaries() {
  [ "$MODE" = systemd ] || return 0
  cpa_pid=$(systemctl show "$CPA_SERVICE" -p MainPID --value)
  cpamp_pid=$(systemctl show "$CPAMP_SERVICE" -p MainPID --value)
  case "$cpa_pid" in ''|0) fail "CPA has no running MainPID" ;; esac
  case "$cpamp_pid" in ''|0) fail "CPAMP has no running MainPID" ;; esac
  [ -e "/proc/$cpa_pid/exe" ] || fail "CPA process executable is unavailable"
  [ -e "/proc/$cpamp_pid/exe" ] || fail "CPAMP process executable is unavailable"
  cpa_disk_hash=$(sha256sum "$ROOT/cli-proxy-api-plus" | awk '{print $1}')
  cpa_proc_hash=$(sha256sum "/proc/$cpa_pid/exe" | awk '{print $1}')
  [ "$cpa_disk_hash" = "$cpa_proc_hash" ] || fail "CPA is still running an old binary"
  cpamp_disk_hash=$(sha256sum "$ROOT/manager/cpa-manager-plus" | awk '{print $1}')
  cpamp_proc_hash=$(sha256sum "/proc/$cpamp_pid/exe" | awk '{print $1}')
  [ "$cpamp_disk_hash" = "$cpamp_proc_hash" ] || fail "CPAMP is still running an old binary"
  case $(readlink "/proc/$cpa_pid/exe") in *" (deleted)"*) fail "CPA is running a deleted binary" ;; esac
  case $(readlink "/proc/$cpamp_pid/exe") in *" (deleted)"*) fail "CPAMP is running a deleted binary" ;; esac
  "/proc/$cpa_pid/exe" --version >/dev/null 2>&1 || fail "running CPA version check failed"
  log "Verified running CPA and CPAMP binaries."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag) [ "$#" -ge 2 ] || fail "$1 requires a value"; TAG=$2; shift 2 ;;
    --repository|--repo) [ "$#" -ge 2 ] || fail "$1 requires a value"; REPOSITORY=$2; shift 2 ;;
    --bucket) [ "$#" -ge 2 ] || fail "$1 requires a value"; BUCKET=$2; shift 2 ;;
    --prefix) [ "$#" -ge 2 ] || fail "$1 requires a value"; PREFIX=$2; shift 2 ;;
    --endpoint) [ "$#" -ge 2 ] || fail "$1 requires a value"; ENDPOINT=$2; shift 2 ;;
    --archive) [ "$#" -ge 2 ] || fail "$1 requires a value"; ARCHIVE=$2; shift 2 ;;
    --checksums|--checksum) [ "$#" -ge 2 ] || fail "$1 requires a value"; CHECKSUMS=$2; shift 2 ;;
    --download-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; DOWNLOAD_DIR=$2; shift 2 ;;
    --root|--install-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; ROOT=$2; shift 2 ;;
    --mode) [ "$#" -ge 2 ] || fail "$1 requires a value"; MODE=$2; shift 2 ;;
    --cpa-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPA_SERVICE=$2; shift 2 ;;
    --cpamp-service) [ "$#" -ge 2 ] || fail "$1 requires a value"; CPAMP_SERVICE=$2; shift 2 ;;
    --health-timeout) [ "$#" -ge 2 ] || fail "$1 requires a value"; HEALTH_TIMEOUT=$2; shift 2 ;;
    --no-restart) NO_RESTART=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[ -n "$ROOT" ] || ROOT=$(script_dir)
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)
[ -n "$TAG" ] || fail "--tag is required"
[ -f "$ROOT/config.yaml" ] || fail "config not found: $ROOT/config.yaml"
resolve_mode
VERSION=$(strip_v "$TAG")
ARCH=$(normalize_arch)
ASSET="CLIProxyAPIPlus_${VERSION}_linux_${ARCH}.tar.gz"
DOWNLOAD_DIR=${DOWNLOAD_DIR:-"$ROOT/.update/downloads/$TAG"}
ARCHIVE=${ARCHIVE:-"$DOWNLOAD_DIR/$ASSET"}
CHECKSUMS=${CHECKSUMS:-"$DOWNLOAD_DIR/checksums.txt"}
STAGING_DIR="$ROOT/.update/staging"
BACKUP_DIR="$ROOT/.update/backups/$(date -u +%Y%m%dT%H%M%SZ)"

need_cmd tar
need_cmd sha256sum
need_cmd uname
need_cmd flock
need_cmd awk
run mkdir -p "$DOWNLOAD_DIR" "$STAGING_DIR" "$ROOT/.update/backups"
if [ "$DRY_RUN" -eq 0 ]; then
  exec 9>"$ROOT/.update/update.lock"
  flock -n 9 || fail "another update is already running"
fi

if [ ! -f "$ARCHIVE" ] || [ ! -f "$CHECKSUMS" ]; then
  if [ -n "$BUCKET" ]; then
    need_cmd "$OSSUTIL"
    PREFIX=$(trim_slashes "$PREFIX")
    if [ -n "$PREFIX" ]; then OSS_BASE="oss://${BUCKET}/${PREFIX}/${TAG}"; else OSS_BASE="oss://${BUCKET}/${TAG}"; fi
    if [ -n "$ENDPOINT" ]; then
      run "$OSSUTIL" cp "${OSS_BASE}/${ASSET}" "$ARCHIVE" -f -e "$ENDPOINT"
      run "$OSSUTIL" cp "${OSS_BASE}/checksums.txt" "$CHECKSUMS" -f -e "$ENDPOINT"
    else
      run "$OSSUTIL" cp "${OSS_BASE}/${ASSET}" "$ARCHIVE" -f
      run "$OSSUTIL" cp "${OSS_BASE}/checksums.txt" "$CHECKSUMS" -f
    fi
  else
    need_cmd curl
    RELEASE_BASE="https://github.com/${REPOSITORY}/releases/download/${TAG}"
    run curl -fL --retry 5 --retry-delay 2 --retry-connrefused "${RELEASE_BASE}/${ASSET}" -o "$ARCHIVE"
    run curl -fL --retry 5 --retry-delay 2 --retry-connrefused "${RELEASE_BASE}/checksums.txt" -o "$CHECKSUMS"
  fi
fi

log "Verifying checksum..."
checksum_line=$(awk -v name="$(basename -- "$ARCHIVE")" '{ file = $NF; sub(/^\*/, "", file); sub(/\r$/, "", file); if (file == name) { print $1 "  " name; exit } }' "$CHECKSUMS")
[ -n "$checksum_line" ] || fail "archive checksum not found: $(basename -- "$ARCHIVE")"
(cd "$(dirname -- "$ARCHIVE")" && printf '%s\n' "$checksum_line" | sha256sum -c -) || fail "checksum verification failed"
run rm -rf "$STAGING_DIR"
run mkdir -p "$STAGING_DIR" "$BACKUP_DIR/manager"
run tar -xzf "$ARCHIVE" -C "$STAGING_DIR"
NEW_BIN=$(find "$STAGING_DIR" -type f -name cli-proxy-api-plus 2>/dev/null | head -n 1 || true)
NEW_MANAGER_BIN=$(find "$STAGING_DIR" -type f -path '*/manager/cpa-manager-plus' 2>/dev/null | head -n 1 || true)
[ -n "$NEW_BIN" ] || fail "cli-proxy-api-plus not found in archive"
[ -n "$NEW_MANAGER_BIN" ] || fail "cpa-manager-plus not found in archive"
run chmod +x "$NEW_BIN" "$NEW_MANAGER_BIN"
[ "$DRY_RUN" -eq 1 ] || "$NEW_BIN" --version >/dev/null 2>&1 || fail "new CPA binary version check failed"

for file in cli-proxy-api-plus start.sh stop.sh restart.sh update.sh; do
  [ -f "$ROOT/$file" ] && run cp "$ROOT/$file" "$BACKUP_DIR/$file"
done
[ -f "$ROOT/manager/cpa-manager-plus" ] && run cp "$ROOT/manager/cpa-manager-plus" "$BACKUP_DIR/manager/cpa-manager-plus"
trap rollback EXIT INT TERM
INSTALLED=1
install_executable "$NEW_BIN" "$ROOT/cli-proxy-api-plus"
run mkdir -p "$ROOT/manager"
install_executable "$NEW_MANAGER_BIN" "$ROOT/manager/cpa-manager-plus"
for file in start.sh stop.sh restart.sh README.md README_CN.md README_JA.md config.example.yaml; do
  [ -f "$STAGING_DIR/$file" ] && run cp "$STAGING_DIR/$file" "$ROOT/$file"
done
[ -f "$STAGING_DIR/update.sh" ] && install_executable "$STAGING_DIR/update.sh" "$ROOT/update.sh"
run chmod +x "$ROOT/start.sh" "$ROOT/stop.sh" "$ROOT/restart.sh"

if [ "$NO_RESTART" -eq 0 ]; then
  restart_services
  [ "$DRY_RUN" -eq 1 ] || verify_running_binaries
else
  log "Skipping restart and running-process validation."
fi
INSTALLED=0
trap - EXIT INT TERM
log "Update complete. Backup: $BACKUP_DIR"
