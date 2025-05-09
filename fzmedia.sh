#!/bin/sh

sourceconf() {
  local config_dir="$HOME/.config/fzmedia"
  local config_file="$config_dir/config"

  # defaults (can be overridden in environment or config file)
  : "${VIDEO_PLAYER:=mpv}"
  : "${FUZZY_FINDER:=fzy}"
  : "${M3U_FILE:=/tmp/filelist.m3u}"

  # bootstrap config if missing
  if [ ! -f "$config_file" ]; then
    echo "Creating default config at $config_file"
    mkdir -p "$config_dir"
    cat >"$config_file" <<'EOF'
# fzmedia config ── adjust as needed

BASE_URL=""          # http index root (required)
# VIDEO_PLAYER="mpv"
# FUZZY_FINDER="fzy"
# M3U_FILE="/tmp/filelist.m3u"
EOF
  fi

  # load user config
  # shellcheck disable=SC1090
  . "$config_file"

  # ensure BASE_URL is set
  if [ -z "$BASE_URL" ]; then
    printf 'Error: BASE_URL is not set in %s\n' "$config_file" >&2
    exit 1
  fi
}

indexfzy () {
  wget -q -O - "$1" \
    | grep -oP '(?<=href=")[^"]*' \
    | sed '1d' \
    | python3 -c "import sys, urllib.parse as ul; print('\n'.join(ul.unquote_plus(line.strip()) for line in sys.stdin))" \
    | $FUZZY_FINDER
}


plbuild () {
  ENCODED_EP=$(printf '%s\n' "$EPISODE" | python3 -c "import sys, urllib.parse as ul; print('\n'.join(ul.quote(ul.unquote(line.strip()), safe='/') for line in sys.stdin))")
  echo "#EXTM3U" > "$M3U_FILE"
  URL_PATH=${1#$BASE_URL/}
  for i in $(wget -q -O - "$1" | grep -oP '(?<=href=")[^"]*' | grep mkv)
  do
    echo "#EXTINF:-1," >> "$M3U_FILE"
    ENCODED=$(echo "$URL_PATH$i" | python3 -c "import sys, urllib.parse as ul; print('\n'.join(ul.quote(ul.unquote(line.strip()), safe='/') for line in sys.stdin))")
    echo $BASE_URL/$ENCODED >> "$M3U_FILE"
  done
  sed "0,/$ENCODED_EP/{//!d;}" "$M3U_FILE" > "$M3U_FILE.tmp" && mv "$M3U_FILE.tmp" "$M3U_FILE"
}

navigate_and_play() {
  local current="$1"
  while :; do
    # pick next entry (decoded by indexfzy)
    choice=$(indexfzy "$current/") || exit
    [ -z "$choice" ] && exit
    current="$current/$choice"

    # grab raw hrefs for any video/audio files
    raw=$(wget -qO- "$current/" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE '\.(mp4|mkv|avi|webm|flv|mov|wmv|m4v|mp3|flac|wav|aac|ogg|m4a)$')

    if [ -n "$raw" ]; then
      # decode them, fuzzy-pick the episode
      decoded=$(printf '%s\n' "$raw" | \
        python3 -c "import sys,urllib.parse as ul; print('\n'.join(ul.unquote(l.strip()) for l in sys.stdin))")
      EPISODE=$(printf '%s\n' "$decoded" | $FUZZY_FINDER) || exit
      [ -z "$EPISODE" ] && exit

      # build & play
      plbuild "$current"
      $VIDEO_PLAYER "$M3U_FILE"
      rm -f "$M3U_FILE"
      break
    fi
    # otherwise loop deeper
  done
}

main () {
  # disallow root
  if [ "`id -u`" -eq 0 ]; then \
  	echo "Do not run this script as root. Aborting."; \
  	exit 1; \
  fi

  sourceconf

  LIBRARY=$(indexfzy "$BASE_URL")
  [ -z "$LIBRARY" ] && exit 

  navigate_and_play "$BASE_URL/$LIBRARY"
}

main
