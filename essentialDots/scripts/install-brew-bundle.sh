#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/progress.sh
. "${SCRIPT_DIR}/lib/progress.sh"
trap 'ui_fail "Homebrew dependency installation failed"' ERR

usage() {
  cat <<'EOF'
Usage: ./scripts/install-brew-bundle.sh BREWFILE

Installs missing Brewfile dependencies without upgrading or reinstalling
applications that are already present. Casks managed by Homebrew and casks
whose declared .app artifacts already exist are skipped.
EOF
}

if [[ "${#}" -ne 1 || "${1}" == "-h" || "${1}" == "--help" ]]; then
  usage
  [[ "${#}" -eq 1 ]] && exit 0
  exit 2
fi

brewfile="$1"
if [[ ! -f "${brewfile}" ]]; then
  echo "Brewfile not found: ${brewfile}" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is not installed." >&2
  exit 1
fi

read_casks() {
  sed -nE 's/^[[:space:]]*cask "([^"]+)".*/\1/p' "${brewfile}"
}

cask_application_exists() {
  local cask="$1"
  local metadata

  metadata="$(brew info --cask --json=v2 "${cask}" 2>/dev/null)" || return 1

  CASK_METADATA="${metadata}" /usr/bin/python3 -c '
import json
import os
from pathlib import Path

data = json.loads(os.environ["CASK_METADATA"])
casks = data.get("casks", [])
if not casks:
    raise SystemExit(1)

apps = set()

def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)

for artifact in casks[0].get("artifacts", []):
    if not isinstance(artifact, dict):
        continue
    for kind in ("app", "uninstall"):
        if kind not in artifact:
            continue
        for candidate in strings(artifact[kind]):
            if candidate.endswith(".app"):
                apps.add(candidate)

home = Path.home()
for app in apps:
    expanded = Path(os.path.expanduser(app))
    candidates = [expanded] if expanded.is_absolute() else [Path("/Applications") / expanded, home / "Applications" / expanded]
    if any(path.exists() for path in candidates):
        raise SystemExit(0)

raise SystemExit(1)
'
}

skip_casks="${HOMEBREW_BUNDLE_CASK_SKIP:-}"
cask_count="$(read_casks | awk 'NF { count++ } END { print count + 0 }')"
ui_init "$((cask_count + 1))" "Homebrew dependency installation"

while IFS= read -r cask; do
  [[ -n "${cask}" ]] || continue
  ui_stage "Checking cask: ${cask}"

  if brew list --cask "${cask}" >/dev/null 2>&1; then
    ui_skip "Already managed by Homebrew"
    skip_casks="${skip_casks} ${cask}"
  elif cask_application_exists "${cask}"; then
    ui_skip "Application bundle already exists"
    skip_casks="${skip_casks} ${cask}"
  else
    ui_info "Missing; Homebrew Bundle will install it"
  fi
done < <(read_casks)

ui_stage "Installing missing Brewfile dependencies"
ui_info "Homebrew may be quiet while downloading, verifying, or running package installers"
ui_run_with_heartbeat "Homebrew Bundle" \
  env HOMEBREW_BUNDLE_CASK_SKIP="${skip_casks# }" \
  brew bundle --file="${brewfile}" --no-upgrade
ui_done "Homebrew Bundle finished"
ui_complete "Homebrew dependencies are satisfied"
