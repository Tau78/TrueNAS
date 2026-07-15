# Alexa + TrueNAS dal Mac Mini (rete locale)

Guida per continuare dal Mac Mini connesso alla stessa rete di TrueNAS ed Echo.

## Prerequisiti sul Mac Mini

```bash
git clone https://github.com/Tau78/TrueNAS.git && cd TrueNAS   # oppure git pull
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

Alexa non può spegnere TrueNAS da sola. **"Invia richiesta web" non esiste** nell'app Alexa italiana — usa invece il bridge Hue già configurato su TrueNAS.

### Soluzione consigliata: Emulated Hue (già attivo)

Bridge Hue su `http://192.168.1.12:8300`. Espone **Spegni NAS**, **Accendi NAS**, **Riavvia NAS** come luci Philips Hue.

```
Voce "spegni nas" → Routine Alexa → Casa intelligente → Spegni NAS → Accendi → HA → SSH → TrueNAS shutdown
```

#### Setup routine (5 minuti)

> **Se il wizard Philips Hue chiede di installare l'app Hue → esci.** È un vicolo cieco per bridge virtuali.

1. **Scopri dispositivi** (percorso corretto, **non** Philips Hue):

   | Passo | Cosa fare |
   |-------|-----------|
   | 1 | App Alexa → **Dispositivi** → **+** |
   | 2 | Scorri in basso → **Altri** (o *Altro*) |
   | 3 | **Scopri dispositivi** |
   | 4 | Attendi 30–60 s |

   **Alternativa vocale:** *"Alexa, scopri i miei dispositivi"* (spesso funziona meglio dell'app).

   > Alexa moderna richiede bridge su **porta 80**. Sul NAS: `scripts/ha_alexa_hue_port80.sh`

2. **Verifica** che compaiano *Accendi NAS*, *Spegni NAS*, *Riavvia NAS*:
   - App Alexa → **Dispositivi** → cerca **NAS** o **Spegni**

3. **Crea routine "Spegni NAS"**:
   - App Alexa → **Routine** → **Crea**
   - **Quando**: *Chiunque dice* → `spegni nas`
   - **Azione**: **Controllo dispositivo intelligente** (o *Casa intelligente*)
     - Dispositivo: **Spegni NAS**
     - Azione: **Accendi** (gli switch one-shot in HA si attivano con "on")
   - Salva

3. **Prova**: *"Alexa, spegni nas"*

Verifica bridge: `curl http://192.168.1.12:8300/description.xml`

> Gli switch NAS sono *one-shot*: ogni "accendi" esegue lo script e torna subito off. Non serve "spegni Spegni NAS" — basta la routine sopra.

#### Comandi vocali diretti (senza routine)

Se i dispositivi Hue sono scoperti, funzionano anche senza routine:

| Comando | Effetto |
|---------|---------|
| *"Alexa, accendi Accendi NAS"* | Wake-on-LAN |
| *"Alexa, accendi Spegni NAS"* | Shutdown |
| *"Alexa, accendi Riavvia NAS"* | Reboot |

---

### Alternativa: webhook Mac Mini (solo se serve SSH dal Mac)

Il webhook sul Mac Mini resta utile per automazioni esterne (script, cron, altri servizi), **non** per Alexa diretta senza skill a pagamento.

```bash
python3 scripts/alexa_webhook.py
curl "http://127.0.0.1:8765/health"
```

Per collegarlo ad Alexa servirebbe una skill intermedia (es. Voice Monkey, Virtual Buttons) — più complesso dell'opzione Hue sopra.

---

### Sicurezza

- Gli switch NAS sono solo in LAN (Emulated Hue non è esposto su internet)
- Non committare `.env`

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
