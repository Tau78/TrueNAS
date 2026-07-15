# Configurazione condivisa per mirror git sul TrueNAS.
# Source: . scripts/git_nas_common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

GIT_NAS_ROOT="${GIT_NAS_ROOT:-/mnt/Share/NAS/git}"
GIT_REMOTE_NAME="${GIT_REMOTE_NAME:-nas}"

repo_basename() {
  basename "$(git -C "${REPO_DIR}" rev-parse --show-toplevel 2>/dev/null)"
}

git_nas_bare_path() {
  local name="${1:-$(repo_basename)}"
  echo "${GIT_NAS_ROOT}/${name}.git"
}

git_nas_remote_url() {
  local bare_path
  bare_path="$(git_nas_bare_path "$1")"
  echo "${TRUENAS_SSH}:${bare_path}"
}
