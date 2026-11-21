# VittixReport v1.0.1 - Proposed Release Notes

> **Status: proposed for owner review.** This document is not an approval,
> publication, or release announcement.

v1.0.0 remains unchanged at tag `v1.0.0` (`a31dc199520eb1079e8617a3d8bd23292a0531ec`).
The v1.0.1 source changes were merged by PR #6 at
`3e7f6ba0293482146313fb5d504de80edaab92f8`. v1.0.1 remains proposed;
integration and release approval remain separate.
The owner reports an overall PASS for the latest installer in a disposable
Windows VM. The VM-side installer hash and itemized scenarios were not supplied,
so this is owner-reported acceptance, not an independently matched executable
or per-scenario result. The local candidate is unsigned, 9,448,740 bytes, SHA-256
`f804f7c1261cdbeee070b8cc8438432512d7039c85b0878181dbaf1b8708f5cc`; the
compiler manifest verifies 136 application payload files. Installer source,
native security results, and evidence limitations are in
`docs/installer-release-audit-v1.0.1.md`. This document remains proposed and
does not announce a release.

Owner-reported GUI acceptance for the PDF-save and Preview UI changes: **7/7
PASS** — Designer main-menu Save PDF, Designer preview Save PDF, component
preview Save PDF, cancel-overwrite preservation, zero-page handling, print
button contrast, and Ctrl+wheel zoom/plain-wheel scrolling. This is owner
acceptance, not automated test evidence.

## PDF saving replaces direct email export

- The Designer preview, the main-window PDF export, and the component preview
  now use **Save PDF...** with a user-selected destination.
- The previews reuse the `TReportExportDocument` captured during their normal
  render; saving does not rerun the report engine.
- Saving is atomic: the Vector PDF is written to a temporary file in the
  destination directory and only replaces the chosen file after a successful
  export. A protected NTFS DACL is applied to the temporary output **before PDF
  data is written**. Existing destinations use Windows `ReplaceFile`; new
  destinations use a non-replacing move to avoid clobbering a racing creator.
  Partial-write and pre-commit failures preserve the destination and attempt
  temporary-file cleanup. Real Windows `ReplaceFile` partial-failure errors
  **1176/1177 were not forced**; partial-swap recovery is a documented limitation.
- The Save dialog uses the standard overwrite confirmation and path-exists
  checks. Existing files are not overwritten without confirmation.
- Direct Simple MAPI email export is retired from all user-facing paths. PDF
  saving no longer requires a mail client, MAPI registration, or a printer
  driver.
- `TReportEmailExporter` remains in the runtime package as a deprecated
  source-compatibility API for existing Delphi consumers. No shipped UI calls
  it. Its `SanitizeTitleToAscii` and `TempPdfPath` helpers and the legacy
  filesystem-safety tests are retained; the release workflow does not exercise
  its MAPI call.
- Historical pagination findings in `docs/ADR-Export-PDF.md` remain historical
  context. This candidate replaces report-email UI with PDF saving; it does not
  claim to fix pagination limitations.

## PDF export

- Vector PDF remains the default PDF export path. The printer-backed PDF path
  remains available as a compatibility path and is not deprecated. The printer
  path still depends on the Windows printing system (such as Microsoft Print to
  PDF); actual printer output is not covered by automated tests.
- Automated checks exercise PDF structure, rendering fixtures, and pagination
  baselines, but do not establish correctness for every report or layout.
  The strict runner checked 41 pinned report baselines; one policy-skipped
  fixture was not checked.
- The 125%/150% display-scale PDF re-probe was **owner-approved on
  2026-10-26**.
- Unicode rendering uses shaping and embedded subset TrueType fonts for the
  verified paths. Indic glyph rendering has been verified for the documented
  fixtures, but Indic text extraction is approximate (glyph-level rather than
  cluster-level). Font subsetting drops GSUB/GPOS/GDEF tables by design; the
  embedded subset is not a general-purpose shaping source.
- Known PDF limitations include unsupported PNG alpha (flattened to white),
  progressive/CMYK JPEG not being distinguished from baseline JPEG, partial
  and not independently verified SVG/EMF/WMF conversion, and no PDF/A or tagged
  PDF support. See `docs/ADR-Export-PDF.md` 6.2 for the capability matrix.

## API and test visibility

- `TReportEmailExporter` is retained for source compatibility. It is not used
  by the Designer, component preview, or main-window actions, and is documented
  as legacy in the ADR.
- `TReportVectorPDFExporter.ExportDocumentAtomic` is the additive public save
  method. `CommitFileAtomic` is a private implementation helper and does not
  add public API.
- Focused tests cover valid PDF output, replacement after successful export,
  preservation of an existing destination when an empty document is rejected,
  rejection of a missing destination directory, protected DACL preservation,
  partial-write failure injection, and pre-commit failure injection. Tests do
  not force real Windows `ReplaceFile` partial-failure errors 1176/1177.
- Filesystem limitations remain: the protected DACL work targets NTFS; this is
  not a guarantee for non-NTFS/network filesystems, EFS/SACL/owner preservation,
  all reparse-point races, crash durability, or every Windows sharing/security
  failure. See `source/Vittix.Report.Export.VectorPDF.pas` for the save contract.

## Verification evidence

The merged source is `3e7f6ba0293482146313fb5d504de80edaab92f8` (tree
`5c4b798620e92f5ea520f50005e4d04e2356cb62`). A fresh release-preparation gate on
2026-10-27 reports:

- Win32 Release DUnitX: **904/904 passed**, 0 failed, 0 errors, 0 leaks.
- Firebird integration: **12/12 passed**; PDF-save fixture: **9/9 passed**.
- Strict runner: **41/41 baselines matched**, one intentional policy skip;
  0 reports failed.
- Resource checks: USER handle delta **0**; GDI handle delta **+8** (limit 16).
- Runtime package, design package, Designer and Demo: **PASS**.
- `tools\ci_gate.ps1 -IncludePackages`: **exit 0**.

The gate used a newly created disposable Firebird database, removed by the
fixture after the run. These source results do not validate the installer.
Evidence is preserved in
`build/release-audit/gate-66c2211748f94ed595eb640880547767/`.
Installer ownership fixtures pass 27 scenarios, and the lifecycle/policy
static-model checks pass 8 scenarios. The rebuilt installer has no VM
acceptance. The fixtures do not execute setup or touch a live IDE hive.
Full results and limitations are recorded in
`docs/installer-release-audit-v1.0.1.md`; no earlier gate is represented as
testing newly changed installer code. A fresh disposable Firebird database is
required for each gate run; existing databases must never be reused.

## Installer security and acceptance status

- Setup requires administrator privileges, has no per-user privilege override,
  and uses the fixed `{commonpf}\VittixReport` destination. The directory page is
  disabled, `/DIR` overrides are rejected, and a remembered alternate path is
  rejected without migration. Validation occurs after `{app}` initialization and
  again after files are installed before any Delphi package registration.
- The security check normalizes the fixed destination, checks existing path
  ancestors plus the install directory, Bpl directory and design BPL for
  reparse-point attributes, and uses `GetNamedSecurityInfoW`, a restricted
  standard-user token and `AccessCheck` for write, delete, child creation,
  ownership and ACL-change rights. Failures to inspect fail closed. Registry
  registration remains ownership-aware and transaction rollback is retained.
- The current installer hash is
  `f804f7c1261cdbeee070b8cc8438432512d7039c85b0878181dbaf1b8708f5cc`.
  The 8/8 lifecycle/policy checks are static/model checks; 27/27 ownership
  scenarios use an in-memory registry fixture. Native Windows tests separately
  passed TokenUser/TokenGroups/restricted-token checks, 80 AccessCheck decisions,
  and reparse fixtures. They exercise production-equivalent Windows APIs, not
  the Pascal Script code inside Setup. No live Delphi IDE registry was modified.
- The owner reports overall disposable-VM PASS for the latest installer, but
  did not provide a VM-measured hash or itemized scenarios. Therefore individual
  elevation, install, IDE integration, reinstall, uninstall, rollback, unsafe
  path, and launch scenarios remain unverified by this record. The genuine
  historical v1.0.0 installer was unavailable, so historical upgrade acceptance
  remains pending. The installer is unsigned; release signing and publication
  remain undecided.

## Supported environment

The repository documents Delphi 12.2 or later and Windows 10 or later. Runtime
and design packages and the CI gate target Win32; the standalone designer also
builds Win64 via `build.bat`. These project targets do not establish support for
every deployment configuration. The demo project remains Win32-only.

## Candidate version metadata

The runtime package, design package, and Designer candidate use
`FileVersion=1.0.1.0` and `ProductVersion=1.0.1.0`; the About-dialog fallback is
`1.0.1.0`. The Win32 Demo also uses `1.0.1.0` metadata for artifact provenance.
This couples the sample application's version to the product release even
though the demo is not itself the supported library or Designer product.
Delphi `ProjectVersion` fields are unchanged.
