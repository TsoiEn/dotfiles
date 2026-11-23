# Zsh entrypoint: sources ~/.config/zshrc/*.zsh in order, then machine-local
# files. Put config in those files, not here.
#
#   00-init       env vars
#   10-path       PATH
#   20-shell      oh-my-zsh, prompt, fzf, history
#   30-aliases    aliases
#   40-functions  shell functions
#   50-tools      zoxide, nvm

ZSHRC_DIR="$HOME/.config/zshrc"

for file in "$ZSHRC_DIR"/*.zsh(N) "$ZSH_LOCAL"/*.zsh(N); do
    [[ -r "$file" ]] && source "$file"
done

# # >>> elio shell integration >>>
# elio() {
#     case "${1-}" in
#         shell|portal|-*)
#             command elio "$@"
#             return $?
#             ;;
#     esac
#
#     local arg tmp cwd status_code
#     for arg in "$@"; do
#         case "$arg" in
#             --chooser-file|--chooser-file=*)
#                 command elio "$@"
#                 return $?
#                 ;;
#         esac
#     done
#
#     tmp="$(mktemp -t "elio-cwd.XXXXXX")" || return
#     command elio --cwd-file "$tmp" "$@"
#     status_code=$?
#
#     if [ -s "$tmp" ]; then
#         cwd="$(cat -- "$tmp")"
#         rm -f -- "$tmp"
#         if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ]; then
#             cd -- "$cwd" || return $?
#         fi
#     else
#         rm -f -- "$tmp"
#     fi
#
#     return "$status_code"
# }
# # <<< elio shell integration <<<
