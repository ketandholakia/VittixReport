#!/usr/bin/env python3
"""Repository consistency checks (compiler-independent, CI-safe).

Checks:
  1. Test-project registration consistency: every `Unit in 'path'` entry in
     tests/VittixReportTests.dpr must resolve to a file on disk.
  2. regression_baselines.json must parse (UTF-8-SIG tolerant — the file
     carries a BOM) and be a non-empty JSON object/array.
  3. Every YAML file under .github/workflows/ plus mkdocs.yml must parse
     (syntax validation of workflow and docs configuration).

Exit codes: 0 = all checks passed, 1 = at least one finding.
"""

import json
import os
import re
import sys

try:
    import yaml
    HAVE_YAML = True
except ImportError:
    HAVE_YAML = False

DPR_PATH = os.path.join("tests", "VittixReportTests.dpr")
BASELINES_PATH = os.path.join("reports", "regression_baselines.json")
ENTRY_RE = re.compile(r"^\s*([\w.]+)\s+in\s+'([^']+)'\s*,?\s*$")


def check_registrations(findings):
    if not os.path.isfile(DPR_PATH):
        findings.append("missing %s" % DPR_PATH)
        return
    count = 0
    with open(DPR_PATH, "r", encoding="utf-8-sig", errors="replace") as fh:
        for line_no, line in enumerate(fh, 1):
            match = ENTRY_RE.match(line.rstrip("\r\n"))
            if not match:
                continue
            count += 1
            unit, rel = match.groups()
            # dpr entries are relative to the dpr's own directory (tests/).
            path = os.path.normpath(os.path.join("tests", rel.replace("\\", "/")))
            if not os.path.isfile(path):
                findings.append(
                    "dpr:%d registration '%s' -> missing file %s" % (line_no, unit, path))
    print("  registrations checked: %d" % count)


def check_baselines(findings):
    if not os.path.isfile(BASELINES_PATH):
        findings.append("missing %s" % BASELINES_PATH)
        return
    try:
        with open(BASELINES_PATH, "r", encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except (ValueError, UnicodeDecodeError) as exc:
        findings.append("regression_baselines.json does not parse: %s" % exc)
        return
    if not isinstance(data, (dict, list)) or len(data) == 0:
        findings.append("regression_baselines.json is empty or not an object/array")
    else:
        print("  baselines entries: %d" % len(data))


def check_yaml(findings):
    if not HAVE_YAML:
        findings.append("PyYAML unavailable - YAML validation skipped")
        return
    targets = []
    wf_dir = os.path.join(".github", "workflows")
    if os.path.isdir(wf_dir):
        for name in sorted(os.listdir(wf_dir)):
            if name.endswith((".yml", ".yaml")):
                targets.append(os.path.join(wf_dir, name))
    if os.path.isfile("mkdocs.yml"):
        targets.append("mkdocs.yml")
    for path in targets:
        try:
            with open(path, "r", encoding="utf-8-sig") as fh:
                yaml.safe_load(fh)
        except (yaml.YAMLError, UnicodeDecodeError) as exc:
            findings.append("YAML parse error in %s: %s" % (path, str(exc)[:120]))
    print("  yaml files checked: %d" % len(targets))


def main():
    findings = []
    check_registrations(findings)
    check_baselines(findings)
    check_yaml(findings)

    if findings:
        print("CONSISTENCY FAILED (%d finding(s)):" % len(findings))
        for item in findings:
            print("  - %s" % item)
        return 1

    print("consistency checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
