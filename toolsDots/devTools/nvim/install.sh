#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="${PROJECT_DIR}/Brewfile-essential"
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${PROJECT_DIR}" --target="${HOME}" --verbose --restow --no-folding)
run_brew=true
sync_plugins=true
install_codex_acp=true
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--no-sync] [--no-codex-acp] [--adopt] [--dry-run]

Installs the Neovim/LazyVim configuration. Essential packages are the default.
The full set additionally installs Pandoc. Codex ACP is installed by default
for online Codex access from CodeCompanion.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --essential) BREWFILE="${PROJECT_DIR}/Brewfile-essential" ;;
    --full) BREWFILE="${PROJECT_DIR}/Brewfile-full" ;;
    --no-brew) run_brew=false ;;
    --no-sync) sync_plugins=false ;;
    --no-codex-acp) install_codex_acp=false ;;
    --adopt) STOW_FLAGS+=(--adopt) ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# codex-acp is npm-distributed, not Homebrew-distributed, so it needs its
# own install path separate from the Brewfile.
ensure_codex_acp() {
  if command -v codex-acp >/dev/null 2>&1; then
    echo "codex-acp is already installed: $(command -v codex-acp)"
    return 0
  fi
  command -v npm >/dev/null 2>&1 || {
    echo "npm is required to install @agentclientprotocol/codex-acp." >&2
    return 1
  }
  echo "Installing Codex ACP for CodeCompanion..."
  npm install --global @agentclientprotocol/codex-acp
  command -v codex-acp >/dev/null 2>&1 || {
    echo "codex-acp was installed but is not on PATH. Open a new terminal and retry." >&2
    return 1
  }
  codex-acp --version
}

if [[ "${dry_run}" == true ]]; then
  stow "${STOW_FLAGS[@]}" --simulate nvim || true
  echo "Would install packages from ${BREWFILE} and synchronize LazyVim plugins"
  [[ "${install_codex_acp}" == true ]] && echo "Would install @agentclientprotocol/codex-acp with npm when missing"
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew is required." >&2; exit 1; }
  brew bundle --file="${BREWFILE}" --no-upgrade
fi

if [[ "${install_codex_acp}" == true ]]; then
  ensure_codex_acp
fi

command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
stow "${STOW_FLAGS[@]}" nvim
if [[ "${sync_plugins}" == true ]]; then
  # Headless-launches Neovim so lazy.nvim can resolve and install plugins
  # before the user ever opens an interactive session.
  "${PROJECT_DIR}/scripts/install-nvim.sh"
fi
echo "nvim installed. Use ':AIProviderUse codex' in Neovim for online Codex."
