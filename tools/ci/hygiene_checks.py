#!/usr/bin/env python3
"""Repository hygiene checks (compiler-independent, CI-safe).

Runs against a plain checkout. No Delphi, no network, no secrets.

Checks:
  1. Conflict-marker detection across tracked text files.
  2. Pascal BOM policy: every tracked .pas containing non-ASCII bytes must
     start with a UTF-8 BOM (repo policy since the encoding-normalization
     commits; pure-ASCII files have no BOM requirement).
  3. Secret regression scan (high-confidence patterns only, fixture-heavy
     directories excluded) and scratch-file path regression (paths that the
     repository has historically kept out of version control).

Exit codes: 0 = all checks passed, 1 = at least one finding.
"""

import re
import subprocess
import sys

# Binary-ish extensions skipped by the text scans.
TEXT_EXCLUDE_SUFFIXES = (
    ".exe", ".dll", ".bpl", ".dcp", ".res", ".png", ".jpg", ".jpeg", ".gif",
    ".ico", ".zip", ".7z", ".pdf", ".ttf", ".ttc", ".otf", ".mdb", ".fdb",
    ".dcu", ".chm", ".woff", ".woff2",
)

CONFLICT_PATTERNS = (
    re.compile(r"^<<<<<<< ", re.M),
    re.compile(r"^>>>>>>> ", re.M),
)

# High-confidence secret indicators only. Fixture-heavy trees (tests/, reports/)
# legitimately contain password strings, so the generic password regex is not
# applied there.
SECRET_PATTERNS = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), ()),
    (re.compile(r"AKIA[0-9A-Z]{16}"), ()),
    (re.compile(r"(?i)(password|passwd|secret)\s*[:=]\s*['\"][^'\"]{8,}"),
     ("tests/", "reports/", "docs/", "demo/")),
]

# Paths that must never re-enter version control (historical scratch assets).
SCRATCH_PATH_PATTERNS = (
    re.compile(r"^scratch/"),
    re.compile(r"^vittixdesigner/bugreport"),
    re.compile(r"^check_anchors\.py$"),
    re.compile(r"^debug_[a-z_]+\.py$"),
    re.compile(r"^[^/]+\.py$"),  # one-off Python scripts at the repo root
)

# Ratchet list: non-ASCII .pas files that already lack a UTF-8 BOM on the
# current main baseline (verified 2026-11-13, origin/main 3e7f6ba). New
# violations fail; these stay tolerated until deliberately normalized.
# ThirdParty/ is vendored code and is expected to keep upstream formatting.
BOM_GRANDFATHERED = frozenset((
    "source/ThirdParty/QRCodeGenLib/src/Interfaces/QlpIQrCode.pas",
    "tools/runner/Vittix.Runner.Baseline.pas",
    "vittixdesigner/Frm.Main.UiStateHelpers.pas",
    "vittixdesigner/Frm.Main.pas",
    "vittixdesigner/Frm.PageSettings.pas",
))


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], capture_output=True, check=True)
    return [f for f in out.stdout.decode("utf-8", "surrogateescape").split("\0") if f]


def is_text(path):
    return not path.lower().endswith(TEXT_EXCLUDE_SUFFIXES)


def read_bytes(path):
    with open(path, "rb") as fh:
        return fh.read()


def main():
    findings = []

    files = tracked_files()

    for path in files:
        for pattern in SCRATCH_PATH_PATTERNS:
            if pattern.search(path):
                findings.append("scratch-path regression: %s" % path)
                break

    for path in files:
        if not is_text(path):
            continue
        try:
            data = read_bytes(path)
        except OSError as exc:
            findings.append("unreadable: %s (%s)" % (path, exc))
            continue

        # Conflict markers.
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            text = data.decode("latin-1")
        for pattern in CONFLICT_PATTERNS:
            if pattern.search(text):
                findings.append("conflict marker in %s" % path)

        # Pascal BOM policy (ratcheted: grandfathered files listed above).
        if (path.lower().endswith(".pas")
                and path.replace("\\", "/") not in BOM_GRANDFATHERED
                and any(b >= 0x80 for b in data)
                and not data.startswith(b"\xef\xbb\xbf")):
            findings.append(
                "non-ASCII Pascal source without UTF-8 BOM: %s" % path)

        # Secret regression scan.
        for pattern, excluded_prefixes in SECRET_PATTERNS:
            if any(path.startswith(p) for p in excluded_prefixes):
                continue
            if pattern.search(text):
                findings.append("potential secret indicator in %s" % path)

    if findings:
        print("HYGIENE FAILED (%d finding(s)):" % len(findings))
        for item in findings:
            print("  - %s" % item)
        return 1

    print("hygiene checks passed (%d tracked files scanned)" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
