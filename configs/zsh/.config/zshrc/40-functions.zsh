# -----------------------------------------------------
# Yazi: cd to wherever yazi was left
# -----------------------------------------------------
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# -----------------------------------------------------
# Elio: cd to wherever elio was left
# -----------------------------------------------------
function e() {
	local tmp="$(mktemp -t "elio-cwd.XXXXXX")" cwd
	command elio "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# -----------------------------------------------------
# gclone: clone a repo and cd into it
# -----------------------------------------------------
unalias gclone 2>/dev/null
gclone() {
    local cd_file dir rc    # not `status`: that name is read-only in zsh
    cd_file="$(mktemp "${TMPDIR:-/tmp}/gclone.XXXXXX")" || return 1
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

# -----------------------------------------------------
# Ctrl-O: open nvim in the current directory from the prompt
# -----------------------------------------------------
function _nvim_here() { BUFFER="nvim ."; zle accept-line }
zle -N _nvim_here
bindkey '^o' _nvim_here
