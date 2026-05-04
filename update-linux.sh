#!/usr/bin/env sh
set -eu

REPO="Tonkic/CLIProxyAPIPlus"
TAG=""
INSTALL_DIR=""
SESSION="cli"
CONFIG_PATH=""
LOG_PATH=""
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
  --session NAME      tmux session name. Defaults to cli.
  --config PATH       Config path. Defaults to INSTALL_DIR/config.yaml.
  --log PATH          Runtime log path. Defaults to INSTALL_DIR/runtime.log.
  --no-restart        Install only; do not restart tmux.
  --dry-run           Print planned actions without changing files or restarting.
  --help              Show this help.

Examples:
  ./update-linux.sh
  ./update-linux.sh --tag v6.10.0
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
DOWNLOAD_DIR="$UPDATE_DIR/downloads"
STAGING_DIR="$UPDATE_DIR/staging"
BACKUP_DIR="$UPDATE_DIR/backups/$(date -u +%Y%m%dT%H%M%SZ)"
ARCH=$(normalize_arch)
OS=linux

need_cmd tar
if [ "$NO_RESTART" -eq 0 ]; then
  need_cmd tmux
fi

if [ -z "$TAG" ]; then
  TAG=$(latest_tag)
fi
VERSION=$(strip_v "$TAG")
ASSET="CLIProxyAPIPlus_${VERSION}_${OS}_${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
ARCHIVE_URL="${BASE_URL}/${ASSET}"
CHECKSUM_URL="${BASE_URL}/checksums.txt"
ARCHIVE_PATH="$DOWNLOAD_DIR/$ASSET"
CHECKSUM_PATH="$DOWNLOAD_DIR/checksums.txt"

log "Repository: $REPO"
log "Release tag: $TAG"
log "Asset: $ASSET"
log "Install dir: $INSTALL_DIR"
log "Binary: $BIN_PATH"
log "Config: $CONFIG_PATH"
log "Log: $LOG_PATH"
log "tmux session: $SESSION"

[ -f "$CONFIG_PATH" ] || fail "config not found: $CONFIG_PATH"

run mkdir -p "$DOWNLOAD_DIR" "$STAGING_DIR" "$BACKUP_DIR" "$(dirname -- "$LOG_PATH")"

download_file "$ARCHIVE_URL" "$ARCHIVE_PATH"
download_file "$CHECKSUM_URL" "$CHECKSUM_PATH"

if [ "$DRY_RUN" -ne 0 ]; then
  log "Dry run complete. No files were changed."
  exit 0
fi

if command -v sha256sum >/dev/null 2>&1; then
  log "Verifying checksum..."
  if [ "$DRY_RUN" -eq 0 ]; then
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
run cp "$NEW_BIN" "$BIN_PATH"
run chmod +x "$BIN_PATH"

for file in start-plus-with-keeper.sh start-plus-with-keeper.ps1 README.md README_CN.md README_JA.md config.example.yaml; do
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
  run cp "$STAGING_DIR/keeper/cpa-usage-keeper" "$INSTALL_DIR/keeper/cpa-usage-keeper"
  run chmod +x "$INSTALL_DIR/keeper/cpa-usage-keeper"
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
