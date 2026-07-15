#!/usr/bin/env bash
# Deploy NordVPN Meshnet su TrueNAS (container Docker, host network).
# Richiede NORDVPN_TOKEN in .env o ambiente.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/nas_common.sh" 2>/dev/null || true

NORDVPN_TOKEN="${NORDVPN_TOKEN:-}"
if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1090
  val="$(grep -E '^NORDVPN_TOKEN=' "$ROOT/.env" | cut -d= -f2- || true)"
  [[ -n "$val" ]] && NORDVPN_TOKEN="$val"
fi

if [[ -z "$NORDVPN_TOKEN" ]]; then
  echo "Errore: imposta NORDVPN_TOKEN in .env"
  echo "  https://my.nordaccount.com/ → Meshnet → Advanced settings → Get access token"
  exit 1
fi

REMOTE="${TRUENAS_SSH:-root@truenas.local}"
REMOTE_DIR="/mnt/Share/NAS/nordvpn-meshnet"
IMAGE="nordvpn-meshnet:local"

echo "→ Copia file su $REMOTE..."
ssh -o BatchMode=yes "$REMOTE" "mkdir -p $REMOTE_DIR/data"
scp -o BatchMode=yes -r "$ROOT/docker/nordvpn-meshnet/"* "$REMOTE:$REMOTE_DIR/"

echo "→ Build immagine Docker..."
ssh -o BatchMode=yes "$REMOTE" "cd $REMOTE_DIR && docker build -t $IMAGE ."

echo "→ Avvio container (host network)..."
ssh -o BatchMode=yes "$REMOTE" "docker rm -f nordvpn-meshnet 2>/dev/null || true
docker run -d \\
  --name nordvpn-meshnet \\
  --hostname truenas-meshnet \\
  --restart unless-stopped \\
  --init \\
  --network host \\
  --cap-add=NET_ADMIN \\
  --device /dev/net/tun \\
  -e NORDVPN_TOKEN='$NORDVPN_TOKEN' \\
  -v $REMOTE_DIR/data:/var/lib/nordvpn \\
  $IMAGE"

echo "→ Log (attendi login + meshnet):"
sleep 8
ssh -o BatchMode=yes "$REMOTE" "docker logs nordvpn-meshnet 2>&1 | tail -25"

echo ""
echo "Comandi utili sul NAS:"
echo "  docker logs -f nordvpn-meshnet"
echo "  docker exec nordvpn-meshnet nordvpn meshnet peer list"
echo "  docker exec nordvpn-meshnet nordvpn meshnet peer local allow <tuo-dispositivo>"
