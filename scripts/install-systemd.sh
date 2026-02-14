#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="radio-record"
FEED_SERVICE_NAME="radio-feed"

echo "Radio Recorder - Systemd Installation (.venv mode)"
echo "=================================================="

# Check if .venv exists
if [ ! -d "$PROJECT_DIR/.venv" ]; then
    echo "❌ Error: .venv not found."
    echo "   Please run './scripts/setup-env.sh' first."
    exit 1
fi

# Create systemd directory
mkdir -p "$SYSTEMD_USER_DIR"

# Function to install a service from template
install_unit() {
    local template_file="$PROJECT_DIR/scripts/systemd/$1"
    local target_file="$SYSTEMD_USER_DIR/$1"
    
    if [ -f "$template_file" ]; then
        echo "🔧 Installing $1..."
        sed "s|{{PROJECT_ROOT}}|$PROJECT_DIR|g" "$template_file" > "$target_file"
    else
        echo "⚠️  Warning: Template $template_file not found. Skipping."
    fi
}

# Install units from templates
install_unit "radio-record.service"
install_unit "radio-record.timer"
install_unit "radio-feed.service"

# Reload and Enable
if command -v systemctl &> /dev/null; then
    echo "🔄 Reloading systemd..."
    systemctl --user daemon-reload
    
    echo "🔄 Starting $SERVICE_NAME.timer..."
    systemctl --user enable "$SERVICE_NAME.timer"
    systemctl --user start "$SERVICE_NAME.timer"
    
    echo "🔄 Starting $FEED_SERVICE_NAME.service..."
    systemctl --user enable "$FEED_SERVICE_NAME.service"
    systemctl --user start "$FEED_SERVICE_NAME.service"
    
    echo ""
    echo "✅ Systemd installation complete!"
    echo "   Mode: .venv + systemd"
    echo "   Recorder Timer:  systemctl --user status $SERVICE_NAME.timer"
    echo "   Feed Service:    systemctl --user status $FEED_SERVICE_NAME.service"
else
    echo "⚠️  systemctl not found. Service files created but not activated."
fi
