export ZDOTDIR="${HOME}/.config/zsh"

if [[ -f "${ZDOTDIR}/.zshrc" ]]; then
  source "${ZDOTDIR}/.zshrc"
fi
export HOMEBREW_NO_INSTALL_CLEANUP=
