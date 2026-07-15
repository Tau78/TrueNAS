#!/usr/bin/env python3
"""Send Wake-on-LAN magic packet to TrueNAS."""

import os
import socket
import sys

MAC = os.environ.get("TRUENAS_MAC", "")
BROADCAST = os.environ.get("WOL_BROADCAST", "255.255.255.255")
PORT = int(os.environ.get("WOL_PORT", "9"))


def mac_to_bytes(mac: str) -> bytes:
    mac = mac.replace("-", ":").lower()
    parts = mac.split(":")
    if len(parts) != 6:
        raise ValueError(f"MAC non valido: {mac}")
    return bytes(int(p, 16) for p in parts)


def send_wol(mac: str, broadcast: str = BROADCAST, port: int = PORT) -> None:
    payload = b"\xff" * 6 + mac_to_bytes(mac) * 16
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(payload, (broadcast, port))
    print(f"WOL inviato a {mac} via {broadcast}:{port}")


if __name__ == "__main__":
    mac = sys.argv[1] if len(sys.argv) > 1 else MAC
    if not mac:
        print("Uso: TRUENAS_MAC=aa:bb:cc:dd:ee:ff python3 scripts/wol_truenas.py", file=sys.stderr)
        print("  oppure: python3 scripts/wol_truenas.py aa:bb:cc:dd:ee:ff", file=sys.stderr)
        sys.exit(1)
    send_wol(mac)
