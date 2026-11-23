# -----------------------------------------------------
# PATH
# -----------------------------------------------------
typeset -U path    # drop duplicate entries

# Homebrew (macOS)
path=(/opt/homebrew/bin /opt/homebrew/sbin $path)

# User binaries
path=($HOME/.local/bin $path)

# bun
export BUN_INSTALL="$HOME/.bun"
path=($BUN_INSTALL/bin $path)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"    # completions

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
[[ "$OSTYPE" == darwin* ]] && export PNPM_HOME="$HOME/Library/pnpm"
path=($PNPM_HOME/bin $path)

# maestro
path+=($HOME/.maestro/bin)
