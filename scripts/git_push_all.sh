#!/usr/bin/env bash
# Push su GitHub (origin) e mirror locale sul TrueNAS (nas).
# Uso: scripts/git_push_all.sh [branch]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=git_nas_common.sh
source "${SCRIPT_DIR}/git_nas_common.sh"

branch="${1:-$(git -C "${REPO_DIR}" symbolic-ref --short HEAD 2>/dev/null || echo main)}"

if ! git -C "${REPO_DIR}" remote get-url origin &>/dev/null; then
  echo "FAIL: remote origin mancante." >&2
  exit 1
fi

if ! git -C "${REPO_DIR}" remote get-url "${GIT_REMOTE_NAME}" &>/dev/null; then
  echo "Remote ${GIT_REMOTE_NAME} assente — eseguo setup..."
  "${SCRIPT_DIR}/git_remote_nas_setup.sh"
fi

echo "== Push ${branch} → origin =="
git -C "${REPO_DIR}" push origin "HEAD:${branch}"

echo "== Push ${branch} → ${GIT_REMOTE_NAME} =="
git -C "${REPO_DIR}" push "${GIT_REMOTE_NAME}" "HEAD:${branch}"

echo "OK push completato (origin + ${GIT_REMOTE_NAME})"
