# Alexa + TrueNAS dal Mac Mini (rete locale)

Guida per continuare dal Mac Mini connesso alla stessa rete di TrueNAS ed Echo.

## Prerequisiti sul Mac Mini

```bash
git clone <repo> && cd TrueNAS   # oppure git pull
cp .env.example .env             # imposta WEBHOOK_TOKEN
chmod +x scripts/spegni_nas.sh scripts/diagnostica_rete.sh
```

SSH senza password verso TrueNAS:

```bash
ssh-copy-id root@truenas.local
ssh -o BatchMode=yes root@truenas.local 'hostname'
```

---

## Problema 1: Echo Show cucina non risponde a "Cancello"

La routine (senza filtri dispositivo) comanda **TienimiChiusoo** con impulso on/off.

### Test locale (5 minuti)

1. Nell'app Alexa, spegni il microfono su **tutti gli Echo tranne la Show cucina**
2. Di': *"Alexa, cancello"* (e anche *"apri cancello"* se l'hai aggiunto alle frasi)
3. App Alexa → **Attività**: annota quale dispositivo ha registrato il comando

| Attività | Diagnosi |
|----------|----------|
| Routine da **Show cucina** | OK: prima un altro Echo intercettava |
| Routine da **altro Echo** | Intercettazione: usa frase dedicata o mic spenti altrove |
| **Nessuna voce** | Mic Show cucina, volume, offline o firmware |

### Fix consigliati

- Aggiungi al trigger: `apri cancello`, `apri il cancello`
- Ultima azione routine: **Alexa dice** → "Cancello aperto" (capisci subito chi risponde)
- Riavvia Show cucina dall'app se offline

---

## Problema 2: "Spegni NAS" non funziona

Alexa non può spegnere TrueNAS da sola. Serve un ponte dal Mac Mini.

### Architettura

```
Voce "spegni nas" → Routine Alexa → Richiesta web → Mac Mini (webhook) → SSH → TrueNAS shutdown
```

### 1. Avvia webhook sul Mac Mini

```bash
python3 scripts/alexa_webhook.py
```

Test locale:

```bash
curl "http://127.0.0.1:8765/health"
curl "http://127.0.0.1:8765/shutdown?token=IL_TUO_TOKEN"   # dry-run consigliato prima con spegni_nas.sh --dry-run
```

### 2. Esposizione ad Alexa

Alexa deve raggiungere il Mac Mini. Opzioni:

**A) Stessa rete + IP fisso Mac Mini** (se la routine supporta URL LAN):

- Trova IP: `ipconfig getifaddr en0`
- URL routine: `http://192.168.x.x:8765/shutdown?token=...`
- Nota: molte routine Alexa richiedono **HTTPS**; in quel caso usa tunnel (opzione B)

**B) Tunnel HTTPS (consigliato)** — es. Tailscale Funnel, Cloudflare Tunnel, ngrok:

```bash
# Esempio ngrok (installare ngrok sul Mac)
ngrok http 8765
# Usa l'URL https://....ngrok.io/shutdown?token=...
```

### 3. Routine Alexa "Spegni NAS"

1. App Alexa → **Routine** → Crea
2. **Quando**: "Chiunque dice" → `spegni nas`
3. **Azione**: **Invia richiesta web** (o "Webhook" / "Custom")
   - Metodo: GET o POST
   - URL: `https://<tuo-tunnel>/shutdown?token=<WEBHOOK_TOKEN>`
4. Salva e prova vicino a un Echo

### 4. Sicurezza

- Usa token lungo e casuale in `.env`
- Non committare `.env`
- Valuta IP allowlist sul router o solo Tailscale

---

## Diagnostica rapida

```bash
./scripts/diagnostica_rete.sh
./scripts/spegni_nas.sh --dry-run
```

---

## Avvio automatico webhook (opzionale)

Su macOS, crea `~/Library/LaunchAgents/com.truenas.alexa-webhook.plist` che esegue
`python3 /percorso/repo/scripts/alexa_webhook.py` al login.
