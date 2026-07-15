# Configurazione condivisa per script di gestione NAS.
# Source: . scripts/nas_common.sh

TRUENAS_IP="${TRUENAS_IP:-192.168.1.12}"
TRUENAS_HOST="${TRUENAS_HOST:-truenas.local}"
TRUENAS_MAC="${TRUENAS_MAC:-e8:de:27:a6:a7:51}"
TRUENAS_SSH="${TRUENAS_SSH:-root@${TRUENAS_HOST}}"
SSH_OPTS="${SSH_OPTS:--o BatchMode=yes -o ConnectTimeout=10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ssh_nas() {
  ssh ${SSH_OPTS} "${TRUENAS_SSH}" "$@"
}
