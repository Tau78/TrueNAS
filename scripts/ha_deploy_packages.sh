#!/usr/bin/env bash
# Copia packages e dashboard HA sul NAS e ricarica configurazione.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${TRUENAS_SSH:-root@truenas.local}"
HA_CFG="/mnt/.ix-apps/app_mounts/home-assistant/config"

echo "→ Packages..."
scp -o BatchMode=yes "$ROOT/home-assistant/packages/"*.yaml "$REMOTE:$HA_CFG/packages/"

echo "→ Dashboard..."
ssh -o BatchMode=yes "$REMOTE" "mkdir -p $HA_CFG/dashboards"
scp -o BatchMode=yes "$ROOT/home-assistant/dashboards/"*.yaml "$REMOTE:$HA_CFG/dashboards/"

echo "→ Reload HA core config..."
HA_TOKEN="$(grep HA_TOKEN "$ROOT/.env" | cut -d= -f2-)"
curl -sf -X POST -H "Authorization: Bearer $HA_TOKEN" \
  "http://192.168.1.12:20810/api/services/homeassistant/reload_core_config" >/dev/null

echo "→ Reload Emulated Hue..."
curl -sf -X POST -H "Authorization: Bearer $HA_TOKEN" \
  "http://192.168.1.12:20810/api/services/emulated_hue/reload" >/dev/null || true

echo "OK — apri http://192.168.1.12:20810 → sidebar MusicPro"
echo "Bridge Alexa: http://192.168.1.12:8300/description.xml"
