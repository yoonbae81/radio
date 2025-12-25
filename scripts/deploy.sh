#!/bin/bash
# Radio Recording Deployment Script (User Mode)

set -e

# Configuration
INSTALL_DIR="/srv/radio"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔧 Setting up Radio Recording in USER mode..."

# 1. Setup data directories (requires sudo for creation, then transfer ownership)
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating data directory $INSTALL_DIR with sudo..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "${USER}:${USER}" "$INSTALL_DIR"
fi

# Create subdirectories for persistent data
mkdir -p "${INSTALL_DIR}/recordings"
mkdir -p "${INSTALL_DIR}/logo"
mkdir -p "${SYSTEMD_USER_DIR}"

# 2. Configuration setup
echo "📝 Setting up configuration..."
if [ ! -f "${SRC_DIR}/.env" ]; then
    if [ -f "${SRC_DIR}/.env.example" ]; then
        cp "${SRC_DIR}/.env.example" "${SRC_DIR}/.env"
    fi
fi

# Ensure DATA_DIR is set for Docker Compose in production
if ! grep -q "DATA_DIR=" "${SRC_DIR}/.env"; then
    echo "DATA_DIR=$INSTALL_DIR" >> "${SRC_DIR}/.env"
fi

# 3. Docker build and (re)start
echo "🐳 Building Docker images and (re)starting feed service..."
cd "$SRC_DIR"
docker compose build
# Pass UID/GID at runtime for interpolation
USER_ID=$(id -u) GROUP_ID=$(id -g) docker compose up -d --force-recreate feed

# Force invalidate feed cache by touching mutation file
echo "♻️ Invalidating feed cache..."
touch "${INSTALL_DIR}/recordings/.last_recording"

# 4. Enable linger so services run without login
echo "👤 Enabling linger for user ${USER}..."
loginctl enable-linger "${USER}" || true

# 5. Setup systemd units with dynamic paths
echo "📝 Configuring systemd units with current path: ${SRC_DIR}"
# Replace all instances of /srv/radio with the actual source directory
sed "s|/srv/radio|${SRC_DIR}|g" \
    "${SRC_DIR}/scripts/systemd/radio-record.service" > "${SYSTEMD_USER_DIR}/radio-record.service"

cp "${SRC_DIR}/scripts/systemd/radio-record.timer" "${SYSTEMD_USER_DIR}/"

# 6. Start the timer
echo "🔄 Reloading systemd user daemon..."
systemctl --user daemon-reload
systemctl --user enable radio-record.timer
systemctl --user start radio-record.timer

echo ""
echo "✅ Setup complete for user ${USER}!"
echo ""
echo "📝 Deployment Summary:"
echo "------------------------------------------------"
# Extract and display configuration
DATA_DIR_VAL=$(grep "^DATA_DIR=" "${SRC_DIR}/.env" | cut -d'=' -f2)
PORT_VAL=$(grep "^PORT=" "${SRC_DIR}/.env" | cut -d'=' -f2)
PORT_VAL=${PORT_VAL:-8013}
ROUTE_PREFIX_VAL=$(grep "^ROUTE_PREFIX=" "${SRC_DIR}/.env" | cut -d'=' -f2)
ROUTE_PREFIX_VAL=${ROUTE_PREFIX_VAL:-/radio}

echo "📂 Data Directory:  $DATA_DIR_VAL"
echo "� App Directory:   $SRC_DIR"
echo "🕒 Check Interval:  Every minute (systemd timer)"
echo "📡 Feed URL:        http://<your-server-ip>:${PORT_VAL}${ROUTE_PREFIX_VAL}/feed.rss"
echo ""
echo "📻 Scheduled Programs:"
grep "^PROGRAM[0-9]*=" "${SRC_DIR}/.env" | cut -d'=' -f2- | while read -r line; do
    IFS='|' read -r schedule alias name url <<< "$line"
    echo "   - [$schedule] $name ($alias)"
done
echo "------------------------------------------------"
echo ""
echo "📊 Monitoring & Control:"
echo "   Timer status:  systemctl --user status radio-record.timer"
echo "   Record logs:   journalctl --user -u radio-record.service -f"
echo "   Trigger now:   systemctl --user start radio-record.service"
echo ""
echo "   Feed status:   docker compose ps feed"
echo "   Feed logs:     docker compose logs -f feed"
echo ""
