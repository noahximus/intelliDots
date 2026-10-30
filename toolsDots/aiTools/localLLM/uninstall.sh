#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dry_run=false
remove_data=false
remove_models=false
remove_turbo_fieldfare_data=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --data) remove_data=true ;;
    --models) remove_models=true ;;
    --turbo-fieldfare-data) remove_turbo_fieldfare_data=true ;;
    -h|--help)
      echo "Usage: ./uninstall.sh [--dry-run] [--data] [--models] [--turbo-fieldfare-data]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

domain="gui/$(id -u)"
for label in local.local-llm.embed local.local-llm.wrapper local.local-llm.backend; do
  if [[ "${dry_run}" == true ]]; then
    echo "Would unload ${domain}/${label} and remove its LaunchAgent"
  else
    launchctl bootout "${domain}/${label}" 2>/dev/null || true
    rm -f "${HOME}/Library/LaunchAgents/${label}.plist"
  fi
done

# Deleting a package that was never stowed is a harmless no-op, so both are
# always attempted regardless of which one(s) install.sh was run with.
if command -v stow >/dev/null 2>&1; then
  for package in local-llm turbo-fieldfare; do
    stow_args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete "${package}")
    [[ "${dry_run}" == true ]] && stow_args=(--dir="${PROJECT_DIR}" --target="${HOME}" --delete --simulate "${package}")
    stow "${stow_args[@]}" || true
  done
fi

if [[ "${remove_data}" == true ]]; then
  for path in "${HOME}/Library/Application Support/local-llm" "${HOME}/Library/Logs/local-llm"; do
    if [[ "${dry_run}" == true ]]; then echo "Would remove ${path}"; else rm -rf "${path}"; fi
  done
fi
if [[ "${remove_models}" == true ]]; then
  if [[ "${dry_run}" == true ]]; then echo "Would remove ${LOCAL_LLM_MODELS_DIR:-${HOME}/Models}"; else rm -rf "${LOCAL_LLM_MODELS_DIR:-${HOME}/Models}"; fi
fi
if [[ "${remove_turbo_fieldfare_data}" == true ]]; then
  if [[ "${dry_run}" == true ]]; then echo "Would remove ${HOME}/.config/turbo-fieldfare"; else rm -rf "${HOME}/.config/turbo-fieldfare"; fi
fi
echo "localLLM configuration removed."
