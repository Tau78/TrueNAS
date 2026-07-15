# TrueNAS — Inventario server

Parametri di rete e servizi del server domestico mappato da questa sessione Cursor.

**Target:** `192.168.1.12/24` · Aggiornato il 2026-07-13.

## Rete

| Parametro | Valore |
|-----------|--------|
| **Hostname** | `truenas` |
| **mDNS** | `truenas.local` |
| **IP LAN** | `192.168.1.12` |
| **Subnet** | `192.168.1.0/24` |
| **Gateway** | `192.168.1.1` |
| **Interfaccia** | `enp4s0` (Ethernet 100Mb/s) |
| **MAC (WOL)** | `e8:de:27:a6:a7:51` |
| **Timezone** | `Europe/Rome` |

## Sistema

| Parametro | Valore |
|-----------|--------|
| **OS** | TrueNAS Scale |
| **Versione** | `25.10.3.1` |
| **CPU** | Intel Core i5-2400 @ 3.10GHz (4 core) |
| **RAM** | ~12 GB |
| **Produttore** | Gigabyte Technology Co., Ltd. |
| **Pool dati** | `Share` (2.64T usati, **~888G liberi**) |
| **Pool boot** | `boot-pool` (216G, OK) |

## Accesso remoto

### SSH

```bash
ssh -o BatchMode=yes root@truenas.local
# oppure
ssh -o BatchMode=yes root@192.168.1.12
```

### Interfaccia web TrueNAS

- HTTP:  http://192.168.1.12
- HTTPS: https://192.168.1.12

### Wake-on-LAN

MAC da usare: `e8:de:27:a6:a7:51`

```bash
# dal Mac, nella cartella del repo
python3 scripts/wol_truenas.py e8:de:27:a6:a7:51

# oppure con variabile d'ambiente
TRUENAS_MAC=e8:de:27:a6:a7:51 python3 scripts/wol_truenas.py
```

Requisiti: WOL abilitato nel BIOS e scheda di rete collegata via cavo Ethernet.

## App installate (TrueNAS Apps)

Dopo l'avvio del NAS le app impiegano alcuni minuti per inizializzarsi (`INITIALIZING` → `RUNNING`).

| App | Porta web | URL |
|-----|-----------|-----|
| **Home Assistant** | `20810` | http://192.168.1.12:20810 |
| **Plex** | `32400` | http://192.168.1.12:32400/web |
| **Immich** | `30041` | http://192.168.1.12:30041 |
| **qBittorrent** | `30024` | http://192.168.1.12:30024 |
| **FileBrowser** | `30051` | http://192.168.1.12:30051 |

Note:

- **Home Assistant**: la porta esterna su TrueNAS è **20810**, non 8123 (8123 è la porta interna del container).
- **Plex**: nome server `PlexTNScale`. Per dispositivi che non trovano il server in LAN, aggiungere URL personalizzato `http://192.168.1.12:32400` nelle impostazioni rete Plex.

### Avvio app da SSH

```bash
ssh root@truenas.local 'midclt call app.start home-assistant'
ssh root@truenas.local 'midclt call app.start plex'
```

### Emulated Hue (Alexa LAN)

| Parametro | Valore |
|-----------|--------|
| **Bridge URL** | http://192.168.1.12:8300 |
| **Config** | `home-assistant/packages/emulated_hue.yaml` |
| **Dispositivi esposti** | Accendi NAS, Spegni NAS, Riavvia NAS |

Setup Alexa: app Alexa → Aggiungi dispositivo → Philips Hue → IP `192.168.1.12`, porta `8300`.

### Home Assistant — API

| Parametro | Valore |
|-----------|--------|
| **URL** | http://192.168.1.12:20810 |
| **Location** | Casa |
| **Versione HA** | 2025.9.3 |
| **Entità** | ~202 |
| **Token** | `.env` → `HA_TOKEN` (client: `Cursor TrueNAS Session`) |

```bash
curl -H "Authorization: Bearer $HA_TOKEN" http://192.168.1.12:20810/api/states
scripts/ha_api.sh /api/config
```

### Home Assistant — integrazioni custom

| Integrazione | Versione | Stato (2026-07-13) |
|--------------|----------|---------------------|
| Meross LAN | 5.8.0 | OK |
| HACS | 2.0.5 | OK |
| Sonoff LAN | (HACS) | Parziale (cloud WS) |
| Tuya | core | **Token scaduto** — riconfigurare in UI |

## Share principali (`/mnt/Share`)

| Cartella | Uso |
|----------|-----|
| `SerieTV` | Libreria serie TV (script `reorg_serietv.py`) |
| `Downloads` | Download |
| `Plex` | Media Plex |
| `Music` | Musica |
| `Foto` / `Videos` / `Video` | Media vari |
| `Backup` / `Time Cap` | Backup |
| `NAS` / `Mauro` / `Albums` / `Ebooks` | Uso generale |

> **TimeMachine rimosso** (2026-07-13): dataset e share SMB eliminati. Backup Mac → Time Capsule esterna.

## Storage

| Pool | Usato | Disponibile | Stato |
|------|-------|-------------|-------|
| `Share` | 2.64T | **~888G** | OK |
| `boot-pool` | ~62G | ~154G | OK |

## Container Incus

| Nome | IP | Stato |
|------|-----|-------|
| `Ubuntu` | `10.186.253.240` | RUNNING |

## Stato ultimo controllo

**2026-07-13 ~01:51**

| Controllo | Esito |
|-----------|-------|
| Ping | OK |
| SSH | OK |
| Web TrueNAS | OK |
| Pool `Share` | **~888G liberi** |
| Docker | RUNNING |
| App platform | RUNNING |
| Home Assistant `:20810` | OK (HTTP 200) |
| Plex `:32400` | OK (HTTP 200) |
| Immich `:30041` | RUNNING |
| qBittorrent `:30024` | RUNNING |
| FileBrowser `:30051` | RUNNING |

### TimeMachine — rimosso

- Eliminato dataset `Share/TimeMachine` (backup `Mac mini.sparsebundle` + snapshot `@aapltm-*`)
- Rimossa share SMB `TimeMachine` (TIMEMACHINE_SHARE)
- Spazio recuperato: ~670G (+ snapshot)
- Backup Mac: migrare su **Time Capsule esterna**

## Verifica connettività rapida

```bash
ping -c 2 192.168.1.12
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.12:20810/
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.12:32400/identity
ssh root@truenas.local 'midclt call docker.status'
```

## Script nel repo

| Script | Descrizione |
|--------|-------------|
| `scripts/nas_status.sh` | Stato NAS (ping, porte, servizi) |
| `scripts/nas_wol.sh` | Accensione via Wake-on-LAN |
| `scripts/nas_shutdown.sh` | Spegnimento via SSH |
| `scripts/nas_reboot.sh` | Riavvio via SSH |
| `scripts/nas_common.sh` | Config condivisa (IP, MAC, SSH) |
| `scripts/reorg_serietv.py` | Riorganizza SerieTV per stagione |
| `scripts/wol_truenas.py` | Invia pacchetto WOL (low-level) |
| `scripts/ha_api.sh` | Chiamate API Home Assistant |
| `scripts/ha_token.sh` | Rigenera JWT Home Assistant |
