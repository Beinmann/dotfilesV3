#!/bin/bash
export LONG_FORMAT='${SYMB} ${VOL}%'
export AUDIO_HIGH_SYMBOL="<span font='FontAwesome'>"$'\uf028'"</span>"
export AUDIO_MED_SYMBOL="<span font='FontAwesome'>"$'\uf027'"</span>"
export AUDIO_LOW_SYMBOL="<span font='FontAwesome'>"$'\uf026'"</span>"
export AUDIO_MUTED_SYMBOL="<span font='FontAwesome'>"$'\uf026'$'\u20e0'"</span>"
exec "$HOME/.config/i3blocks/scripts/volume-pipewire/volume-pipewire" -S
