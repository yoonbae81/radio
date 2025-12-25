#!/usr/bin/env python3
import os
import re
from pathlib import Path
import sys

def rename_recordings(directory):
    dir_path = Path(directory)
    if not dir_path.is_dir():
        print(f"Error: {directory} is not a directory.")
        return

    print(f"Checking for files with spaces in: {dir_path.absolute()}")
    
    # Pattern to match: YYYYMMDD HHMM [hash].m4a
    # We want to change it to: YYYYMMDD-HHMM-[hash].m4a
    pattern = re.compile(r'^(\d{8})\s+(\d{4})\s+([a-f0-9]{8})\.m4a$')
    
    renamed_count = 0
    for p in dir_path.glob('*.m4a'):
        match = pattern.match(p.name)
        if match:
            date_part = match.group(1)
            time_part = match.group(2)
            hash_part = match.group(3)
            
            new_name = f"{date_part}-{time_part}-{hash_part}.m4a"
            new_path = p.with_name(new_name)
            
            print(f"Renaming: '{p.name}' -> '{new_name}'")
            try:
                p.rename(new_path)
                renamed_count += 1
            except Exception as e:
                print(f"Error renaming {p.name}: {e}")
    
    print(f"\nDone! Renamed {renamed_count} files.")

if __name__ == "__main__":
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    rename_recordings(target_dir)
