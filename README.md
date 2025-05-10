install with `sudo make install`

ebuild and apt repository coming soon tm

# how it works
Just a shitty shell script that can be installed with a make file

All it does is pass the file dirs (if they have a very specific file tree) to a fuzzy finder of your choice, then pass the output chosen from the fuzzy finder to a media player of your choice

`${HTTP_INDEX} -> ${FUZZY_FINDER} -> ${VIDEO_PLAYER}`

HTTP_INDEX: no default, needs to be set in config file or with -u flag {value}

FUZZY_FINDER: confirmed working with `dmenu`, `fzy`, and `fzf`. defaults to `fzy`. it just passes stdin to another app so it should work with whatever fuxxy finder you like

VIDEO_PLAYER: currently only works with `mpv` but working on getting at least vlc to work. defaults to `mpv`

# TODO
I am a devops engineer so ofc I am going to overengineer the ci/cd for a stupid little shell script
- Get VLC (and other media players) to work
- ensure works with different shells and envs
- Continue watching feature (remember what you have watched and and pick up where you left off)
- gentoo ebuild
- selfhosted apt repository for debian and ubuntu
