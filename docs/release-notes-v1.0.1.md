# VittixReport v1.0.1 - Proposed Release Notes

> **Status: proposed for owner review.** This document is not an approval,
> publication, or release announcement.

v1.0.0 remains unchanged at tag `v1.0.0` (`a31dc199520eb1079e8617a3d8bd23292a0531ec`).
v1.0.1 is still proposed; integration and release approval remain separate.
Installer validation is a separate workstream and is not covered by this
candidate's automated gate.

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
  export. A failed export leaves an existing destination untouched; cleanup
  attempts to remove the temporary file.
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
  and rejection of a missing destination directory. They do not inject a
  mid-export write failure or a final replacement failure.

## Verification evidence

Verification applies to the **uncommitted candidate working-tree snapshot**
based on HEAD `c33b7e97b0346de83fca6bbf785c75f468d1e95a`, including its PDF-save
source and test changes. It does not validate that commit alone or any future
commit. These results were obtained before this documentation-only correction;
no production or test files changed afterward.

- Win32 Release DUnitX: **899/899 passed**, 0 failed, 0 errors, 0 leaks,
  including **12/12 Firebird integration tests passed**.
- Strict runner: **41/41 baselines matched**, 0 mismatches, with 1 intentional
  policy skip; 0 reports failed.
- Resource checks: USER handle delta **0**; GDI handle delta **+8** (limit 16).
- Runtime package: **PASS**; design package: **PASS**; Designer: **PASS**;
  Demo: **PASS**.
- `tools\ci_gate.ps1 -IncludePackages`: **exit 0** (`All gates passed`).
- Firebird used a newly created disposable database that was removed after the
  run. The pre-existing `D:\CI\firebird\vittix_ci.fdb` was preserved and its
  SHA-256 was unchanged.
- Evidence artifacts: `build\gate\dunitx-console.txt`,
  `tests\dunitx-results.xml`, `build\gate\runner-console.txt`, and
  `build\gate\firebird-pdfsave-3c888caa206c40d380e348fccde2c304.log`. The
  DUnitX XML records each Firebird case as successful; the gate's final output
  records the package builds and exit status.

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
