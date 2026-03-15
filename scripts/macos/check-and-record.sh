#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${RADIO_CONFIG:-$SCRIPT_DIR/radio.conf}"
LOCK_FILE="${RADIO_LOCK_FILE:-/tmp/radio-macos-recording.lock}"

log() {
  print -- "$*"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

day_to_num() {
  case "${1:u}" in
    MON) print 1 ;;
    TUE) print 2 ;;
    WED) print 3 ;;
    THU) print 4 ;;
    FRI) print 5 ;;
    SAT) print 6 ;;
    SUN) print 7 ;;
    *) return 1 ;;
  esac
}

is_today_scheduled() {
  local days="${1:u}"
  local today_num="$2"
  local today_name="$3"

  if [[ -z "$days" || "$days" == "ALL" || "$days" == "EVERY" || "$days" == "*" ]]; then
    return 0
  fi

  if [[ "$days" == *","* ]]; then
    local token
    for token in ${(s:,:)days}; do
      [[ "${token:u}" == "$today_name" ]] && return 0
    done
    return 1
  fi

  if [[ "$days" == *"-"* ]]; then
    local start_day="${days%%-*}"
    local end_day="${days##*-}"
    local start_num end_num
    start_num="$(day_to_num "$start_day")" || return 1
    end_num="$(day_to_num "$end_day")" || return 1

    if (( start_num <= end_num )); then
      (( today_num >= start_num && today_num <= end_num )) && return 0
    else
      (( today_num >= start_num || today_num <= end_num )) && return 0
    fi
    return 1
  fi

  [[ "$days" == "$today_name" ]]
}

if [[ ! -f "$CONFIG_PATH" ]]; then
  log "Config not found: $CONFIG_PATH"
  exit 1
fi

source "$CONFIG_PATH"

: "${OUTPUT_DIR:?Set OUTPUT_DIR in $CONFIG_PATH}"

FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"
AUDIO_CODEC="${AUDIO_CODEC:-aac}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
MATCH_WINDOW_MINUTES="${MATCH_WINDOW_MINUTES:-5}"
FEED_ENABLED="${FEED_ENABLED:-0}"

mkdir -p "$OUTPUT_DIR"

if [[ -f "$LOCK_FILE" ]]; then
  log "Recording already in progress. Skipping."
  exit 0
fi

current_hour="$(date +%H)"
current_min="$(date +%M)"
current_hhmm="${current_hour}${current_min}"
current_total_min=$((10#$current_hour * 60 + 10#$current_min))
today_num="$(date +%u)"

case "$today_num" in
  1) today_name="MON" ;;
  2) today_name="TUE" ;;
  3) today_name="WED" ;;
  4) today_name="THU" ;;
  5) today_name="FRI" ;;
  6) today_name="SAT" ;;
  7) today_name="SUN" ;;
  *) log "Could not determine current weekday."; exit 1 ;;
esac

forced_program="${1:-}"
matched_program=""
matched_alias=""
matched_title=""
matched_start=""
matched_duration=""
matched_url=""
min_diff=9999

for i in {1..50}; do
  eval "program=\${PROGRAM${i}:-}"
  [[ -z "${program:-}" ]] && continue

  fields=("${(@s:|:)program}")
  if (( ${#fields[@]} < 6 )); then
    log "Skipping PROGRAM$i because it does not have 6 fields."
    continue
  fi

  alias="$(trim "${fields[1]}")"
  title="$(trim "${fields[2]}")"
  days="$(trim "${fields[3]}")"
  start="$(trim "${fields[4]}")"
  duration_min="$(trim "${fields[5]}")"
  stream_url="$(trim "${fields[6]}")"

  if [[ -z "$alias" || -z "$title" || -z "$stream_url" ]]; then
    log "Skipping PROGRAM$i because alias, title, or stream URL is empty."
    continue
  fi

  if [[ ! "$duration_min" =~ '^[0-9]+$' ]] || (( 10#$duration_min <= 0 )); then
    log "Skipping PROGRAM$i because duration '$duration_min' is invalid."
    continue
  fi

  if [[ -n "$forced_program" && "$forced_program" != "PROGRAM$i" && "$forced_program" != "$alias" ]]; then
    continue
  fi

  if [[ -z "$forced_program" ]]; then
    if ! is_today_scheduled "$days" "$today_num" "$today_name"; then
      continue
    fi

    if [[ ! "$start" =~ '^[0-9]{2}:[0-9]{2}$' ]]; then
      log "Skipping PROGRAM$i because start time '$start' is invalid."
      continue
    fi

    start_hour="${start%:*}"
    start_min="${start#*:}"
    start_total_min=$((10#$start_hour * 60 + 10#$start_min))
    diff=$((current_total_min - start_total_min))

    if (( diff < 0 || diff > MATCH_WINDOW_MINUTES )); then
      continue
    fi

    if (( diff < min_diff )); then
      min_diff=$diff
      matched_program="PROGRAM$i"
      matched_alias="$alias"
      matched_title="$title"
      matched_start="$start"
      matched_duration="$duration_min"
      matched_url="$stream_url"
    fi
  else
    matched_program="PROGRAM$i"
    matched_alias="$alias"
    matched_title="$title"
    matched_start="$start"
    matched_duration="$duration_min"
    matched_url="$stream_url"
    break
  fi
done

if [[ -z "$matched_program" ]]; then
  log "No matching program for ${today_name} ${current_hhmm}."
  exit 0
fi

if ! command -v "$FFMPEG_BIN" >/dev/null 2>&1; then
  log "ffmpeg not found: $FFMPEG_BIN"
  exit 1
fi

program_dir="$OUTPUT_DIR/$matched_alias"
mkdir -p "$program_dir"

timestamp_prefix="$(date +%Y%m%d)-${matched_start//:/}"
timestamp_suffix="$(date +%s)"
output_file="$program_dir/${timestamp_prefix}-${timestamp_suffix}.m4a"
duration_seconds=$((10#$matched_duration * 60))

trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

log "Recording $matched_title into $output_file"

stream_candidates=("${(@s:,:)matched_url}")
recording_succeeded=0
last_error=0

for stream_candidate in "${stream_candidates[@]}"; do
  stream_candidate="$(trim "$stream_candidate")"
  [[ -n "$stream_candidate" ]] || continue

  log "Trying stream: $stream_candidate"

  ffmpeg_cmd=(
    "$FFMPEG_BIN"
    -hide_banner
    -loglevel
    error
    -y
    -i
    "$stream_candidate"
    -t
    "$duration_seconds"
    -vn
  )

  if [[ "$AUDIO_CODEC" == "copy" ]]; then
    ffmpeg_cmd+=(-c:a copy)
  else
    ffmpeg_cmd+=(-c:a "$AUDIO_CODEC" -b:a "$AUDIO_BITRATE")
  fi

  ffmpeg_cmd+=("$output_file")

  if "${ffmpeg_cmd[@]}"; then
    recording_succeeded=1
    break
  fi

  last_error=$?
  rm -f "$output_file"
  log "Failed to open stream: $stream_candidate"
done

if (( recording_succeeded == 0 )); then
  log "All configured stream URLs failed."
  exit "${last_error:-1}"
fi

log "Finished recording: $output_file"

if [[ "$FEED_ENABLED" == "1" ]]; then
  if ! "$SCRIPT_DIR/generate-feed.sh" "$matched_alias"; then
    log "Feed generation failed for $matched_alias."
    log "Install Tailscale or set PUBLIC_BASE_URL, then rerun generate-feed.sh."
  fi
fi
