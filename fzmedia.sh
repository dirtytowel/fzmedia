#!/bin/sh

sourceconf () {
  # defaults
  : "${VIDEO_PLAYER:=mpv}"
  : "${FUZZY_FINDER:=fzy}"
  : "${M3U_FILE:=/tmp/filelist.m3u}"

  CONFIG_FILE_PATH="$HOME/.config/fzmedia/"
  if [ ! -f "$CONFIG_FILE_PATH/config" ]; then
    echo "File $CONFIG_FILE_PATH not found. Creating from template..."
    mkdir -p $CONFIG_FILE_PATH
    echo "BASE_URL=\"\"
  #VIDEO_PLAYER=\"mpv\" #default
  #FUZZY_FINDER=\"fzy\" #default
  #M3U_FILE=\"/tmp/ep_list.m3u\" #default" > $CONFIG_FILE_PATH/config
  fi
  . $CONFIG_FILE_PATH/config
  [ -z "${BASE_URL}" ] && echo "Error: BASE_URL is not set. Please set it in the configuration file at $HOME/.config/fzmedia/config" && exit 1
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


navigate_and_play () {
  local current_path="$1"
  while :; do
    # Present a fuzzy selection of directories or media files
    selection=$(indexfzy "$current_path/")
    [ -z "$selection" ] && exit
    new_path="$current_path/$selection"

    # Check if there are media files (video or music) in the directory
    media_files=$(wget -q -O - "$new_path/" \
      | grep -oP '(?<=href=")[^"]*' \
      | grep -iE '\.(mp4|mkv|avi|webm|flv|mov|wmv|m4v|mp3|flac|wav|aac|ogg|m4a)$')

    if [ -n "$media_files" ]; then
      # If there are media files, let the user select and play/build playlist
      EPISODE=$(echo "$media_files" | $FUZZY_FINDER)
      [ -z "$EPISODE" ] && exit
      plbuild "$new_path"
      $VIDEO_PLAYER "$M3U_FILE"
      rm -f "$M3U_FILE"
      break
    else
      # If no media files, navigate deeper into the selected directory
      current_path="$new_path"
    fi
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
