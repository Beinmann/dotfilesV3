#!/bin/sh
. "$HOME/Main/Scripts/Helper_Scripts/wallpaper.sh"

tmp=$(mktemp /tmp/lockimg.XXXXXX.png) || exit 1

if [ -f "$WALLPAPER" ] && convert "$WALLPAPER" -resize 1920x1080^ -gravity center -extent 1920x1080 "$tmp"; then
    i3lock --nofork -i "$tmp"
else
    i3lock --nofork -c "$FALLBACK_COLOR"
fi

rm -f "$tmp"
