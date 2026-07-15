#!/usr/bin/env bash
# Espone Emulated Hue su porta 80 (richiesta Alexa moderna).
# Proxy nginx TrueNAS: /description.xml e /api/* → 127.0.0.1:8300
set -euo pipefail

REMOTE="${TRUENAS_SSH:-root@truenas.local}"
NGINX="/etc/nginx/nginx.conf"
MARKER="# hue-bridge-emulated-hue"

if ssh -o BatchMode=yes "$REMOTE" "grep -q '${MARKER}' ${NGINX}"; then
  echo "Proxy Hue su porta 80 già presente."
else
  echo "→ Patch nginx porta 80..."
  ssh -o BatchMode=yes "$REMOTE" 'python3 - <<'"'"'PY'"'"'
from pathlib import Path
path = Path("/etc/nginx/nginx.conf")
marker = "# hue-bridge-emulated-hue"
text = path.read_text()
insert = """        # hue-bridge-emulated-hue
        location = /description.xml {
            proxy_pass http://127.0.0.1:8300/description.xml;
            proxy_set_header Host $host;
        }
        location ^~ /api/ {
            proxy_pass http://127.0.0.1:8300/api/;
            proxy_set_header Host $host;
        }
"""
old = """        server_name localhost;
        return 307 https://$host:443$request_uri;"""
new = """        server_name localhost;
""" + insert + """
        location / {
            return 307 https://$host:443$request_uri;
        }"""
if marker in text:
    raise SystemExit(0)
if old not in text:
    raise SystemExit("nginx.conf: blocco porta 80 non trovato")
path.write_text(text.replace(old, new))
PY'
  ssh -o BatchMode=yes "$REMOTE" "nginx -t && systemctl reload nginx"
  echo "Nginx ricaricato."
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/ha_deploy_packages.sh"

echo "Verifica:"
curl -sf "http://192.168.1.12:80/description.xml" | head -3
echo "OK — ora in Alexa: Dispositivi → + → Altri → Scopri dispositivi"
