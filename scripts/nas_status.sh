#!/usr/bin/env bash
# Verifica se il NAS è online e quali servizi rispondono.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nas_common.sh
source "${SCRIPT_DIR}/nas_common.sh"

check_ping() {
  ping -c 1 -t 3 "${TRUENAS_IP}" >/dev/null 2>&1
}

check_port() {
  nc -z -G 2 -w 2 "${TRUENAS_IP}" "$1" >/dev/null 2>&1
}

check_http() {
  curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${TRUENAS_IP}:$1/" 2>/dev/null || echo "000"
}

echo "=== NAS ${TRUENAS_IP} (${TRUENAS_HOST}) ==="

if check_ping; then
  echo "Ping:       OK"
else
  echo "Ping:       OFFLINE"
  echo ""
  echo "NAS spento o irraggiungibile. Per accenderlo: scripts/nas_wol.sh"
  exit 1
fi

for port in 22 80 443 20810 32400; do
  if check_port "$port"; then
    echo "Porta $port:  OPEN"
  else
    echo "Porta $port:  closed"
  fi
done

ha_code="$(check_http 20810)"
plex_code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://${TRUENAS_IP}:32400/identity" 2>/dev/null || echo "000")"
echo "Home Assist: HTTP ${ha_code}"
echo "Plex:        HTTP ${plex_code}"

if ssh_nas 'midclt call docker.status 2>/dev/null' 2>/dev/null; then
  :
else
  echo "SSH/API:     non disponibile"
fi
