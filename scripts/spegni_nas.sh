#!/usr/bin/env bash
# Spegnimento TrueNAS via SSH dal Mac Mini (rete locale).
# Uso: ./scripts/spegni_nas.sh [--dry-run]
set -euo pipefail

TRUENAS_HOST="${TRUENAS_HOST:-truenas.local}"
TRUENAS_USER="${TRUENAS_USER:-root}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if ! ping -c 1 -W 2 "$TRUENAS_HOST" &>/dev/null; then
  log "ERRORE: $TRUENAS_HOST non raggiungibile sulla rete locale."
  exit 1
fi

if ! ssh "${SSH_OPTS[@]}" "${TRUENAS_USER}@${TRUENAS_HOST}" 'echo ok' &>/dev/null; then
  log "ERRORE: SSH verso ${TRUENAS_USER}@${TRUENAS_HOST} non configurato."
  log "Configura chiave: ssh-copy-id ${TRUENAS_USER}@${TRUENAS_HOST}"
  exit 1
fi

if $dry_run; then
  log "DRY RUN: avrei eseguito shutdown su ${TRUENAS_HOST}"
  exit 0
fi

log "Spegnimento ${TRUENAS_HOST} in corso..."
ssh "${SSH_OPTS[@]}" "${TRUENAS_USER}@${TRUENAS_HOST}" 'shutdown -h now'
log "Comando inviato."
