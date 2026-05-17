#!/usr/bin/env sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CLI_SESSION=${CLI_SESSION:-cli}
KEEPER_SESSION=${KEEPER_SESSION:-keeper}
DRY_RUN=0
START_ARGS=""

quote_squote() { printf "%s" "$1" | sed "s/'/'\\''/g"; }
append_arg() { START_ARGS="$START_ARGS '$(quote_squote "$1")'"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cli-session) [ "$#" -ge 2 ] || { echo "error: $1 requires a value" >&2; exit 1; }; CLI_SESSION=$2; append_arg "$1"; append_arg "$2"; shift 2 ;;
    --keeper-session) [ "$#" -ge 2 ] || { echo "error: $1 requires a value" >&2; exit 1; }; KEEPER_SESSION=$2; append_arg "$1"; append_arg "$2"; shift 2 ;;
    --root|--install-dir|--config|--keeper-env|--log-dir) [ "$#" -ge 2 ] || { echo "error: $1 requires a value" >&2; exit 1; }; append_arg "$1"; append_arg "$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; append_arg "$1"; shift ;;
    --help|-h) sh "$DIR/start.sh" --help; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; exit 1 ;;
  esac
done

stop_args="--cli-session '$(quote_squote "$CLI_SESSION")' --keeper-session '$(quote_squote "$KEEPER_SESSION")'"
[ "$DRY_RUN" -eq 1 ] && stop_args="$stop_args --dry-run"
eval "sh '$(quote_squote "$DIR/stop.sh")' $stop_args"
eval "sh '$(quote_squote "$DIR/start.sh")' $START_ARGS"