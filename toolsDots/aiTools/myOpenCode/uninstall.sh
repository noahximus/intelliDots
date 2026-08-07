#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { echo "Usage: ./uninstall.sh [--dry-run]"; exit 0; }
args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete opencode)
[[ "${dry_run}" == true ]] && args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate opencode)
command -v stow >/dev/null 2>&1 && stow "${args[@]}"
echo "myOpenCode configuration removed."
