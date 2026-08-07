#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/progress.sh
. "${SCRIPT_DIR}/lib/progress.sh"
trap 'ui_fail "Neovim plugin installation failed"' ERR

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-"${HOME}/.cache"}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-"${HOME}/.local/share"}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-"${HOME}/.local/state"}"

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim is not installed. Install the Brewfile first, then rerun this script." >&2
  exit 1
fi

ui_init 2 "Neovim plugin installation"
ui_stage "Synchronizing plugins to the locked versions"
nvim --headless "+Lazy! sync" +qa
ui_done "Neovim plugins match lazy-lock.json"

markdown_preview_dir="${XDG_DATA_HOME}/nvim/lazy/markdown-preview.nvim"
ui_stage "Checking the Markdown Preview binary"
if [[ -d "${markdown_preview_dir}" ]]; then
  ui_info "Running the plugin's version-aware binary installer"
  nvim --headless \
    "+Lazy load markdown-preview.nvim" \
    "+lua vim.fn['mkdp#util#install_sync'](true)" \
    +qa
  ui_done "Markdown Preview binary is current"
else
  ui_warn "markdown-preview.nvim is not installed; open nvim once and rerun this script if needed"
fi

ui_complete "Neovim plugins are ready"
