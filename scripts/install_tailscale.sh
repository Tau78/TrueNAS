#!/usr/bin/env bash
# Installa o aggiorna l'app Tailscale ufficiale su TrueNAS SCALE.
#
# Esecuzione sul server:
#   TS_AUTHKEY='tskey-auth-...' bash /mnt/Share/Downloads/scripts/install_tailscale.sh
#
# Esecuzione remota via SSH:
#   TS_AUTHKEY='tskey-auth-...' ssh -o BatchMode=yes root@truenas.local \
#     'bash -s' < scripts/install_tailscale.sh
#
# Variabili opzionali:
#   TS_HOSTNAME        Nome nodo nel tailnet (default: truenas-scale)
#   TS_USERSPACE       true/false (default: true)
#   TS_HOST_NETWORK    true/false (default: true)
#   TS_ACCEPT_DNS      true/false (default: false)
#   TS_ACCEPT_ROUTES   true/false (default: false)
#   TS_ADVERTISE_ROUTES  Subnet da annunciare, es. 192.168.1.0/24
#   TS_ADVERTISE_EXIT_NODE  true/false (default: false)
#   TZ                 Timezone (default: Europe/Rome)
#   TRUENAS_APP_NAME   Nome app (default: tailscale)

set -euo pipefail

APP_NAME="${TRUENAS_APP_NAME:-tailscale}"
CATALOG_APP="tailscale"
TRAIN="community"
VERSION="latest"
HOSTNAME="${TS_HOSTNAME:-truenas-scale}"
USERSPACE="${TS_USERSPACE:-true}"
HOST_NETWORK="${TS_HOST_NETWORK:-true}"
ACCEPT_DNS="${TS_ACCEPT_DNS:-false}"
ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-false}"
ADVERTISE_EXIT_NODE="${TS_ADVERTISE_EXIT_NODE:-false}"
ADVERTISE_ROUTES="${TS_ADVERTISE_ROUTES:-}"
TZ_VALUE="${TZ:-Europe/Rome}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  log "ERRORE: $*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Comando richiesto non trovato: $1"
}

require_cmd midclt
require_cmd jq

if [[ -z "${TS_AUTHKEY:-}" ]]; then
  die "Imposta TS_AUTHKEY con una auth key da https://login.tailscale.com/admin/settings/keys"
fi

if ! midclt call system.info >/dev/null 2>&1; then
  die "midclt non risponde: esegui questo script come root su TrueNAS SCALE"
fi

log "Sincronizzazione catalogo app..."
midclt call catalog.sync >/dev/null 2>&1 || log "Avviso: catalog.sync non riuscito, continuo comunque"

build_values_json() {
  local routes_json='[]'
  if [[ -n "$ADVERTISE_ROUTES" ]]; then
    routes_json="$(jq -n --arg route "$ADVERTISE_ROUTES" '[{route: $route}]')"
  fi

  jq -n \
    --arg tz "$TZ_VALUE" \
    --arg hostname "$HOSTNAME" \
    --arg auth_key "$TS_AUTHKEY" \
    --argjson userspace "$([[ "$USERSPACE" == "true" ]] && echo true || echo false)" \
    --argjson accept_dns "$([[ "$ACCEPT_DNS" == "true" ]] && echo true || echo false)" \
    --argjson accept_routes "$([[ "$ACCEPT_ROUTES" == "true" ]] && echo true || echo false)" \
    --argjson advertise_exit_node "$([[ "$ADVERTISE_EXIT_NODE" == "true" ]] && echo true || echo false)" \
    --argjson host_network "$([[ "$HOST_NETWORK" == "true" ]] && echo true || echo false)" \
    --argjson advertise_routes "$routes_json" \
    '{
      TZ: $tz,
      tailscale: {
        hostname: $hostname,
        auth_key: $auth_key,
        auth_once: true,
        reset: false,
        userspace: $userspace,
        accept_dns: $accept_dns,
        accept_routes: $accept_routes,
        advertise_exit_node: $advertise_exit_node,
        advertise_routes: $advertise_routes
      },
      network: {
        host_network: $host_network
      },
      storage: {
        state: {
          type: "ix_volume",
          ix_volume_config: {
            dataset_name: "state"
          }
        }
      }
    }'
}

app_exists() {
  midclt call app.query "[[\"name\", \"=\", \"$APP_NAME\"]]" | jq -e 'length > 0' >/dev/null 2>&1
}

wait_for_running() {
  local attempts=60
  local state

  for ((i = 1; i <= attempts; i++)); do
    state="$(midclt call app.query "[[\"name\", \"=\", \"$APP_NAME\"]]" | jq -r '.[0].state // empty')"
    case "$state" in
      RUNNING)
        log "App $APP_NAME in stato RUNNING"
        return 0
        ;;
      CRASHED|STOPPED)
        log "Stato attuale: $state (tentativo $i/$attempts)"
        ;;
      *)
        log "Stato attuale: ${state:-sconosciuto} (tentativo $i/$attempts)"
        ;;
    esac
    sleep 5
  done

  die "Timeout in attesa che $APP_NAME diventi RUNNING"
}

VALUES_JSON="$(build_values_json)"

if app_exists; then
  log "App $APP_NAME già presente, aggiornamento configurazione..."
  midclt call -job app.update "$APP_NAME" "{\"values\": $(echo "$VALUES_JSON" | jq -c '.')}" >/dev/null
  log "Riavvio app $APP_NAME..."
  midclt call app.stop "$APP_NAME" >/dev/null 2>&1 || true
  midclt call app.start "$APP_NAME" >/dev/null
else
  log "Installazione app $APP_NAME dal catalogo ufficiale TrueNAS..."
  PAYLOAD="$(jq -n \
    --arg app_name "$APP_NAME" \
    --arg catalog_app "$CATALOG_APP" \
    --arg train "$TRAIN" \
    --arg version "$VERSION" \
    --argjson values "$VALUES_JSON" \
    '{
      app_name: $app_name,
      catalog_app: $catalog_app,
      train: $train,
      version: $version,
      values: $values
    }')"
  midclt call -job app.create "$PAYLOAD" >/dev/null
fi

wait_for_running

log "Installazione completata."
log "Verifica su https://login.tailscale.com/admin/machines che compaia '$HOSTNAME'."
log "Per accedere alla UI TrueNAS da remoto, apri https://<IP-tailscale> nel browser."
