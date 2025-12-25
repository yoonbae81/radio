#!/usr/bin/env python3

import os
import sys
import time
from pathlib import Path

# 외부 라이브러리
import ffmpeg

# ======================================================================
# --- Global Constants ---
# ======================================================================

# 저장 디렉토리
RECORDINGS_DIR = Path("/app/recordings")
# Lock 파일 (중복 실행 방지)
LOCK_FILE = Path("/tmp/radio-record.lock")

# ======================================================================
# 1. 설정 및 유효성 검사
# ======================================================================

def parse_programs_config():
    """
    Parse PROGRAMS from environment variables.
    Format: PROGRAM1=start-end|alias|name|url
    
    Example:
        PROGRAM1=07:40-08:00|program1|Program Name #1|https://example.com/stream1.m3u8
        PROGRAM2=08:00-08:20|program2|Program Name #2|https://example.com/stream2.m3u8
    """
    programs = {}
    
    # Check for up to 50 programs (PROGRAM1 to PROGRAM50)
    for i in range(1, 51):
        program_str = os.getenv(f'PROGRAM{i}')
        
        # Stop when we don't find a program
        if not program_str:
            break
        
        # Parse: schedule|alias|name|url
        parts = program_str.split('|', 3)
        if len(parts) != 4:
            print(f"⚠️ WARNING: Invalid format for PROGRAM{i}: {program_str}")
            print(f"   Expected format: start-end|alias|name|url")
            continue
        
        program_schedule, program_id, program_name, program_url = parts
        program_id = program_id.strip()
        program_name = program_name.strip()
        program_schedule = program_schedule.strip()
        program_url = program_url.strip()
        
        if not program_id or not program_name or not program_schedule or not program_url:
            print(f"⚠️ WARNING: PROGRAM{i} has empty fields")
            continue
        
        # Parse schedule: "07:40-08:00"
        if '-' not in program_schedule:
            print(f"⚠️ WARNING: Invalid schedule format for PROGRAM{i}: {program_schedule}")
            print(f"   Expected format: HH:MM-HH:MM")
            continue
        
        start, end = program_schedule.split('-', 1)
        # Convert "07:40" to "0740"
        start = start.strip().replace(':', '')
        end = end.strip().replace(':', '')
        
        if not start or not end:
            print(f"⚠️ WARNING: Invalid time format for PROGRAM{i}")
            continue
        
        # Store as single schedule entry
        schedule = [{'start': start, 'end': end}]
        
        programs[program_id] = {
            'name': program_name,
            'schedule': schedule,
            'url': program_url
        }
    
    if programs:
        print(f"📋 Loaded {len(programs)} programs from environment variables")
        for prog_id, prog_info in programs.items():
            schedules = [f"{s['start']}-{s['end']}" for s in prog_info['schedule']]
            print(f"   - {prog_id}: {prog_info['name']} @ {', '.join(schedules)}")
    else:
        print(f"⚠️ No programs configured")
    
    return programs

def calculate_duration_from_time(start_time: str, end_time: str) -> int:
    """
    Calculate duration in seconds from start and end time (HHMM format).
    Example: start_time='0740', end_time='0800' -> 1200 seconds (20 minutes)
    """
    try:
        start_hour = int(start_time[:2])
        start_min = int(start_time[2:])
        end_hour = int(end_time[:2])
        end_min = int(end_time[2:])
        
        start_total_min = start_hour * 60 + start_min
        end_total_min = end_hour * 60 + end_min
        
        # Handle case where end time is next day (e.g., 2350-0010)
        if end_total_min < start_total_min:
            end_total_min += 24 * 60
        
        duration_min = end_total_min - start_total_min
        return duration_min * 60  # Convert to seconds
    except (ValueError, IndexError) as e:
        raise ValueError(f"Failed to parse time range {start_time}-{end_time}: {e}")

def parse_and_validate_args():
    """
    Parse and validate command line arguments.
    
    Usage:
    - With argument: python record.py 30  (manual execution, duration in minutes)
    - Without argument: python record.py  (auto-calculate from PROGRAMS env var)
    """
    # Check if duration is provided as command line argument
    if len(sys.argv) > 1:
        duration_min_str = sys.argv[1]
        try:
            duration_min = int(duration_min_str)
            if duration_min <= 0:
                sys.stderr.write("ERROR: Duration must be a positive integer.\\n")
                sys.exit(1)
            print(f"📝 Manual execution: {duration_min} minutes")
            # Use global default URL if provided, otherwise error
            manual_url = os.getenv('STREAM_URL')
            if not manual_url:
                sys.stderr.write("ERROR: STREAM_URL environment variable must be set for manual execution.\\n")
                sys.exit(1)
            # Return duration, None for start_time, and manual_url
            return (duration_min * 60, None, manual_url)
        except ValueError:
            sys.stderr.write("ERROR: Duration must be an integer (minutes).\\n")
            sys.stderr.write(f"Usage: {sys.argv[0]} [duration_minutes]\\n")
            sys.stderr.write(f"Example: {sys.argv[0]} 30\\n")
            sys.exit(1)
    
    # Auto-calculate duration from PROGRAMS environment variable (systemd timer mode)
    print("🤖 Auto-execution mode: checking for scheduled programs...")
    programs = parse_programs_config()
    
    if not programs:
        print(f"❌ ERROR: No PROGRAMS configured in environment variables")
        print(f"   Please set PROGRAM1, PROGRAM2, etc. in .env file")
        sys.exit(1)
    
    # Get current time in HHMM format
    current_time = time.strftime('%H%M', time.localtime())
    current_hour = int(current_time[:2])
    current_min = int(current_time[2:])
    current_total_min = current_hour * 60 + current_min
    
    # Find matching program schedule
    best_match = None
    min_diff = float('inf')
    
    for program_id, program_info in programs.items():
        for schedule in program_info['schedule']:
            start_time = schedule['start']
            end_time = schedule['end']
            
            try:
                start_hour = int(start_time[:2])
                start_min = int(start_time[2:])
                start_total_min = start_hour * 60 + start_min
                
                # Check if current time is within 0-2 minutes of start time
                diff = current_total_min - start_total_min
                
                if diff <= 5 and diff < min_diff:
                    min_diff = diff
                    best_match = {
                        'program_id': program_id,
                        'program_name': program_info['name'],
                        'start': start_time,
                        'end': end_time,
                        'url': program_info['url']
                    }
            except (ValueError, IndexError):
                continue
    
    if best_match:
        duration_sec = calculate_duration_from_time(best_match['start'], best_match['end'])
        print(f"🎯 Matched program: {best_match['program_name']}")
        print(f"⏰ Time range: {best_match['start']}-{best_match['end']}")
        print(f"⏱️  Auto-calculated duration: {duration_sec // 60} minutes")
        # Return duration, start time, and url
        return (duration_sec, best_match['start'], best_match['url'])
    
    # No matching program found - this is normal, just exit quietly
    print(f"ℹ️  No matching program for current time {current_time} (within 5-minute window)")
    print(f"   This is normal - timer runs every minute, lock file prevents conflicts")
    sys.exit(0)

# ======================================================================
# 2. 녹음 실행
# ======================================================================

def execute_recording(sec: int, stream_url: str, start_time: str = None) -> Path:
    """
    FFmpeg을 사용하여 녹음을 실행하고, 생성된 파일 경로를 반환합니다.
    
    Args:
        sec: 녹음 시간 (초)
        stream_url: 라디오 스트림 URL
        start_time: 프로그램 시작 시간 (HHMM format), None이면 현재 시간 사용
    """
    # 디렉토리 생성
    RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Use program start time if provided, otherwise use current time
    if start_time:
        # Convert HHMM to HH:MM for time formatting
        hour = start_time[:2]
        minute = start_time[2:]
        date_str = time.strftime('%Y%m%d', time.localtime())
        DATE_TIME = f"{date_str}-{hour}{minute}"
    else:
        DATE_TIME = time.strftime('%Y%m%d-%H%M', time.localtime())
    
    SUFFIX = hex(int(time.time() * 1000000))[2:10] 
    output_file = RECORDINGS_DIR / f"{DATE_TIME}-{SUFFIX}.m4a"

    print(f"\\n--- Recording Started ---")
    print(f"File: {output_file.resolve()}")
    print(f"Duration: {sec // 60} minutes ({sec} seconds)")

    try:
        # FFmpeg-python을 사용하여 명령 구성 및 실행
        (
            ffmpeg
            .input(stream_url, t=str(sec)) 
            .output(
                str(output_file),
                vn=None,           
                acodec='copy'      
            )
            .overwrite_output()
            .run(capture_stdout=True, capture_stderr=True)
        )
        
        print(f"✅ SUCCESS: Recording saved to {output_file}")
        
        # Write cache invalidation file to trigger feed cache refresh
        try:
            invalidation_file = RECORDINGS_DIR / '.last_recording'
            invalidation_file.touch()
            print(f"📝 Cache invalidation file updated: {invalidation_file}")
        except Exception as cache_error:
            print(f"⚠️ WARNING: Failed to update cache invalidation file: {cache_error}")
        
        return output_file
        
    except ffmpeg.Error as e:
        sys.stderr.write(f"ERROR: FFMPEG command failed (Exit Code: {e.returncode}).\\n")
        sys.stderr.write(f"FFmpeg Stderr: {e.stderr.decode('utf8', errors='ignore')}\\n")
        if output_file.exists():
             output_file.unlink() # 실패한 파일 삭제
        sys.exit(1)
    except FileNotFoundError:
        sys.stderr.write("FATAL ERROR: 'ffmpeg' command not found. Ensure it is installed and in PATH.\\n")
        sys.exit(1)

# ======================================================================
# 메인 실행 함수
# ======================================================================

def main():
    """
    녹음 워크플로우를 실행하는 메인 함수
    """
    # Check for lock file (prevent concurrent executions)
    if LOCK_FILE.exists():
        print(f"ℹ️  Another recording is in progress (lock file exists)")
        print(f"   Skipping this execution to prevent conflicts")
        sys.exit(0)
    
    try:
        # Create lock file
        LOCK_FILE.touch()
        print(f"🔒 Lock file created: {LOCK_FILE}")
        
        # 1. 설정 및 유효성 검사
        duration_sec, start_time, stream_url = parse_and_validate_args()
        
        # 2. 녹음 실행
        output_file = execute_recording(duration_sec, stream_url, start_time)
        
        print(f"\n✅ Recording completed successfully")
        print(f"📁 Saved to: {output_file}")
        
    finally:
        # Always remove lock file
        if LOCK_FILE.exists():
            LOCK_FILE.unlink()
            print(f"🔓 Lock file removed: {LOCK_FILE}")

if __name__ == "__main__":
    main()
