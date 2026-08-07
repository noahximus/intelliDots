#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
remove_brew=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --brew) remove_brew=true ;;
    -h|--help) echo "Usage: ./uninstall.sh [--dry-run] [--brew]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "${dry_run}" == true ]]; then
  stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate iterm2
  echo "Would reset iTerm2 custom preference-folder defaults"
  [[ "${remove_brew}" == true ]] && echo "Would uninstall the iterm2 cask"
  exit 0
fi

command -v stow >/dev/null 2>&1 && stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete iterm2
defaults delete com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true
defaults delete com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || true
if [[ "${remove_brew}" == true ]] && command -v brew >/dev/null 2>&1; then
  brew uninstall --cask iterm2
fi
echo "myITerm configuration removed."
