#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
remove_data=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --data) remove_data=true ;;
    -h|--help) echo "Usage: ./uninstall.sh [--dry-run] [--data]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

stow_args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete nvim)
[[ "${dry_run}" == true ]] && stow_args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate nvim)
command -v stow >/dev/null 2>&1 && stow "${stow_args[@]}"

if [[ "${remove_data}" == true ]]; then
  for path in "${XDG_DATA_HOME:-${HOME}/.local/share}/nvim" "${XDG_STATE_HOME:-${HOME}/.local/state}/nvim" "${XDG_CACHE_HOME:-${HOME}/.cache}/nvim"; do
    if [[ "${dry_run}" == true ]]; then echo "Would remove ${path}"; else rm -rf "${path}"; fi
  done
fi
echo "myNvim configuration removed."
