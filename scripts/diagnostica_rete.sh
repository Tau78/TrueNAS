#!/usr/bin/env bash
# Diagnostica rapida rete locale dal Mac Mini.
set -euo pipefail

TRUENAS_HOST="${TRUENAS_HOST:-truenas.local}"

echo "=== Diagnostica rete locale ==="
echo "Host: $(hostname)"
echo "Data: $(date)"
echo

echo "--- TrueNAS (${TRUENAS_HOST}) ---"
if ping -c 2 -W 2 "$TRUENAS_HOST" &>/dev/null; then
  echo "Ping: OK"
else
  echo "Ping: FALLITO"
fi

if command -v ssh &>/dev/null; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@${TRUENAS_HOST}" 'hostname' 2>/dev/null; then
    echo "SSH: OK"
  else
    echo "SSH: non disponibile (configura chiave SSH)"
  fi
fi

echo
echo "--- Gateway / DNS ---"
route -n get default 2>/dev/null | awk '/gateway:|interface:/{print}' || ip route | head -3
scutil --dns 2>/dev/null | awk '/nameserver\[0\]/{print; exit}' || true

echo
echo "--- Dispositivi noti (ARP) ---"
arp -a 2>/dev/null | head -20 || ip neigh 2>/dev/null | head -20 || echo "ARP non disponibile"

echo
echo "--- Suggerimento Echo Show cucina ---"
echo "1. App Alexa > Attivita: verifica quale Echo avvia la routine Cancello"
echo "2. Test con microfono spento su tutti gli altri Echo"
echo "3. Aggiungi frase trigger esplicita: apri cancello"
