#!/bin/sh
set -e

if [ -z "$NORDVPN_TOKEN" ]; then
  echo "NORDVPN_TOKEN mancante. Genera un token su https://my.nordaccount.com/ (Meshnet → Advanced → Get access token)"
  exit 1
fi

start_daemon() {
  if [ -S /run/nordvpn/nordvpnd.sock ]; then
    return 0
  fi
  echo "Avvio demone NordVPN..."
  if [ -x /etc/init.d/nordvpn ]; then
    /etc/init.d/nordvpn start
  elif command -v nordvpnd >/dev/null 2>&1; then
    nordvpnd &
  else
    echo "Impossibile avviare nordvpnd"
    exit 1
  fi
  for i in $(seq 1 30); do
    if [ -S /run/nordvpn/nordvpnd.sock ]; then
      return 0
    fi
    sleep 1
  done
  echo "Timeout avvio nordvpnd"
  exit 1
}

start_daemon

# Evita prompt interattivo al primo login
nordvpn set analytics off >/dev/null 2>&1 || true

if ! nordvpn account 2>&1 | grep -qi "email address"; then
  echo "Login NordVPN..."
  printf 'n\n' | nordvpn login --token "$NORDVPN_TOKEN"
fi

echo "Abilito Meshnet..."
nordvpn set firewall off >/dev/null 2>&1 || true
nordvpn set routing off >/dev/null 2>&1 || true
nordvpn set meshnet on || { echo "WARN: meshnet on fallito, riprovo tra 30s..."; sleep 30; nordvpn set meshnet on || true; }
nordvpn set lan-discovery on 2>/dev/null || true

echo "Stato Meshnet:"
nordvpn meshnet peer list || true
nordvpn settings | grep -i meshnet || true

echo "NordVPN Meshnet attivo. In attesa..."
while true; do sleep 3600; done
