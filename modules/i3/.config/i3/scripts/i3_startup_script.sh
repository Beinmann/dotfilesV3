#!/bin/bash

if [ -f "$HOME/.config/dotfiles/system_local/monitors.sh" ]; then
    . "$HOME/.config/dotfiles/system_local/monitors.sh"
fi

autokey-gtk &

source $HOME/.xinitrc

# firefox &

tilix -e bash -c "tmux a || tmux" &

setxkbmap -layout custom -variant basiccustom -print | xkbcomp -I$HOME/.config/xkb -xkm - :0

xbindkeys

flatpak run org.mozilla.firefox &
flatpak run md.obsidian.Obsidian &
flatpak run com.bitwarden.desktop &
nm-applet &

# [ -n "$DISPLAY" ]                     && tmux set-environment -g DISPLAY "$DISPLAY"
# [ -n "$WAYLAND_DISPLAY" ]            && tmux set-environment -g WAYLAND_DISPLAY "$WAYLAND_DISPLAY"
# [ -n "$XDG_SESSION_TYPE" ]           && tmux set-environment -g XDG_SESSION_TYPE "$XDG_SESSION_TYPE"
# [ -n "$DBUS_SESSION_BUS_ADDRESS" ]   && tmux set-environment -g DBUS_SESSION_BUS_ADDRESS "$DBUS_SESSION_BUS_ADDRESS"
# exec /usr/bin/tmux "$@"

# ~/Main/Scripts/Startup_Script/i3_window_change_subscriber.sh &

# seperate Super key from hyper key by making hyper key be mod3 instead of mod4
# this is important because I remapped my RAlt to be the hyper key instead
# and on i3 suddenly some key combinations overlap with the super key
# xmodmap -e "remove mod4 = Hyper_L"
# xmodmap -e "add mod3 = Hyper_L"
