###################### Temp comments (for commands I used recently and want to remember ######################
# Might later turn these into their own Guides at the bottom

# Starting default network on virsh (used for VM's for example)
# sudo virsh net-start default

# Stopping default network on virsh. Pretty sure destroy is correct even though it sounds wrong
# sudo virsh net-destroy default


# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

export EDITOR=vim
export VISUAL=vim

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


####################### Imports
if [ -f ~/Main/Additional_Config/general_settings.sh ]; then
    . ~/Main/Additional_Config/general_settings.sh
fi
if [ -f ~/Main/Additional_Config/functions_and_aliases.sh ]; then
    . ~/Main/Additional_Config/functions_and_aliases.sh
fi
if [ -f ~/Main/Additional_Config/plugins.sh ]; then
    . ~/Main/Additional_Config/plugins.sh
fi
if [ -f ~/Main/Additional_Config/system_specific_bashrc_config.sh ]; then
    . ~/Main/Additional_Config/system_specific_bashrc_config.sh
fi
for f in ~/.config/bash/aliases.d/*.sh; do [ -f "$f" ] && . "$f"; done





################   Things that I am unsure if I keep   ################

################   Things that I am usure if I keep end   ################

# Alias definitions.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.


export PATH=/usr/local/node/bin:$PATH

export PATH="$PATH:~/bin"

export PATH="$PATH:$HOME/Main/Tools/decker"

PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
export PATH=$PATH:/sbin:/usr/sbin


