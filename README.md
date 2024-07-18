install with `make install`

# how it works
Right now this is just a shitty shell script that can be installed with a make file

All it does is pass the file dirs (if they have a very specific file tree) to a fuzzy finder of your choice, then pass the output chosen from the fuzzy finder to a media player of your choice (rn it only works with from what I can tell)

`${HTTP_INDEX} -> ${FUZZY_FINDER} -> ${VIDEO_PLAYER}`

HTTP_INDEX: currently only works with my own private index. no default, needs to be set in config file

FUZZY_FINDER: confirmed working with `dmenu`, `fzy`, and `fzf`. defaults to `fzy`

VIDEO_PLAYER: currently only works with `mpv` but working on getting at least vlc to work. defaults to `mpv`

# TODO
- manually overide variables with a flag
- Work with any http index, not just my own
- Get VLC (and other media players) to work
- Clean up the code
- go back a dir
- Continue watching feature (remember what you have watched and and pick up where you left off)
