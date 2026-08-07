#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${PROJECT_DIR}" --target="${HOME}" --verbose --restow --no-folding)
run_brew=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--adopt] [--dry-run]

Installs OpenCode and its standalone configuration. Essential is the default;
--full currently installs the same package set.
EOF
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    # No distinct full profile yet; accepted only so the root installer can
    # pass --full uniformly across every component.
    --essential|--full) ;;
    --no-brew) run_brew=false ;;
    --adopt) STOW_FLAGS+=(--adopt) ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${dry_run}" == true ]]; then
  stow "${STOW_FLAGS[@]}" --simulate opencode || true
  echo "Would install packages from ${PROJECT_DIR}/Brewfile-essential"
  exit 0
fi
if [[ "${run_brew}" == true ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew is required." >&2; exit 1; }
  brew bundle --file="${PROJECT_DIR}/Brewfile-essential" --no-upgrade
fi
command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
stow "${STOW_FLAGS[@]}" opencode
echo "opencode installed. Run 'opencode-online setup' once for ChatGPT/Codex,"
echo "'opencode-online run' for hosted models, or 'opencode-local help' for local models."
