#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${RADIO_CONFIG:-$SCRIPT_DIR/radio.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  print -- "Config not found: $CONFIG_PATH"
  exit 1
fi

source "$CONFIG_PATH"

PODCAST_HTTP_PORT="${PODCAST_HTTP_PORT:-17880}"
TAILSCALE_BIN="${TAILSCALE_BIN:-}"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$TAILSCALE_BIN" ]]; then
  if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_BIN="$(command -v tailscale)"
  else
    print -- "tailscale CLI not found. Install Tailscale and set TAILSCALE_BIN in $CONFIG_PATH if needed."
    exit 1
  fi
fi

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

"$TAILSCALE_BIN" serve --bg --yes --https=443 "http://127.0.0.1:$PODCAST_HTTP_PORT"

base_url="$("$TAILSCALE_BIN" status --json | "$PYTHON_BIN" -c 'import json, sys; data=json.load(sys.stdin); dns=(data.get("Self", {}).get("DNSName") or "").rstrip("."); print(f"https://{dns}" if dns else "")')"

if [[ -n "$base_url" ]]; then
  print -- "Tailscale Serve is configured."
  print -- "Tailnet URL: $base_url"
  print -- "Example podcast feed: $base_url/<alias>/feed.xml"
else
  print -- "Tailscale Serve is configured."
  print -- "Run '$TAILSCALE_BIN serve status' to see the tailnet URL."
fi
