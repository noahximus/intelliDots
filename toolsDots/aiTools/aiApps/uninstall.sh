#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="${PROJECT_DIR}/Brewfile-essential"
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [--essential] [--full] [--dry-run]

Uninstalls the Homebrew casks/formulae listed in the selected Brewfile.
--essential (default) only removes ChatGPT, Claude, and Claude Code, leaving
Gemini CLI/Antigravity in place even if they were installed via --full.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --essential) BREWFILE="${PROJECT_DIR}/Brewfile-essential" ;;
    --full) BREWFILE="${PROJECT_DIR}/Brewfile" ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -f "${BREWFILE}" ]] || { echo "Brewfile not found: ${BREWFILE}" >&2; exit 1; }

read_brewfile_items() {
  local kind="$1"
  sed -nE "s/^[[:space:]]*${kind} \"([^\"]+)\".*/\1/p" "${BREWFILE}"
}

if [[ "${dry_run}" == false ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew is not available; nothing to uninstall." >&2; exit 0; }
fi

while IFS= read -r cask; do
  [[ -n "${cask}" ]] || continue
  if [[ "${dry_run}" == true ]]; then
    echo "Would uninstall cask: ${cask}"
  elif brew list --cask "${cask}" >/dev/null 2>&1; then
    brew uninstall --cask "${cask}"
  fi
done < <(read_brewfile_items cask)

while IFS= read -r formula; do
  [[ -n "${formula}" ]] || continue
  if [[ "${dry_run}" == true ]]; then
    echo "Would uninstall formula: ${formula}"
  elif brew list --formula "${formula}" >/dev/null 2>&1; then
    brew uninstall --formula --ignore-dependencies "${formula}"
  fi
done < <(read_brewfile_items brew)

echo "aiApps configuration removed."
