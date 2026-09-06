#!/usr/bin/env python3
"""Write-only HTTP event sink for the fixed local package-lab beacon."""

from __future__ import annotations

import argparse
import json
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


class BeaconHandler(BaseHTTPRequestHandler):
    server_version = "PackageLabBeacon/1.0"

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler API
        source_ip = self.client_address[0]
        parsed = urlsplit(self.path)
        if parsed.path != "/apt-event":
            self.send_error(404)
            return

        values = parse_qs(parsed.query, keep_blank_values=True)
        record = {
            "received_utc": datetime.now(timezone.utc).isoformat(),
            "source_ip": source_ip,
            "event": values.get("event", ["unknown"])[0][:80],
            "host": values.get("host", ["unknown"])[0][:128],
            "uid": values.get("uid", ["unknown"])[0][:20],
            "euid": values.get("euid", ["unknown"])[0][:20],
            "epoch_seconds": values.get("epoch", ["unknown"])[0][:32],
            "fixture": values.get("fixture", ["unknown"])[0][:80],
        }
        line = json.dumps(record, sort_keys=True)
        # DEBUG_ONLY_JSON_ARTIFACT: remove JSONL evidence storage for production builds.
        with self.server.log_lock:
            with self.server.log_path.open("a", encoding="utf-8") as handle:
                handle.write(line + "\n")
        print(line, flush=True)

        self.send_response(204)
        self.end_headers()

    def log_message(self, _format: str, *_args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", default="192.168.88.20")
    parser.add_argument("--port", type=int, default=8088)
    parser.add_argument("--log", type=Path, required=True)
    args = parser.parse_args()

    args.log.parent.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((args.listen, args.port), BeaconHandler)
    server.log_path = args.log
    server.log_lock = threading.Lock()
    print(
        f"listening=http://{args.listen}:{args.port}/apt-event log={args.log}",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
