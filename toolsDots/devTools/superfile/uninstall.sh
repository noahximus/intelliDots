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
  stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate superfile
  [[ "${remove_brew}" == true ]] && echo "Would uninstall the superfile formula"
  exit 0
fi

command -v stow >/dev/null 2>&1 && stow --dir="${PROJECT_DIR}" --target="${HOME}" --delete superfile

if [[ "${remove_brew}" == true ]] && command -v brew >/dev/null 2>&1; then
  brew uninstall --formula --ignore-dependencies superfile
fi

echo "superfile configuration removed."
