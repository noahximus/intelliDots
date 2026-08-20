#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"

GITHUB_OWNER="${GITHUB_OWNER:-noahximus}"
REPO_NAME="${REPO_NAME:-intelliDots}"
RUNNING_FROM_CHECKOUT=false
if [[ -f "${SCRIPT_DIR}/features.yaml" ]]; then
  RUNNING_FROM_CHECKOUT=true
  # A checkout's parent directory is where a standalone downloaded copy of
  # this script would otherwise clone the repo, so reuse it as the default
  # install root when run from inside an existing checkout.
  INSTALL_ROOT="${MY_CONFIG_ROOT:-$(dirname "${SCRIPT_DIR}")}"
else
  INSTALL_ROOT="${MY_CONFIG_ROOT:-${HOME}/Developer/myConfigs}"
fi

REPO_URL="https://github.com/${GITHUB_OWNER}/${REPO_NAME}.git"
REPO_DIR="${INSTALL_ROOT}/${REPO_NAME}"
BOOTSTRAP_COPY="${INSTALL_ROOT}/bootstrap.sh"
profile=daily
dry_run=false

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--profile NAME] [--root DIRECTORY] [--dry-run]

Bootstrap a fresh Mac, authenticate GitHub, clone or update intelliDots, and
run its installer with the named profile. Profiles live in the checkout's
profiles/ directory; see intelliDots/install.sh --help.

Options:
  --profile NAME    Profile to install. Default: daily
  --air             Shorthand for --profile air: a Mac that is not a
                     development machine (desktop and AI apps, no toolchains).
  --daily           Shorthand for --profile daily (the default).
  --everything      Shorthand for --profile everything.
  --essential       Deprecated alias for --daily.
  --full            Deprecated alias for --everything.
  --root DIRECTORY  Parent directory for the intelliDots checkout.
  --dry-run         Describe the work without installing, cloning, or logging in.
  -h, --help        Show this help.

Environment:
  MY_CONFIG_ROOT  Alternative installation root.
  GITHUB_OWNER    GitHub account or organization. Default: noahximus
  REPO_NAME       Repository name. Default: intelliDots
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      [[ $# -gt 0 ]] || { echo "--profile requires a name." >&2; exit 2; }
      profile="$1"
      ;;
    --profile=*) profile="${1#*=}" ;;
    --air) profile=air ;;
    --daily) profile=daily ;;
    --everything) profile=everything ;;
    --essential)
      echo "Note: --essential is deprecated; using --profile daily." >&2
      profile=daily
      ;;
    --full)
      echo "Note: --full is deprecated; using --profile everything." >&2
      profile=everything
      ;;
    --root)
      shift
      [[ $# -gt 0 ]] || { echo "--root requires a directory." >&2; exit 2; }
      INSTALL_ROOT="$1"
      REPO_DIR="${INSTALL_ROOT}/${REPO_NAME}"
      BOOTSTRAP_COPY="${INSTALL_ROOT}/bootstrap.sh"
      ;;
    --root=*)
      INSTALL_ROOT="${1#*=}"
      REPO_DIR="${INSTALL_ROOT}/${REPO_NAME}"
      BOOTSTRAP_COPY="${INSTALL_ROOT}/bootstrap.sh"
      ;;
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

load_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

if [[ "${dry_run}" == true ]]; then
  cat <<EOF
Fresh-Mac bootstrap preview
  installation root: ${INSTALL_ROOT}
  repo checkout:      ${REPO_DIR}
  repository:         ${REPO_URL}
  profile:            ${profile}

Would:
  1. Create ${INSTALL_ROOT} and keep a reusable bootstrap.sh there.
  2. Verify or start Apple's command-line tools installer.
  3. Install Homebrew when missing.
  4. Install GitHub CLI when missing.
  5. Authenticate GitHub and configure Git credentials when needed.
  6. Clone intelliDots, or pull it with --ff-only when clean.
  7. Run intelliDots/install.sh --profile ${profile} --macos-defaults.
EOF
  exit 0
fi

mkdir -p "${INSTALL_ROOT}"
if [[ "${RUNNING_FROM_CHECKOUT}" == false && "${SCRIPT_DIR}/bootstrap.sh" != "${BOOTSTRAP_COPY}" ]]; then
  cp "${SCRIPT_DIR}/bootstrap.sh" "${BOOTSTRAP_COPY}"
  chmod +x "${BOOTSTRAP_COPY}"
  echo "Saved a reusable bootstrap script at ${BOOTSTRAP_COPY}"
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple's command-line tools are required."
  echo "Starting Apple's installer. Complete it, open a new terminal, and run:"
  echo "  ${BOOTSTRAP_COPY}"
  xcode-select --install
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "Git is unavailable after installing the command-line tools." >&2; exit 1; }

load_homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew installation requires administrator access."
  echo "Enter your Mac login password when sudo prompts (typing will not be displayed)."
  sudo -v
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_homebrew
fi
command -v brew >/dev/null 2>&1 || { echo "Homebrew is not available on PATH. Open a new terminal and rerun." >&2; exit 1; }

if ! command -v gh >/dev/null 2>&1; then
  echo "Installing GitHub CLI..."
  brew install gh
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "Installing yq..."
  brew install yq
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "GitHub authentication is required for the private configuration repository."
  gh auth login --hostname github.com --git-protocol https --web
fi

if [[ -d "${REPO_DIR}/.git" ]]; then
  origin="$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || true)"
  [[ "${origin%.git}" == "${REPO_URL%.git}" ]] || {
    echo "Unexpected origin at ${REPO_DIR}: ${origin}" >&2
    exit 1
  }
  [[ -z "$(git -C "${REPO_DIR}" status --porcelain)" ]] || {
    echo "Refusing to update an intelliDots checkout with local changes: ${REPO_DIR}" >&2
    exit 1
  }
  echo "Updating intelliDots..."
  git -C "${REPO_DIR}" pull --ff-only
elif [[ -e "${REPO_DIR}" ]]; then
  echo "${REPO_DIR} exists but is not a Git checkout." >&2
  exit 1
else
  echo "Cloning intelliDots into ${REPO_DIR}..."
  gh repo clone "${GITHUB_OWNER}/${REPO_NAME}" "${REPO_DIR}"
fi

[[ -x "${REPO_DIR}/install.sh" ]] || { echo "Missing executable installer: ${REPO_DIR}/install.sh" >&2; exit 1; }
echo "Starting the ${profile} configuration installation..."
exec "${REPO_DIR}/install.sh" --profile "${profile}" --macos-defaults
