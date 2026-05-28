#!/usr/bin/env python3
"""Review and optionally delete clearly outdated documentation files.

The default operation is read-only:
    python tools/cleanup_outdated_docs.py

To request deletion after reviewing candidates:
    python tools/cleanup_outdated_docs.py --delete

For explicitly approved non-interactive cleanup:
    python tools/cleanup_outdated_docs.py --delete --auto-approve
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable


EXCLUDED_DIRECTORIES = {".git", ".svn", ".vs", "__history", "__recovery"}

# These file types must never be selected, even if their names contain
# legacy/archive markers.
PROTECTED_EXTENSIONS = {
    ".pas", ".dfm", ".dpr", ".dpk", ".inc", ".res", ".rc", ".dproj",
    ".groupproj", ".bpl", ".dll", ".dcu", ".exe", ".obj", ".hpp",
    ".cpp", ".json", ".xml", ".ini", ".cfg",
}

DOC_EXTENSIONS = {
    ".md", ".rst", ".adoc", ".wiki", ".pdf", ".docx", ".odt", ".rtf",
    ".bak", ".~", ".old", ".orig",
}
AMBIGUOUS_DOC_EXTENSIONS = {".txt", ".log", ".htm", ".html"}
DOC_DIRECTORIES = {"docs", "documentation", "help", "manual"}
OUTDATED_WORDS = {"old", "deprecated", "archive", "legacy", "v1", "obsolete", "backup", "tmp"}
DRAFT_SUFFIXES = ("_draft", "_backup", "_old")
PROTECTED_ROOT_FILES = {"readme.md", "license"}
AGE_DAYS = 90

VERSION_RE = re.compile(
    r"^(?P<prefix>.*?)(?:[_\-. ]v)(?P<version>\d+)(?P<suffix>(?:\.[^.]+)?)$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Finding:
    path: Path
    reason: str


def relative_display(path: Path, root: Path) -> str:
    return str(path.relative_to(root))


def is_under_excluded_directory(path: Path, root: Path) -> bool:
    return any(part.lower() in EXCLUDED_DIRECTORIES for part in path.relative_to(root).parts[:-1])


def is_in_doc_directory(path: Path, root: Path) -> bool:
    return any(part.lower() in DOC_DIRECTORIES for part in path.relative_to(root).parts[:-1])


def doc_type_status(path: Path, root: Path) -> tuple[bool, str]:
    suffix = path.suffix.lower()
    name = path.name.lower()

    if suffix in PROTECTED_EXTENSIONS:
        return False, "protected code/resource/configuration extension"
    if path.parent == root and name in PROTECTED_ROOT_FILES:
        return False, "protected root documentation file"
    if suffix in DOC_EXTENSIONS:
        return True, ""
    if suffix in AMBIGUOUS_DOC_EXTENSIONS:
        if is_in_doc_directory(path, root):
            return True, ""
        return False, "ambiguous extension outside a documentation directory"
    if suffix == "" and path.stem.lower() in {
        "readme", "changelog", "contributing", "license", "install",
        "upgrade", "history", "todo", "notes",
    }:
        if path.parent == root and name in PROTECTED_ROOT_FILES:
            return False, "protected root documentation file"
        return True, ""
    return False, "not an eligible documentation extension"


def first_five_lines(path: Path) -> str:
    try:
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            return " ".join(next(handle, "") for _ in range(5)).lower()
    except OSError:
        return ""


def has_outdated_marker(path: Path) -> str | None:
    search_text = path.name.lower() + " " + first_five_lines(path)
    for word in sorted(OUTDATED_WORDS):
        if re.search(r"(?<![a-z0-9])" + re.escape(word) + r"(?![a-z0-9])", search_text):
            return word
    return None


def is_old(path: Path, cutoff_timestamp: float) -> bool:
    return path.stat().st_mtime < cutoff_timestamp


def find_version_duplicates(paths: list[Path]) -> dict[Path, str]:
    version_groups: dict[tuple[Path, str, str], list[tuple[int, Path]]] = {}
    results: dict[Path, str] = {}

    for path in paths:
        match = VERSION_RE.match(path.name)
        if not match:
            continue
        key = (path.parent, match.group("prefix").lower(), match.group("suffix").lower())
        version_groups.setdefault(key, []).append((int(match.group("version")), path))

    for versions in version_groups.values():
        if len(versions) < 2:
            continue
        newest_version = max(version for version, _ in versions)
        for version, path in versions:
            if version < newest_version:
                results[path] = "older duplicate version; a newer v%d file exists" % newest_version
    return results


def scan(root: Path) -> tuple[list[Finding], list[Finding]]:
    now = datetime.now(timezone.utc)
    cutoff = (now - timedelta(days=AGE_DAYS)).timestamp()
    eligible_docs: list[Path] = []
    skipped: list[Finding] = []

    for path in root.rglob("*"):
        if not path.is_file() or is_under_excluded_directory(path, root):
            continue
        eligible, reason = doc_type_status(path, root)
        if not eligible:
            # Report only files resembling requested documentation cleanup,
            # not every source file in the repository.
            if path.suffix.lower() in AMBIGUOUS_DOC_EXTENSIONS or path.name.lower() in PROTECTED_ROOT_FILES:
                skipped.append(Finding(path, reason))
            continue
        eligible_docs.append(path)

    duplicate_reasons = find_version_duplicates(eligible_docs)
    candidates: list[Finding] = []
    for path in eligible_docs:
        lower_stem = path.stem.lower()
        if lower_stem.endswith(DRAFT_SUFFIXES):
            candidates.append(Finding(path, "draft/backup filename suffix"))
            continue
        if path in duplicate_reasons:
            candidates.append(Finding(path, duplicate_reasons[path]))
            continue
        marker = has_outdated_marker(path)
        if marker and is_old(path, cutoff):
            candidates.append(Finding(path, "older than %d days and marked '%s'" % (AGE_DAYS, marker)))
        else:
            reason = "not clearly outdated"
            if marker and not is_old(path, cutoff):
                reason = "outdated marker present but file is not older than %d days" % AGE_DAYS
            skipped.append(Finding(path, reason))

    candidates.sort(key=lambda finding: str(finding.path).lower())
    skipped.sort(key=lambda finding: str(finding.path).lower())
    return candidates, skipped


def print_findings(title: str, findings: Iterable[Finding], root: Path) -> None:
    findings = list(findings)
    print("\n%s (%d)" % (title, len(findings)))
    if not findings:
        print("  (none)")
        return
    for finding in findings:
        print("  %s - %s" % (relative_display(finding.path, root), finding.reason))


def delete_candidates(candidates: list[Finding], root: Path) -> tuple[list[Finding], list[Finding]]:
    deleted: list[Finding] = []
    failed: list[Finding] = []
    resolved_root = root.resolve()
    for finding in candidates:
        resolved_path = finding.path.resolve()
        if resolved_root not in resolved_path.parents:
            failed.append(Finding(finding.path, "safety check failed: outside repository root"))
            continue
        try:
            resolved_path.unlink()
            deleted.append(finding)
        except OSError as exc:
            failed.append(Finding(finding.path, "delete failed: %s" % exc))
    return deleted, failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="repository root to scan")
    parser.add_argument("--delete", action="store_true", help="allow deletion after listing candidates")
    parser.add_argument("--auto-approve", action="store_true", help="skip confirmation; requires --delete")
    args = parser.parse_args()

    if args.auto_approve and not args.delete:
        parser.error("--auto-approve requires --delete")

    root = args.root.resolve()
    if not root.is_dir():
        parser.error("root is not a directory: %s" % root)

    candidates, skipped = scan(root)
    print("Repository documentation cleanup scan: %s" % root)
    print_findings("Candidates for deletion", candidates, root)
    print_findings("Skipped files", skipped, root)

    if not args.delete:
        print("\nRead-only scan completed. Rerun with --delete to review and confirm deletion.")
        return 0
    if not candidates:
        print("\nNo files qualify for deletion.")
        return 0

    if not args.auto_approve:
        answer = input("\nDelete the listed candidate files? Type DELETE to confirm: ").strip()
        if answer != "DELETE":
            print("Deletion cancelled; no files removed.")
            return 0

    deleted, failed = delete_candidates(candidates, root)
    print_findings("Deleted files", deleted, root)
    print_findings("Deletion failures", failed, root)
    print("\nSummary: deleted=%d skipped=%d failed=%d" % (len(deleted), len(skipped), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
