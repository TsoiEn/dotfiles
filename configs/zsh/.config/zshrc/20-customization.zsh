# -----------------------------------------------------
# oh-my-zsh
# sonicradish
# -----------------------------------------------------
ZSH_THEME="sonicradish"

plugins=(
    git
    sudo
    web-search
    zsh-autosuggestions
    fast-syntax-highlighting
    copyfile
    copybuffer
    dirhistory
)

# zsh-syntax-highlighting is deliberately absent: it and
# fast-syntax-highlighting both wrap ZLE's highlighting hooks, so loading both
# highlighted every line twice. Swap the two names here to go back.

# archlinux only wraps pacman/yay, which do not exist on macOS.
[[ "$OSTYPE" == linux* ]] && plugins+=(archlinux)

# Guarded so a machine that has not run bootstrap.sh yet still gets a shell.
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# -----------------------------------------------------
# FZF
# -----------------------------------------------------
if (( $+commands[fzf] )); then
    source <(fzf --zsh)
fi

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
