#!/bin/sh
set -e

if [ -z "$NORDVPN_TOKEN" ]; then
  echo "NORDVPN_TOKEN mancante. Genera un token su https://my.nordaccount.com/ (Meshnet → Advanced → Get access token)"
  exit 1
fi

if ! nordvpn account >/dev/null 2>&1; then
  echo "Login NordVPN..."
  nordvpn login --token "$NORDVPN_TOKEN"
fi

echo "Abilito Meshnet..."
nordvpn set meshnet on
nordvpn set lan-discovery on 2>/dev/null || true

echo "Stato Meshnet:"
nordvpn meshnet peer list || true
nordvpn settings | grep -i meshnet || true

echo "NordVPN Meshnet attivo. In attesa..."
while true; do sleep 3600; done
