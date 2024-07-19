#!/bin/sh

# disallow root
if [ "`id -u`" -eq 0 ]; then \
	echo "Do not run this script as root. Aborting."; \
	exit 1; \
fi

# defaults
: "${VIDEO_PLAYER:=mpv}"
: "${FUZZY_FINDER:=fzy}"
: "${M3U_FILE:=/tmp/filelist.m3u}"

sourceconf () {
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
  ESCAPED_EP=$(printf '%s\n' "$EPISODE" | sed 's/[\/&]/\\&/g')
  echo "#EXTM3U" > "$M3U_FILE"
  URL_PATH=${1#$BASE_URL/}
  for i in $(wget -q -O - "$1" | grep -oP '(?<=href=")[^"]*' | grep mkv)
  do
    echo "#EXTINF:-1," >> "$M3U_FILE"
    ENCODED=$(echo "$URL_PATH$i" | python3 -c "import sys, urllib.parse as ul; print('\n'.join(ul.quote(ul.unquote(line.strip()), safe='/') for line in sys.stdin))")
    echo $BASE_URL/$ENCODED >> "$M3U_FILE"
  done
}

main () {
  sourceconf

  LIBRARY="$(echo "movies\ntv\nanime" | $FUZZY_FINDER)"
  [ -z "$LIBRARY" ] && exit 

  case $LIBRARY in

    movies)
      DIR=$(indexfzy $BASE_URL/$LIBRARY/)
      [ -z "$DIR" ] && exit
      VIDEO_PATH="$BASE_URL/$LIBRARY/$DIR/$(wget -q -O - "$BASE_URL/$LIBRARY/$DIR" | grep -oP '(?<=href=")[^"]*' | grep mkv)"
      $VIDEO_PLAYER "$VIDEO_PATH"
    ;;
    
    tv | anime)
      SHOW=$(indexfzy "$BASE_URL/$LIBRARY/" | tr -d '\n' | sed 's/.$//')
      [ -z "$SHOW" ] && exit
      wget -q -O - "$BASE_URL/$LIBRARY/$SHOW/" | grep -oP '(?<=href=")[^"]*' | grep -q mkv
      if [ $? = 0 ]; then
        #ONLY ONE SEASON
        EPISODE=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW/" | tr -d '\n' | grep mkv)
        [ -z "$EPISODE" ] && exit
        plbuild "$BASE_URL/$LIBRARY/$SHOW/"
        $VIDEO_PLAYER $M3U_FILE
        rm -rf $M3U_FILE
      else
        #MULTIPLE SEASONS
        SEASON=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW/" | tr -d '\n')
        [ -z "$SEASON" ] && exit
        EPISODE=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW/$SEASON" | tr -d '\n' | grep mkv)
        [ -z "$EPISODE" ] && exit
        plbuild "$BASE_URL/$LIBRARY/$SHOW/$SEASON"
        $VIDEO_PLAYER $M3U_FILE
        rm -rf $M3U_FILE
      fi
    ;;

  esac

}

main
