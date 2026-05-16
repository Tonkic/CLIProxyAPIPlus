#!/usr/bin/env sh
set -eu

TAG=${UPDATE_TAG:-}
BUCKET=${ALIYUN_OSS_BUCKET:-}
PREFIX=${ALIYUN_OSS_PREFIX:-CLIProxyAPIPlus}
ENDPOINT=${ALIYUN_OSS_ENDPOINT:-}
ACCESS_KEY_ID=${ALIYUN_OSS_ACCESS_KEY_ID:-}
ACCESS_KEY_SECRET=${ALIYUN_OSS_ACCESS_KEY_SECRET:-}
OSSUTIL=${OSSUTIL_BIN:-ossutil}
INSTALL_DIR=""
SESSION=""
CONFIG_PATH=""
LOG_PATH=""
RESTART_SCRIPT=""
DOWNLOAD_DIR=""
NO_RESTART=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: update-linux-oss.sh --tag VERSION --bucket BUCKET [options]

Download a private Aliyun OSS release archive with ossutil, then run update-linux.sh
with the downloaded archive and checksums.txt.

Options:
  --tag VERSION              Release tag to install, for example v7.1.1.1.
                             Can also be set with UPDATE_TAG.
  --bucket NAME              OSS bucket name. Can also be set with ALIYUN_OSS_BUCKET.
  --prefix PREFIX            OSS object prefix. Defaults to CLIProxyAPIPlus.
                             Can also be set with ALIYUN_OSS_PREFIX.
  --endpoint ENDPOINT        OSS endpoint. Can also be set with ALIYUN_OSS_ENDPOINT.
                             For same-region ECS, prefer an internal endpoint such as
                             oss-cn-shenzhen-internal.aliyuncs.com.
  --access-key-id VALUE      AccessKey ID. Can also be set with ALIYUN_OSS_ACCESS_KEY_ID.
  --access-key-secret VALUE  AccessKey secret. Can also be set with ALIYUN_OSS_ACCESS_KEY_SECRET.
  --download-dir PATH        Directory for downloaded release files.
  --install-dir PATH         Installation directory passed to update-linux.sh.
  --session NAME             tmux session name passed to update-linux.sh.
  --config PATH              Config path passed to update-linux.sh.
  --log PATH                 Runtime log path passed to update-linux.sh.
  --restart-script PATH      Restart script passed to update-linux.sh.
  --no-restart               Install only; do not restart tmux.
  --dry-run                  Print planned actions without downloading or installing.
  --help                     Show this help.

Examples:
  ./update-linux-oss.sh --tag v7.1.1.1 --bucket update-cpa-plus --endpoint oss-cn-shenzhen-internal.aliyuncs.com

  ALIYUN_OSS_BUCKET=update-cpa-plus \
  ALIYUN_OSS_ENDPOINT=oss-cn-shenzhen-internal.aliyuncs.com \
  ./update-linux-oss.sh --tag v7.1.1.1
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run() {
  log "+ $*"
  if [ "$DRY_RUN" -eq 0 ]; then
    "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

script_dir() {
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

normalize_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *) fail "unsupported architecture: $arch" ;;
  esac
}

strip_v() {
  case "$1" in
    v*) printf '%s' "${1#v}" ;;
    *) printf '%s' "$1" ;;
  esac
}

trim_slashes() {
  value=$1
  value=${value#/}
  value=${value%/}
  printf '%s' "$value"
}

ossutil_cp() {
  src=$1
  dst=$2
  log "+ ${OSSUTIL} cp ${src} ${dst}"
  if [ "$DRY_RUN" -ne 0 ]; then
    return 0
  fi

  if [ -n "$ACCESS_KEY_ID" ] || [ -n "$ACCESS_KEY_SECRET" ]; then
    [ -n "$ACCESS_KEY_ID" ] || fail "ALIYUN_OSS_ACCESS_KEY_ID is required when access key auth is used"
    [ -n "$ACCESS_KEY_SECRET" ] || fail "ALIYUN_OSS_ACCESS_KEY_SECRET is required when access key auth is used"
    [ -n "$ENDPOINT" ] || fail "ALIYUN_OSS_ENDPOINT is required when access key auth is used"
    "$OSSUTIL" cp "$src" "$dst" -f -e "$ENDPOINT" -i "$ACCESS_KEY_ID" -k "$ACCESS_KEY_SECRET"
  elif [ -n "$ENDPOINT" ]; then
    "$OSSUTIL" cp "$src" "$dst" -f -e "$ENDPOINT"
  else
    "$OSSUTIL" cp "$src" "$dst" -f
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag)
      [ "$#" -ge 2 ] || fail "--tag requires a value"
      TAG=$2
      shift 2
      ;;
    --bucket)
      [ "$#" -ge 2 ] || fail "--bucket requires a value"
      BUCKET=$2
      shift 2
      ;;
    --prefix)
      [ "$#" -ge 2 ] || fail "--prefix requires a value"
      PREFIX=$2
      shift 2
      ;;
    --endpoint)
      [ "$#" -ge 2 ] || fail "--endpoint requires a value"
      ENDPOINT=$2
      shift 2
      ;;
    --access-key-id)
      [ "$#" -ge 2 ] || fail "--access-key-id requires a value"
      ACCESS_KEY_ID=$2
      shift 2
      ;;
    --access-key-secret)
      [ "$#" -ge 2 ] || fail "--access-key-secret requires a value"
      ACCESS_KEY_SECRET=$2
      shift 2
      ;;
    --download-dir)
      [ "$#" -ge 2 ] || fail "--download-dir requires a value"
      DOWNLOAD_DIR=$2
      shift 2
      ;;
    --install-dir)
      [ "$#" -ge 2 ] || fail "--install-dir requires a value"
      INSTALL_DIR=$2
      shift 2
      ;;
    --session)
      [ "$#" -ge 2 ] || fail "--session requires a value"
      SESSION=$2
      shift 2
      ;;
    --config)
      [ "$#" -ge 2 ] || fail "--config requires a value"
      CONFIG_PATH=$2
      shift 2
      ;;
    --log)
      [ "$#" -ge 2 ] || fail "--log requires a value"
      LOG_PATH=$2
      shift 2
      ;;
    --restart-script)
      [ "$#" -ge 2 ] || fail "--restart-script requires a value"
      RESTART_SCRIPT=$2
      shift 2
      ;;
    --no-restart)
      NO_RESTART=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[ -n "$TAG" ] || fail "--tag is required"
[ -n "$BUCKET" ] || fail "--bucket or ALIYUN_OSS_BUCKET is required"

SCRIPT_DIR=$(script_dir)
UPDATE_SCRIPT="$SCRIPT_DIR/update-linux.sh"
[ -f "$UPDATE_SCRIPT" ] || fail "update-linux.sh not found next to update-linux-oss.sh"

need_cmd "$OSSUTIL"
need_cmd uname

VERSION=$(strip_v "$TAG")
ARCH=$(normalize_arch)
ASSET="CLIProxyAPIPlus_${VERSION}_linux_${ARCH}.tar.gz"
PREFIX=$(trim_slashes "$PREFIX")

if [ -z "$DOWNLOAD_DIR" ]; then
  DOWNLOAD_DIR="$SCRIPT_DIR/.update/oss-downloads/$TAG"
fi

if [ -n "$PREFIX" ]; then
  OSS_BASE="oss://${BUCKET}/${PREFIX}/${TAG}"
else
  OSS_BASE="oss://${BUCKET}/${TAG}"
fi
ARCHIVE_PATH="$DOWNLOAD_DIR/$ASSET"
CHECKSUM_PATH="$DOWNLOAD_DIR/checksums.txt"

log "Release tag: $TAG"
log "OSS archive: ${OSS_BASE}/${ASSET}"
log "OSS checksums: ${OSS_BASE}/checksums.txt"
log "Download dir: $DOWNLOAD_DIR"
if [ -n "$ENDPOINT" ]; then
  log "OSS endpoint: $ENDPOINT"
fi

run mkdir -p "$DOWNLOAD_DIR"
ossutil_cp "${OSS_BASE}/${ASSET}" "$ARCHIVE_PATH"
ossutil_cp "${OSS_BASE}/checksums.txt" "$CHECKSUM_PATH"

set -- "$UPDATE_SCRIPT" --tag "$TAG" --archive "$ARCHIVE_PATH" --checksums "$CHECKSUM_PATH"
if [ -n "$INSTALL_DIR" ]; then
  set -- "$@" --install-dir "$INSTALL_DIR"
fi
if [ -n "$SESSION" ]; then
  set -- "$@" --session "$SESSION"
fi
if [ -n "$CONFIG_PATH" ]; then
  set -- "$@" --config "$CONFIG_PATH"
fi
if [ -n "$LOG_PATH" ]; then
  set -- "$@" --log "$LOG_PATH"
fi
if [ -n "$RESTART_SCRIPT" ]; then
  set -- "$@" --restart-script "$RESTART_SCRIPT"
fi
if [ "$NO_RESTART" -eq 1 ]; then
  set -- "$@" --no-restart
fi
if [ "$DRY_RUN" -eq 1 ]; then
  set -- "$@" --dry-run
fi

run sh "$@"
