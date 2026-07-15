#!/usr/bin/env bash
# Riavvia il NAS via SSH (richiede NAS acceso e raggiungibile).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

if [[ "${1:-}" != "--yes" && "${NAS_POWER_FORCE:-}" != "1" ]]; then
  echo "Riavvio ${TRUENAS_HOST} (${TRUENAS_IP})"
  echo "Conferma con: $0 --yes"
  exit 1
fi

echo "Riavvio ${TRUENAS_HOST}..."
ssh_nas 'midclt call system.reboot'
echo "Comando inviato. Attendi 2-5 minuti, poi verifica con: scripts/nas_status.sh"
