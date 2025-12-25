@echo off
REM Development Environment Setup Script for Windows
REM Sets up local development environment without systemd

echo.
echo Setting up Radio Recording development environment...
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed
    echo Please install Docker Desktop: https://www.docker.com/products/docker-desktop
    exit /b 1
)

REM Check if Docker Compose is available
docker compose version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose is not available
    echo Please install Docker Desktop with Compose support
    exit /b 1
)

echo Docker and Docker Compose are installed
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed
    echo Please install Python 3.11 or later
    exit /b 1
)
echo Python is installed
echo.

REM Create .venv if it doesn't exist
if not exist .venv (
    echo Creating Python virtual environment (.venv)...
    python -m venv .venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        exit /b 1
    )
    echo Virtual environment created
    echo.
    
    echo Installing dependencies...
    call .venv\Scripts\activate.bat
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        exit /b 1
    )
    echo Dependencies installed
    echo.
) else (
    echo Python virtual environment already exists
    echo.
)

REM Create .env file if it doesn't exist
if not exist .env (
    echo Creating .env file from .env.example...
    copy .env.example .env >nul
    echo .env file created
    echo.
    echo WARNING: Please edit .env file to configure your programs:
    echo   - Set STREAM_URL for the radio stream
    echo   - Set PROGRAM1, PROGRAM2, etc.
    echo   - Optionally set SECRET for authentication
    echo.
) else (
    echo .env file already exists
    echo.
)

REM Create recordings directory
echo Creating recordings directory...
if not exist recordings mkdir recordings
echo recordings\ directory created
echo.

REM Build Docker images
echo Building Docker images...
docker compose build
if errorlevel 1 (
    echo ERROR: Failed to build Docker images
    exit /b 1
)
echo Docker images built
echo.

REM Start feed service
echo Starting feed service...
docker compose up -d feed
if errorlevel 1 (
    echo ERROR: Failed to start feed service
    exit /b 1
)
echo Feed service started
echo.

echo ============================================================
echo Development environment setup complete!
echo ============================================================
echo.
echo Next steps:
echo.
echo 1. Configure programs in .env file:
echo    PROGRAM1=07:40-08:00^|program1^|Program Name #1^|https://example.com/stream.m3u8
echo    PROGRAM2=08:00-08:20^|program2^|Program Name #2^|https://example.com/stream.m3u8
echo.
echo 2. Access feed service:
echo    http://localhost:8013/radio/feed.rss
echo.
echo 3. Activate virtual environment (for local development/tests):
echo    .venv\Scripts\activate.bat
echo.
echo 4. Test manual recording:
echo    docker compose run --rm recorder 1
echo    (Records for 1 minute)
echo.
echo 5. View logs:
echo    docker compose logs -f feed
echo.
echo 6. Stop services:
echo    docker compose down
echo.
echo Note: For production deployment with automatic scheduling,
echo       use setup-systemd.sh on a Linux server
echo.
pause
