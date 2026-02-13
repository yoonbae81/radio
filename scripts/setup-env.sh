#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

echo "Radio Recorder - Environment Setup"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo ""

# 1. Check Docker (Optional but recommended)
if command -v docker &> /dev/null; then
    echo "✅ Docker is installed"
else
    echo "⚠️  Docker is not installed. Feed service and docker-based recording will not work."
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

# Configure DATA_DIR in .env to current project path (crucial for Docker volumes)
echo "Updating DATA_DIR in .env..."
if grep -q "DATA_DIR=" "$PROJECT_DIR/.env"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed requires empty string for -i
        sed -i '' "s|DATA_DIR=.*|DATA_DIR=$PROJECT_DIR|g" "$PROJECT_DIR/.env"
    else
        sed -i "s|DATA_DIR=.*|DATA_DIR=$PROJECT_DIR|g" "$PROJECT_DIR/.env"
    fi
    echo "✅ DATA_DIR set to $PROJECT_DIR"
else
    echo "DATA_DIR=$PROJECT_DIR" >> "$PROJECT_DIR/.env"
    echo "✅ Added DATA_DIR=$PROJECT_DIR to .env"
fi
echo ""

# 4. Create Directories
if [ ! -d "$PROJECT_DIR/recordings" ]; then
    mkdir -p "$PROJECT_DIR/recordings"
    echo "✅ Created recordings/ directory"
fi

# 5. Docker Services Setup
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo "🐳 Setting up Docker services..."
    
    # Check if we are in the project root for docker compose to work, or use -f
    # docker compose usually looks for compose.yml in cwd or parents. 
    # Best to cd to project dir.
    pushd "$PROJECT_DIR" > /dev/null
    
    echo "Building images..."
    docker compose build
    
    echo "Starting background services (feed)..."
    docker compose up -d feed
    
    popd > /dev/null
    echo "✅ Docker services started"
else
    echo "⚠️  Skipping Docker setup (Docker or Docker Compose not found)"
fi
echo ""

echo "Environment setup completed!"
echo "========================================"
echo "Next steps:"
echo "1. Edit .env to configure your programs (PROGRAM1, etc.)"
echo "2. Access feed service: http://localhost:8013/radio/feed.rss"
echo "3. Run manual recording: ./scripts/run.sh [minutes]"
echo "4. Monitor logs: docker compose logs -f feed"
