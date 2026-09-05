#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared with every other stow-using component so a moved checkout can be
# relinked instead of aborting with "existing target is not owned by stow".
# shellcheck source=../../../essentialDots/scripts/lib/stow-migrate.sh
. "${PROJECT_DIR}/../../../essentialDots/scripts/lib/stow-migrate.sh"
# --restow removes and relinks every managed target, so reruns self-heal any
# manually deleted symlinks; --no-folding keeps stow from collapsing whole
# directories into a single symlink, which would swallow unrelated sibling
# files a package doesn't own.
STOW_FLAGS=(--dir="${PROJECT_DIR}" --target="${HOME}" --verbose --restow --no-folding)
run_brew=true
run_pipx=true
dry_run=false
with_local_llm=false
with_turbo_fieldfare=false

TURBO_FIELDFARE_REPO="https://github.com/drumih/turbo-fieldfare.git"
TURBO_FIELDFARE_DIR="${HOME}/.config/turbo-fieldfare"

usage() {
  cat <<'EOF'
Usage: ./install.sh --with-local-llm|--with-turbo-fieldfare [options]

Installs the standalone local-LLM runtime. Both backends are opt-in and may
be combined in the same invocation:

  --with-local-llm        Install the llama.cpp-based local-llm stack.
  --with-turbo-fieldfare  Clone TurboFieldfare into ~/.config/turbo-fieldfare
                           and install its CLI wrapper. Does not build or
                           download its model; run `turbo-fieldfare install`
                           afterward for that.

Other options:
  --essential          Accepted for compatibility; packages come from tiers/.
  --full               Accepted for compatibility; packages come from tiers/.
  --no-brew            Skip Homebrew bundle installation.
  --no-pipx            Skip installing huggingface-hub via pipx.
  --adopt              Pass --adopt to GNU Stow.
  --dry-run            Preview actions without changing anything.
  -h, --help           Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-local-llm) with_local_llm=true ;;
    --with-turbo-fieldfare) with_turbo_fieldfare=true ;;
    --essential) ;;
    --full) ;;
    --no-brew) run_brew=false ;;
    --no-pipx) run_pipx=false ;;
    --adopt) STOW_FLAGS+=(--adopt) ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "${with_local_llm}" == false && "${with_turbo_fieldfare}" == false ]]; then
  echo "Nothing to install: pass --with-local-llm and/or --with-turbo-fieldfare." >&2
  usage >&2
  exit 2
fi

# Writes a disabled (RunAtLoad=false) LaunchAgent so `local-llm start`/`stop`
# (and `local-llm-embed start`/`stop`) can drive llama-server, the wrapper,
# and the embedding server as managed services without a terminal window
# staying open, while never auto-starting them at login. `program` is the
# CLI under ~/.local/bin that launchd invokes; `command` its serve subcommand.
write_agent() {
  local label="$1" program="$2" command="$3" log_file="$4"
  local destination="${HOME}/Library/LaunchAgents/${label}.plist"
  # LaunchAgents run with a minimal environment, so PATH must be set
  # explicitly rather than inherited from the interactive shell.
  local path_value="${HOMEBREW_PREFIX:-/opt/homebrew}/bin:/usr/local/bin:/usr/bin:/bin"
  mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs/local-llm"
  cat >"${destination}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>${label}</string>
<key>ProgramArguments</key><array><string>${HOME}/.local/bin/${program}</string><string>${command}</string></array>
<key>EnvironmentVariables</key><dict><key>HOME</key><string>${HOME}</string><key>PATH</key><string>${path_value}</string></dict>
<key>ProcessType</key><string>Interactive</string><key>RunAtLoad</key><false/>
<key>StandardOutPath</key><string>${HOME}/Library/Logs/local-llm/${log_file}</string>
<key>StandardErrorPath</key><string>${HOME}/Library/Logs/local-llm/${log_file}</string>
</dict></plist>
EOF
}

install_local_llm() {
  if [[ "${dry_run}" == true ]]; then
    stow "${STOW_FLAGS[@]}" --simulate local-llm || true
    echo "Would initialize runtime directories and write three LaunchAgents"
    return 0
  fi

  if [[ "${run_brew}" == true ]]; then
    echo "Note: this component no longer installs its own packages." >&2
    echo "      Run the repository's root install.sh to install from tiers/." >&2
  fi

  command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
  stow_migrate "${PROJECT_DIR}" "${HOME}" local-llm
  stow "${STOW_FLAGS[@]}" local-llm

  # huggingface-hub backs the model downloader; installed via pipx (isolated
  # venv) rather than the Brewfile since it's a Python CLI tool, not a
  # Homebrew formula.
  if [[ "${run_pipx}" == true ]]; then
    if command -v pipx >/dev/null 2>&1; then
      if ! pipx list --short 2>/dev/null | grep -qx huggingface-hub; then
        pipx install huggingface-hub
      fi
    else
      # pipx is a dev-essentials formula, so a profile that takes ai-local
      # without dev-essentials lands here. The runtime still works; only
      # authenticated and gated model downloads are unavailable. Worth saying
      # out loud -- skipping quietly is the kind of gap you rediscover months
      # later, wondering why `hf` is missing.
      echo "Note: pipx not found, so huggingface-hub was not installed." >&2
      echo "      local-llm works, but 'hf' for gated model downloads is missing." >&2
      echo "      Install pipx (it ships with the dev-essentials tier) and rerun." >&2
    fi
  fi

  mkdir -p "${HOME}/Models" "${HOME}/Library/Application Support/local-llm" "${HOME}/Library/Logs/local-llm"
  write_agent "local.local-llm.backend" "local-llm" "_serve-backend" "llama-server.log"
  write_agent "local.local-llm.wrapper" "local-llm" "_serve-wrapper" "wrapper.log"
  write_agent "local.local-llm.embed" "local-llm-embed" "_serve" "embed-server.log"
  echo "local-llm installed. Run: local-llm doctor && local-llm-embed doctor"
}

# Clones (or fast-forward updates) the upstream TurboFieldfare repository and
# stows this package's CLI wrapper. The Swift build and the ~14GB model
# download are deliberately left to `turbo-fieldfare install`, not run here,
# since they can take 15-30+ minutes and shouldn't be a surprise side effect
# of running this installer.
install_turbo_fieldfare() {
  if [[ "${dry_run}" == true ]]; then
    stow "${STOW_FLAGS[@]}" --simulate turbo-fieldfare || true
    if [[ -d "${TURBO_FIELDFARE_DIR}/.git" ]]; then
      echo "Would fast-forward pull ${TURBO_FIELDFARE_DIR} if clean"
    else
      echo "Would clone ${TURBO_FIELDFARE_REPO} into ${TURBO_FIELDFARE_DIR}"
    fi
    return 0
  fi

  command -v stow >/dev/null 2>&1 || { echo "GNU Stow is required." >&2; exit 1; }
  command -v swift >/dev/null 2>&1 || {
    echo "A Swift toolchain (Xcode 26+, Swift 6.2+) is required for TurboFieldfare." >&2
    exit 1
  }
  stow_migrate "${PROJECT_DIR}" "${HOME}" turbo-fieldfare
  stow "${STOW_FLAGS[@]}" turbo-fieldfare

  if [[ -d "${TURBO_FIELDFARE_DIR}/.git" ]]; then
    local origin
    origin="$(git -C "${TURBO_FIELDFARE_DIR}" remote get-url origin 2>/dev/null || true)"
    if [[ "${origin%.git}" != "${TURBO_FIELDFARE_REPO%.git}" ]]; then
      echo "Origin mismatch at ${TURBO_FIELDFARE_DIR}: ${origin}" >&2
      exit 1
    fi
    if [[ -n "$(git -C "${TURBO_FIELDFARE_DIR}" status --porcelain)" ]]; then
      echo "Existing TurboFieldfare checkout has local changes; leaving it as-is: ${TURBO_FIELDFARE_DIR}"
    else
      git -C "${TURBO_FIELDFARE_DIR}" pull --ff-only
    fi
  elif [[ -e "${TURBO_FIELDFARE_DIR}" ]]; then
    echo "Path exists but is not a Git checkout: ${TURBO_FIELDFARE_DIR}" >&2
    exit 1
  else
    git clone "${TURBO_FIELDFARE_REPO}" "${TURBO_FIELDFARE_DIR}"
  fi

  # Our own CLI state (PID, logs, config) lives inside the clone, as
  # requested, but it isn't upstream's content. Excluding it locally (the
  # repo's own git-info/exclude, not a tracked .gitignore) keeps
  # `git status`/`git pull` clean in there without touching a file we don't
  # own.
  mkdir -p "${TURBO_FIELDFARE_DIR}/.runtime"
  grep -qxF '.runtime/' "${TURBO_FIELDFARE_DIR}/.git/info/exclude" 2>/dev/null \
    || echo '.runtime/' >> "${TURBO_FIELDFARE_DIR}/.git/info/exclude"

  echo "TurboFieldfare cloned into ${TURBO_FIELDFARE_DIR}."
  echo "Run: turbo-fieldfare install   (builds release binaries and downloads the ~14GB model)"
}

if [[ "${with_local_llm}" == true ]]; then
  install_local_llm
fi
if [[ "${with_turbo_fieldfare}" == true ]]; then
  install_turbo_fieldfare
fi
