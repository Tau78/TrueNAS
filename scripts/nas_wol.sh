#!/usr/bin/env bash
# Accende il NAS via Wake-on-LAN (richiede WOL abilitato nel BIOS, Ethernet).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

echo "Invio WOL a ${TRUENAS_MAC} (${TRUENAS_IP})..."
python3 "${SCRIPT_DIR}/wol_truenas.py" "${TRUENAS_MAC}"
echo "Attendi 1-3 minuti, poi verifica con: scripts/nas_status.sh"
