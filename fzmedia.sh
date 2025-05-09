#!/bin/sh

# Parse CLI flags (override config)
while getopts "u:p:f:m:h" opt; do
  case "$opt" in
    u) FLAG_BASE_URL=$OPTARG ;;
    p) FLAG_VIDEO_PLAYER=$OPTARG ;;
    f) FLAG_FUZZY_FINDER=$OPTARG ;;
    m) FLAG_M3U_FILE=$OPTARG ;;
    h)
      cat <<EOF
Usage: $(basename "$0") [-u BASE_URL] [-p VIDEO_PLAYER] [-f FUZZY_FINDER] [-m M3U_FILE]

  -u  HTTP index root (overrides BASE_URL in config)
  -p  video player command   (overrides VIDEO_PLAYER)
  -f  fuzzy-finder command   (overrides FUZZY_FINDER)
  -m  path to m3u file       (overrides M3U_FILE)
  -h  this help
EOF
      exit 0
      ;;
    *) exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# Load configuration, apply defaults, and ensure BASE_URL is set
sourceconf() {
  local config_dir="$HOME/.config/fzmedia"
  local config_file="$config_dir/config"

  # Default settings (can be overridden by environment or config file)
  : "${VIDEO_PLAYER:=mpv}"        # Video player command
  : "${FUZZY_FINDER:=fzy}"        # Fuzzy‐finder command
  : "${M3U_FILE:=/tmp/filelist.m3u}"  # Playlist file path

  # If config file doesn’t exist, create a template
  if [ ! -f "$config_file" ]; then
    echo "Creating default config at $config_file"
    mkdir -p "$config_dir"
    cat >"$config_file" <<'EOF'
# fzmedia config ── adjust as needed

BASE_URL=""          # HTTP index root (required)
# VIDEO_PLAYER="mpv"
# FUZZY_FINDER="fzy"
# M3U_FILE="/tmp/filelist.m3u"
EOF
  fi

  # Source user config (override defaults)
  # shellcheck disable=SC1090
  . "$config_file"
}


# URL-encode stdin lines (safe='/')
url_encode() {
  python3 -c '
import sys, urllib.parse as ul
print("\n".join(
    ul.quote(ul.unquote(line.strip()), safe="/")
    for line in sys.stdin
))'
}

# URL-decode stdin lines
url_decode() {
  python3 -c '
import sys, urllib.parse as ul
print("\n".join(
    ul.unquote_plus(line.strip())
    for line in sys.stdin
))'
}

# List and fuzzy‐select directory entries under a given URL
indexfzy () {
  wget -q -O - "$1" \
    | grep -oP '(?<=href=")[^"]*' \
    | sed '1d' \
    | python3 -c "import sys, urllib.parse as ul; print('\n'.join(ul.unquote_plus(line.strip()) for line in sys.stdin))" \
    | $FUZZY_FINDER
}

# supported media extensions
MEDIA_EXT='|mkv|mp4|avi|webm|flv|mov|wmv|m4v|mp3|flac|wav|aac|ogg|m4a'
MEDIA_REGEX="\.\($(printf '%s' "$MEDIA_EXT")\)\$"

# Build an M3U playlist from a URL directory, starting from selected episode
plbuild() {
  # URL‐encode the chosen episode name
  ENCODED_FILE=$(printf '%s\n' "$FILE" | url_encode)

  # Start playlist file with M3U header
  echo "#EXTM3U" > "$M3U_FILE"

  # Strip base URL prefix to get relative path
  URL_PATH=${1#$BASE_URL}

  # Loop over all .mkv files in the directory listing
  for i in $(wget -q -O - "$1" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE "$MEDIA_REGEX")
  do
    echo "#EXTINF:-1," >> "$M3U_FILE"      # add a new playlist entry
    # URL‐encode each file name
    ENCODED=$(echo "$URL_PATH$i" | url_encode)
    echo "$BASE_URL$ENCODED" >> "$M3U_FILE"
  done

  # Remove entries before the chosen episode
  sed "0,/$ENCODED_FILE/{//!d;}" "$M3U_FILE" \
    > "$M3U_FILE.tmp" && mv "$M3U_FILE.tmp" "$M3U_FILE"
}

# Navigate directories via fuzzy picker and play when reaching media files
navigate_and_play() {
  local current="$1"

  while :; do
    # Choose next directory entry
    choice=$(indexfzy "$current") || exit
    [ -z "$choice" ] && exit
    current="$current$choice"

    # Fetch raw hrefs of video/audio files in this directory
    raw=$(wget -qO- "$current" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE "$MEDIA_REGEX")

    if [ -n "$raw" ]; then
      # Decode filenames and pick one via fuzzy finder
      decoded=$(printf '%s\n' "$raw" | url_decode)
      FILE=$(printf '%s\n' "$decoded" | $FUZZY_FINDER) || exit
      [ -z "$FILE" ] && exit

      # Build playlist starting from chosen episode and play
      plbuild "$current"
      $VIDEO_PLAYER "$M3U_FILE"
      rm -f "$M3U_FILE"
      break
    fi
    # Otherwise, descend into the next directory
  done
}

# Entry point
main() {
  # Prevent running as root
  if [ "$(id -u)" -eq 0 ]; then
    echo "Do not run this script as root. Aborting."
    exit 1
  fi

  sourceconf  # load config

  # Apply CLI overrides
  [ -n "$FLAG_BASE_URL" ]    && BASE_URL=$FLAG_BASE_URL
  [ -n "$FLAG_VIDEO_PLAYER" ] && VIDEO_PLAYER=$FLAG_VIDEO_PLAYER
  [ -n "$FLAG_FUZZY_FINDER" ] && FUZZY_FINDER=$FLAG_FUZZY_FINDER
  [ -n "$FLAG_M3U_FILE" ]     && M3U_FILE=$FLAG_M3U_FILE

  # now BASE_URL must exist
  [ -z "$BASE_URL" ] && echo "Error: BASE_URL must be set." >&2 && exit 1

  # Top‐level fuzzy pick of library categories
  LIBRARY=$(indexfzy "$BASE_URL")
  [ -z "$LIBRARY" ] && exit

  # Start navigation/playback
  navigate_and_play "$BASE_URL/$LIBRARY"
}

main

