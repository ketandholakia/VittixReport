# VittixReport v1.0.1 installer release-readiness report

Historical audit snapshot dated 2026-10-27. The status and artifact details below
reflect that snapshot; the 2026-10-28 final integration update below supersedes
them where they differ. No release is published.

## Current status — 2026-10-28

- Source PR #6 is merged at `3e7f6ba0293482146313fb5d504de80edaab92f8`.
- Inno Setup 6.7.1 rebuilt the current installer after fixing the production
  security-descriptor request. Candidate: 1.0.1.0, AppId
  `{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}`, 9,448,740 bytes, SHA-256
  `f804f7c1261cdbeee070b8cc8438432512d7039c85b0878181dbaf1b8708f5cc`;
  unsigned. Compiler manifest verified 136 payload files and architecture/version
  checks.
- Confirmed AccessCheck failure: requesting `DACL_SECURITY_INFORMATION` alone
  omitted owner/group fields on the retrieved descriptor and reproduced Windows
  error 1338. Production now requests DACL, owner and group, validates their SIDs,
  and fails closed if unavailable. The native regression reproduces the DACL-only
  failure and passes with the complete descriptor.
- Fresh executable checks: registry ownership **27/27 PASS**; policy/model
  **8/8 PASS**; native TokenUser/TokenGroups/restricted-token/TokenOwner **PASS**;
  native AccessCheck **80/80 API calls PASS with expected decisions**; missing
  descriptor failure and junction/symlink/reparse-parent fixture checks **PASS**.
  These tests exercise Windows APIs with a native harness, not Pascal Script
  running inside Setup. No live IDE settings were changed.
- The owner reports overall PASS for the latest installer in a disposable VM.
  The owner did not provide the VM-measured hash or an itemized scenario matrix;
  this report does not independently establish that the VM ran the exact local
  SHA above or claim individual VM scenarios. Record:
  `D:\CI\firebird\vittix-v101-owner-vm-report-20261028-7c99abc49e\`.
- Current native evidence and SHA-256 manifest:
  `build/release-audit/final-readiness-20261028T143621-1076e171/`; it contains
  the final native results, test source, fresh policy/ownership logs, compiler
  log, installer identity, and SHA-256 manifest.
- Genuine historical v1.0.0 setup/upgrade remains unverified; the distributed
  installer was unavailable. Signing and release publication remain undecided.
  Proposed release notes remain unpublished. No commit, push, PR, merge, tag or
  release is created by the test evidence itself.

## A. Verified base and worktree

- PR #6: MERGED, 2026-10-26T17:59:56Z.
- Verified remote main/base: `3e7f6ba0293482146313fb5d504de80edaab92f8`.
- Merge tree: `5c4b798620e92f5ea520f50005e4d04e2356cb62`, equal to reviewed
  PR head `ceeb75f97874a69e0c752bcf97ca396d314c5cbf` tree.
- Branch: `release/v1.0.1-preparation`.
- Worktree: `D:\ketan\github\VittixReport-v1.0.1-release-prep`.
- v1.0.0 tag object remains `029b8dc4e76070d1fa0f0a50eae7fd4cd9c80d2b`,
  peeling to `a31dc199520eb1079e8617a3d8bd23292a0531ec`, locally/remotely.
- Status: modified proposed release notes; untracked installer files and this
  report. Generated binaries/evidence are ignored build output. Product source,
  tests, projects and tools have no diff against the verified merged HEAD.

## B. Approved import and installer audit

Owner explicitly approved only the three audited files from
`D:\ketan\github\VittixReport\installer`. Every hash was rechecked before copy,
the destination was absent, and imported hashes matched byte-for-byte before
editing. No other developer files were imported. Original source hashes still
match. Import receipt: `build/release-audit/imported-baseline.json`.

| Approved original file | Bytes | SHA-256 |
|---|---:|---|
| build_installer.bat | 2675 | `4d9cf115f51141bbab32fcd52127cb560e346f6721c5d1a66b555278b46b7d8c` |
| README.md | 4598 | `7179021636faba50a889565c91236886ea5259306babe713f38b4d9d97977641` |
| VittixReport.iss | 13853 | `5d2d15cc9940d7a8929ef055c6a0c91101f61c07f422986b5a6a4974eca66b3d` |

Identity remains `{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}`. The compatible
Program Files layout, `Bpl`, `vittixdesigner`, `demo`, sources and packages
remain. The latest Setup requires administrator mode and fixes the path to
`{commonpf}\VittixReport`; it rejects `/DIR` and remembered alternate paths.
It checks existing ancestors and package files for reparse redirection and
standard-user write/replace/delete/ACL/ownership access before payload writes
and before IDE registration. No directory ACLs are relaxed. Windows 10 minimum
matches existing product documentation. Setup logging remains enabled; no
external install-time command was introduced. Installed source files are
selected tracked files, never recursive developer checkout contents.

The initial audit confirmed:

1. Whole Library Path snapshots overwrite user changes; adding source then Bpl
   overwrites the snapshot a second time and can leave source behind.
2. Known Packages writes/deletes ignored existing ownership and user edits.
3. Registry errors were unchecked and custom changes lacked rollback.
4. Unscoped installer state, mixed accounts and mixed privilege modes needed
   explicit handling/documentation.
5. Wildcard/stale binary staging could package wrong architecture or version.
6. Delphi 12 Bpl/DCP paths were added to Delphi 13 despite compiler incompatibility.
7. Demo's required Northwind launch dependency was optional/missing.

Published v1.0.0 GitHub assets are Designer, Demo and two BPLs, with no setup
binary. Reported installer GUID/layout agree with source, but independently
verifying the actual previously distributed setup and upgrade remains pending.

The owner previously reported overall PASS for an earlier corrected installer
in a disposable Windows VM. The exact VM-executed SHA and scenario checklist
remain unspecified; the report predates the current destination-security build
and does not accept its hash.
The durable record is at
`D:\CI\firebird\vittix_v101_owner_vm_final_20261027T093000Z\owner-vm-acceptance.txt`;
its manifest SHA-256 is
`aaa238227bed15538b749ac47ee50baf595221f41a7a4312b1b36812d6957a85`.
It records the locally verified SHA and explicitly leaves the VM hash and all
individual scenarios PENDING EVIDENCE. The earlier owner record and sealed
PR #6 ACL GUI supplement remain unchanged and do not establish installer cases.

## Security review result

**Fixed-destination DACL/reparse implementation completed; installer runtime acceptance remains pending.** The installer requires admin, has no privilege override, fixes the destination to `{commonpf}\VittixReport`, disables destination selection, rejects `/DIR`, and retains/rejects a remembered nonstandard path without migration. It checks the normalized expected location, all existing ancestors, install root, Bpl directory and design BPL for reparse attributes. `GetNamedSecurityInfoW`, a standard-user check token, and `AccessCheck` check write/replace/delete, child creation, ACL modification and ownership rights. The token disables the Administrators SID and privileges while preserving the account's other groups; its owner is set to the logged-on user SID to avoid inheriting elevated owner access. Security API errors fail closed. IDE package registration occurs only after the post-copy validation succeeds. No whole Library Path snapshot restoration or unconditional Known Packages deletion was introduced; ownership checks and transaction rollback remain in `IdeOwnership.inc`.

Inno compilation and static/model policy coverage pass, but this Windows development host was not used to install or modify IDE registry settings. The Windows API logic has not been exercised against disposable NTFS ACL/reparse fixtures or by Setup in a disposable VM. Thus source/build checks do not prove runtime behavior; the new binary requires disposable VM validation before release.

Classification of other findings:

- **NON-BLOCKING FOLLOW-UP:** legacy v1.0.0 entries have no trustworthy
  per-entry owner marker. Current uninstall intentionally preserves them, so a
  completed upgrade followed by uninstall may leave stale Library Path or
  Known Packages entries. Actual v1.0.0 upgrade evidence is not available.
- **INFORMATIONAL:** user-scope IDE integration is tied to the installing
  account's HKCU; abrupt process termination cannot run the in-memory rollback;
  real Windows ReplaceFile 1176/1177 failures were not forced; installer and
  application binaries are unsigned. These limits are documented.
- No system PATH mutation or external command execution was found. The setup
  launches only the packaged Designer if the user selects the post-install
  launch option. Administrative install and Program Files path enforcement
  are now required. Payload staging is tracked and allowlisted, and no test
  Firebird database or secret was found in it.

The privilege/path restriction was rebuilt. The owner now reports an overall
PASS for the corrected installer, but the exact VM-measured SHA and individual
scenarios remain undocumented. The custom-destination security blocker is
independent of that generic acceptance report.

## C. Implemented fixes and tests

Exact proposed file set:

- `installer/VittixReport.iss`: compatible identity/layout; fixed 1.0.1 and
  1.0.1.0 metadata; checked IDE wrappers; transactional event handling;
  source-only Delphi 13 integration; verified stage and compiler manifest.
- `installer/IdeOwnership.inc`: shared ownership/rollback implementation.
- `installer/build_installer.bat`: delegates to the verified release builder.
- `installer/build_release.ps1`: guarded build, architecture-separated output,
  tracked-only stage, pinned sample dependency, verification and compilation.
- `installer/verify_payload.py`: PE/version/import/signature-table inspection,
  SHA-256 manifest and compiler input/hash/size comparison.
- `installer/test_ownership.bat`, `installer/tests/IdeOwnershipTests.dpr`:
  executable in-memory registry regression harness using the identical include.
- `installer/README.md`: existing behavior, build and acceptance documentation.
- `docs/release-notes-v1.0.1.md`: corrected validation/security statements.
- `docs/installer-release-audit-v1.0.1.md`: this report.

Ownership state is scoped by normalized installation-directory hash, IDE,
platform and path slot. Only newly inserted tokens are claimed. Existing path
text/order and unrelated later modifications remain; uninstall removes one
owned occurrence. Reinstall avoids duplicates and respects manual removal.
Effective inherited HKLM paths are preserved as remaining HKCU text, not
deleted/restored wholesale. No whole registry key is deleted.

Existing Known Packages values are not overwritten or claimed, even when the
description is identical. Uninstall removes only an owned value still matching
the expected description; user replacements are retained.

Checked writes are journaled before mutation. Ownership markers precede actual
insertion. Setup integrates at ssInstall, before Inno's file transaction, and
DeinitializeSetup rolls back unless ssDone was reached. Rollback restores an
exact before-image only when the current value still equals this transaction's
result; otherwise an inserted path token alone is removed. Uninstall errors
roll back and stop; failed rollback writes retain ownership for recovery.
Event semantics follow the official [Inno event documentation](https://jrsoftware.org/ishelp/topic_scriptevents.htm).

Baseline reproduction compiled the exact audited AddSearchPath/RemoveSearchPath
functions with fixture wrappers: expected FAIL, exit 1, returning
`X:\Original;C:\Vittix\source` instead of retaining `D:\UserLater`.
Evidence: `build/release-audit/baseline-reproduction.log`.

Final shared-code regression suite: **27 scenarios PASS; failures 0**. Covers
clean/existing paths, duplicate prevention, reinstall, user additions/removals,
reordering/whitespace, independently added duplicates, owned/non-owned/modified
packages, legacy/v2 upgrade, HKLM inheritance, multiple IDEs/platforms/install
directories, version dispatch, every install/uninstall write boundary (six
each), concurrent user edits, rollback-write failure, ownership tampering,
quoted semicolon paths, malformed quotes and custom semicolon installation paths.
No live registry API is linked by the test harness. Evidence:
`build/release-audit/ownership-tests.log`.

Demo databases and .vrt samples now use onlyifdoesntexist/uninsneveruninstall:
upgrade and uninstall preserve user-edited copies. Existing copies may therefore
remain older and require explicit owner review before replacement.

## D. Proposed release notes

Notes remain proposed/unpublished, explicitly marking installer acceptance
unvalidated. They now state 904/904 DUnitX, 12/12 Firebird, 9/9 PDF-save,
41/41 strict plus one policy skip, zero failed/errored/leaked, GDI +8, USER 0,
and package/Designer/Demo PASS. Protected temporary DACL precedes PDF writes;
existing targets use ReplaceFile, new targets a non-replacing move. Partial-write
and pre-commit injection are covered. Real Windows 1176/1177 errors were not
forced, and other filesystem/security limitations remain explicit. Historical
v1.0.0 notes were not edited.

## E. Build verification

Delphi 12.2 Studio 23.0: dcc32 file version **29.0.53982.329**, compiler banner
36.0; MSBuild **4.8.9032.0**. Inno Setup **6.7.1**, compilation exit 0, with a
compile-time >=6.1 guard. No toolchain download was needed.

| Product output | Result | Architecture | File/Product version |
|---|---|---|---|
| Runtime BPL | PASS | Win32 / 0x14c | 1.0.1.0 |
| Design BPL | PASS | Win32 / 0x14c | 1.0.1.0 |
| Designer | PASS | Win32 / 0x14c | 1.0.1.0 |
| Designer | PASS | Win64 / 0x8664 | 1.0.1.0 |
| Demo | PASS | Win32 / 0x14c | 1.0.1.0 |

Product binaries were rebuilt from the verified worktree using Rebuild. Designer
executables/DCUs were separated into build/release-bin/Win32 and Win64; no
shared output was trusted. Original tracked resource bytes were restored only
inside this release worktree. Logs: build/release-audit/*-build.log.

The BPLs require matching Delphi 12 rtl/vcl/dbrtl/vclimg/xmlrtl packages;
Design additionally needs designide/vclactnband/vclwinx and VittixReportRuntime.
Exact PE import lists are in payload-manifest.json. Standalone PE imports are
Windows DLLs, not Delphi BPLs; dynamic loading/printing/fonts still need actual
acceptance. Win64 imports include the Windows Universal CRT string API.

## F. Latest unsigned artifact and payload

Installer: `build/installer/VittixReport-1.0.1-setup.exe`.
Latest size **9,448,569 bytes**; SHA-256:
`e7bc0f0d6b7dded70c612e9db4c9c741da0f5a791ce76ff2942d168875870828`.
File/Product version **1.0.1.0**, PE32 setup launcher, unchanged AppId
`{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}`, admin-only, unsigned. Inno Setup
6.7.1 compilation passed. The compiled payload contains 136 application files;
compiler manifest source hashes and sizes matched the 137-file staging allowlist
(the branding icon is compiled into Setup, not an installed file). Win32 and
Win64 Designer payload architectures and all five application PE versions were
verified by the payload checker. No extra payload was reported.

This hash supersedes `12765fdb0630f6a325357fb93405b6a007e577fdad7fe029f18c57edd3bb1e4d`,
`9d70374f254ee0deab5778c785310e0cfa2342a6a9bb2679590c29fa242433e5`, and
`7ed5c48e3a5cdaea3134922a5d95468a9e0ee119ec998b0f30e44515ce11318f`. The
historical early `{app}` expansion runtime failure and the former arbitrary
Program Files descendant/reparse gap are corrected in source. This artifact
has not been run in a VM; earlier owner VM reporting does not apply to it.
The preprocessed source is `build/release-audit/preprocessed.iss`; compiler
output and manifest are under `build/release-audit` and `build/installer`.

|---|---:|---|---|
| Proposed binary/build output | Bytes | Architecture | SHA-256 |
|---|---:|---|---|
| Bpl/VittixReportDesign.bpl | 42496 | Win32 | `23c8eeec9aced4341df419b82fca7c2cd30a22b4025de776ad738e9e6c2bc00f` |
| Bpl/VittixReportDesign.dcp | 16847 | Delphi Win32 compiler metadata | `3fe12c947c26763584920155ca763344007a1f13ed6d1c04e2bc3f13d4c1af73` |
| Bpl/VittixReportRuntime.bpl | 1719808 | Win32 | `fac770d8365a07ac3d00b1ff4b120561c2b313802eb159ab9dd5b8d7cb25c10f` |
| Bpl/VittixReportRuntime.dcp | 5637994 | Delphi Win32 compiler metadata | `34c053be5fb4fef2f88bcdf7b2f1acec1687c846917fa712baca6d32a8502318` |
| demo/VittixReportDemo.exe | 5704704 | Win32 | `4d20b2c206c48200fe814d4082229139a0c265c2e521dba8db453e48d187c2bc` |
| vittixdesigner/VittixDesigner.exe | 6462464 | Win32 | `5c123245933eb3c8636569723d6fd1469f167c2d6b9ec68111ef910fd7e0c798` |
| vittixdesigner/Win64/VittixDesigner.exe | 10077696 | Win64 | `5c0b1d77596e7e57618e6b0f0bd3bbf2f937b7f0d267478f7ef71740ba5a4dc4` |
| VittixReport-1.0.1-setup.exe | 9448569 | Win32 | `e7bc0f0d6b7dded70c612e9db4c9c741da0f5a791ce76ff2942d168875870828` |

DCPs are Win32 compiler metadata, not PE files; File/Product versions do not
apply to them. Product source commit for all product artifacts is the verified
merge. Installer scripts are uncommitted changes; do not describe setup as
built from that commit alone. Exact source hashes are in
build/release-audit/installer-source-manifest.json. Earlier attempt1/2/3/4 setup
files were preserved under explicit experimental filenames, are NOT release
assets and must not be uploaded.

## G. Acceptance status

| Scenario | Status |
|---|---|
| Approved baseline import/hash match | PASS |
| Isolated ownership/rollback/upgrade transformations | PASS (27 scenarios) |
| Privilege/path/lifecycle policy regressions | PASS (8 static source/model scenarios) |
| Inno compilation and compiler payload hashes | PASS (136 compiled payload files) |
| Owner-reported overall VM acceptance | PASS (scenario evidence absent) |
| Exact VM-tested binary SHA equals current installer | PENDING EVIDENCE |
| Installer wizard launch without runtime error | PENDING OWNER |
| Elevation and safe default destination in VM | PENDING OWNER |
| Unsafe destination rejection and silent setup in VM | PENDING OWNER |
| Installation completes; Designer/Demo launch | PENDING OWNER |
| Clean install, correct installed files/uninstall registration | PENDING EVIDENCE |
| Actual v1.0.0 -> v1.0.1 upgrade and retained directory/settings | PENDING EVIDENCE (old setup unavailable) |
| Actual reinstall, duplicate checks | PENDING EVIDENCE |
| Actual uninstall and unrelated data/IDE preservation | PENDING EVIDENCE |
| Designer/Demo launch and real IDE package loading | PENDING EVIDENCE |
| Real installation-failure rollback | PENDING EVIDENCE |
| Preservation of user-added Library Path entries | PENDING EVIDENCE |
| Preservation of unrelated Known Packages registrations | PENDING EVIDENCE |
| x86/x64 payload correctness | PASS (independent local verification); owner VM detail PENDING |
| No unrelated registry or application damage | PENDING EVIDENCE |
| Tested installer hash equals rebuilt installer hash | PENDING (no new VM run) |
| Prior distributed setup identity/artifact provenance | PENDING OWNER |

The owner reported generic VM PASS for a prior corrected installer, but did
not provide its measured hash or scenario details. This record does not infer
individual results, and the report does not apply to the current destination-
security build. VirtualBox is installed; registered VMs were inspected
read-only, but none was identified or approved as a disposable test target. No
VM was started by this audit. No production installation or IDE write was
attempted. Fixture success does not establish actual acceptance.

The following rebuilt-installer VM scenarios are each **PENDING**: elevation
prompt; non-elevated bypass rejection; Program Files installation; standard-user
package-directory write protection; protected IDE package registration; Designer
launch; Demo launch; reinstall idempotence; preservation of unrelated Library
Path changes; preservation of unrelated Known Packages; partial-install rollback;
and genuine historical v1.0.0 upgrade. The old installer was unavailable, so
that last scenario cannot be simulated by substituting a reconstructed setup.

## H. Source validation and integrity

Earlier corrected-installer evidence remains preserved outside the repository at
`D:\CI\firebird\vittix_v101_app_lifecycle_fix_20261027T091200Z\` and
identifies the superseded `12765fdb...` executable, not the current build.
It includes the executable, compiler manifest/log, preprocessed script, source
hashes, and test logs. Owner-reported acceptance is recorded separately at
`D:\CI\firebird\vittix_v101_owner_vm_final_20261027T093000Z\`. Earlier
evidence directories retain superseded executables unchanged.

Fresh command: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages`.
**Exit 0**; DUnitX **904/904**, Firebird **12/12**, PDF-save **9/9**;
failed/errored/leaked **0**; strict **41 PASS, 0 FAIL, 1 policy skip**;
GDI **+8**, USER **0**; runtime/design/Designer/Demo **PASS**.

Durable gate evidence:
`build/release-audit/gate-66c2211748f94ed595eb640880547767/`
(stdout/stderr, exit.txt, dunitx-results.xml, Firebird diagnostics and gate output).
The fixture database was newly created at a unique path inside that directory
and removed by the fixture; no pre-existing database was reused or deleted.
This validates current merged product source, not installer acceptance. Later
edits affected installer/docs/tests for the installer only, not product inputs.

Final integrity: protected worktree HEAD/status values match the recorded
inventory; original installer bytes match audited hashes; main/tag unchanged;
product diff empty; `git diff --check` PASS for the tracked diff. The untracked
imported installer/docs files contain existing trailing whitespace and missing
terminal newlines; these were detected by an explicit hygiene scan and remain
unstaged. Evidence: build/release-audit/final-integrity.json. Status comparison
establishes HEAD/porcelain invariance, not a byte-level historical snapshot of
every dirty developer file. No protected worktree was written by this task.
No reset/stash/clean/rebase, push, merge, tag, release, or upload was performed.

## I. Remaining limitations and release requirements

1. The latest fixed-destination DACL/reparse security implementation has not
   been exercised by Setup on NTFS or in a disposable VM. Validate the exact new
   hash before release.
2. Legacy snapshots cannot prove individual ownership. Ambiguous legacy paths
   and package registrations are intentionally preserved rather than guessed;
   stale entries may require owner-reviewed manual cleanup. No unsafe snapshot
   migration or automatic cross-user cleanup is attempted.
3. Integration targets executing HKCU. Different-account elevation/uninstall
   cannot manage the original user's settings. Use the same account/mode and
   validate this in acceptance. Actual registry types/views remain part of VM
   acceptance; fixtures exercise string-value transformations only.
4. Abrupt termination cannot run the in-memory journal. Durable ownership
   supports conservative cleanup, not crash-atomic registry transactions.
   External concurrent registry writers are not locked; close IDEs and run one
   installer at a time. Explicit write-failure/recovery behavior is tested.
5. Unsigned status is explicit. Authenticode signing was not requested and no
   approved certificate is available. Publication/release authorization remains
   a separate owner action.

## J. Final verdict (updated 2026-10-27)

**CONDITIONAL GO — fixed-destination DACL/reparse security implementation and build pass; installer runtime/NTFS acceptance remains pending in a disposable Windows VM.**

### Latest implementation and build evidence

- Changed installer files: `installer/VittixReport.iss`,
  `installer/InstallerSecurity.inc`, `installer/README.md`,
  `installer/verify_payload.py`, `installer/tests/test_installer_policy.py`.
- `installer/test_ownership.bat`: **27/27 PASS**, fixture-only registry model;
  no live IDE registry access.
- `installer/tests/test_installer_policy.py`: **8/8 PASS**, static/model checks;
  these do not execute Setup or Windows ACL calls.
- Inno Setup 6.7.1 compilation: **PASS**. Product payload stage verified;
  136 application files compiled and each compiler-manifest SHA/size matched.
- Current unsigned setup: `build/installer/VittixReport-1.0.1-setup.exe`,
  9,448,569 bytes, SHA-256
  `e7bc0f0d6b7dded70c612e9db4c9c741da0f5a791ce76ff2942d168875870828`;
  PE32/Win32, file/product version 1.0.1.0, unchanged AppId.
- Existing Program Files security, BPL/DCP paths, `/DIR` rejection, and
  post-install package verification are enforced by source. No new installer
  was run on this development host. New-binary elevation, startup, ACL behavior,
  install, package loading, and uninstall are pending disposable-VM acceptance.
- `git diff --check` passed for tracked changes. No commits, push, tag, PR or
  publication was performed. The prior generic owner VM PASS applies only to
  the prior reported build, not this new hash.
- Current evidence bundle: `D:\CI\firebird\vittix_v101_destination_security_20261027T135116Z\`.
  `SHA256-manifest.txt` SHA-256:
  `5ece44cf093b2f2f7c25ffa5396fcdcd419091d5e14bc9e37db12f7aeba09311`.
  It includes compiler output, preprocessed source, source manifest,
  ownership/policy logs and the exact installer binary. NTFS fixtures and VM
  acceptance were not run; this is recorded in `results.txt`.
