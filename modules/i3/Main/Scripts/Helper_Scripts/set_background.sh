#!/bin/sh
. "$HOME/Main/Scripts/Helper_Scripts/wallpaper.sh"

if [ -f "$WALLPAPER" ]; then
    feh --bg-fill "$WALLPAPER"
else
    xsetroot -solid "#$FALLBACK_COLOR"
fi
