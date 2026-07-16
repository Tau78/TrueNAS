# Installare Tailscale su TrueNAS SCALE

Guida per installare l'app **Tailscale** ufficiale dal catalogo TrueNAS e accedere al NAS da remoto in modo sicuro.

> Richiede **TrueNAS SCALE** (24.10 o successivo). Su TrueNAS Core non è disponibile l'app catalogo; serve un jail FreeBSD (non coperto da questa guida).

## 1. Genera una Auth Key Tailscale

1. Accedi a [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Clicca **Generate auth key**
3. Assegna una descrizione (es. `truenas`)
4. (Consigliato) Attiva **Reusable** se reinstalli spesso
5. Copia la chiave (`tskey-auth-...`) — non sarà più visibile dopo

## 2. Installazione via interfaccia web (consigliata)

1. Apri la UI TrueNAS → **Apps** → **Discover Apps**
2. Se non vedi le app, clicca **Refresh Catalog**
3. Cerca **Tailscale** e clicca **Install**
4. Configura:
   - **Auth Key**: incolla la chiave generata al passo 1
   - **Hostname**: es. `truenas-scale` (solo minuscole, numeri e trattini)
   - **Userspace**: attiva ✓ (consigliato per uso standard)
   - **Host Network**: attiva ✓ (necessario per raggiungere UI e altre app via IP Tailscale)
5. Clicca **Install** e attendi stato **Running**
6. Verifica su [Machines](https://login.tailscale.com/admin/machines) che il nodo sia online

### Accesso remoto

Dal dispositivo con Tailscale installato, apri nel browser:

```
https://<IP-100.x.x.x>
```

L'IP `100.x.x.x` è visibile nella console Tailscale accanto al nodo TrueNAS.

## 3. Installazione automatica via script

Lo script `scripts/install_tailscale.sh` usa l'API TrueNAS (`midclt`) per installare o aggiornare l'app.

### Copia lo script sul server

```bash
scp scripts/install_tailscale.sh root@truenas.local:/mnt/Share/Downloads/scripts/
```

### Esecuzione sul server

```bash
ssh root@truenas.local

export TS_AUTHKEY='tskey-auth-XXXXXXXX'
bash /mnt/Share/Downloads/scripts/install_tailscale.sh
```

### Esecuzione remota (senza copiare il file)

```bash
TS_AUTHKEY='tskey-auth-XXXXXXXX' ssh -o BatchMode=yes root@truenas.local \
  'bash -s' < scripts/install_tailscale.sh
```

### Opzioni avanzate

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `TS_HOSTNAME` | `truenas-scale` | Nome del nodo nel tailnet |
| `TS_USERSPACE` | `true` | Networking userspace |
| `TS_HOST_NETWORK` | `true` | Condivide la rete dell'host |
| `TS_ACCEPT_DNS` | `false` | Accetta DNS Tailscale |
| `TS_ACCEPT_ROUTES` | `false` | Accetta route subnet da altri nodi |
| `TS_ADVERTISE_ROUTES` | — | Subnet da esporre, es. `192.168.1.0/24` |
| `TS_ADVERTISE_EXIT_NODE` | `false` | Pubblica TrueNAS come exit node |
| `TZ` | `Europe/Rome` | Timezone dell'app |

Esempio con subnet router:

```bash
export TS_AUTHKEY='tskey-auth-XXXXXXXX'
export TS_ADVERTISE_ROUTES='192.168.1.0/24'
export TS_USERSPACE='false'
export TS_HOST_NETWORK='true'
bash /mnt/Share/Downloads/scripts/install_tailscale.sh
```

Dopo l'installazione, approva le subnet in [Tailscale Admin](https://login.tailscale.com/admin/machines) → nodo TrueNAS → **Edit route settings**.

## 4. Risoluzione problemi

| Problema | Soluzione |
|----------|-----------|
| App in loop Deploying/Stopped | Genera una **nuova** auth key e reinstalla |
| `invalid key: API key does not exist` | La chiave è scaduta o già usata; creane una nuova |
| App non nel catalogo | Apps → **Refresh Catalog**; verifica DNS e ora di sistema (UTC) |
| UI raggiungibile ma non le altre app | Attiva **Host Network** nell'app Tailscale |
| Replica ZFS tra due TrueNAS | Disattiva Userspace, attiva Host Network; vedi [doc Tailscale](https://tailscale.com/docs/integrations/truenas) |

## Riferimenti

- [TrueNAS – Accesso remoto](https://cdn.truenas.com/docs/solutions/remoteaccess/)
- [Tailscale – TrueNAS SCALE](https://tailscale.com/docs/integrations/truenas)
