#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${RADIO_CONFIG:-$SCRIPT_DIR/radio.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  print -- "Config not found: $CONFIG_PATH"
  exit 1
fi

source "$CONFIG_PATH"

: "${OUTPUT_DIR:?Set OUTPUT_DIR in $CONFIG_PATH}"

PODCAST_HTTP_PORT="${PODCAST_HTTP_PORT:-17880}"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  elif [[ -x /usr/bin/python3 ]]; then
    PYTHON_BIN="/usr/bin/python3"
  else
    print -- "python3 not found. Set PYTHON_BIN in $CONFIG_PATH."
    exit 1
  fi
fi

mkdir -p "$OUTPUT_DIR"

exec "$PYTHON_BIN" -m http.server "$PODCAST_HTTP_PORT" --bind 127.0.0.1 --directory "$OUTPUT_DIR"
