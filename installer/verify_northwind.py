"""Verify release Northwind bytes, allowing only SQLite writer-version metadata."""
import hashlib
from pathlib import Path

# Keep acceptance of the original audited artifact.
AUDITED_SHA256 = '324f1362b2f4fead11ab4f5a5667a57226b61af5a39c22f480011502dc109185'
# Independently rebuilt from build_northwind_acceptance.py's hash-pinned SQL
# (upstream 4f56e7f5906dfd23b25244c5bfe8fb5da6402efd), using SQLite 3.45.1
# and 3.50.4. All bytes match except the last-writer version at offsets 96..99:
# https://sqlite.org/fileformat2.html#write_library_version_number_and_version_valid_for_number
NORMALIZED_SHA256 = '8828e6b4e954aadca9be71b6893b51452ff3efa343c06825c2043f27742ffd9d'


def verify_northwind(path: Path) -> None:
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() == AUDITED_SHA256:
        return
    normalized = data[:96] + b'\x00' * 4 + data[100:]
    if len(data) < 100 or hashlib.sha256(normalized).hexdigest() != NORMALIZED_SHA256:
        raise ValueError('Unexpected Northwind sample bytes')
