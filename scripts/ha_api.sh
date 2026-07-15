#!/usr/bin/env bash
# Chiamate API Home Assistant. Uso: ha_api.sh /api/states
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
fi

HA_URL="${HA_URL:-http://192.168.1.12:20810}"
HA_TOKEN="${HA_TOKEN:-}"

if [[ -z "${HA_TOKEN}" ]]; then
  echo "HA_TOKEN mancante. Esegui: scripts/ha_token.sh > .env (o aggiorna .env)" >&2
  exit 1
fi

path="${1:-/api/}"
shift || true

curl -sS -H "Authorization: Bearer ${HA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${HA_URL}${path}" "$@"
