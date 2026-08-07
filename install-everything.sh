#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install-everything.sh [options]

Installs every node in features.yaml at the full profile, with macOS
defaults applied and essentialDots' Pipxfile applications installed with
pipx. No node, skip, or profile choice is accepted here -- use install.sh
directly when you want to choose what gets installed.

Options (forwarded to install.sh):
  --no-bootstrap          Do not install Homebrew/yq when missing.
  --with-turbo-fieldfare  Also install localLLM's TurboFieldfare backend.
  --continue-on-error     Continue after a node fails (default).
  --stop-on-error         Stop at the first failing node instead.
  --dry-run               Preview every action without changing anything.
  -h, --help              Show this help.
EOF
}

# Fixed choice: every node, full profile, macOS defaults applied,
# pipx apps installed. Only operational flags (how, not what) may be added.
args=(--full --all --macos-defaults --pipx)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-bootstrap|--with-turbo-fieldfare|--continue-on-error|--stop-on-error|--dry-run) args+=("$1") ;;
    -h|--help) usage; exit 0 ;;
    --essential|--full|--all|--macos-defaults|--pipx|--only|--only=*|--skip|--skip=*)
      echo "install-everything.sh always installs every node's full profile; $1 is not accepted here." >&2
      exit 2
      ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

exec "${SCRIPT_DIR}/install.sh" "${args[@]}"
