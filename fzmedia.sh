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

  -u  HTTP index root        (overrides BASE_URL in config)
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
  [ -z $XDG_CONFIG_HOME ] && local config_home="$HOME/.config" || config_home="$XDG_CONFIG_HOME"
  [ -z $XDG_CACHE_HOME ] && local cache_home="$HOME/.cache" || cache_home="$XDG_CACHE_HOME"
  local config_dir="$config_home/fzmedia"
  local config_file="$config_dir/config"

  # Ensure the config directory exists and create the file if it doesn't
  mkdir -p "$config_dir"
  touch "$config_file"
  . "$config_file"

  # Define all VAR=default pairs once
  set -- \
    "BASE_URL=" \
    "VIDEO_PLAYER=mpv --save-position-on-quit --no-resume-playback" \
    "RESUME_PLAYER=mpv --save-position-on-quit" \
    "FUZZY_FINDER=fzy" \
    "M3U_FILE=/tmp/fzmedia.m3u" \
    "PREFERRED_ORDER=movies/,tv/,anime/,music/" \
    "CACHE_DIR=$cache_home/fzmedia"

  # Apply defaults: for each “VAR=default”, do : "${VAR:=default}"
  for each in "$@"; do eval ": \"\${${each%%=*}:=${each#*=}}\""; done

  # Ensure the cache directory exists now that CACHE_DIR is set
  mkdir -p "$CACHE_DIR"

  # Append any missing VAR lines (commented or not) to the end of the config file
  for each in "$@"; do
    var=${each%%=*}
    eval "val=\$$var"
    # only BASE_URL gets a custom trailing comment; everything else uses “#default”
    if ! grep -q -E "^[[:space:]]*#?[[:space:]]*$var=" "$config_file"; then
      if [ "$var" = "BASE_URL" ]; then
        printf '#%s="%s" #/path/to/file or http://example.com\n' \
          "$var" "$val" >> "$config_file"
      else
        printf '#%s="%s" #default\n' \
          "$var" "$val" >> "$config_file"
      fi
    fi
  done

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

reorder() {
  awk -v order="$PREFERRED_ORDER" '
  BEGIN {
    n = split(order, arr, ",")
    for (i=1; i<=n; i++) prio[arr[i]] = i
  }
  {
    p = ($0 in prio ? prio[$0] : n+1)
    print p "\t" $0
  }' \
  | sort -k1,1n \
  | cut -f2
}

list_entries() {
  case "$1" in
    http://*|https://*)
      wget -q -O - "$1" \
        | grep -oP '(?<=href=")[^"]*' \
        | sed '1d' \
        | url_decode
      ;;
    *)
      # assume $1 is a directory on disk (with or without trailing slash)
      dir="${1%/}"
      ( cd "$dir" 2>/dev/null && ls -1p )
      ;;
  esac
}

# List and fuzzy‐select directory entries under a given URL
indexfzy() {
  list_entries "$1" | $FUZZY_FINDER
}
# supported media extensions
MEDIA_EXT='|mkv|mp4|avi|webm|flv|mov|wmv|m4v|mp3|flac|wav|aac|ogg|m4a'
MEDIA_REGEX="\.\($(printf '%s' "$MEDIA_EXT")\)\$"

# Build an M3U playlist from a URL/directory, starting from first selected file
plbuild() {
  echo "#EXTM3U" > "$M3U_FILE"

  list_entries "$1" \
    | grep -iE "$MEDIA_REGEX" \
    | while IFS= read -r file; do
        printf '#EXTINF:-1,\n' >> "$M3U_FILE"
        case "$1" in
          http://*|https://*)
            enc=$(printf '%s' "$file" | url_encode)
            printf '%s%s\n' "$1" "$enc" >> "$M3U_FILE"
            ;;
          *)
            printf '%s%s\n' "$1" "$file" >> "$M3U_FILE"
            ;;
        esac
      done

  # remove everything before the chosen file
  if case "$1" in http://*|https://*) true;; *) false;; esac; then
    pattern=$(printf '%s' "$FILE" | url_encode)
  else
    pattern="$FILE"
  fi
  sed "0,/$pattern/{//!d;}" "$M3U_FILE" > "$M3U_FILE.tmp" \
    && mv "$M3U_FILE.tmp" "$M3U_FILE"
}

# Prompt via fuzzy finder whether to add to the add to continue watching cache dir
cont_watch() {
  ans=$( printf "add to continue watching\ndon't add\n" | $FUZZY_FINDER ) || return
  [ "$ans" = "add to continue watching" ] && cp "$1" "$CACHE_DIR/${2%.*}.m3u"
}

manage_cache() {
  local sel
  sel=$(find "$CACHE_DIR" -maxdepth 1 -name '*.m3u' -printf '%f\n' 2>/dev/null \
    | $FUZZY_FINDER) || return
  [ -n "$sel" ] && rm "$CACHE_DIR/$sel"
}

# Navigate directories via fuzzy picker and play when reaching media files
navigate_and_play() {
  local current="${1%/}/"
  local choice

  while :; do
    choice=$(
      {
        [ "${current%/}" = "${BASE_URL%/}" ] \
          && ls "$CACHE_DIR"/*.m3u >/dev/null 2>&1 \
          && printf 'continue watching\n'
        list_entries "$current" | reorder
        [ "${current%/}" = "${CACHE_DIR%/}" ] && printf 'rm\n'
        [ "${current%/}" != "${BASE_URL%/}" ] && printf '../\n'
      } | $FUZZY_FINDER
    ) || exit

    [ -z "$choice" ] && exit

    case "$choice" in
      "continue watching")
        current="${CACHE_DIR%/}/"
        ;;

      "rm")
        manage_cache
        # if CACHE_DIR is now empty of .m3u, reset to BASE_URL; otherwise stay in CACHE_DIR
        [ ! -e "$CACHE_DIR"/*.m3u ] && current="${BASE_URL%/}/" || current="${CACHE_DIR%/}/"
        ;;
      ../)
        [ "${current%/}" = "${CACHE_DIR%/}" ] && current="${BASE_URL%/}" || current="${current%/*/}/"
        ;;

      */)
        current="${current}${choice}"
        ;;

      *)
        if printf '%s\n' "$choice" | grep -qiE '\.m3u$'; then
          $RESUME_PLAYER "${current}${choice}"
          break

        elif printf '%s\n' "$choice" | grep -qiE "$MEDIA_REGEX"; then
          FILE="$choice"
          plbuild "$current"
          $VIDEO_PLAYER "$M3U_FILE"
          cont_watch "$M3U_FILE" "$choice"
          rm -f "$M3U_FILE"
          break

        else
          echo "Skipping non-media: $choice" >&2
        fi
        ;;
    esac
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

  # If BASE_URL is still empty after sourcing/applying defaults, error out
  [ -z "$BASE_URL" ] && echo "Error: BASE_URL must be set." >&2 && return 1

  # Start navigation/playback
  navigate_and_play "${BASE_URL%/}/"

}

main

