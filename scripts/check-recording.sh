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

# Get current time and day
CURRENT_TIME=$(date +%H%M)
CURRENT_DAY_NUM=$(date +%u) # 1=MON, 7=SUN
case $CURRENT_DAY_NUM in
    1) TODAY="MON" ;;
    2) TODAY="TUE" ;;
    3) TODAY="WED" ;;
    4) TODAY="THU" ;;
    5) TODAY="FRI" ;;
    6) TODAY="SAT" ;;
    7) TODAY="SUN" ;;
esac

CURRENT_HOUR=${CURRENT_TIME:0:2}
CURRENT_MIN=${CURRENT_TIME:2:2}
CURRENT_TOTAL_MIN=$((10#$CURRENT_HOUR * 60 + 10#$CURRENT_MIN))

# Check all PROGRAM* variables by reading the file directly
MATCH_FOUND=0

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    if [[ "$line" =~ ^(PROGRAM[0-9]+)=(.*)$ ]]; then
        PROGRAM_STR="${BASH_REMATCH[2]}"
        
        # Parse: schedule|days|alias|name[|url]
        IFS='|' read -r SCHEDULE DAYS ALIAS NAME URL <<< "$PROGRAM_STR"
        
        if [[ -z "$NAME" ]]; then
            continue
        fi
        
        # 1. Day Check
        DAY_MATCH=0
        if [[ "$DAYS" == "ALL" || "$DAYS" == "EVERY" || "$DAYS" == "*" ]]; then
            DAY_MATCH=1
        elif [[ "$DAYS" == *"$TODAY"* ]]; then
            # Simple check for list (MON,WED) or single day
            DAY_MATCH=1
        elif [[ "$DAYS" == *-* ]]; then
            # Simple range check (e.g., MON-FRI)
            # This is a bit simplified for bash, but covers MON-FRI/SAT-SUN well
            IFS='-' read -r START_DAY END_DAY <<< "$DAYS"
            
            # Map names to numbers for comparison
            declare -A WD_MAP=([MON]=1 [TUE]=2 [WED]=3 [THU]=4 [FRI]=5 [SAT]=6 [SUN]=7)
            START_VAL=${WD_MAP[$START_DAY]}
            END_VAL=${WD_MAP[$END_DAY]}
            
            if [[ -n "$START_VAL" && -n "$END_VAL" ]]; then
                if [ $START_VAL -le $END_VAL ]; then
                    if [ $CURRENT_DAY_NUM -ge $START_VAL ] && [ $CURRENT_DAY_NUM -le $END_VAL ]; then
                        DAY_MATCH=1
                    fi
                else
                    # Wrap around range (e.g., SAT-MON)
                    if [ $CURRENT_DAY_NUM -ge $START_VAL ] || [ $CURRENT_DAY_NUM -le $END_VAL ]; then
                        DAY_MATCH=1
                    fi
                fi
            fi
        fi
        
        if [ $DAY_MATCH -eq 0 ]; then
            continue
        fi

        # 2. Time Check: Parse schedule HH:MM-HH:MM
        if [[ ! "$SCHEDULE" =~ ^([0-9]{2}):([0-9]{2})-([0-9]{2}):([0-9]{2})$ ]]; then
            continue
        fi
        
        START_HOUR="${BASH_REMATCH[1]}"
        START_MIN="${BASH_REMATCH[2]}"
        START_TOTAL_MIN=$((10#$START_HOUR * 60 + 10#$START_MIN))
        
        DIFF=$((CURRENT_TOTAL_MIN - START_TOTAL_MIN))
        
        if [ $DIFF -eq 0 ]; then
            echo "🎯 Matched program: $NAME ($DAYS)"
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
