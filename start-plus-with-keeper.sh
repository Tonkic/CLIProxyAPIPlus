#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG=${CONFIG:-"$ROOT/config.yaml"}
KEEPER_ENV=${KEEPER_ENV:-"$ROOT/keeper/.env"}
LOG_DIR=${LOG_DIR:-"$ROOT/logs"}
mkdir -p "$LOG_DIR"

CPA_EXE="$ROOT/cli-proxy-api-plus"
if [ ! -x "$CPA_EXE" ]; then
  CPA_EXE="$ROOT/CLIProxyAPIPlus"
fi
if [ ! -x "$CPA_EXE" ]; then
  echo "CLIProxyAPIPlus executable not found. Expected cli-proxy-api-plus or CLIProxyAPIPlus next to this script." >&2
  exit 1
fi

KEEPER_EXE="$ROOT/keeper/cpa-usage-keeper"
if [ ! -x "$KEEPER_EXE" ]; then
  echo "CPA Usage Keeper executable not found: $KEEPER_EXE" >&2
  exit 1
fi
if [ ! -f "$CONFIG" ]; then
  echo "Config file not found: $CONFIG" >&2
  exit 1
fi
if [ ! -f "$KEEPER_ENV" ]; then
  echo "Keeper env file not found: $KEEPER_ENV" >&2
  exit 1
fi

"$CPA_EXE" --config "$CONFIG" >"$LOG_DIR/cli-proxy-api-plus.out.log" 2>"$LOG_DIR/cli-proxy-api-plus.err.log" &
CPA_PID=$!
sleep 2
(
  cd "$ROOT/keeper"
  "$KEEPER_EXE" --env "$KEEPER_ENV"
) >"$LOG_DIR/cpa-usage-keeper.out.log" 2>"$LOG_DIR/cpa-usage-keeper.err.log" &
KEEPER_PID=$!

cleanup() {
  kill "$KEEPER_PID" "$CPA_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "CLIProxyAPIPlus started: PID=$CPA_PID, http://127.0.0.1:8317"
echo "CPA Usage Keeper started: PID=$KEEPER_PID, http://127.0.0.1:8080"
echo "Logs: $LOG_DIR"
echo "Press Ctrl+C to stop both services."

wait
