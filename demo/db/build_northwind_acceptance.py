#!/usr/bin/env python3
"""Build a separate canonical-sized Northwind DB for GUI acceptance.

The default output is northwind_acceptance.db beside this script. Existing
outputs are never overwritten. The upstream SQL revision and SHA-256 hashes
are pinned so the generated sample is reproducible and does not inherit local
changes from northwind.db.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path
from urllib.request import Request, urlopen


UPSTREAM_COMMIT = "4f56e7f5906dfd23b25244c5bfe8fb5da6402efd"
UPSTREAM_BASE = (
    "https://raw.githubusercontent.com/jpwhite3/northwind-SQLite3/"
    + UPSTREAM_COMMIT
    + "/src/"
)
SOURCE_SHA256 = {
    "create.sql": "5854B536DEA3FE8C586223BF7B47A793727DD44C34FC32537A68A97FEC8E2F4B",
    "update.sql": "59DF0F3C88B1878946B712CC6E8A7F37C971C802FF2ED611C59FEB72ACB39EA6",
    "report.sql": "48763558F205A0F30B3F36C5FE818B0F017B868FF3187432AA08046F021522BB",
}
EXPECTED_COUNTS = {
    "Customers": 93,
    "Orders": 830,
    "Order Details": 2155,
    "Products": 77,
    "Categories": 8,
}
EXPECTED_JOIN_ROWS = 2155


def fetch_source(filename: str, source_dir: Path | None) -> str:
    if source_dir is None:
        request = Request(
            UPSTREAM_BASE + filename,
            headers={"User-Agent": "VittixReport-demo-acceptance-builder"},
        )
        with urlopen(request, timeout=30) as response:
            content = response.read()
    else:
        content = (source_dir / filename).read_bytes()
    actual = hashlib.sha256(content).hexdigest().upper()
    if actual != SOURCE_SHA256[filename]:
        raise RuntimeError(
            f"Pinned source hash mismatch for {filename}: {actual}"
        )
    return content.decode("utf-8-sig")


def verify_database(connection: sqlite3.Connection) -> dict[str, int]:
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if integrity != "ok":
        raise RuntimeError(f"SQLite integrity_check failed: {integrity}")

    counts = {
        table: connection.execute(
            f'SELECT COUNT(*) FROM "{table}"'
        ).fetchone()[0]
        for table in EXPECTED_COUNTS
    }
    if counts != EXPECTED_COUNTS:
        raise RuntimeError(f"Unexpected canonical table counts: {counts}")

    joined_rows = connection.execute(
        'SELECT COUNT(*) '
        'FROM Orders o '
        'JOIN Customers c ON c.CustomerID = o.CustomerID '
        'JOIN "Order Details" od ON od.OrderID = o.OrderID '
        'JOIN Products p ON p.ProductID = od.ProductID '
        'LEFT JOIN Categories cat ON cat.CategoryID = p.CategoryID'
    ).fetchone()[0]
    if joined_rows != EXPECTED_JOIN_ROWS:
        raise RuntimeError(
            f"Unexpected Master-Detail-SubDetail query count: {joined_rows}"
        )
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).with_name("northwind_acceptance.db"),
        help="new output DB path (must not already exist)",
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="use previously downloaded pinned SQL files from this directory",
    )
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output.exists():
        parser.error(f"refusing to overwrite existing database: {output}")

    output.parent.mkdir(parents=True, exist_ok=True)
    fd, build_name = tempfile.mkstemp(
        prefix=output.stem + ".building.", suffix=".db", dir=tempfile.gettempdir()
    )
    os.close(fd)
    build_temp = Path(build_name)
    publish_temp: Path | None = None

    try:
        connection = sqlite3.connect(str(build_temp))
        try:
            for filename in ("create.sql", "update.sql", "report.sql"):
                connection.executescript(
                    fetch_source(filename, args.source_dir.expanduser().resolve()
                                 if args.source_dir else None)
                )
            counts = verify_database(connection)
        finally:
            connection.close()

        # Hard-link publication is atomic and fails rather than replacing a
        # database that another process created after the initial existence test.
        # Build in the system temp directory first so antivirus/indexing of an
        # application's data folder does not slow the many SQLite inserts.
        fd, publish_name = tempfile.mkstemp(
            prefix=output.stem + ".publish.", suffix=".db", dir=output.parent
        )
        os.close(fd)
        publish_temp = Path(publish_name)
        shutil.copyfile(build_temp, publish_temp)
        os.link(publish_temp, output)
        publish_temp.unlink()
    finally:
        if publish_temp is not None and publish_temp.exists():
            publish_temp.unlink()
        if build_temp.exists():
            build_temp.unlink()

    output_hash = hashlib.sha256(output.read_bytes()).hexdigest().upper()
    print(f"Source: jpwhite3/northwind-SQLite3 @ {UPSTREAM_COMMIT}")
    print(f"Output: {output}")
    for table, count in counts.items():
        print(f"{table}: {count}")
    print(f"Master-Detail-SubDetail joined rows: {EXPECTED_JOIN_ROWS}")
    print(f"SHA-256: {output_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
