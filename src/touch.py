#!/usr/bin/env python3

import os
import sys
from pathlib import Path
from datetime import datetime

def main():
    target_path = sys.argv[1] if len(sys.argv) > 1 else "."
    dir_path = Path(target_path)

    if not dir_path.is_dir():
        print(f"Error: {target_path} is not a directory.")
        return

    print(f"Processing files in: {dir_path.absolute()}")

    for p in dir_path.glob('*.m4a'):
        try:
            date_part = p.name[:8]
            dt = datetime.strptime(date_part, '%Y%m%d')
            dt = dt.replace(hour=6, minute=0, second=0)
            timestamp = dt.timestamp()
            
            os.utime(p, (timestamp, timestamp))
            print(f"{p.name} - {dt}")
            
        except (ValueError, IndexError):
            continue

if __name__ == "__main__":
    main()
