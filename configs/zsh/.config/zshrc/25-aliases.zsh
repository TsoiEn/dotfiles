# -----------------------------------------------------
# COMMON
# -----------------------------------------------------
alias ..='cd ..'
alias c='clear'
alias ls='eza -a --icons=always'
alias ll='eza -al --icons=always'
# alias lt='eza -a --tree --level=3 --icons=always'
alias lt='eza -a --tree --level=3 --icons=always --ignore-glob=".git|.venv|venv|__pycache__|node_modules|.pytest_cache|.mypy_cache|.ruff_cache|.next|.nuxt|dist|build|coverage|.DS_Store"'
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
# clone with the identity of the directory you're in (Personal vs Work), then
# cd into the new repo. The script runs in its own process and so cannot move
# this shell — it writes the directory it cloned into to $GCLONE_CD_FILE and we
# follow it here. `gclone --no-cd ...` stays put.
#
# The unalias + quoted name matter: this used to be a plain alias, and in zsh an
# alias both shadows a same-named function and is expanded while the function
# definition is parsed ("defining function based on alias"), so re-sourcing from
# a shell that still holds the old alias would fail without these two lines.
unalias gclone 2>/dev/null
'gclone'() {
    local cd_file dir rc    # not `status`: that name is read-only in zsh
    cd_file="$(mktemp -t gclone)" || return 1
    GCLONE_CD_FILE="$cd_file" ~/.config/myscripts/gclone.sh "$@"
    rc=$?
    dir="$(<"$cd_file")"
    rm -f -- "$cd_file"
    if (( rc == 0 )) && [[ -n "$dir" && -d "$dir" ]]; then
        builtin cd -- "$dir" || return
        (( $+commands[zoxide] )) && zoxide add "$dir"   # make it a z target
    fi
    return $rc
}
# git status for every repo under ~/Development at once
alias gstats='~/.config/myscripts/gstats.sh'


# -----------------------------------------------------
# Work
# -----------------------------------------------------
alias cps="~/Development/Work/frontend-monorepo/apps/app-e2e/scripts/run-e2e-staging.sh"
alias startwork='~/Development/setup.sh'

devstart() {
    git pull &&
    ./service.sh setup &&
    ./service.sh start &&
    ld
}
