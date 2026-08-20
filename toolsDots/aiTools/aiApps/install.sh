#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run_brew=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--dry-run]

Installs the tracked AI desktop/CLI apps (ChatGPT, Claude, Claude Code, and
on --full, Gemini CLI and Antigravity) via Homebrew. No dotfile payload --
this component manages no packages of its own; they live in tiers/.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --essential) ;;
    --full) ;;
    --no-brew) run_brew=false ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${dry_run}" == true ]]; then
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  echo "Note: this component no longer installs its own packages." >&2
  echo "      Run the repository's root install.sh to install from tiers/." >&2
fi

echo "aiApps installed."
