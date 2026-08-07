#!/usr/bin/env bash

# Shared terminal progress helpers. Colors are disabled for redirected output
# and when NO_COLOR is set.
UI_STEP=0
UI_TOTAL=0
UI_TITLE=''

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  UI_BOLD=$'\033[1m'
  UI_BLUE=$'\033[34m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_RED=$'\033[31m'
  UI_RESET=$'\033[0m'
else
  UI_BOLD=''
  UI_BLUE=''
  UI_GREEN=''
  UI_YELLOW=''
  UI_RED=''
  UI_RESET=''
fi

ui_init() {
  UI_TOTAL="$1"
  UI_TITLE="$2"
  UI_STEP=0
  printf '\n%s%s%s\n' "${UI_BOLD}" "${UI_TITLE}" "${UI_RESET}"
}

ui_stage() {
  UI_STEP=$((UI_STEP + 1))
  printf '\n%s[%d/%d]%s %s%s%s\n' \
    "${UI_BLUE}" "${UI_STEP}" "${UI_TOTAL}" "${UI_RESET}" \
    "${UI_BOLD}" "$1" "${UI_RESET}"
}

ui_info() {
  printf '  %s•%s %s\n' "${UI_BLUE}" "${UI_RESET}" "$1"
}

ui_skip() {
  printf '  %s↷%s %s\n' "${UI_YELLOW}" "${UI_RESET}" "$1"
}

ui_done() {
  printf '  %s✓%s %s\n' "${UI_GREEN}" "${UI_RESET}" "$1"
}

ui_warn() {
  printf '  %s!%s %s\n' "${UI_YELLOW}" "${UI_RESET}" "$1" >&2
}

ui_fail() {
  printf '  %s✗%s %s\n' "${UI_RED}" "${UI_RESET}" "$1" >&2
}

ui_complete() {
  printf '\n%s%s✓ %s%s\n' "${UI_BOLD}" "${UI_GREEN}" "$1" "${UI_RESET}"
}

# Run a command with its output attached to the terminal while periodically
# confirming that the process is still alive. This is useful for commands such
# as Homebrew Bundle that can be quiet during downloads and verification.
ui_run_with_heartbeat() {
  local label="$1"
  shift

  local interval="${UI_HEARTBEAT_SECONDS:-15}"
  local elapsed=0
  local pid status

  "$@" <&0 &
  pid=$!

  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${interval}"
    if kill -0 "${pid}" 2>/dev/null; then
      elapsed=$((elapsed + interval))
      ui_info "${label} is still running (${elapsed}s elapsed)"
    fi
  done

  if wait "${pid}"; then
    return 0
  else
    status=$?
    ui_fail "${label} exited with status ${status}"
    return "${status}"
  fi
}
