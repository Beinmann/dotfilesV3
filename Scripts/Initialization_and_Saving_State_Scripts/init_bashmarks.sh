if [ ! -f "$HOME/.sdirs" ]; then
    cat > "$HOME/.sdirs" << 'EOF'
export DIR_main="$HOME/Main"
export DIR_downloads="$HOME/Downloads"
export DIR_tools="$HOME/Main/Tools"
export DIR_dotfiles="$HOME/Main/dotfilesV3"
export DIR_nvim="$HOME/Main/dotfilesV3/modules/nvim/.config/nvim"
EOF
fi
