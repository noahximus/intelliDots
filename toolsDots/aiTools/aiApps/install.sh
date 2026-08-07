#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="${PROJECT_DIR}/Brewfile-essential"
run_brew=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--dry-run]

Installs the tracked AI desktop/CLI apps (ChatGPT, Claude, Claude Code, and
on --full, Gemini CLI and Antigravity) via Homebrew. No dotfile payload --
this component only manages the Brewfile.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --essential) BREWFILE="${PROJECT_DIR}/Brewfile-essential" ;;
    --full) BREWFILE="${PROJECT_DIR}/Brewfile" ;;
    --no-brew) run_brew=false ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${dry_run}" == true ]]; then
  [[ "${run_brew}" == true ]] && echo "Would install ${BREWFILE}"
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew is required." >&2; exit 1; }
  brew bundle --file="${BREWFILE}" --no-upgrade
fi

echo "aiApps installed."
