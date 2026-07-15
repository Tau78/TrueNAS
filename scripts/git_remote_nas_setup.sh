#!/usr/bin/env bash
# Crea bare repo sul TrueNAS e aggiunge remote git "nas" al repo locale.
# Uso: scripts/git_remote_nas_setup.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=git_nas_common.sh
source "${SCRIPT_DIR}/git_nas_common.sh"

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
fi

if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
  echo "FAIL: ${REPO_DIR} non è un repository git." >&2
  exit 1
fi

repo_name="$(repo_basename)"
bare_path="$(git_nas_bare_path "${repo_name}")"
remote_url="$(git_nas_remote_url "${repo_name}")"

echo "== Setup remote NAS per ${repo_name} =="
echo "Bare path: ${bare_path}"
echo "Remote URL: ${remote_url}"

if $dry_run; then
  echo "[dry-run] ssh ${TRUENAS_SSH} mkdir -p ${GIT_NAS_ROOT} && git init --bare ${bare_path}"
  if git -C "${REPO_DIR}" remote get-url "${GIT_REMOTE_NAME}" &>/dev/null; then
    echo "[dry-run] remote ${GIT_REMOTE_NAME} già presente: $(git -C "${REPO_DIR}" remote get-url "${GIT_REMOTE_NAME}")"
  else
    echo "[dry-run] git -C ${REPO_DIR} remote add ${GIT_REMOTE_NAME} ${remote_url}"
  fi
  exit 0
fi

ssh_nas "mkdir -p '${GIT_NAS_ROOT}'"
if ssh_nas "test -d '${bare_path}/refs'"; then
  echo "OK bare repo già presente su NAS"
else
  ssh_nas "git init --bare '${bare_path}'"
  echo "OK bare repo creato su NAS"
fi

if git -C "${REPO_DIR}" remote get-url "${GIT_REMOTE_NAME}" &>/dev/null; then
  current_url="$(git -C "${REPO_DIR}" remote get-url "${GIT_REMOTE_NAME}")"
  if [[ "${current_url}" != "${remote_url}" ]]; then
    git -C "${REPO_DIR}" remote set-url "${GIT_REMOTE_NAME}" "${remote_url}"
    echo "OK remote ${GIT_REMOTE_NAME} aggiornato"
  else
    echo "OK remote ${GIT_REMOTE_NAME} già configurato"
  fi
else
  git -C "${REPO_DIR}" remote add "${GIT_REMOTE_NAME}" "${remote_url}"
  echo "OK remote ${GIT_REMOTE_NAME} aggiunto"
fi

echo
echo "Prossimo passo:"
echo "  git push -u ${GIT_REMOTE_NAME} main"
echo "oppure:"
echo "  scripts/git_push_all.sh"
