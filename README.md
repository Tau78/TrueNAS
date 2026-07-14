# TrueNAS

Script e utilità per la gestione del server TrueNAS domestico.

## Script

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

## Alexa + Mac Mini (rete locale)

Per Echo Show cucina / routine Cancello e comando vocale **spegni nas**, vedi
[`docs/alexa-mac-mini.md`](docs/alexa-mac-mini.md).

Script utili sul Mac Mini:

```bash
./scripts/diagnostica_rete.sh
./scripts/spegni_nas.sh --dry-run
cp .env.example .env && python3 scripts/alexa_webhook.py
```
