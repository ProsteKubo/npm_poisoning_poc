#!/usr/bin/env python3
"""Visible, fixed-destination root-state heartbeat for the competition lab."""

import os
import platform
import socket
import stat
import time
from pathlib import Path
from urllib.parse import urlencode


STATE_PATH = Path("/var/lib/package-lab/root-stage-observed")
DESTINATION = ("192.168.88.20", 8088)


def state_is_valid() -> bool:
    try:
        details = STATE_PATH.stat()
    except FileNotFoundError:
        return False
    return details.st_uid == 0 and stat.S_IMODE(details.st_mode) == 0o600


def send_heartbeat() -> None:
    fields = urlencode(
        {
            "event": "root-persistence-alive",
            "host": platform.node(),
            "uid": os.getuid(),
            "euid": os.geteuid(),
            "epoch": int(time.time()),
            "fixture": "package-lab-visible-root-state-1.1",
        }
    )
    request = (
        f"GET /apt-event?{fields} HTTP/1.1\r\n"
        "Host: 192.168.88.20:8088\r\n"
        "Connection: close\r\n\r\n"
    ).encode("ascii", "strict")
    try:
        with socket.create_connection(DESTINATION, timeout=0.5) as channel:
            channel.sendall(request)
    except OSError:
        pass


def main() -> None:
    while state_is_valid():
        send_heartbeat()
        for _ in range(30):
            if not state_is_valid():
                return
            time.sleep(1)


if __name__ == "__main__":
    main()
