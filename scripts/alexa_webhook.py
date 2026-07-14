#!/usr/bin/env python3
"""
Webhook locale per routine Alexa (es. "spegni nas").
Avvia sul Mac Mini: python3 scripts/alexa_webhook.py
Configura .env da .env.example.
"""

from __future__ import annotations

import logging
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_SPEGNI = REPO_ROOT / "scripts" / "spegni_nas.sh"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("alexa_webhook")


def load_dotenv() -> None:
    env_file = REPO_ROOT / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


def check_token(path: str, headers: dict[str, str], body: bytes) -> bool:
    expected = os.environ.get("WEBHOOK_TOKEN", "")
    if not expected:
        log.error("WEBHOOK_TOKEN non impostato in .env")
        return False

    query = parse_qs(urlparse(path).query)
    if query.get("token", [None])[0] == expected:
        return True

    auth = headers.get("Authorization", "")
    if auth == f"Bearer {expected}":
        return True

    if body.decode("utf-8", errors="ignore").strip() == expected:
        return True

    return False


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        log.info("%s - %s", self.address_string(), fmt % args)

    def _reject(self, code: int, msg: str) -> None:
        body = msg.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _handle_shutdown(self) -> None:
        if not SCRIPT_SPEGNI.exists():
            self._reject(500, "Script spegni_nas.sh non trovato")
            return

        try:
            subprocess.Popen(
                ["/bin/bash", str(SCRIPT_SPEGNI)],
                cwd=REPO_ROOT,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError as exc:
            log.exception("Esecuzione spegni_nas fallita")
            self._reject(500, f"Errore: {exc}")
            return

        self._reject(200, "Shutdown TrueNAS avviato")

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path not in ("/shutdown", "/health"):
            self._reject(404, "Not found")
            return

        if parsed.path == "/health":
            self._reject(200, "ok")
            return

        if not check_token(self.path, dict(self.headers), b""):
            self._reject(403, "Token non valido")
            return

        self._handle_shutdown()

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""

        parsed = urlparse(self.path)
        if parsed.path != "/shutdown":
            self._reject(404, "Not found")
            return

        if not check_token(self.path, dict(self.headers), body):
            self._reject(403, "Token non valido")
            return

        self._handle_shutdown()


def main() -> int:
    load_dotenv()
    host = os.environ.get("WEBHOOK_HOST", "0.0.0.0")
    port = int(os.environ.get("WEBHOOK_PORT", "8765"))

    if not SCRIPT_SPEGNI.exists():
        log.error("Manca %s", SCRIPT_SPEGNI)
        return 1

    server = HTTPServer((host, port), Handler)
    log.info("Webhook in ascolto su http://%s:%s", host, port)
    log.info("Health: GET /health | Shutdown: GET/POST /shutdown?token=...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Arresto.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
