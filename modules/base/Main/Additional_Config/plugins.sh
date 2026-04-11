#!/bin/sh

# Cargo (I think for rust, but I might be wrong)
# . "$HOME/.cargo/env"

# GHCup (Haskell)
[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env" # ghcup-env

# Add adb to path as well as other android studio tools
export PATH=$HOME/Android/Sdk/platform-tools:$PATH

# Bashmarks
source ~/.local/bin/bashmarks.sh
# Treat some bashmarks as if they were local variables

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
    # python $HOME/Main/Tools/ranger/ranger.py --choosedir="$tempfile" "${@:-$(pwd)}"
    ranger --choosedir="$tempfile" "${@:-$(pwd)}" --cmd="set show_hidden true"
    if chosen_dir=$(cat "$tempfile"); then
        cd "$chosen_dir"
    fi
    rm -f "$tempfile"
}

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"


#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
# I moved this into plugins.sh so this might have broken this thing. But I don't even really know what sdkman is
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"


### Zoxide
# eval "$(zoxide init --cmd cd bash)"
