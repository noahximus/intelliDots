#!/usr/bin/env bash
set -euo pipefail
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"

if [[ -d "${SCRIPT_DIR}/.git" ]]; then
  if [[ -n "$(git -C "${SCRIPT_DIR}" status --porcelain)" ]]; then
    echo "Refusing to pull a checkout with local changes: ${SCRIPT_DIR}" >&2
    exit 1
  fi
  git -C "${SCRIPT_DIR}" pull --ff-only
fi

exec "${SCRIPT_DIR}/install.sh" "$@"
