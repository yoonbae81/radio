#!/bin/bash
set -e

echo "🎙️  Radio Recording Service"

# Run the recording with passed arguments or default to auto-mode
cd /app
if [ $# -eq 0 ]; then
    echo "🤖 Running in auto-schedule mode..."
    python3 record.py
else
    echo "📝 Running in manual mode: $1 minutes"
    python3 record.py "$1"
fi

echo "✅ Execution finished."
