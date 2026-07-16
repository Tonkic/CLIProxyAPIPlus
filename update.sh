#!/usr/bin/env sh
set -eu

TAG=${UPDATE_TAG:-}
BUCKET=${ALIYUN_OSS_BUCKET:-}
PREFIX=${ALIYUN_OSS_PREFIX:-CLIProxyAPIPlus}
ENDPOINT=${ALIYUN_OSS_ENDPOINT:-}
OSSUTIL=${OSSUTIL_BIN:-ossutil}
ARCHIVE=${UPDATE_ARCHIVE:-}
CHECKSUMS=${UPDATE_CHECKSUMS:-}
ROOT=""
DOWNLOAD_DIR=""
NO_RESTART=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: update.sh --tag VERSION [options]

Update CLIProxyAPI Plus from Aliyun OSS or local release files, then restart services.

Options:
  --tag VERSION          Release tag, for example v7.2.80.1.
  --bucket NAME          OSS bucket. Can also be set with ALIYUN_OSS_BUCKET.
  --prefix PREFIX        OSS prefix. Defaults to CLIProxyAPIPlus.
  --endpoint ENDPOINT    OSS endpoint. Can also be set with ALIYUN_OSS_ENDPOINT.
  --archive PATH         Local release archive instead of OSS download.
  --checksums PATH       Local checksums.txt.
  --download-dir PATH    Download directory. Defaults to ROOT/.update/downloads/TAG.
  --root PATH            Install directory. Defaults to this script's directory.
  --no-restart           Install only.
  --dry-run              Print commands only.
  --help                 Show this help.

Example:
  ./update.sh --tag v7.2.80.1 --bucket update-cpa-plus --endpoint oss-cn-shenzhen.aliyuncs.com
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
run() { log "+ $*"; [ "$DRY_RUN" -eq 1 ] || "$@"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
script_dir() { CDPATH= cd -- "$(dirname -- "$0")" && pwd; }
strip_v() { case "$1" in v*) printf '%s' "${1#v}" ;; *) printf '%s' "$1" ;; esac; }
trim_slashes() { v=${1#/}; v=${v%/}; printf '%s' "$v"; }

normalize_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *) fail "unsupported architecture: $arch" ;;
  esac
}

install_executable() {
  src=$1
  dst=$2
  tmp="${dst}.new.$$"
  run cp "$src" "$tmp"
  run chmod +x "$tmp"
  run mv -f "$tmp" "$dst"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag) [ "$#" -ge 2 ] || fail "$1 requires a value"; TAG=$2; shift 2 ;;
    --bucket) [ "$#" -ge 2 ] || fail "$1 requires a value"; BUCKET=$2; shift 2 ;;
    --prefix) [ "$#" -ge 2 ] || fail "$1 requires a value"; PREFIX=$2; shift 2 ;;
    --endpoint) [ "$#" -ge 2 ] || fail "$1 requires a value"; ENDPOINT=$2; shift 2 ;;
    --archive) [ "$#" -ge 2 ] || fail "$1 requires a value"; ARCHIVE=$2; shift 2 ;;
    --checksums|--checksum) [ "$#" -ge 2 ] || fail "$1 requires a value"; CHECKSUMS=$2; shift 2 ;;
    --download-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; DOWNLOAD_DIR=$2; shift 2 ;;
    --root|--install-dir) [ "$#" -ge 2 ] || fail "$1 requires a value"; ROOT=$2; shift 2 ;;
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

VERSION=$(strip_v "$TAG")
ARCH=$(normalize_arch)
ASSET="CLIProxyAPIPlus_${VERSION}_linux_${ARCH}.tar.gz"
DOWNLOAD_DIR=${DOWNLOAD_DIR:-"$ROOT/.update/downloads/$TAG"}
ARCHIVE=${ARCHIVE:-"$DOWNLOAD_DIR/$ASSET"}
CHECKSUMS=${CHECKSUMS:-"$DOWNLOAD_DIR/checksums.txt"}

need_cmd tar
need_cmd sha256sum
need_cmd uname

run mkdir -p "$DOWNLOAD_DIR" "$ROOT/.update/staging" "$ROOT/.update/backups"

if [ ! -f "$ARCHIVE" ] || [ ! -f "$CHECKSUMS" ]; then
  [ -n "$BUCKET" ] || fail "--bucket or ALIYUN_OSS_BUCKET is required when archive/checksums are not local"
  need_cmd "$OSSUTIL"
  PREFIX=$(trim_slashes "$PREFIX")
  if [ -n "$PREFIX" ]; then
    OSS_BASE="oss://${BUCKET}/${PREFIX}/${TAG}"
  else
    OSS_BASE="oss://${BUCKET}/${TAG}"
  fi
  if [ -n "$ENDPOINT" ]; then
    run "$OSSUTIL" cp "${OSS_BASE}/${ASSET}" "$ARCHIVE" -f -e "$ENDPOINT"
    run "$OSSUTIL" cp "${OSS_BASE}/checksums.txt" "$CHECKSUMS" -f -e "$ENDPOINT"
  else
    run "$OSSUTIL" cp "${OSS_BASE}/${ASSET}" "$ARCHIVE" -f
    run "$OSSUTIL" cp "${OSS_BASE}/checksums.txt" "$CHECKSUMS" -f
  fi
fi

log "Verifying checksum..."
(cd "$(dirname -- "$ARCHIVE")" && grep "  $(basename -- "$ARCHIVE")\$" "$CHECKSUMS" | sha256sum -c -) || fail "checksum verification failed"

BACKUP_DIR="$ROOT/.update/backups/$(date -u +%Y%m%dT%H%M%SZ)"
STAGING_DIR="$ROOT/.update/staging"
run rm -rf "$STAGING_DIR"
run mkdir -p "$STAGING_DIR" "$BACKUP_DIR"
run tar -xzf "$ARCHIVE" -C "$STAGING_DIR"

NEW_BIN=$(find "$STAGING_DIR" -type f -name cli-proxy-api-plus 2>/dev/null | head -n 1 || true)
[ -n "$NEW_BIN" ] || fail "cli-proxy-api-plus not found in archive"
[ -f "$ROOT/cli-proxy-api-plus" ] && run cp "$ROOT/cli-proxy-api-plus" "$BACKUP_DIR/cli-proxy-api-plus"
install_executable "$NEW_BIN" "$ROOT/cli-proxy-api-plus"

for file in start.sh stop.sh restart.sh update.sh README.md README_CN.md README_JA.md config.example.yaml; do
  [ -f "$STAGING_DIR/$file" ] && run cp "$STAGING_DIR/$file" "$ROOT/$file"
done

NEW_MANAGER_BIN=$(find "$STAGING_DIR" -type f -path '*/manager/cpa-manager-plus' 2>/dev/null | head -n 1 || true)
if [ -n "$NEW_MANAGER_BIN" ]; then
  run mkdir -p "$ROOT/manager" "$BACKUP_DIR/manager"
  [ -f "$ROOT/manager/cpa-manager-plus" ] && run cp "$ROOT/manager/cpa-manager-plus" "$BACKUP_DIR/manager/cpa-manager-plus"
  install_executable "$NEW_MANAGER_BIN" "$ROOT/manager/cpa-manager-plus"
fi

if [ "$NO_RESTART" -eq 0 ]; then
  run sh "$ROOT/restart.sh" --root "$ROOT"
else
  log "Skipping restart."
fi

log "Update complete."
