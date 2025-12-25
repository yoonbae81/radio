#!/bin/bash
# Radio Recording Check Script
# Runs every minute to check if recording is needed
# Only launches Docker container when a program matches

set -e

LOCK_FILE="/tmp/radio-record.lock"
# Look for .env in the parent directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Check if lock file exists (recording in progress)
if [ -f "$LOCK_FILE" ]; then
    echo "ℹ️  Recording in progress (lock file exists), skipping"
    exit 0
fi

# Load environment variables
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Get current time in HHMM format
CURRENT_TIME=$(date +%H%M)
CURRENT_HOUR=${CURRENT_TIME:0:2}
CURRENT_MIN=${CURRENT_TIME:2:2}
CURRENT_TOTAL_MIN=$((10#$CURRENT_HOUR * 60 + 10#$CURRENT_MIN))

# Check all PROGRAM* variables by reading the file directly
# This avoids 'source' which fails with pipe characters in values
MATCH_FOUND=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    # Check if line starts with PROGRAM
    if [[ "$line" =~ ^(PROGRAM[0-9]+)=(.*)$ ]]; then
        PROGRAM_STR="${BASH_REMATCH[2]}"
        
        # Parse: start-end|alias|name|url
        IFS='|' read -r SCHEDULE ALIAS NAME URL <<< "$PROGRAM_STR"
        
        # Parse schedule: HH:MM-HH:MM
        if [[ ! "$SCHEDULE" =~ ^([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})$ ]]; then
            continue
        fi
        
        START_HOUR="${BASH_REMATCH[1]}"
        START_MIN="${BASH_REMATCH[2]}"
        START_TOTAL_MIN=$((10#$START_HOUR * 60 + 10#$START_MIN))
        
        # Check if it's the exact start time
        DIFF=$((CURRENT_TOTAL_MIN - START_TOTAL_MIN))
        
        if [ $DIFF -eq 0 ]; then
            echo "🎯 Matched program: $NAME"
            echo "⏰ Current time: $CURRENT_TIME, Start time: ${START_HOUR}${START_MIN}"
            MATCH_FOUND=1
            break
        fi
    fi
done < "$ENV_FILE"

if [ $MATCH_FOUND -eq 0 ]; then
    echo "ℹ️  No matching program for current time $CURRENT_TIME"
    exit 1  # No match found
fi

# Match found - return success
echo "✅ Recording needed for: $NAME"
exit 0
