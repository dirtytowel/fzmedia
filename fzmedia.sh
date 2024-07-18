#!/bin/sh
. ~/.config/fzmedia/config
[ -z "${BASE_URL}" ] && echo "Error: BASE_URL is not set. Please set it in the configuration file at $HOME/.config/fzmedia/config" && exit 1

# defaults
: "${VIDEO_PLAYER:=mpv}"
: "${FUZZY_FINDER:=fzy}"
: "${M3U_FILE:=/tmp/ep_list.m3u}"

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
  for i in $(wget -q -O - "$1" | grep -oP '(?<=href=")[^"]*' | grep mkv)
  do
    echo "#EXTINF:-1," >> "$M3U_FILE"
    echo "$1$i" >> "$M3U_FILE"
  done
  sed "0,/$ESCAPED_EP/{//!d;}" "$M3U_FILE" > "$M3U_FILE.tmp" && mv "$M3U_FILE.tmp" "$M3U_FILE"
}

main () {

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
      SHOW=$(indexfzy "$BASE_URL/$LIBRARY/" | tr -d '\n' )
      [ -z "$SHOW" ] && exit
      wget -q -O - "$BASE_URL/$LIBRARY/$SHOW" | grep -oP '(?<=href=")[^"]*' | grep -q mkv
      if [ $? = 0 ]; then
        #ONLY ONE SEASON
        EPISODE=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW" | tr -d '\n' | grep mkv)
        [ -z "$EPISODE" ] && exit
        plbuild "$BASE_URL/$LIBRARY/$SHOW"
        $VIDEO_PLAYER $M3U_FILE
        rm -rf $M3U_FILE
      else
        #MULTIPLE SEASONS
        SEASON=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW/" | tr -d '\n' )
        [ -z "$SEASON" ] && exit
        EPISODE=$(indexfzy "$BASE_URL/$LIBRARY/$SHOW/$SEASON/" | tr -d '\n' | grep mkv)
        [ -z "$EPISODE" ] && exit
        plbuild "$BASE_URL/$LIBRARY/$SHOW/$SEASON"
        $VIDEO_PLAYER $M3U_FILE
        rm -rf $M3U_FILE
      fi
    ;;

  esac

}

main
