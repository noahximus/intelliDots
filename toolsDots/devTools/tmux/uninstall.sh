#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
remove_brew=false
remove_data=false

TPM_DIR="${HOME}/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

usage() {
  echo "Usage: ./uninstall.sh [--dry-run] [--brew] [--data]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --brew) remove_brew=true ;;
    --data) remove_data=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

remove_tpm() {
  [[ -d "${TPM_DIR}/.git" ]] || return 0
  local origin
  origin="$(git -C "${TPM_DIR}" config --get remote.origin.url || true)"
  case "${origin}" in
    "${TPM_REPO}"|"${TPM_REPO}.git")
      if [[ "${dry_run}" == true ]]; then
        echo "Would remove ${TPM_DIR}"
      else
        rm -rf "${TPM_DIR}"
      fi
      ;;
    *)
      echo "Skipping ${TPM_DIR}; Git origin does not match ${TPM_REPO}." >&2
      ;;
  esac
}

if [[ "${dry_run}" == true ]]; then
  stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate tmux
  [[ "${remove_data}" == true ]] && {
    echo "Would remove ${HOME}/.config/tmux/theme.conf"
    remove_tpm
    echo "Would remove ${HOME}/.tmux/plugins and ${HOME}/.tmux if empty"
  }
  [[ "${remove_brew}" == true ]] && echo "Would uninstall the tmux formula"
  exit 0
fi

command -v stow >/dev/null 2>&1 && stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete tmux

if [[ "${remove_data}" == true ]]; then
  rm -f "${HOME}/.config/tmux/theme.conf"
  remove_tpm
  rmdir "${HOME}/.tmux/plugins" 2>/dev/null || true
  rmdir "${HOME}/.tmux" 2>/dev/null || true
fi

if [[ "${remove_brew}" == true ]] && command -v brew >/dev/null 2>&1; then
  brew uninstall --formula --ignore-dependencies tmux
fi

echo "tmux configuration removed."
