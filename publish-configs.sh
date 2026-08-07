#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SCRIPT_SOURCE}" ]]; do
  SCRIPT_LINK_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
  SCRIPT_SOURCE="$(readlink "${SCRIPT_SOURCE}")"
  [[ "${SCRIPT_SOURCE}" = /* ]] || SCRIPT_SOURCE="${SCRIPT_LINK_DIR}/${SCRIPT_SOURCE}"
done
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"

owner="${GITHUB_OWNER:-noahximus}"
repo="${REPO_NAME:-intelliDots}"
visibility="private"
dry_run=false
description="Consolidated macOS configuration: essentialDots, toolsDots/devTools, toolsDots/aiTools"

usage() {
  cat <<'EOF'
Usage: ./publish-configs.sh [--dry-run] [--public]

Commits every change in this checkout, creates the intelliDots GitHub
repository if it doesn't exist yet, and pushes. Prompts for a commit message
when there are changes to commit. Missing repositories are private by
default; use --public to create one publicly.

Environment:
  GITHUB_OWNER  GitHub account or organization. Default: noahximus
  REPO_NAME     Repository name. Default: intelliDots
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --public) visibility="public" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is required." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Git is required." >&2; exit 1; }
gh auth status >/dev/null || exit 1
[[ -d "${SCRIPT_DIR}/.git" ]] || { echo "Not a Git repository: ${SCRIPT_DIR}. Run 'git init' first." >&2; exit 1; }

if [[ "${dry_run}" == true ]]; then
  git -C "${SCRIPT_DIR}" status --short
  if gh repo view "${owner}/${repo}" >/dev/null 2>&1; then
    echo "GitHub repository exists: ${owner}/${repo}"
  else
    echo "Would create ${visibility} GitHub repository: ${owner}/${repo}"
  fi
  if [[ -n "$(git -C "${SCRIPT_DIR}" status --porcelain)" ]]; then
    echo "Would prompt for a commit message."
  else
    echo "No changes; would not prompt for a commit message."
  fi
  echo "Would push: $(git -C "${SCRIPT_DIR}" branch --show-current) -> origin"
  exit 0
fi

if ! gh repo view "${owner}/${repo}" >/dev/null 2>&1; then
  gh repo create "${owner}/${repo}" "--${visibility}" --description "${description}"
fi

git -C "${SCRIPT_DIR}" remote get-url origin >/dev/null 2>&1 \
  && git -C "${SCRIPT_DIR}" remote set-url origin "https://github.com/${owner}/${repo}.git" \
  || git -C "${SCRIPT_DIR}" remote add origin "https://github.com/${owner}/${repo}.git"

git -C "${SCRIPT_DIR}" add -A

if git -C "${SCRIPT_DIR}" diff --cached --quiet; then
  echo "No changes to commit."
else
  [[ -t 0 ]] || { echo "An interactive terminal is required to enter a commit message." >&2; exit 2; }
  git -C "${SCRIPT_DIR}" diff --cached --stat
  commit_message=""
  while :; do
    read -r -p "Commit message: " commit_message
    case "${commit_message}" in
      *[![:space:]]*) break ;;
      *) echo "Commit message cannot be empty." >&2 ;;
    esac
  done
  git -C "${SCRIPT_DIR}" commit -m "${commit_message}"
fi

branch="$(git -C "${SCRIPT_DIR}" branch --show-current)"
git -C "${SCRIPT_DIR}" push --set-upstream origin "${branch}"

echo
echo "intelliDots committed and pushed."
