#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="radio-record"

echo "Radio Recorder - Systemd Timer Installation"
echo "=============================================="
echo "Project directory: $PROJECT_DIR"
echo ""

# Load environment variables from .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    # Only export variables that don't have spaces or are quoted properly, 
    # but for systemd installation we mainly need to know if vars exist.
    # Actually, we don't strictly need to load them here, but it's good practice.
    echo "Found .env file"
else
    echo "Warning: .env file not found"
fi

# Create systemd directory
echo "Setting up systemd timer..."
mkdir -p "$SYSTEMD_USER_DIR"

# Create service file with environment variables
echo "Creating $SERVICE_NAME.service..."
# We generate the service file dynamically to inject PROJECT_DIR
cat > "$SYSTEMD_USER_DIR/$SERVICE_NAME.service" << EOF
[Unit]
Description=Radio Recorder Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/.venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$PROJECT_DIR/.env

ExecStart=$PROJECT_DIR/.venv/bin/python $PROJECT_DIR/src/record.py

StandardOutput=journal
StandardError=journal
SyslogIdentifier=radio-record

[Install]
WantedBy=default.target
EOF

# Create or Copy timer file
echo "Creating $SERVICE_NAME.timer..."
cat > "$SYSTEMD_USER_DIR/$SERVICE_NAME.timer" << EOF
[Unit]
Description=Radio Recorder Timer
Requires=$SERVICE_NAME.service

[Timer]
# Run every minute to check schedule
OnCalendar=*:0/1
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "Systemd files installed"
echo ""

# Reload systemd daemon
echo "Reloading systemd daemon..."
if command -v systemctl &> /dev/null; then
    systemctl --user daemon-reload

    # Enable and start timer
    echo "Enabling and starting timer..."
    systemctl --user enable "$SERVICE_NAME.timer"
    systemctl --user start "$SERVICE_NAME.timer"

    echo ""
    echo "Timer installation completed!"
    echo ""
    echo "Useful commands:"
    echo "  • Check timer status:   systemctl --user status $SERVICE_NAME.timer"
    echo "  • Check service logs:   journalctl --user -u $SERVICE_NAME.service"
    echo "  • Follow logs:          journalctl --user -u $SERVICE_NAME.service -f"
else
    echo "Warning: systemctl not found. Systemd files created but not activated."
fi
