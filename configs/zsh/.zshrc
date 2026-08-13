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

    if [[ -d "$ZSHRC_DIR/custom" ]]; then
        for file in "$ZSHRC_DIR/custom"/*.zsh(N); do
            [[ -r "$file" ]] && source "$file"
        done
    fi
fi

# Comment this if you're using linux
source /opt/homebrew/opt/nvm/nvm.sh
