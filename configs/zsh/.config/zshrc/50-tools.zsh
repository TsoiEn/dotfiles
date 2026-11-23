# -----------------------------------------------------
# zoxide
# -----------------------------------------------------
export _ZO_ECHO=1                # print directory after jump
export _ZO_RESOLVE_SYMLINKS=1
export _ZO_DATA_DIR="$HOME/.local/share/zoxide"
eval "$(zoxide init zsh)"

# -----------------------------------------------------
# nvm
# -----------------------------------------------------
# Absent on Linux, and on a macOS box without the nvm formula.
[[ -r /opt/homebrew/opt/nvm/nvm.sh ]] && source /opt/homebrew/opt/nvm/nvm.sh
