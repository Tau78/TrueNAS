# TrueNAS

Ambiente di lavoro Cursor dedicato al server **TrueNAS Scale** di casa.

## Scopo di questa sessione

Questo workspace — sessione **TrueNAS** — serve a **pilotare, configurare e mappare** il NAS con indirizzo:

```
192.168.1.12/24
```

Da qui l'agente può:

- connettersi via SSH al server e agire su file, share e servizi
- documentare rete, app, porte e parametri operativi
- eseguire script di automazione (WOL, riorganizzazione media, ecc.)
- verificare lo stato dei servizi e delle app TrueNAS
- in futuro: controllare Home Assistant e altri servizi via API
- **accendere, spegnere e riavviare** il NAS da script
- **pilotare Home Assistant** via API (token in `.env`)

Inventario completo e parametri di rete: **[TRUENAS.md](TRUENAS.md)**

---

## Mappa rapida NAS

| Parametro | Valore |
|-----------|--------|
| **IP / subnet** | `192.168.1.12/24` |
| **Hostname** | `truenas` |
| **mDNS** | `truenas.local` |
| **Gateway** | `192.168.1.1` |
| **Interfaccia** | `enp4s0` |
| **MAC (WOL)** | `e8:de:27:a6:a7:51` |
| **OS** | TrueNAS Scale `25.10.3.1` |
| **SSH** | `root@truenas.local` |
| **Web UI** | http://192.168.1.12 · https://192.168.1.12 |
| **Emulated Hue (Alexa)** | http://192.168.1.12:8300 |
| **Timezone** | `Europe/Rome` |

## App e servizi

| Servizio | Porta | URL |
|----------|-------|-----|
| Home Assistant | `20810` | http://192.168.1.12:20810 |
| Plex (`PlexTNScale`) | `32400` | http://192.168.1.12:32400/web |
| Immich | `30041` | http://192.168.1.12:30041 |
| qBittorrent | `30024` | http://192.168.1.12:30024 |
| FileBrowser | `30051` | http://192.168.1.12:30051 |

> Home Assistant espone la porta **20810** su TrueNAS (8123 è solo la porta interna del container).

## Home Assistant — integrazioni

**2026-07-13 ~22:50** — intervento su Meross, HACS e Tuya.

| Integrazione | Stato | Azione |
|--------------|-------|--------|
| **Meross LAN** | OK | Aggiornato a **v5.8.0** (fix paho-mqtt 2.x). Entità Lavandino operative dopo reload. |
| **HACS** | OK | Aggiornato a **v2.0.5**; rimosso repo duplicato `music-assistant/hass-music-assistant`. |
| **Tuya** | **Da rifare login** | Token scaduto (`tau.yo@libero.it`). In HA: Impostazioni → Dispositivi → Tuya → **Riconfigura**. |

> Meross e Tuya richiedono credenziali cloud — non riconfigurabili da script senza password.

## NordVPN Meshnet (Casa → MusicPro)

TrueNAS **non permette** `apt` sull'host → NordVPN gira in **container Docker** (`nordvpn-meshnet`) con rete host.

**Setup (una volta):**

1. Genera token: [my.nordaccount.com](https://my.nordaccount.com/) → Meshnet → Advanced → **Get access token**
2. Aggiungi a `.env`: `NORDVPN_TOKEN=...`
3. Deploy:

```bash
scripts/nordvpn_meshnet_deploy.sh
```

**Dopo il deploy** (da telefono/PC con NordVPN + Meshnet):

- Abilita Meshnet sul client
- Sul NAS: `docker exec nordvpn-meshnet nordvpn meshnet peer local allow <nome-dispositivo>`
- Route traffic verso `truenas-meshnet` per raggiungere la LAN Casa (HA, telecamere, ecc.)

File: `docker/nordvpn-meshnet/` · dati persistenti: `/mnt/Share/NAS/nordvpn-meshnet/data` sul NAS.

## Stato ultimo controllo

**2026-07-13 ~22:50** — NAS operativo, integrazioni HA parzialmente ripristinate.

| Controllo | Esito |
|-----------|-------|
| Ping `192.168.1.12` | OK |
| SSH (22) | OK |
| Web TrueNAS (80/443) | OK |
| Pool `Share` | **~888 GB liberi** |
| Docker | **RUNNING** |
| App TrueNAS | **RUNNING** |
| Home Assistant `:20810` | **OK** (HTTP 200) |
| Plex `:32400` | **OK** (HTTP 200) |
| Immich `:30041` | RUNNING |
| qBittorrent `:30024` | RUNNING |
| FileBrowser `:30051` | RUNNING |

### Intervento effettuato

- Eliminato dataset `Share/TimeMachine` (~670G backup Mac + snapshot)
- Rimossa share SMB **TimeMachine** (id 17)
- Time Machine **non più disponibile su questo NAS** — backup spostati su Time Capsule esterna (da configurare)
- Docker riavviato, app ripartite

```bash
# verifica rapida
ping -c 2 192.168.1.12
curl -s -o /dev/null -w "HA: %{http_code}\n" http://192.168.1.12:20810/
curl -s -o /dev/null -w "Plex: %{http_code}\n" http://192.168.1.12:32400/identity
ssh root@truenas.local 'zfs list -o name,avail Share; midclt call docker.status'
```

## Share principali

Montate su `/mnt/Share`: `SerieTV`, `Downloads`, `Plex`, `Music`, `Foto`, `Videos`, `Backup`, `NAS`, `Mauro`, …

Pool dati: `Share` (2.64T usati, **~888G liberi**) · boot: `boot-pool` (216G, OK)

> **TimeMachine rimosso** dal NAS. Usare Time Capsule esterna per backup Mac.

---

## Tailscale (accesso remoto)

Per installare l'app Tailscale su TrueNAS SCALE e accedere al NAS da ovunque:

- Guida completa: [`docs/tailscale.md`](docs/tailscale.md)
- Script automatico: [`scripts/install_tailscale.sh`](scripts/install_tailscale.sh)

Installazione rapida via SSH:

```bash
TS_AUTHKEY='tskey-auth-...' ssh -o BatchMode=yes root@truenas.local \
  'bash -s' < scripts/install_tailscale.sh
```

## Script

### Gestione alimentazione NAS

| Script | Azione |
|--------|--------|
| `scripts/nas_status.sh` | Verifica ping, porte e servizi |
| `scripts/nas_wol.sh` | **Accende** il NAS (Wake-on-LAN) |
| `scripts/nas_shutdown.sh --yes` | **Spegne** il NAS |
| `scripts/nas_reboot.sh --yes` | **Riavvia** il NAS |

```bash
# Stato attuale
scripts/nas_status.sh

# Accendi (NAS spento, WOL abilitato in BIOS)
scripts/nas_wol.sh

# Spegni / riavvia (richiede --yes)
scripts/nas_shutdown.sh --yes
scripts/nas_reboot.sh --yes
```

Configurazione in `scripts/nas_common.sh` (IP, hostname, MAC). Override via env: `TRUENAS_IP`, `TRUENAS_MAC`, ecc.

### Home Assistant API

Token creato sul NAS (refresh token **Cursor TrueNAS Session**, valido ~10 anni). Salvato in **`.env`** (non committato).

```bash
# Test API
scripts/ha_api.sh /api/
scripts/ha_api.sh /api/states | python3 -m json.tool | head

# Rigenera JWT se scaduto
scripts/ha_token.sh
```

| Script | Descrizione |
|--------|-------------|
| `scripts/ha_api.sh` | Chiamate GET all'API HA |
| `scripts/ha_deploy_packages.sh` | Deploy packages + dashboard HA sul NAS |

### Comandi vocali Alexa (via Home Assistant)

Switch e script esposti in HA (`home-assistant/packages/nas_control.yaml`):

| Entità HA | Comando Alexa (esempio) |
|-----------|-------------------------|
| `switch.accendi_nas` | *"Alexa, accendi Accendi NAS"* |
| `switch.spegni_nas` | *"Alexa, spegni Spegni NAS"* |
| `switch.riavvia_nas` | *"Alexa, accendi Riavvia NAS"* |

**Setup Alexa — opzione A: Nabu Casa** (consigliato)

1. HA → Impostazioni → Home Assistant Cloud → collega account
2. Abilita Alexa → esponi i 3 switch NAS
3. App Alexa → Dispositivi → *Scopri dispositivi*

**Opzione B: Emulated Hue** (gratuito, LAN) — **configurato**

Bridge attivo su `http://192.168.1.12:8300`. Config: `home-assistant/packages/emulated_hue.yaml`.

**Setup Alexa (da fare una volta):**

> **Non usare** *Altro* → *Skill e giochi* → Philips Hue (chiede account cloud, non funziona con Emulated Hue).
> Se il wizard Hue chiede l'**app Philips Hue** → **esci**, è un vicolo cieco.

1. App **Alexa** → **Dispositivi** → **+** → scorri → **Altri** → **Scopri dispositivi**
2. Oppure di' *"Alexa, scopri i miei dispositivi"*
3. Attendi 30–60 s — compaiono *Accendi NAS*, *Spegni NAS*, *Riavvia NAS* come luci

Setup tecnico porta 80 (già applicato sul NAS): `scripts/ha_alexa_hue_port80.sh`

4. Dopo discovery, i dispositivi compaiono come luci:
   - *"Alexa, accendi Accendi NAS"*
   - *"Alexa, spegni Spegni NAS"*
   - *"Alexa, accendi Riavvia NAS"*

**Routine naturale "spegni nas"** (senza "Invia richiesta web", non disponibile in Italia):

1. App Alexa → **Routine** → **Crea**
2. **Quando**: *Chiunque dice* → `spegni nas`
3. **Azione**: **Controllo dispositivo intelligente** → **Spegni NAS** → **Accendi**

Guida completa: [docs/alexa-mac-mini.md](docs/alexa-mac-mini.md)

Verifica bridge: `curl http://192.168.1.12:8300/description.xml`

#### Se dopo "Hub" chiede login Philips o non trova nulla

| Sintomo | Cosa fare |
|---------|-----------|
| Chiede **email/password Philips** | Hai aperto la **skill** Hue, non l'aggiunta dispositivo. Torna indietro, usa **Dispositivi → + → Hub**. |
| **Nessun bridge trovato** | Prova *"Alexa, scopri i miei dispositivi"* vicino all'Echo. Attendi 1 minuto. |
| Ancora niente | Echo e NAS devono essere sulla **stessa rete** (`192.168.1.x`). |
| Echo nuovo (Show recente) | Alcuni modelli richiedono bridge su **porta 80** — oggi è su `8300`; se fallisce tutto, segnalalo per cambio configurazione. |

> Lo **stato NAS** resta su `scripts/nas_status.sh` — Alexa non è adatta a report tecnici.

### `scripts/reorg_serietv.py`

Riorganizza la libreria SerieTV su TrueNAS in cartelle per stagione (formato Plex/Jellyfin).

Esecuzione sul server:

```bash
ssh -o BatchMode=yes root@truenas.local 'python3 /mnt/Share/Downloads/scripts/reorg_serietv.py'
```

Simulazione (dry run):

```bash
DRY_RUN=true python3 scripts/reorg_serietv.py
```

### `scripts/wol_truenas.py`

Implementazione WOL (usata da `nas_wol.sh`):

```bash
python3 scripts/wol_truenas.py e8:de:27:a6:a7:51
```

### Git — mirror su TrueNAS (oltre a GitHub)

Oltre a `origin` (GitHub), il repo può avere un secondo remote **`nas`** su bare repo locale:

| Remote | URL |
|--------|-----|
| `origin` | `https://github.com/Tau78/TrueNAS.git` |
| `nas` | `root@truenas.local:/mnt/Share/NAS/git/TrueNAS.git` |

**Setup (una volta per macchina):**

```bash
chmod +x scripts/git_remote_nas_setup.sh scripts/git_push_all.sh
scripts/git_remote_nas_setup.sh
```

**Push su GitHub + NAS:**

```bash
scripts/git_push_all.sh
# oppure solo NAS: git push nas main
```

Prerequisito: SSH senza password verso `root@truenas.local` (`ssh-copy-id root@truenas.local`).

Override env: `GIT_NAS_ROOT`, `GIT_REMOTE_NAME`, `TRUENAS_SSH` (vedi `scripts/git_nas_common.sh`).
