#!/usr/bin/env sh
set -eu

REPO="Tonkic/CLIProxyAPIPlus"
TAG=""
INSTALL_DIR=""
SESSION="cli"
CONFIG_PATH=""
LOG_PATH=""
BASE_URL_OVERRIDE=${UPDATE_BASE_URL:-}
LOCAL_ARCHIVE=${UPDATE_ARCHIVE:-}
LOCAL_CHECKSUMS=${UPDATE_CHECKSUMS:-}
DOWNLOAD_DIR_OVERRIDE=""
SKIP_CHECKSUM=0
NO_RESTART=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: update-linux.sh [options]

Download a CLIProxyAPIPlus Linux release, install it as ./cli-proxy-api-plus,
and restart the tmux session used by a simple release-directory deployment.

Options:
  --install-dir PATH  Installation directory. Defaults to this script's directory.
  --tag VERSION       Release tag to install, for example v6.10.0. Defaults to latest.
  --repo OWNER/REPO   GitHub repository. Defaults to Tonkic/CLIProxyAPIPlus.
  --base-url URL      Download base URL for a mirror/OSS path. Expected files:
                      URL/<asset> and URL/checksums.txt. Can also be set with UPDATE_BASE_URL.
  --archive PATH      Use a local release archive instead of downloading it.
                      Can also be set with UPDATE_ARCHIVE.
  --checksums PATH    Use a local checksums.txt file instead of downloading it.
                      Can also be set with UPDATE_CHECKSUMS.
  --download-dir PATH Directory used for downloaded/copied release files.
  --skip-checksum     Install without checksum verification. Not recommended.
  --session NAME      tmux session name. Defaults to cli.
  --config PATH       Config path. Defaults to INSTALL_DIR/config.yaml.
  --log PATH          Runtime log path. Defaults to INSTALL_DIR/runtime.log.
  --no-restart        Install only; do not restart tmux.
  --dry-run           Print planned actions without changing files or restarting.
  --help              Show this help.

Examples:
  ./update-linux.sh
  ./update-linux.sh --tag v7.0.3.1
  ./update-linux.sh --tag v7.0.3.1 --base-url https://example.com/CLIProxyAPIPlus/v7.0.3.1
  ./update-linux.sh --archive ./CLIProxyAPIPlus_7.0.3.1_linux_amd64.tar.gz --checksums ./checksums.txt
  ./update-linux.sh --install-dir /opt/CLIProxyAPIPlus --session cli
EOF
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

quote_squote() {
  printf "%s" "$1" | sed "s/'/'\\''/g"
}

run() {
  log "+ $*"
  if [ "$DRY_RUN" -eq 0 ]; then
    "$@"
  fi
}

install_executable() {
  src=$1
  dst=$2
  tmp="${dst}.new.$$"
  run cp "$src" "$tmp"
  run chmod +x "$tmp"
  run mv -f "$tmp" "$dst"
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

api_get() {
  url=$1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    fail "curl or wget is required"
  fi
}

download_file() {
  url=$1
  out=$2
  if command -v curl >/dev/null 2>&1; then
    run curl -fL --retry 3 --connect-timeout 15 -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    run wget -O "$out" "$url"
  else
    fail "curl or wget is required"
  fi
}

latest_tag() {
  json=$(api_get "https://api.github.com/repos/${REPO}/releases/latest")
  tag=$(printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$tag" ] || fail "failed to parse latest release tag for ${REPO}"
  printf '%s' "$tag"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      [ "$#" -ge 2 ] || fail "--install-dir requires a value"
      INSTALL_DIR=$2
      shift 2
      ;;
    --tag)
      [ "$#" -ge 2 ] || fail "--tag requires a value"
      TAG=$2
      shift 2
      ;;
    --repo)
      [ "$#" -ge 2 ] || fail "--repo requires a value"
      REPO=$2
      shift 2
      ;;
    --base-url)
      [ "$#" -ge 2 ] || fail "--base-url requires a value"
      BASE_URL_OVERRIDE=$2
      shift 2
      ;;
    --archive)
      [ "$#" -ge 2 ] || fail "--archive requires a value"
      LOCAL_ARCHIVE=$2
      shift 2
      ;;
    --checksums|--checksum)
      [ "$#" -ge 2 ] || fail "--checksums requires a value"
      LOCAL_CHECKSUMS=$2
      shift 2
      ;;
    --download-dir)
      [ "$#" -ge 2 ] || fail "--download-dir requires a value"
      DOWNLOAD_DIR_OVERRIDE=$2
      shift 2
      ;;
    --skip-checksum)
      SKIP_CHECKSUM=1
      shift
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

[ -n "$INSTALL_DIR" ] || INSTALL_DIR=$(script_dir)
INSTALL_DIR=$(CDPATH= cd -- "$INSTALL_DIR" && pwd)
CONFIG_PATH=${CONFIG_PATH:-"$INSTALL_DIR/config.yaml"}
LOG_PATH=${LOG_PATH:-"$INSTALL_DIR/runtime.log"}
BIN_PATH="$INSTALL_DIR/cli-proxy-api-plus"
UPDATE_DIR="$INSTALL_DIR/.update"
DOWNLOAD_DIR=${DOWNLOAD_DIR_OVERRIDE:-"$UPDATE_DIR/downloads"}
STAGING_DIR="$UPDATE_DIR/staging"
BACKUP_DIR="$UPDATE_DIR/backups/$(date -u +%Y%m%dT%H%M%SZ)"
ARCH=$(normalize_arch)
OS=linux

need_cmd tar
if [ "$NO_RESTART" -eq 0 ]; then
  need_cmd tmux
fi

if [ -z "$TAG" ] && [ -z "$LOCAL_ARCHIVE" ]; then
  TAG=$(latest_tag)
fi
if [ -n "$LOCAL_ARCHIVE" ]; then
  [ -f "$LOCAL_ARCHIVE" ] || fail "local archive not found: $LOCAL_ARCHIVE"
  ASSET=$(basename -- "$LOCAL_ARCHIVE")
  if [ -z "$TAG" ]; then
    TAG="local"
  fi
else
  VERSION=$(strip_v "$TAG")
  ASSET="CLIProxyAPIPlus_${VERSION}_${OS}_${ARCH}.tar.gz"
fi
if [ -n "$BASE_URL_OVERRIDE" ]; then
  BASE_URL=$(printf '%s' "$BASE_URL_OVERRIDE" | sed 's:/*$::')
else
  BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
fi
ARCHIVE_URL="${BASE_URL}/${ASSET}"
CHECKSUM_URL="${BASE_URL}/checksums.txt"
ARCHIVE_PATH="$DOWNLOAD_DIR/$ASSET"
CHECKSUM_PATH="$DOWNLOAD_DIR/checksums.txt"

log "Repository: $REPO"
log "Release tag: $TAG"
log "Asset: $ASSET"
if [ -n "$BASE_URL_OVERRIDE" ]; then
  log "Download base URL: $BASE_URL"
fi
if [ -n "$LOCAL_ARCHIVE" ]; then
  log "Local archive: $LOCAL_ARCHIVE"
fi
if [ -n "$LOCAL_CHECKSUMS" ]; then
  log "Local checksums: $LOCAL_CHECKSUMS"
fi
log "Install dir: $INSTALL_DIR"
log "Binary: $BIN_PATH"
log "Config: $CONFIG_PATH"
log "Log: $LOG_PATH"
log "tmux session: $SESSION"

[ -f "$CONFIG_PATH" ] || fail "config not found: $CONFIG_PATH"

run mkdir -p "$DOWNLOAD_DIR" "$STAGING_DIR" "$BACKUP_DIR" "$(dirname -- "$LOG_PATH")"

if [ -n "$LOCAL_ARCHIVE" ]; then
  if [ "$(CDPATH= cd -- "$(dirname -- "$LOCAL_ARCHIVE")" && pwd)/$(basename -- "$LOCAL_ARCHIVE")" != "$ARCHIVE_PATH" ]; then
    run cp "$LOCAL_ARCHIVE" "$ARCHIVE_PATH"
  else
    log "Using local archive already in download dir: $ARCHIVE_PATH"
  fi
else
  download_file "$ARCHIVE_URL" "$ARCHIVE_PATH"
fi

if [ -n "$LOCAL_CHECKSUMS" ]; then
  [ -f "$LOCAL_CHECKSUMS" ] || fail "local checksums file not found: $LOCAL_CHECKSUMS"
  if [ "$(CDPATH= cd -- "$(dirname -- "$LOCAL_CHECKSUMS")" && pwd)/$(basename -- "$LOCAL_CHECKSUMS")" != "$CHECKSUM_PATH" ]; then
    run cp "$LOCAL_CHECKSUMS" "$CHECKSUM_PATH"
  else
    log "Using local checksums already in download dir: $CHECKSUM_PATH"
  fi
elif [ -n "$LOCAL_ARCHIVE" ] && [ -f "$(dirname -- "$LOCAL_ARCHIVE")/checksums.txt" ]; then
  run cp "$(dirname -- "$LOCAL_ARCHIVE")/checksums.txt" "$CHECKSUM_PATH"
elif [ "$SKIP_CHECKSUM" -eq 0 ]; then
  download_file "$CHECKSUM_URL" "$CHECKSUM_PATH"
fi

if [ "$DRY_RUN" -ne 0 ]; then
  log "Dry run complete. No files were changed."
  exit 0
fi

if [ "$SKIP_CHECKSUM" -eq 1 ]; then
  log "Skipping checksum verification because --skip-checksum was provided."
elif command -v sha256sum >/dev/null 2>&1; then
  log "Verifying checksum..."
  if [ "$DRY_RUN" -eq 0 ]; then
    [ -f "$CHECKSUM_PATH" ] || fail "checksums file not found: $CHECKSUM_PATH"
    (cd "$DOWNLOAD_DIR" && grep "  $ASSET\$" checksums.txt | sha256sum -c -) || fail "checksum verification failed for $ASSET"
  else
    log "+ (cd '$DOWNLOAD_DIR' && grep '  $ASSET$' checksums.txt | sha256sum -c -)"
  fi
else
  fail "sha256sum is required for checksum verification"
fi

run rm -rf "$STAGING_DIR"
run mkdir -p "$STAGING_DIR"
run tar -xzf "$ARCHIVE_PATH" -C "$STAGING_DIR"

NEW_BIN=""
if [ -f "$STAGING_DIR/cli-proxy-api-plus" ]; then
  NEW_BIN="$STAGING_DIR/cli-proxy-api-plus"
elif [ -f "$STAGING_DIR/bin/cli-proxy-api-plus" ]; then
  NEW_BIN="$STAGING_DIR/bin/cli-proxy-api-plus"
else
  NEW_BIN=$(find "$STAGING_DIR" -type f -name cli-proxy-api-plus 2>/dev/null | head -n 1 || true)
fi
[ -n "$NEW_BIN" ] || fail "cli-proxy-api-plus not found in archive"

if [ -f "$BIN_PATH" ]; then
  run cp "$BIN_PATH" "$BACKUP_DIR/cli-proxy-api-plus"
fi
install_executable "$NEW_BIN" "$BIN_PATH"

for file in start-plus-with-keeper.sh start-plus-with-keeper.ps1 update-linux-oss.sh README.md README_CN.md README_JA.md config.example.yaml; do
  if [ -f "$STAGING_DIR/$file" ]; then
    run cp "$STAGING_DIR/$file" "$INSTALL_DIR/$file"
  fi
done

if [ -f "$STAGING_DIR/keeper/.env.example" ]; then
  run mkdir -p "$INSTALL_DIR/keeper"
  run cp "$STAGING_DIR/keeper/.env.example" "$INSTALL_DIR/keeper/.env.example"
fi
if [ -f "$STAGING_DIR/keeper/cpa-usage-keeper" ]; then
  run mkdir -p "$INSTALL_DIR/keeper"
  install_executable "$STAGING_DIR/keeper/cpa-usage-keeper" "$INSTALL_DIR/keeper/cpa-usage-keeper"
fi

if [ "$NO_RESTART" -eq 0 ]; then
  log "Restarting tmux session: $SESSION"
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    run tmux kill-session -t "$SESSION"
  fi
  install_q=$(quote_squote "$INSTALL_DIR")
  bin_q=$(quote_squote "$BIN_PATH")
  config_q=$(quote_squote "$CONFIG_PATH")
  log_q=$(quote_squote "$LOG_PATH")
  cmd="cd '$install_q' && '$bin_q' -config '$config_q' >> '$log_q' 2>&1"
  run tmux new-session -d -s "$SESSION" "$cmd"
else
  log "Skipping restart because --no-restart was provided."
fi

log "Update complete."
log "Status: tmux ls"
log "Logs: tail -n 50 '$LOG_PATH'"
