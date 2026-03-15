#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLIST_TEMPLATE="$SCRIPT_DIR/com.radio.recorder.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/com.radio.recorder.plist"
CONFIG_PATH="${RADIO_CONFIG:-$SCRIPT_DIR/radio.conf}"
LOG_DIR="$PROJECT_ROOT/logs"
TMP_PLIST="$(mktemp)"

if [[ ! -f "$PLIST_TEMPLATE" ]]; then
  print -- "Missing plist template: $PLIST_TEMPLATE"
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" && -f "$SCRIPT_DIR/radio.conf.example" ]]; then
  cp "$SCRIPT_DIR/radio.conf.example" "$CONFIG_PATH"
  print -- "Created config file: $CONFIG_PATH"
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$SCRIPT_DIR/check-and-record.sh" "$SCRIPT_DIR/generate-feed.sh"

sed \
  -e "s|{{PROJECT_ROOT}}|$PROJECT_ROOT|g" \
  -e "s|{{CONFIG_PATH}}|$CONFIG_PATH|g" \
  "$PLIST_TEMPLATE" > "$TMP_PLIST"

mv "$TMP_PLIST" "$PLIST_TARGET"

launchctl bootout "gui/$(id -u)" "$PLIST_TARGET" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"
launchctl enable "gui/$(id -u)/com.radio.recorder"
launchctl kickstart -k "gui/$(id -u)/com.radio.recorder"

print -- "Installed launchd agent at $PLIST_TARGET"
print -- "Edit $CONFIG_PATH and then rerun this installer if needed."
