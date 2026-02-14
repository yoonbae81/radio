#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

echo "Radio Recorder - Environment Setup"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo ""

# 1. Python Environment Setup
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
