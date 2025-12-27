#!/bin/bash

# Target directory from argument or default to current directory
TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: $TARGET_DIR is not a directory."
    exit 1
fi

# Get absolute path for display
ABS_PATH=$(cd "$TARGET_DIR" && pwd)
echo "Processing files in: $ABS_PATH"

# Iterate over .m4a files in the target directory
for file in "$TARGET_DIR"/*.m4a; do
    # Skip if no .m4a files found (handles case where glob doesn't match)
    [ -f "$file" ] || continue
    
    filename=$(basename "$file")
    # Extract first 8 characters (YYYYMMDD)
    date_part="${filename:0:8}"
    
    # Check if date_part consists of 8 digits
    if [[ "$date_part" =~ ^[0-9]{8}$ ]]; then
        # Format for touch -t: [[CC]YY]MMDDhhmm[.SS]
        # We set time to 06:00
        timestamp="${date_part}0600"
        
        # Update file access and modification times
        if touch -t "$timestamp" "$file" 2>/dev/null; then
            echo "$filename - ${date_part:0:4}-${date_part:4:2}-${date_part:6:2} 06:00:00"
        fi
    fi
done
