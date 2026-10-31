# Zsh configuration

export EDITOR="nvim"

# Keep PATH entries unique so re-sourcing this file (the `src` alias) cannot
# append the same directory again.
typeset -U path PATH

# User binaries
export PATH="$HOME/.local/bin:$PATH"

# macOS-only: Homebrew, nvm and pnpm live under paths that do not exist on
# Linux, and sourcing them unguarded errors on every shell start.
if [[ "$OSTYPE" == darwin* ]]; then
    # Homebrew
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

    # nvm
    [[ -r /opt/homebrew/opt/nvm/nvm.sh ]] && source /opt/homebrew/opt/nvm/nvm.sh

    # pnpm
    export PNPM_HOME="$HOME/Library/pnpm"
    case ":$PATH:" in
      *":$PNPM_HOME/bin:"*) ;;
      *) export PATH="$PNPM_HOME/bin:$PATH" ;;
    esac
    # pnpm end
fi

ZSHRC_DIR="$HOME/.config/zshrc"

if [[ -d "$ZSHRC_DIR" ]]; then
    for file in "$ZSHRC_DIR"/*.zsh(N); do
        [[ -r "$file" ]] && source "$file"
    done

    if [[ -d "$ZSHRC_DIR/custom" ]]; then
        for file in "$ZSHRC_DIR/custom"/*.zsh(N); do
            [[ -r "$file" ]] && source "$file"
        done
    fi
fi
