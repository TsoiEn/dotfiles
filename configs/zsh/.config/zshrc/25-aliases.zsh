# -----------------------------------------------------
# COMMON
# -----------------------------------------------------
alias ..='cd ..'
alias c='clear'
alias ls='eza -a --icons=always'
alias ll='eza -al --icons=always'
alias lt='eza -a --tree --level=3 --icons=always'
alias shutdown='systemctl poweroff'
alias v='nvim .'
alias vim='$EDITOR'


# -----------------------------------------------------
# ZOXIDE
# -----------------------------------------------------
# zoxide initialization
eval "$(zoxide init zsh)"

# aliases
alias cd="z"        # replace cd with zoxide
alias cdi="zi"      # interactive selection

# optional settings
export _ZO_ECHO=1          # print directory after jump
export _ZO_RESOLVE_SYMLINKS=1
export _ZO_DATA_DIR="$HOME/.local/share/zoxide"

# completions (optional)
autoload -Uz compinit
compinit

# -----------------------------------------------------
# MyAliases
# -----------------------------------------------------
alias ld='lazydocker'
alias lg='lazygit'
alias ts='~/.config/tmuxScript/sessionizer.sh'
alias oc='opencode'
alias src='source ~/.zshrc'


# -----------------------------------------------------
# Work
# -----------------------------------------------------
alias cps="~/Development/Work/frontend-monorepo/apps/app-e2e/scripts/run-e2e-staging.sh"
