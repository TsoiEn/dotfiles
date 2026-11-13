# Zsh configuration

export EDITOR="nvim"

# Homebrew
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# User binaries
export PATH="$HOME/.local/bin:$PATH"

ZSHRC_DIR="$HOME/.config/zshrc"

if [[ -d "$ZSHRC_DIR" ]]; then
    for file in "$ZSHRC_DIR"/*.zsh(N); do
        [[ -r "$file" ]] && source "$file"
    done

    if [[ -d "$ZSH_LOCAL" ]]; then
        for file in "$ZSH_LOCAL"/*.zsh(N); do
            [[ -r "$file" ]] && source "$file"
        done
    fi
fi

# Absent on Linux, and on a macOS box without the nvm formula.
[[ -r /opt/homebrew/opt/nvm/nvm.sh ]] && source /opt/homebrew/opt/nvm/nvm.sh

# pnpm
export PNPM_HOME="/Users/Aaron/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
export PATH=$PATH:$HOME/.maestro/bin
