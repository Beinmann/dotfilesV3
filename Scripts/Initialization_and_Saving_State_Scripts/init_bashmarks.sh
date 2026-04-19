if [ ! -f "$HOME/.sdirs" ]; then
    cat > "$HOME/.sdirs" << 'EOF'
export DIR_main="$HOME/Main"
export DIR_downloads="$HOME/Downloads"
export DIR_tools="$HOME/Main/Tools"
export DIR_dotfiles="$HOME/Main/dotfilesV3"
export DIR_nvim="$HOME/Main/dotfilesV3/modules/nvim/.config/nvim"
export DIR_scripts="$HOME/Main/Scripts"
export DIR_config="$HOME/.config"
export DIR_i3="$HOME/.config/i3"
export DIR_logs="/var/log"
export DIR_applications="/usr/share/applications"
EOF
fi
