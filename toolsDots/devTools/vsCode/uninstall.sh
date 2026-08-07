#!/usr/bin/env bash
set -euo pipefail

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
  [[ "${remove_brew}" == true ]] && echo "Would uninstall the visual-studio-code cask"
  echo "Installed extensions are left in place; remove them individually if desired."
  exit 0
fi

if [[ "${remove_brew}" == true ]] && command -v brew >/dev/null 2>&1; then
  brew uninstall --cask visual-studio-code
fi
echo "vsCode configuration removed. Installed extensions were left in place."
