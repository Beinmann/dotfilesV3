#!/usr/bin/env bash
# No strict mode: persistent block; pactl and the grep filter may fail while the
# sound server restarts, and the loop has to keep going.
# i3blocks mic block (persistent): shows a crossed-out microphone while the
# default source is muted, and nothing (block hidden) otherwise. Redrawn on
# every pulse/pipewire source event. Needs format=json and FontAwesome.
# JSON because i3blocks ignores an empty plain-text line in persist mode, so the
# block would keep showing the old icon; an empty "full_text" hides it.

# microphone-slash (U+F131) as UTF-8 bytes so output doesn't depend on locale.
icon="<span font='FontAwesome'>"$'\xef\x84\xb1'"</span>"

print_mic() {
    local mute
    mute=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null)
    if [[ $mute == *yes* ]]; then
        echo "{\"full_text\":\"$icon\",\"markup\":\"pango\",\"color\":\"#FB4934\"}"
    else
        echo '{"full_text":""}'
    fi
}

print_mic
pactl subscribe | stdbuf -oL grep -E "'change' on (source|server)" |
    while read -r _; do print_mic; done
