#!/bin/bash
export LONG_FORMAT='${SYMB} ${VOL}%'
export AUDIO_HIGH_SYMBOL="<span font='FontAwesome'></span>"
export AUDIO_MED_SYMBOL="<span font='FontAwesome'></span>"
export AUDIO_LOW_SYMBOL="<span font='FontAwesome'></span>"
export AUDIO_MUTED_SYMBOL="<span font='FontAwesome'></span>"
exec "$HOME/.config/i3blocks/scripts/volume-pipewire/volume-pipewire" -S
