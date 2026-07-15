# TrueNAS

Script e utilità per la gestione del server TrueNAS domestico.

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
