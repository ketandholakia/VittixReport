# VittixReport v1.0.1 installer

This is a proposed, unsigned release candidate. The owner reports overall PASS
for the latest installer in a disposable Windows VM; the VM-measured hash and
itemized scenario results were not supplied. Do not test setup on the Delphi
development machine.

## Baseline and identity

The three original installer files were imported byte-for-byte from the
owner-approved hashes in `docs/installer-release-audit-v1.0.1.md`, then fixed
in the isolated `release/v1.0.1-preparation` worktree.

AppId remains `{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}`. The original
`{commonpf}\VittixReport` layout remains: `Bpl`, `vittixdesigner` (with `Win64`
subdirectory), `demo`, `source`, `packages` and documentation. Setup requires
administrative installation; no privilege-mode override is available. A setup
path is fixed and the directory-selection page is disabled. `/DIR` overrides
are rejected, while a remembered nonstandard installation path is retained
only long enough to reject it safely. Before installation and again before IDE
registration, Setup checks the exact normalized destination, all existing
ancestors and the design BPL for reparse points and standard-user write, delete,
ownership and ACL-change access using Windows security APIs. The descriptor
lookup requests and validates owner, group and DACL information before
`AccessCheck`; requesting only the DACL reproduced Windows error 1338. Any API
failure fails closed. Native Windows tests validate token/ACL behavior, not the
Pascal Script helper inside Setup. This verifies inherited ACLs instead of assuming every
Program-Files descendant is protected. Setup logging is on.
Windows 10 or later is required, matching the documented product policy.

## Build

Prerequisites: Delphi 12.2 (Studio 23.0), Inno Setup >=6.1, Python 3 with
`pefile`, and access to the Northwind helper's pinned, hash-verified SQL sources.
No certificate is required or used. Run from the isolated release branch:

```bat
installer\test_ownership.bat
installer\build_installer.bat
```

The wrapper calls `build_release.ps1`. It checks the merged base and product
input diff, rebuilds both Win32 packages, Win32/Win64 Designer and Win32 Demo,
and uses separate executable/DCU directories for each architecture. Captured
tracked resource bytes are restored in this worktree after building. No other
checkout is used as a binary source.

Only selected tracked distribution files and the freshly built binaries enter
`build\release-payload`. The Demo's required canonical Northwind sample is
built by the existing merged helper using pinned SQL hashes. No developer DB,
test Firebird database, logs, credentials, or arbitrary BPL/DCP files enter the
stage. PE machine, file/product version 1.0.1.0, imports and SHA-256 are checked.
Inno compilation enforces >=6.1 and emits its own payload manifest. The build
verifier compares all compiler-compressed inputs with the staged allowlist and
checks that the stage did not change during compilation.

Output: `build\installer\VittixReport-1.0.1-setup.exe`.
Evidence: `build\release-audit` (ignored local output, preserve separately).

The script refuses to overwrite an existing stage during a fresh build.
To verify and recompile an already reviewed stage after installer-only changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build_release.ps1 -CompileOnly
```

This mode does not rebuild product binaries. A changed product source requires
a fresh stage/build and gate. Earlier experimental setup files are not release
assets. Do not package by pointing ISCC at developer output directories.

## IDE ownership and recovery

Integration uses executing-user HKCU and the original 32-bit registry view.
BDS 23.0 receives Win32 package registration plus Win32 source/Bpl and Win64
source paths. BDS 24.0 receives source search paths only; prebuilt packages are
Delphi 12 Win32 and must not be registered into Delphi 13.

`IdeOwnership.inc` is shared verbatim with the Delphi fixture executable.
`OwnedV2` state is scoped by a hash of the normalized installation directory,
IDE version, platform and path slot. Only newly added path tokens are claimed.
Reinstall avoids normalized duplicates and respects manually removed owned
tokens. Uninstall removes one owned occurrence, preserving unrelated token text,
ordering, empty segments and later user additions. Quoted semicolon directories
are parsed as single entries, custom
installation directories containing semicolons are quoted, and malformed quote
lists fail installation without mutation. An inherited HKLM path is
copied before adding HKCU tokens; after successful uninstall the remaining path
stays in HKCU rather than deleting potentially user-modified settings.

Known Packages is not overwritten if already present, even if its text matches.
Only registrations with an ownership marker and unchanged expected text are
removed. User replacements and unrelated registrations remain intact.

Every write/delete is checked. A transaction journals before-images before
mutation, and records durable ownership before inserting tokens/registrations.
Custom IDE changes happen at `ssInstall`, before Inno's file commit. Failure
before `ssDone` invokes rollback from `DeinitializeSetup`. Rollback restores a
value only if it still matches this transaction's result; if a path changed,
only the added token is removed. Uninstall failures similarly roll back and
stop cleanup. A rollback write failure retains ownership for recovery and is
logged. No whole registry keys are deleted.

Abrupt process termination/power loss cannot run the in-memory rollback;
durable markers support conservative subsequent cleanup, not a crash-atomic
registry transaction. Simultaneous external registry writers are not locked.
Use one setup/uninstall at a time and close the IDE.

Legacy `Original` snapshots are never restored or used to guess ownership.
Unproven pre-existing paths/package values remain; old installations may need
owner-reviewed manual removal of stale IDE entries. This is preferable to
deleting independently owned settings. Actual old-setup upgrade remains pending.

Elevating with another account targets that account's HKCU, and uninstalling
as another user cannot clean the original user's HKCU. Use the same Windows
account for IDE integration and uninstall. No real IDE registry is touched by
the fixture tests. The owner reports overall VM PASS for the latest candidate,
but exact VM hash and per-scenario evidence are absent; do not infer individual
scenario results. The native Windows results and owner-report limitations are
recorded in `docs/installer-release-audit-v1.0.1.md`.

## User data and acceptance

Existing Demo databases and .vrt samples are not overwritten on upgrade and
are retained on uninstall. Files created by users are not recursively removed.
Retained old samples may not incorporate newer corrections; review them before
replacing. No source changes move existing Demo settings out of APPDATA.

Individual clean-install, actual v1.0.0 upgrade, reinstall, uninstall, GUI
launch, real package loading, account/elevation behavior and installation
rollback scenarios are NOT independently evidenced by the owner report. The
public v1.0.0 release has no setup asset, so its installer identity is not
independently established from a published binary. Do not infer individual
acceptance from an overall VM PASS or from fixture tests.
