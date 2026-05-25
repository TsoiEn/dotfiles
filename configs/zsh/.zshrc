# Zsh configuration

export EDITOR="nvim"

# Add custom bin to PATH
export PATH="$HOME/.local/bin:$PATH"

ZSHRC_DIR="$HOME/.config/zshrc"

if [ -d "$ZSHRC_DIR" ]; then
	for file in "$ZSHRC_DIR"/*.zsh; do
		[ -r "$file" ] && . "$file"
	done

	if [ -d "$ZSHRC_DIR/custom" ]; then
		for file in "$ZSHRC_DIR/custom"/*.zsh; do
			[ -r "$file" ] && . "$file"
		done
	fi
fi
