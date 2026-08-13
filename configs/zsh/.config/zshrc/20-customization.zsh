# -----------------------------------------------------
# oh-my-zsh
# -----------------------------------------------------
ZSH_THEME="robbyrussell"

plugins=(
    git
    sudo
    web-search
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    copyfile
    copybuffer
    dirhistory
)

source "$ZSH/oh-my-zsh.sh"

# -----------------------------------------------------
# FZF
# -----------------------------------------------------
source <(fzf --zsh)

# -----------------------------------------------------
# History
# -----------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt appendhistory


# -----------------------------------------------------
# Yazi
# -----------------------------------------------------
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

