#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path


def timestamp(event):
    return str(
        event.get("timestamp_utc")
        or event.get("started_utc")
        or event.get("epoch_seconds")
        or ""
    )


def main():
    root = Path(sys.argv[1])
    rows = []
    for path in sorted(root.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        events = data if isinstance(data, list) else [data]
        for event in events:
            if isinstance(event, dict) and event.get("event"):
                rows.append(
                    {
                        "timestamp": timestamp(event),
                        "event": event["event"],
                        "source": str(path.relative_to(root)),
                        "details": json.dumps(event, sort_keys=True),
                    }
                )
    rows.sort(key=lambda row: row["timestamp"])
    output = root / "timeline.csv"
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["timestamp", "event", "source", "details"])
        writer.writeheader()
        writer.writerows(rows)
    print(output)


if __name__ == "__main__":
    main()

