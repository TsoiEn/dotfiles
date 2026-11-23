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
# Starship prompt
# -----------------------------------------------------
# Runs after oh-my-zsh so it overrides $ZSH_THEME; the theme above stays as the
# fallback on a box where starship is not installed yet.
(( $+commands[starship] )) && eval "$(starship init zsh)"

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
