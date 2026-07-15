#!/usr/bin/env bash
# Spegne il NAS via SSH (richiede NAS acceso e raggiungibile).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

if [[ "${1:-}" != "--yes" && "${NAS_POWER_FORCE:-}" != "1" ]]; then
  echo "Spegnimento ${TRUENAS_HOST} (${TRUENAS_IP})"
  echo "Conferma con: $0 --yes"
  exit 1
fi

echo "Spegnimento ${TRUENAS_HOST}..."
ssh_nas 'midclt call system.shutdown'
echo "Comando inviato. Il NAS si spegnerà a breve."
