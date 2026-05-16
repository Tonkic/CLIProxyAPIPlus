#!/usr/bin/env sh
set -eu

INSTALL_DIR=""
CLI_SESSION=${CLI_SESSION:-cli}
KEEPER_SESSION=${KEEPER_SESSION:-keeper}
CONFIG_PATH=""
KEEPER_ENV=""
LOG_DIR=""
CLI_LOG=""
KEEPER_OUT_LOG=""
KEEPER_ERR_LOG=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: restart-plus-with-keeper.sh [options]

Restart CLIProxyAPI Plus and CPA Usage Keeper in separate tmux sessions.

Options:
  --install-dir PATH       Installation directory. Defaults to this script's directory.
  --cli-session NAME       CLIProxyAPI Plus tmux session. Defaults to cli.
  --keeper-session NAME    CPA Usage Keeper tmux session. Defaults to keeper.
  --config PATH            CLIProxyAPI Plus config path. Defaults to INSTALL_DIR/config.yaml.
  --keeper-env PATH        Keeper env path. Defaults to INSTALL_DIR/keeper/.env.
  --log-dir PATH           Log directory. Defaults to INSTALL_DIR/logs.
  --cli-log PATH           CLIProxyAPI Plus log path. Defaults to LOG_DIR/runtime.log.
  --keeper-out-log PATH    Keeper stdout log path. Defaults to LOG_DIR/cpa-usage-keeper.out.log.
  --keeper-err-log PATH    Keeper stderr log path. Defaults to LOG_DIR/cpa-usage-keeper.err.log.
  --dry-run                Print planned actions without changing sessions.
  --help                   Show this help.

Example:
  ./restart-plus-with-keeper.sh
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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      [ "$#" -ge 2 ] || fail "--install-dir requires a value"
      INSTALL_DIR=$2
      shift 2
      ;;
    --cli-session)
      [ "$#" -ge 2 ] || fail "--cli-session requires a value"
      CLI_SESSION=$2
      shift 2
      ;;
    --keeper-session)
      [ "$#" -ge 2 ] || fail "--keeper-session requires a value"
      KEEPER_SESSION=$2
      shift 2
      ;;
    --config)
      [ "$#" -ge 2 ] || fail "--config requires a value"
      CONFIG_PATH=$2
      shift 2
      ;;
    --keeper-env)
      [ "$#" -ge 2 ] || fail "--keeper-env requires a value"
      KEEPER_ENV=$2
      shift 2
      ;;
    --log-dir)
      [ "$#" -ge 2 ] || fail "--log-dir requires a value"
      LOG_DIR=$2
      shift 2
      ;;
    --cli-log)
      [ "$#" -ge 2 ] || fail "--cli-log requires a value"
      CLI_LOG=$2
      shift 2
      ;;
    --keeper-out-log)
      [ "$#" -ge 2 ] || fail "--keeper-out-log requires a value"
      KEEPER_OUT_LOG=$2
      shift 2
      ;;
    --keeper-err-log)
      [ "$#" -ge 2 ] || fail "--keeper-err-log requires a value"
      KEEPER_ERR_LOG=$2
      shift 2
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
KEEPER_ENV=${KEEPER_ENV:-"$INSTALL_DIR/keeper/.env"}
LOG_DIR=${LOG_DIR:-"$INSTALL_DIR/logs"}
CLI_LOG=${CLI_LOG:-"$LOG_DIR/runtime.log"}
KEEPER_OUT_LOG=${KEEPER_OUT_LOG:-"$LOG_DIR/cpa-usage-keeper.out.log"}
KEEPER_ERR_LOG=${KEEPER_ERR_LOG:-"$LOG_DIR/cpa-usage-keeper.err.log"}

BIN_PATH="$INSTALL_DIR/cli-proxy-api-plus"
KEEPER_DIR="$INSTALL_DIR/keeper"
KEEPER_BIN="$KEEPER_DIR/cpa-usage-keeper"

need_cmd tmux

[ -x "$BIN_PATH" ] || fail "CLIProxyAPI Plus binary not found or not executable: $BIN_PATH"
[ -f "$CONFIG_PATH" ] || fail "config not found: $CONFIG_PATH"
[ -x "$KEEPER_BIN" ] || fail "CPA Usage Keeper binary not found or not executable: $KEEPER_BIN"
[ -f "$KEEPER_ENV" ] || fail "keeper env not found: $KEEPER_ENV"

run mkdir -p "$LOG_DIR"

if tmux has-session -t "$CLI_SESSION" 2>/dev/null; then
  run tmux kill-session -t "$CLI_SESSION"
fi
if tmux has-session -t "$KEEPER_SESSION" 2>/dev/null; then
  run tmux kill-session -t "$KEEPER_SESSION"
fi

install_q=$(quote_squote "$INSTALL_DIR")
bin_q=$(quote_squote "$BIN_PATH")
config_q=$(quote_squote "$CONFIG_PATH")
cli_log_q=$(quote_squote "$CLI_LOG")
keeper_dir_q=$(quote_squote "$KEEPER_DIR")
keeper_bin_q=$(quote_squote "$KEEPER_BIN")
keeper_env_q=$(quote_squote "$KEEPER_ENV")
keeper_out_q=$(quote_squote "$KEEPER_OUT_LOG")
keeper_err_q=$(quote_squote "$KEEPER_ERR_LOG")

cli_cmd="cd '$install_q' && '$bin_q' -config '$config_q' >> '$cli_log_q' 2>&1"
keeper_cmd="cd '$keeper_dir_q' && '$keeper_bin_q' --env '$keeper_env_q' >> '$keeper_out_q' 2>> '$keeper_err_q'"

run tmux new-session -d -s "$CLI_SESSION" "$cli_cmd"
run tmux new-session -d -s "$KEEPER_SESSION" "$keeper_cmd"

log "Restart complete."
log "CLI session: $CLI_SESSION"
log "Keeper session: $KEEPER_SESSION"
log "Status: tmux ls"
log "CLI log: tail -n 50 '$CLI_LOG'"
log "Keeper log: tail -n 50 '$KEEPER_OUT_LOG'"
