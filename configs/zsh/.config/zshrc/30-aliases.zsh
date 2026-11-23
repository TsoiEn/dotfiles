# -----------------------------------------------------
# Navigation & listing
# -----------------------------------------------------
alias ..='cd ..'
alias cd='z'        # zoxide
alias cdi='zi'      # zoxide, interactive
alias c='clear'
alias ls='eza -a --icons=always'
alias ll='eza -al --icons=always'
alias lt='eza -a --tree --level=3 --icons=always --ignore-glob=".git|.venv|venv|__pycache__|node_modules|.pytest_cache|.mypy_cache|.ruff_cache|.next|.nuxt|dist|build|coverage|.DS_Store"'

# -----------------------------------------------------
# Editor & shell
# -----------------------------------------------------
alias v='nvim .'
alias vim='$EDITOR'
alias src='source ~/.zshrc'

# -----------------------------------------------------
# Apps
# -----------------------------------------------------
alias ld='lazydocker'
alias lg='lazygit'
alias oc='opencode'
alias cj='claude'
alias ts='~/.config/tmuxScript/sessionizer.sh'

# -----------------------------------------------------
# System & scripts
# -----------------------------------------------------
alias shutdown='systemctl poweroff'
alias gstats='~/.config/myscripts/gstats.sh'    # git status for every repo under ~/Development
alias pkg='~/.config/myscripts/pkg.sh'          # which package manager installed this, and which can install it
alias update='~/.config/myscripts/update.sh'    # one clean Arch update (-n to preview)
alias jplanning='~/.config/myscripts/journal/journal.sh planning'   # journal templates into cwd
alias jtech='~/.config/myscripts/journal/journal.sh technical'
alias jnotes='~/.config/myscripts/journal/journal.sh notes'
alias jproj='~/.config/myscripts/journal/journal.sh project'
