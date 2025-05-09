#!/bin/sh

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

  # Abort if BASE_URL is not configured
  if [ -z "$BASE_URL" ]; then
    printf 'Error: BASE_URL is not set in %s\n' "$config_file" >&2
    exit 1
  fi
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
MEDIA_EXT='mp4|mkv|avi|webm|flv|mov|wmv|m4v|mp3|flac|wav|aac|ogg|m4a'
MEDIA_REGEX="\.\($(printf '%s' "$MEDIA_EXT")\)\$"

# Build an M3U playlist from a URL directory, starting from selected episode
plbuild() {
  # URL‐encode the chosen episode name
  ENCODED_EP=$(printf '%s\n' "$EPISODE" \
    | python3 -c "import sys, urllib.parse as ul; \
        print('\n'.join(ul.quote(ul.unquote(line.strip()), safe='/') for line in sys.stdin))")

  # Start playlist file with M3U header
  echo "#EXTM3U" > "$M3U_FILE"

  # Strip base URL prefix to get relative path
  URL_PATH=${1#$BASE_URL/}

  # Loop over all .mkv files in the directory listing
  for i in $(wget -q -O - "$1" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE "$MEDIA_REGEX")
  do
    echo "#EXTINF:-1," >> "$M3U_FILE"      # add a new playlist entry
    # URL‐encode each file name
    ENCODED=$(echo "$URL_PATH$i" \
      | python3 -c "import sys, urllib.parse as ul; \
          print('\n'.join(ul.quote(ul.unquote(line.strip()), safe='/') for line in sys.stdin))")
    echo "$BASE_URL/$ENCODED" >> "$M3U_FILE"
  done

  # Remove entries before the chosen episode
  sed "0,/$ENCODED_EP/{//!d;}" "$M3U_FILE" \
    > "$M3U_FILE.tmp" && mv "$M3U_FILE.tmp" "$M3U_FILE"
}

# Navigate directories via fuzzy picker and play when reaching media files
navigate_and_play() {
  local current="$1"

  while :; do
    # Choose next directory entry
    choice=$(indexfzy "$current/") || exit
    [ -z "$choice" ] && exit
    current="$current/$choice"

    # Fetch raw hrefs of video/audio files in this directory
    raw=$(wget -qO- "$current/" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE "$MEDIA_REGEX")

    if [ -n "$raw" ]; then
      # Decode filenames and pick one via fuzzy finder
      decoded=$(printf '%s\n' "$raw" \
        | python3 -c "import sys,urllib.parse as ul; \
            print('\n'.join(ul.unquote(l.strip()) for l in sys.stdin))")
      EPISODE=$(printf '%s\n' "$decoded" | $FUZZY_FINDER) || exit
      [ -z "$EPISODE" ] && exit

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

  # Top‐level fuzzy pick of library categories
  LIBRARY=$(indexfzy "$BASE_URL")
  [ -z "$LIBRARY" ] && exit

  # Start navigation/playback
  navigate_and_play "$BASE_URL/$LIBRARY"
}

main

