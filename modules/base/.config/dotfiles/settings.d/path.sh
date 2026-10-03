# PATH additions; skips entries already present so re-sourcing is harmless.
# Machine-specific entries (node, local tool dirs) belong in
# ~/.config/dotfiles/system_local/bashrc.sh.

_dotfiles_path_append() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$PATH:$1" ;;
    esac
}

_dotfiles_path_append "$HOME/bin"
_dotfiles_path_append /sbin
_dotfiles_path_append /usr/sbin
export PATH
unset -f _dotfiles_path_append
