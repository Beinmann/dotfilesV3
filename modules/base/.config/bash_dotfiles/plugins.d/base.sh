#!/bin/sh

# Bashmarks
source ~/.local/bin/bashmarks.sh

q() {
  echo "$(p q)"
}

a() {
  echo "$(p a)"
}

y() {
  echo "$(p y)"
}

# Using ranger to select cwd
ranger_cd() {
    tempfile=$(mktemp)
    ranger --choosedir="$tempfile" "${@:-$(pwd)}" --cmd="set show_hidden true"
    if chosen_dir=$(cat "$tempfile"); then
        cd "$chosen_dir"
    fi
    rm -f "$tempfile"
}
