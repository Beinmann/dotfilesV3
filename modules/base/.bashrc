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

PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
