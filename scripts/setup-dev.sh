#!/bin/bash
# Development Environment Setup Script for macOS/Linux
# Sets up local development environment without systemd

set -e

echo "🔧 Setting up Radio Recording development environment..."
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker is not installed"
    echo "   Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "❌ ERROR: Docker Compose is not available"
    echo "   Please install Docker Desktop with Compose support"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "❌ ERROR: Python 3 is not installed"
    echo "   Please install Python 3.11 or later"
    exit 1
fi
echo "✅ Python 3 is installed"
echo ""

# Create .venv if it doesn't exist
if [ ! -d .venv ]; then
    echo "🐍 Creating Python virtual environment (.venv)..."
    python3 -m venv .venv
    echo "✅ Virtual environment created"
    echo ""
    
    echo "📦 Installing dependencies..."
    source .venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    echo "✅ Dependencies installed"
    echo ""
else
    echo "✅ Python virtual environment already exists"
    echo ""
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ .env file created"
    echo ""
    echo "⚠️  Please edit .env file to configure your programs:"
    echo "   - Set STREAM_URL for the radio stream"
    echo "   - Set PROGRAM1, PROGRAM2, etc."
    echo "   - Optionally set SECRET for authentication"
    echo ""
else
    echo "✅ .env file already exists"
    echo ""
fi

fi

if grep -q "DATA_DIR=" .env; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|DATA_DIR=.*|DATA_DIR=$(pwd)|g" .env
    else
        sed -i "s|DATA_DIR=.*|DATA_DIR=$(pwd)|g" .env
    fi
else
    echo "DATA_DIR=$(pwd)" >> .env
fi

# Create recordings directory
echo "📁 Creating recordings directory..."
mkdir -p recordings
echo "✅ recordings/ directory created"
echo ""

# Build Docker images
echo "🐳 Building Docker images..."
docker compose build
echo "✅ Docker images built"
echo ""

# Start feed service
echo "🚀 Starting feed service..."
docker compose up -d feed
echo "✅ Feed service started"
echo ""

echo "=" | tr '=' '=' | head -c 60; echo ""
echo "✅ Development environment setup complete!"
echo "=" | tr '=' '=' | head -c 60; echo ""
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Configure programs in .env file:"
echo "   PROGRAM1=07:40-08:00|program1|Program Name #1|https://example.com/stream.m3u8"
echo "   PROGRAM2=08:00-08:20|program2|Program Name #2|https://example.com/stream.m3u8"
echo ""
echo "2. Access feed service:"
echo "   http://localhost:8013/radio/feed.rss"
echo ""

echo "3. Activate virtual environment (for local development/tests):"
echo "   source .venv/bin/activate"
echo ""

echo "4. Test manual recording:"
echo "   USER_ID=\$(id -u) GROUP_ID=\$(id -g) docker compose run --rm recorder 1"
echo "   (Records for 1 minute)"
echo ""

echo "5. View logs:"
echo "   docker compose logs -f feed"
echo ""

echo "6. Stop services:"
echo "   docker compose down"
echo ""
echo "📌 Note: For production deployment with automatic scheduling,"
echo "   use setup-systemd.sh on a Linux server"
echo ""
