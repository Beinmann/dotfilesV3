#!/bin/bash
[ "$BLOCK_BUTTON" = "1" ] && "$HOME/.config/i3/scripts/show_sysinfo.sh" &

mod_key=$(grep -m1 '^set \$mod ' "$HOME/.config/i3/config" | awk '{print $3}')
case "$mod_key" in
    Mod4) mod_display="Win" ;;
    Mod1) mod_display="Alt" ;;
    *)    mod_display="$mod_key" ;;
esac

echo "<span font='FontAwesome'>"$'\uf05a'"</span> ${mod_display}+i"
