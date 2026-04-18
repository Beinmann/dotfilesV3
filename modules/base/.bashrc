# ~/.bashrc: executed by bash(1) for non-login shells.

export EDITOR=vim
export VISUAL=vim

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


####################### Imports
for f in ~/.config/bash_dotfiles/settings.d/*.sh; do [ -f "$f" ] && . "$f"; done
for f in ~/.config/bash_dotfiles/aliases.d/*.sh; do [ -f "$f" ] && . "$f"; done
for f in ~/.config/bash_dotfiles/functions.d/*.sh; do [ -f "$f" ] && . "$f"; done
for f in ~/.config/bash_dotfiles/plugins.d/*.sh; do [ -f "$f" ] && . "$f"; done

if [ -f ~/Main/Additional_Config/system_specific_bashrc_config.sh ]; then
    . ~/Main/Additional_Config/system_specific_bashrc_config.sh
fi


####################### PATH
export PATH=/usr/local/node/bin:$PATH
export PATH="$PATH:~/bin"
export PATH="$PATH:$HOME/Main/Tools/decker"
export PATH=$PATH:/sbin:/usr/sbin
