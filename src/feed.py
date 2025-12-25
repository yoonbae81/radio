#!/usr/bin/env python3

import os
import re
import time
from pathlib import Path
from bottle import Bottle, static_file, response, request, abort
from podgen import Podcast, Episode, Media, Category, Person
from cachetools import TTLCache

# ======================================================================
# Configuration
# ======================================================================

RECORDINGS_DIR = Path(os.getenv('RECORDINGS_DIR', '/app/recordings'))
SECRET = os.getenv('SECRET', '')
PROGRAMS_CONFIG = os.getenv('PROGRAMS', '')
ROUTE_PREFIX = os.getenv('ROUTE_PREFIX', '/radio')
CACHE_TTL = int(os.getenv('CACHE_TTL', '3600'))  # Default 1 hour
CACHE_INVALIDATION_FILE = RECORDINGS_DIR / '.last_recording'
LOGO_DIR = Path('/app/logo')
FORCE_HTTPS = os.getenv('FORCE_HTTPS', 'false').lower() == 'true'

app = Bottle()

# ======================================================================
# Program Configuration
# ======================================================================

def parse_programs(config_str):
    """
    Parse program configuration from environment variables.
    Format: PROGRAM1=start-end|alias|name|url
    
    Example:
        PROGRAM1=07:40-08:00|program1|Program Name #1|https://example.com/stream1.m3u8
        PROGRAM2=08:00-08:20|program2|Program Name #2|https://example.com/stream2.m3u8
    
    Note: config_str parameter is ignored (kept for compatibility with existing code)
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
            print(f"WARNING: Invalid format for PROGRAM{i}: {program_str}")
            print(f"   Expected format: start-end|alias|name|url")
            continue
        
        program_schedule, program_id, program_name, program_url = parts
        program_id = program_id.strip()
        program_name = program_name.strip()
        program_schedule = program_schedule.strip()
        program_url = program_url.strip()
        
        if not program_id or not program_name or not program_schedule or not program_url:
            print(f"WARNING: PROGRAM{i} has empty fields")
            continue
        
        # Parse schedule: "07:40-08:00"
        if '-' not in program_schedule:
            print(f"WARNING: Invalid schedule format for PROGRAM{i}: {program_schedule}")
            print(f"   Expected format: HH:MM-HH:MM")
            continue
        
        start = program_schedule.split('-')[0].strip()
        # Convert "07:40" to "0740"
        start = start.replace(':', '')
        
        if not start:
            print(f"WARNING: Invalid time format for PROGRAM{i}")
            continue
        
        # Store as single schedule entry (list for compatibility)
        schedule = [start]
        
        programs[program_id] = {
            'name': program_name,
            'schedule': schedule
        }
    
    if programs:
        print(f"📋 Loaded {len(programs)} programs from environment variables")
        for prog_id, prog_info in programs.items():
            print(f"   - {prog_id}: {prog_info['name']} @ {', '.join(prog_info['schedule'])}")
    else:
        print(f"WARNING: No programs configured")
    
    return programs

PROGRAMS = parse_programs(PROGRAMS_CONFIG)

# ======================================================================
# Authentication
# ======================================================================

def require_auth():
    """Require authentication via query string secret."""
    # Bypass authentication if SECRET is not set or empty
    if not SECRET:
        return
    
    provided_secret = request.query.get('secret', '')
    if provided_secret != SECRET:
        print(f"🚫 Unauthorized access attempt from {request.remote_addr} to {request.path}")
        abort(403, "Invalid or missing secret")

# ======================================================================
# File Filtering
# ======================================================================

def extract_time_from_filename(filename):
    """
    Extract HHMM from filename.
    Format: YYYYMMDD-HHMM-[hash].m4a or YYYYMMDD HHMM [hash].m4a
    Example: 20251222-0740-5f3a2b1c.m4a -> 0740
    """
    match = re.match(r'\d{8}[- ](\d{4})', filename)
    if match:
        return match.group(1)
    return None

def matches_schedule(file_time, schedule, tolerance_min=5):
    """
    Check if file time matches any schedule time within tolerance.
    
    Args:
        file_time: HHMM string from filename
        schedule: List of HHMM strings
        tolerance_min: Minutes of tolerance (default 5)
    
    Returns:
        True if file_time matches any schedule time within tolerance
    """
    if not file_time or not schedule:
        return False
    
    try:
        file_hour = int(file_time[:2])
        file_min = int(file_time[2:])
        file_total_min = file_hour * 60 + file_min
        
        for sched_time in schedule:
            sched_hour = int(sched_time[:2])
            sched_min = int(sched_time[2:])
            sched_total_min = sched_hour * 60 + sched_min
            
            diff = abs(file_total_min - sched_total_min)
            if diff <= tolerance_min:
                return True
        
        return False
    except (ValueError, IndexError):
        return False

def filter_files_by_program(files, schedule):
    """Filter files by program schedule."""
    if not schedule:
        return files
    
    filtered = []
    for f in files:
        file_time = extract_time_from_filename(f.name)
        if file_time and matches_schedule(file_time, schedule):
            filtered.append(f)
    
    return filtered

# ======================================================================
# Utility Functions
# ======================================================================

def get_base_url():
    """Generate base URL from request headers, respecting reverse proxy headers."""
    # Get scheme from proxy headers if available, otherwise fallback to request scheme
    scheme = request.get_header('X-Forwarded-Proto', '').lower()
    
    if not scheme:
        if request.get_header('X-Forwarded-Ssl', '').lower() == 'on':
            scheme = 'https'
        else:
            # Bottle request.urlparts.scheme might be unreliable behind proxy
            scheme = request.urlparts.scheme or 'http'
    
    # Get host from headers (supports proxies)
    host = request.get_header('X-Forwarded-Host') or request.get_header('Host') or 'localhost:8013'
    
    # Construct base URL with dynamic route prefix
    prefix = ROUTE_PREFIX.lstrip('/')
    
    # Force HTTPS if configured
    if FORCE_HTTPS:
        scheme = 'https'
        
    base_url = f"{scheme}://{host}/{prefix}/"
    return base_url

# ======================================================================
# Feed Generation and Caching
# ======================================================================

# Cache for podcast feeds: key=(program_id, schedule_tuple, base_url), value=rss_string
_feed_cache = TTLCache(maxsize=100, ttl=CACHE_TTL)
_last_invalidation_time = 0

def get_last_recording_time():
    """Get timestamp of last recording from invalidation file."""
    try:
        if CACHE_INVALIDATION_FILE.exists():
            return CACHE_INVALIDATION_FILE.stat().st_mtime
    except Exception as e:
        print(f"WARNING: Failed to read cache invalidation file: {e}")
    return 0

def should_invalidate_cache():
    """Check if cache should be invalidated based on new recordings."""
    global _last_invalidation_time
    
    current_mtime = get_last_recording_time()
    # Initialize timestamp on first run without clearing cache
    if _last_invalidation_time == 0:
        _last_invalidation_time = current_mtime
        return False
        
    if current_mtime > _last_invalidation_time:
        _last_invalidation_time = current_mtime
        return True
    return False

def _generate_podcast_feed_internal(program_name=None, program_id=None, schedule=None):
    """Internal function to generate RSS feed from .m4a files in recordings directory."""
    p = Podcast()
    
    # Get dynamic base URL from request
    web_base_url = get_base_url()
    
    # Use program-specific name or default
    if program_name:
        p.name = program_name
        base_url = web_base_url + f"{program_id}/"
    else:
        p.name = os.getenv('PROGRAM_NAME', 'Radio Recorder')
        base_url = web_base_url
    
    p.website = base_url
    p.feed_url = base_url + 'feed.rss'
    
    # Per-program logo support: Search for alias.png, alias.jpg, or alias.jpeg
    logo_file = 'default.png'
    if program_id:
        for ext in ['.png', '.jpg', '.jpeg']:
            if (LOGO_DIR / f"{program_id}{ext}").exists():
                logo_file = f"{program_id}{ext}"
                break
    
    p.image = web_base_url + f'logo/{logo_file}'
        
    p.description = 'Personal Radio Archive'
    p.language = 'ko'
    p.authors = [Person('Radio Recorder')]
    p.explicit = False
    
    # Find all .m4a files
    all_files = sorted(RECORDINGS_DIR.glob('*.m4a'), reverse=True)

    
    # Filter by program schedule if provided
    if schedule:
        files = filter_files_by_program(all_files, schedule)
        print(f"Filtered {len(all_files)} files to {len(files)} for program {program_id}")
    else:
        files = all_files
    
    if not files:
        print(f"WARNING: No .m4a files found")
    
    for f in files:
        try:
            size = f.stat().st_size
            mtime = f.stat().st_mtime
            date = time.localtime(mtime)
            
            e = Episode()
            e.title = time.strftime('%Y-%m-%d %H:%M Recording', date)
            e.media = Media(web_base_url + f.name, size)
            # Use filename as GUID for consistency
            e.id = f.name
            e.publication_date = time.strftime('%a, %d %b %Y %H:%M:%S +0900', date)
            
            # iTunes specific duration
            try:
                e.media.populate_duration_from(str(f))
            except Exception as duration_error:
                # print(f"WARNING: Could not get duration for {f.name}: {duration_error}")
                pass
            
            p.episodes.append(e)
        except Exception as e:
            print(f"WARNING: Failed to process file {f.name}: {e}")
            continue
    
    return p

def generate_podcast_feed_xml(program_name=None, program_id=None, schedule=None):
    """Generate RSS feed XML with caching support."""
    # Check if cache should be invalidated
    if should_invalidate_cache():
        print("♻️ Cache invalidated due to new recording")
        _feed_cache.clear()
    
    # Get dynamic base URL for this request
    web_base_url = get_base_url()
    
    # Create cache key including the base URL to prevent HTTP/HTTPS cache poisoning
    schedule_tuple = tuple(schedule) if schedule else None
    cache_key = (program_id, schedule_tuple, web_base_url)
    
    # Check cache
    if cache_key in _feed_cache:
        # print(f"🚀 Cache HIT for {cache_key}")
        return _feed_cache[cache_key]
    
    # Cache miss - generate feed
    print(f"📦 Cache MISS - Generating new feed for: {web_base_url} (ID: {program_id or 'all'})")
    podcast = _generate_podcast_feed_internal(program_name, program_id, schedule)
    rss_xml = podcast.rss_str()
    
    # Store string in cache
    _feed_cache[cache_key] = rss_xml
    
    return rss_xml

# ======================================================================
# Routes
# ======================================================================

@app.route('/')
def index():
    """Health check endpoint."""
    return {
        'status': 'ok',
        'service': 'Radio Feed Service',
        'recordings_dir': str(RECORDINGS_DIR),
        'programs': list(PROGRAMS.keys()) if PROGRAMS else []
    }

@app.route(f'{ROUTE_PREFIX}/feed.rss')
def feed_all():
    """Generate and serve RSS feed for all programs."""
    require_auth()
    
    try:
        rss_content = generate_podcast_feed_xml()
        
        response.content_type = 'application/rss+xml; charset=utf-8'
        return rss_content
    except Exception as e:
        print(f"ERROR: Failed to generate feed: {e}")
        abort(500, f"Failed to generate feed: {e}")

@app.route(f'{ROUTE_PREFIX}/<program_id>/feed.rss')
def feed_program(program_id):
    """Generate and serve RSS feed for specific program."""
    require_auth()
    
    if program_id not in PROGRAMS:
        abort(404, f"Program '{program_id}' not found")
    
    try:
        program = PROGRAMS[program_id]
        rss_content = generate_podcast_feed_xml(
            program_name=program['name'],
            program_id=program_id,
            schedule=program['schedule']
        )
        
        response.content_type = 'application/rss+xml; charset=utf-8'
        return rss_content
    except Exception as e:
        print(f"ERROR: Failed to generate feed for {program_id}: {e}")
        abort(500, f"Failed to generate feed: {e}")

@app.route(f'{ROUTE_PREFIX}/<filename:path>')
def serve_file(filename):
    """Serve audio files and other static assets."""
    # Security: prevent directory traversal
    if '..' in filename or filename.startswith('/'):
        abort(403, "Access denied")
    
    # Handle logo files: /radio/logo/<alias>.png
    if filename.startswith('logo/'):
        logo_filename = filename[len('logo/'):]
        if '/' in logo_filename:
            abort(403, "Access denied")
        
        logo_path = LOGO_DIR / logo_filename
        if not logo_path.exists():
            # If default.png doesn't exist, return 404
            abort(404, "Logo not found")
            
        suffix = logo_path.suffix.lower()
        mime_types = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg'}
        mimetype = mime_types.get(suffix, 'image/png')
        return static_file(logo_filename, root=str(LOGO_DIR), mimetype=mimetype)

    # Handle program-specific paths (e.g., /radio/program1/file.m4a)
    # Extract actual filename if it's a program path
    if '/' in filename:
        parts = filename.split('/')
        if len(parts) == 2 and parts[0] in PROGRAMS:
            filename = parts[1]
    
    file_path = RECORDINGS_DIR / filename
    
    if not file_path.exists():
        abort(404, "File not found")
    
    # Determine MIME type (m4a is the primary audio format)
    mime_types = {
        '.m4a': 'audio/mp4',
    }
    
    suffix = file_path.suffix.lower()
    mimetype = mime_types.get(suffix, 'application/octet-stream')
    
    return static_file(filename, root=str(RECORDINGS_DIR), mimetype=mimetype)

# ======================================================================
# Main
# ======================================================================

if __name__ == '__main__':
    print(f"Starting Radio Feed Service...")
    print(f"Recordings directory: {RECORDINGS_DIR}")
    print(f"Authentication: {'Enabled (SECRET)' if SECRET else 'Disabled (no SECRET)'}")
    print(f"Route prefix: {ROUTE_PREFIX}")
    print(f"Cache TTL: {CACHE_TTL} seconds")
    print(f"Base URL: Dynamic (from request headers)")
    print(f"Programs configured: {len(PROGRAMS)}")
    for prog_id, prog_info in PROGRAMS.items():
        print(f"  - {prog_id}: {prog_info['name']} @ {', '.join(prog_info['schedule'])}")
    
    # Create recordings directory if it doesn't exist
    RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Run server
    app.run(host='0.0.0.0', port=8080, debug=False, reloader=False)
