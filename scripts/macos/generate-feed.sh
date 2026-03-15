#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${RADIO_CONFIG:-$SCRIPT_DIR/radio.conf}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  print -- "Config not found: $CONFIG_PATH"
  exit 1
fi

source "$CONFIG_PATH"

: "${OUTPUT_DIR:?Set OUTPUT_DIR in $CONFIG_PATH}"
FEED_FILE_NAME="${FEED_FILE_NAME:-feed.xml}"
PODCAST_AUTHOR="${PODCAST_AUTHOR:-Radio Archive}"
PODCAST_LANGUAGE="${PODCAST_LANGUAGE:-en-US}"
PODCAST_DESCRIPTION="${PODCAST_DESCRIPTION:-Personal radio archive}"
PODCAST_COPYRIGHT="${PODCAST_COPYRIGHT:-Personal use only}"
PODCAST_EXPLICIT="${PODCAST_EXPLICIT:-no}"
FFPROBE_BIN="${FFPROBE_BIN:-}"
TAILSCALE_BIN="${TAILSCALE_BIN:-}"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$FFPROBE_BIN" ]]; then
  if [[ -n "${FFMPEG_BIN:-}" ]]; then
    FFPROBE_BIN="$(cd "$(dirname "$FFMPEG_BIN")" && pwd)/ffprobe"
  else
    FFPROBE_BIN="ffprobe"
  fi
fi

if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  elif [[ -x /usr/bin/python3 ]]; then
    PYTHON_BIN="/usr/bin/python3"
  fi
fi

if [[ -z "$TAILSCALE_BIN" ]]; then
  if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_BIN="$(command -v tailscale)"
  fi
fi

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

escape_xml() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  print -r -- "$value"
}

rfc2822_date() {
  LC_ALL=C date -r "$1" '+%a, %d %b %Y %H:%M:%S %z'
}

duration_hms() {
  local seconds="$1"
  local hours minutes remainder

  hours=$(( seconds / 3600 ))
  remainder=$(( seconds % 3600 ))
  minutes=$(( remainder / 60 ))
  remainder=$(( remainder % 60 ))

  printf '%02d:%02d:%02d\n' "$hours" "$minutes" "$remainder"
}

audio_duration_seconds() {
  local file="$1"
  local raw_duration

  if ! command -v "$FFPROBE_BIN" >/dev/null 2>&1; then
    print -- "0"
    return 0
  fi

  raw_duration="$("$FFPROBE_BIN" -v error -show_entries format=duration -of default=nk=1:nw=1 "$file" 2>/dev/null || true)"
  raw_duration="${raw_duration%%.*}"

  if [[ -z "$raw_duration" ]]; then
    print -- "0"
  else
    print -- "$raw_duration"
  fi
}

resolve_public_base_url() {
  if [[ -n "${PUBLIC_BASE_URL:-}" ]]; then
    print -r -- "${PUBLIC_BASE_URL%/}"
    return 0
  fi

  if [[ -n "$TAILSCALE_BIN" && -n "$PYTHON_BIN" ]]; then
    if ! command -v "$TAILSCALE_BIN" >/dev/null 2>&1; then
      print -- "PUBLIC_BASE_URL is empty and tailscale is not installed or not in PATH." >&2
      print -- "Install Tailscale or set PUBLIC_BASE_URL in $CONFIG_PATH." >&2
      return 1
    fi

    local derived_url
    derived_url="$("$TAILSCALE_BIN" status --json 2>/dev/null | "$PYTHON_BIN" -c 'import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
dns = (data.get("Self", {}) or {}).get("DNSName") or ""
dns = dns.rstrip(".")
print(f"https://{dns}" if dns else "")')"

    if [[ -n "$derived_url" ]]; then
      print -r -- "$derived_url"
      return 0
    fi
  fi

  print -- "PUBLIC_BASE_URL is not set and Tailscale base URL could not be determined." >&2
  return 1
}

title_for_alias() {
  local wanted_alias="$1"
  local title=""

  for i in {1..50}; do
    eval "program=\${PROGRAM${i}:-}"
    [[ -z "${program:-}" ]] && continue

    fields=("${(@s:|:)program}")
    if (( ${#fields[@]} < 2 )); then
      continue
    fi

    if [[ -n "$(trim "${fields[1]}")" && "$(trim "${fields[1]}")" == "$wanted_alias" ]]; then
      title="$(trim "${fields[2]}")"
    fi
  done

  if [[ -n "$title" ]]; then
    print -r -- "$title"
  else
    print -r -- "$wanted_alias"
  fi
}

generate_feed_for_alias() {
  local alias="$1"
  local title channel_url feed_url program_dir feed_file tmp_file
  local image_url last_build_date
  local file filename filesize mtime pub_date episode_title item_duration item_url
  local files
  local public_base_url

  title="$(title_for_alias "$alias")"
  program_dir="$OUTPUT_DIR/$alias"
  mkdir -p "$program_dir"

  public_base_url="$(resolve_public_base_url)"
  channel_url="$public_base_url/$alias/"
  feed_url="$channel_url$FEED_FILE_NAME"
  feed_file="$program_dir/$FEED_FILE_NAME"
  tmp_file="$(mktemp)"
  last_build_date="$(LC_ALL=C date '+%a, %d %b %Y %H:%M:%S %z')"
  image_url="${PODCAST_IMAGE_URL:-}"

  files=("${(@f)$(find "$program_dir" -maxdepth 1 -type f -name '*.m4a' -print | sort -r)}")

  {
    print -- '<?xml version="1.0" encoding="UTF-8"?>'
    print -- '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">'
    print -- '  <channel>'
    printf '    <title>%s</title>\n' "$(escape_xml "$title")"
    printf '    <link>%s</link>\n' "$(escape_xml "$channel_url")"
    printf '    <atom:link href="%s" rel="self" type="application/rss+xml" />\n' "$(escape_xml "$feed_url")"
    printf '    <description>%s</description>\n' "$(escape_xml "$PODCAST_DESCRIPTION")"
    printf '    <language>%s</language>\n' "$(escape_xml "$PODCAST_LANGUAGE")"
    printf '    <lastBuildDate>%s</lastBuildDate>\n' "$last_build_date"
    printf '    <copyright>%s</copyright>\n' "$(escape_xml "$PODCAST_COPYRIGHT")"
    printf '    <itunes:author>%s</itunes:author>\n' "$(escape_xml "$PODCAST_AUTHOR")"
    printf '    <itunes:summary>%s</itunes:summary>\n' "$(escape_xml "$PODCAST_DESCRIPTION")"
    printf '    <itunes:explicit>%s</itunes:explicit>\n' "$(escape_xml "$PODCAST_EXPLICIT")"

    if [[ -n "$image_url" ]]; then
      printf '    <itunes:image href="%s" />\n' "$(escape_xml "$image_url")"
      print -- '    <image>'
      printf '      <url>%s</url>\n' "$(escape_xml "$image_url")"
      printf '      <title>%s</title>\n' "$(escape_xml "$title")"
      printf '      <link>%s</link>\n' "$(escape_xml "$channel_url")"
      print -- '    </image>'
    fi

    for file in "${files[@]}"; do
      [[ -f "$file" ]] || continue

      filename="$(basename "$file")"
      filesize="$(stat -f %z "$file")"
      mtime="$(stat -f %m "$file")"
      pub_date="$(rfc2822_date "$mtime")"
      episode_title="$title $(date -r "$mtime" '+%Y-%m-%d')"
      item_duration="$(duration_hms "$(audio_duration_seconds "$file")")"
      item_url="$channel_url$filename"

      print -- '    <item>'
      printf '      <title>%s</title>\n' "$(escape_xml "$episode_title")"
      printf '      <guid isPermaLink="false">%s</guid>\n' "$(escape_xml "$filename")"
      printf '      <pubDate>%s</pubDate>\n' "$pub_date"
      printf '      <description>%s</description>\n' "$(escape_xml "$episode_title")"
      printf '      <enclosure url="%s" length="%s" type="audio/mp4" />\n' "$(escape_xml "$item_url")" "$filesize"
      printf '      <itunes:duration>%s</itunes:duration>\n' "$item_duration"
      print -- '    </item>'
    done

    print -- '  </channel>'
    print -- '</rss>'
  } > "$tmp_file"

  mv "$tmp_file" "$feed_file"
  print -- "Updated $feed_file"
}

if (( $# > 0 )); then
  generate_feed_for_alias "$1"
  exit 0
fi

for i in {1..50}; do
  eval "program=\${PROGRAM${i}:-}"
  [[ -z "${program:-}" ]] && continue

  fields=("${(@s:|:)program}")
  if (( ${#fields[@]} < 2 )); then
    continue
  fi

  alias="$(trim "${fields[1]}")"
  [[ -n "$alias" ]] || continue
  generate_feed_for_alias "$alias"
done
