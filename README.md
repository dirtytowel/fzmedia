Just a shitty shell script to navigate file trees, play media files, and continue watching where you left off later. It is just fun to tinker with sometimes and does what I want it to, and when it doesn't it's simple enough to fix. meant to be hackable, flexible, and minimal "replacement" for tools like plex for remote http indexes and local directories

# how to install

install with `sudo make install`

uninstall with `sudo make uninstall`

ebuild and apt repository coming soon tm

# how it works

All it does is pass the file dirs from a http index or local dir to a fuzzy finder of your choice, then pass the output chosen from the fuzzy finder to a media player of your choice

`${DIRECTORY} -> ${FUZZY_FINDER} -> ${VIDEO_PLAYER}`

DIRECTORY: no default, needs to be set in config file or with -u {dir/url}

FUZZY_FINDER: confirmed working with `dmenu`, `fzy`, and `fzf`. defaults to `fzy`. it just passes stdin to another app so it should work with whatever fuzzy finder you like.

VIDEO_PLAYER: works with both mpv and vlc from my testing, though continue watching for m3u files works better with mpv. There is also an additional var that can be set for the resume player.

the only thing this tool actually does is glue these preferences together.

# how to use/configure and random comments

A config file at `~/.config/{user}/fzmedia/config` is created if the script is run and does not have a config file. I wrote it in a way that will add new commented out values if more config options are added later or if a variable name changed.

```
# Where are we looking for media files? works with urls and local directories. This has to be set to something or you can just pass the -u flag.
# the tool is kinda useless if you don't have a dir or http index you want to point to. 
BASE_URL="/path/to/file or http://example.com"

# the default video player when playing a file when not under the continue
# watching header. the mpv flags for this allow for saving the current position
# to mpvs watch_later dir located at `~/.local/state/mpv`
VIDEO_PLAYER="mpv --save-position-on-quit --no-resume-playback" #default

# the video player when resuming something that was saved to the continue_watching cache
# the --no-resume-playback flag mpv flag is removed so that it does not restart your saved progress
# it is worth noting that if you use vlc there are no such flags so they should both VIDEO_PLAYER and RESUME_PLAYER should be "vlc"
# though vlc isn't very good for the continue watching feature when using m3u files which is what the the RESUME_PLAYER and VIDEO_PLAYER actually attempt to play
# (there could be some sort of addon for vlc that adds something similar to the feature that mpv has but I am unaware of one if it exists), 
RESUME_PLAYER="mpv --save-position-on-quit" #default

# any fuzzy finder will do here. It is important to note there are two real types of fuzzy finders: basic fuzzy finders, and menu tools like dmenu/rofi
# I have made the tool so that it works with both, at the caveat of not being able to give yes/no prompts or other script abilities like renaming the m3u's saved
# in the cache dir. Though I think the flexability of being able to use any type of fuzzy finder that accepts stdin more than makes up for this caveat.
FUZZY_FINDER="fzy" #default

# /tmp should be a ramdisk. The m3u file just has path/url reference(s), it's deleted after you close the video player
# if there are muliple playable files in a directory it will contain all of them, if it is a single one it will only add that single file to the m3u file
M3U_FILE="/tmp/fzmedia.m3u" #default

# after you play a file you will be prompted on whether you would like to add the current m3u file to your continue watching queue
# it just copies the `/tmp/fzmedia.m3u` to this cache dir as the filename you originally played
# it looks kinda ugly if it's an episode bc it will be called the episode number you left off on but naming conventions for this can
# vary wildly so if you want a better name you can just navigate to this directory and rename the m3u file and it will still remember where you left off. unfortunately
# you can not pass a name as a value into a fuzzy finder, you can only pick from a list you passed to it from stdin. a menu tool such as `dmenu` or `rofi` would solve this problem, though
# it would be important to not break basic fuzzy finder functionality
CACHE_DIR="~/.cache/fzmedia" #default

# fuzzy finders will default to the order they are given, this is usually some type of alpha-numeric order. If you have a prefered order you want these to show up in then change this value
# the current syntax is important
PREFERRED_ORDER="movies/,tv/,anime/,music/" #default
```

after the tool is installed in your $PATH you can call it with `fzmedia`. you can also pass the `-h` flag to print this help text to the terminal:

```
Usage: fzmedia [-u BASE_URL] [-p VIDEO_PLAYER] [-f FUZZY_FINDER] [-m M3U_FILE]

  -u  HTTP index root        (overrides BASE_URL in config)
  -p  video player command   (overrides VIDEO_PLAYER)
  -r  resume player command  (overrides RESUME_PLAYER)
  -f  fuzzy-finder command   (overrides FUZZY_FINDER)
  -m  path to m3u file       (overrides M3U_FILE)
  -h  this help
```

For example you could have the keybind `mod + f` set to `fzmedia -f "dmenu -S -i -l 10"` so that it opens in dmenu on the keybind. This gives the flexibility for when you want to use the tool in the terminal with a fuzzy finder such as `fzf` or `fzy`. You could have shows saved locally and not on my http index or want to use a different http index so you can override the default with `-u /path/to/dir` or `-u https://user:password@example.com`.

# TODO
- gentoo ebuild
- selfhosted apt repository for debian and ubuntu
- rename vars, flags, and config file vars so that they are more accurate, breaking change though so would probably be a major update for semver.
- maybe an config file option and flag to specify whether you are using a menu or plain fuzzy finder. this could really level up the "UI" capabilities, such as renaming Continue watching m3u files or cleaner prompts, though I don't want to break compat with plain fuzzy finders
- maybe ssh as a supported source? could be nice.
