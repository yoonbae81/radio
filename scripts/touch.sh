#!/bin/bash

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a directory."
    exit 1
fi

ABS_PATH=$(cd "$TARGET_DIR" && pwd)
echo "Processing files in: $ABS_PATH"

for file in "$TARGET_DIR"/*.m4a; do
    [ -f "$file" ] || continue
    
    filename=$(basename "$file")
    datetime_part="${filename:0:13}"
    
    if [[ "$datetime_part" =~ ^[0-9]{8}-[0-9]{4}$ ]]; then
        timestamp="${datetime_part//-}"
        
        if touch -t "$timestamp" "$file" 2>/dev/null; then
            echo "$filename - ${timestamp:0:4}-${timestamp:4:2}-${timestamp:6:2} ${timestamp:8:2}:${timestamp:10:2}:00"
        fi
    fi
done
