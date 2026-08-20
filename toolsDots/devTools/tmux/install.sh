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

TPM_REPO="https://github.com/tmux-plugins/tpm"
TPM_DIR="${HOME}/.tmux/plugins/tpm"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--essential] [--full] [--no-brew] [--adopt] [--dry-run]

Installs tmux, its configuration, and the Tmux Plugin Manager (tpm). The
essential Brewfile is the default; --full is accepted for a consistent
component interface and currently installs the same package set.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    # Profile flags are accepted so the root installer can pass them uniformly,
    # but they no longer select a Brewfile: packages come from tiers/.
    --essential) ;;
    --full) ;;
    --no-brew) run_brew=false ;;
    --adopt) STOW_FLAGS+=(--adopt) ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${dry_run}" == true ]]; then
  stow "${STOW_FLAGS[@]}" --simulate tmux || true
  if [[ -d "${TPM_DIR}/.git" ]]; then
    echo "Would fast-forward pull ${TPM_DIR} if clean"
  else
    echo "Would clone ${TPM_REPO} into ${TPM_DIR}"
  fi
  exit 0
fi

if [[ "${run_brew}" == true ]]; then
  echo "Note: this component no longer installs its own packages." >&2
  echo "      Run the repository's root install.sh to install from tiers/." >&2
fi

command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
mkdir -p "${HOME}/.tmux/plugins"
stow "${STOW_FLAGS[@]}" tmux

if [[ -d "${TPM_DIR}/.git" ]]; then
  if [[ -z "$(git -C "${TPM_DIR}" status --porcelain)" ]]; then
    git -C "${TPM_DIR}" pull --ff-only
  fi
elif [[ -e "${TPM_DIR}" ]]; then
  echo "Path exists but is not a Git checkout: ${TPM_DIR}" >&2
  exit 1
else
  git clone "${TPM_REPO}" "${TPM_DIR}"
fi

echo "tmux installed. Press prefix + I inside tmux to install plugins."
