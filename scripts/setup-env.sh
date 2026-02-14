#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

echo "Radio Recorder - Environment Setup"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
# 1. System Dependencies (ffmpeg)
echo "Checking system dependencies..."
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Attempting to install..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install ffmpeg
        else
            echo "❌ Error: Homebrew not found. Please install ffmpeg manually."
            exit 1
        fi
    elif [ -f /etc/debian_version ]; then
        sudo apt-get update && sudo apt-get install -y ffmpeg
    elif [ -f /etc/arch-release ]; then
        sudo pacman -S --noconfirm ffmpeg
    else
        echo "❌ Error: Unsupported OS for auto-installation. Please install ffmpeg manually."
        exit 1
    fi
    echo "✅ ffmpeg installed"
else
    echo "✅ ffmpeg is already installed: $(ffmpeg -version | head -n 1)"
fi
echo ""

# 2. Python Environment Setup
echo "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    exit 1
fi
echo "Found: $(python3 --version)"

# Create venv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Install dependencies
echo "Upgrading pip and installing dependencies..."
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    "$VENV_DIR/bin/pip" install -r "$PROJECT_DIR/requirements.txt"
    echo "✅ Dependencies installed"
else
    echo "⚠️  requirements.txt not found"
fi
echo ""

# 3. Configuration (.env) Setup
echo "Configuring environment variables..."
if [ ! -f "$PROJECT_DIR/.env" ]; then
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        echo "✅ Created .env from template"
    else
        echo "⚠️  .env.example not found, skipping .env creation"
    fi
else
    echo "✅ .env file already exists"
fi

# 4. Create Directories
if [ ! -d "$PROJECT_DIR/recordings" ]; then
    mkdir -p "$PROJECT_DIR/recordings"
    echo "✅ Created recordings/ directory"
fi
echo ""

echo "Environment setup completed!"
echo "========================================"
echo "Next steps:"
echo "1. Edit .env to configure your programs (PROGRAM1, etc.)"
echo "2. Install systemd timer:"
echo "   ./scripts/install-systemd.sh"
echo "3. Run manual recording:"
echo "   ./scripts/run.sh [minutes]"
