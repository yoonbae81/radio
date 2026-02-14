#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Deploying Radio Recorder..."
echo "========================================"

# 1. Update Code
echo "📥 Pulling latest changes..."
git pull origin main || echo "⚠️  Git pull failed (local changes?), continuing..."

# 2. Run Environment Setup (Dependencies, Directories, .env)
echo "🔧 Setting up environment..."
if [ -f "$SCRIPT_DIR/setup-env.sh" ]; then
    bash "$SCRIPT_DIR/setup-env.sh"
else
    echo "❌ Error: setup-env.sh not found!"
    exit 1
fi

echo ""
echo "✅ Deployment preparation complete!"
echo "------------------------------------------------"
echo "To apply changes to running services:"
echo "  • Systemd mode:  systemctl --user restart radio-record.timer radio-feed.service"
echo "------------------------------------------------"
