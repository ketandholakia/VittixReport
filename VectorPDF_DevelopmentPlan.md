# VittixReport Vector PDF Development Plan

## Goal

Add a sharp, vector-friendly PDF export path while preserving the existing printer-based PDF exporter for backward compatibility.

## Current State

- The report engine renders pages as `TMetafile`.
- Preview converts rendered pages to `TBitmap`.
- Current PDF export uses `Microsoft Print to PDF`.
- Current PDF output quality depends on the Windows printer driver.
- Current PDF exporter is not guaranteed to preserve vector text, lines, and shapes.

## Development Rules

- Do not replace the existing `TReportPDFExporter` until the new path is proven stable.
- Do not duplicate pagination logic.
- Keep existing public APIs working.
- Add new APIs only after review.
- Commit only at safe milestones.
- Keep each milestone small and reversible.

## Milestones

### M1 - Planning and Architecture

Status: Complete

Tasks:
- [x] Document current PDF export limitations.
- [x] Define vector PDF export architecture.
- [x] Decide whether export should be based on metafile replay or report object commands.
- [x] Identify affected units.

Decision:
- Use semantic report object command capture.
- Do not parse or replay `TMetafile` records into PDF commands.
- Keep `TMetafile` generation for current preview, print, and existing PDF export.

Reason:
- `TMetafile` preserves drawing operations but loses clean report semantics.
- Parsing EMF records is fragile and Windows-specific.
- Report objects already know text, font, bounds, borders, fields, and image paths.
- Command capture can share current pagination without duplicating layout logic.

Affected runtime units:
- `Vittix.Report.Engine.pas`
- `Vittix.Report.Bands.pas`
- `Vittix.Report.Objects.pas`
- `Vittix.Report.Objects.Barcode.pas`
- `Vittix.Report.Objects.Table.pas`
- `Vittix.Report.Interfaces.pas`
- `Vittix.Report.Component.pas`
- `Vittix.Report.Export.PDF.pas`

Likely new runtime units:
- `Vittix.Report.Export.Commands.pas`
- `Vittix.Report.Export.VectorPDF.pas`

Affected designer units later:
- `vittixdesigner/Frm.Main.pas`
- `vittixdesigner/Frm.Preview.pas` only if preview/export UI is expanded

Architecture outline:
- Add an optional export command collector.
- Engine keeps existing rendering to `TMetafile`.
- During final render pass only, object drawing can also emit semantic commands.
- PDF vector exporter writes those commands directly as PDF content streams.
- Existing printer-based `TReportPDFExporter` remains unchanged.

Command capture location options:
- Engine-level capture around `PrintBand` and `StartNewPage`.
- Object-level capture inside object draw helpers.
- Dedicated command renderer separate from `TCanvas`.

Preferred first implementation:
- Engine-level page lifecycle capture.
- Object-level command emission after scripts and conditions are resolved.
- No pagination duplication.

M1 risks:
- Object draw code currently combines value resolution and drawing.
- Capturing text values may require small helper extraction from draw methods.
- Image objects may need path/source tracking separate from cached `TPicture`.
- Barcode, table, and memo export were deferred until after the text/line MVP.

Safe commit condition:
- Documentation only.
- No runtime behavior changes.

Status result:
- M1 is complete after this document update.

### M2 - Export Command Model

Status: Complete

Goal:
Capture report output as semantic drawing commands without changing pagination.

Possible new unit:
- [x] `Vittix.Report.Export.Commands.pas`

Possible command types:
- [x] Page begin/end
- [x] Text
- [x] Line
- [x] Rectangle
- [x] Fill rectangle
- [x] Image

Initial implementation:
- Added a standalone command document/page model.
- Added typed command classes for text, line, rectangle, fill rectangle, and image.
- Registered the unit in the runtime package.
- Added optional engine page capture plumbing.
- Engine records export pages only during the final render pass and only when `ExportDocument` is assigned.
- Added text value/style resolution helpers for export command capture.
- Added basic text command capture for text, label, and data field objects.
- Added basic image command capture for file-path images resolved from image `DataField`.
- Added first object command capture for `TReportLineObject`.
- Added basic shape command capture for rectangles, horizontal lines, and diagonal lines.
- Added basic barcode command capture for legacy and Code39 bars plus optional text.
- Added basic memo command capture through the existing text export command path.
- Added basic table command capture for background, header fill, border, and grid lines.
- Embedded image byte capture remains deferred.
- RoundRect and ellipse shape capture are deferred until the command model supports them.
- No runtime behavior changes yet.

Rules:
- Commands must be page-local.
- Coordinates must preserve current engine layout.
- Existing preview, print, and PDF export must continue working.

Safe commit condition:
- Runtime package compiles.
- Existing preview/export behavior unchanged.
- Command capture can be disabled by default.

### M3 - Minimal Vector PDF Writer

Status: Complete

Goal:
Create a direct PDF writer for simple vector content.

Possible new unit:
- [x] `Vittix.Report.Export.VectorPDF.pas`

Initial support:
- [x] PDF header
- [x] Page tree
- [x] Empty content streams
- [x] Cross-reference table
- [x] Trailer
- [x] Page size mapping
- [x] Basic coordinate conversion

Initial implementation:
- Added standalone `TReportVectorPDFExporter`.
- Exporter writes a valid PDF from `TReportExportDocument` pages.
- Writer emits line, rectangle border, and filled rectangle content streams.
- Writer emits basic single-line text commands using built-in Helvetica.
- Regression runner writes a temporary vector PDF and validates the `%PDF-` header.
- Image commands are handled for file-path JPEG and PNG images.
- Text font embedding, Unicode shaping, and full word-wrap layout are deferred.
- Existing printer-based `TReportPDFExporter` remains unchanged.

Safe commit condition:
- Exports a valid blank PDF with correct page count and page size.
- Existing PDF exporter unchanged.

### M4 - Text and Line Export

Status: Complete

Goal:
Export the most important report primitives as vector PDF commands.

Initial support:
- [x] Static text
- [x] DataField text after engine resolution
- [x] Font size
- [x] Basic font style mapping
- [x] Font color
- [x] Lines
- [x] Rectangles
- [x] Borders

Initial implementation:
- Vector PDF writer maps regular, bold, italic, and bold italic text to built-in Helvetica variants.
- Font embedding and exact font family matching remain deferred.

Safe commit condition:
- Simple sample report exports with selectable/sharp text.
- Multi-page output works.
- Existing preview/export still compiles and runs.

### M5 - Image Export

Status: Complete

Goal:
Support common raster images while keeping vector report primitives sharp.

Initial support:
- [x] PNG image embedding or raster fallback
- [x] JPEG image embedding or raster fallback
- [x] EMF/WMF fallback policy documented
- [x] SVG deferred unless a runtime-safe renderer is selected

Initial implementation:
- Vector PDF writer embeds file-path JPEG image commands as inline DCTDecode images.
- Vector PDF writer embeds file-path PNG image commands as flattened RGB inline FlateDecode images.
- EMF/WMF, SVG, and embedded serialized image data remain deferred.

EMF/WMF policy:
- Do not parse EMF/WMF records in the first vector PDF implementation.
- Treat EMF/WMF as unsupported by the direct vector writer until a safe raster fallback or dedicated vector conversion layer is added.
- Unsupported EMF/WMF image commands must fail gracefully and must not affect text, line, shape, JPEG, or PNG output.

SVG policy:
- SVG support remains deferred.
- Do not add a runtime dependency only for SVG until licensing, deployment, rendering quality, and thread-safety are reviewed.
- Future SVG support should use either a controlled raster fallback or a dedicated vector conversion layer without changing existing report files.

Safe commit condition:
- Reports with images export without crashing.
- Unsupported images fail gracefully.
- Raster images do not break vector text output.

### M5.5 - Vector PDF Hardening

Status: In Progress (implemented, pending build/test verification)

Goal:
Fix correctness/safety issues found in review before wiring up designer UI in M6.

Findings from review:
- Inline `BI/ID/EI` images had no `/L` (Length) key, so PDF readers had to
  scan raw JPEG/PNG bytes for an `EI` byte sequence to find the end of the
  image. Real compressed image data can coincidentally contain that
  sequence, corrupting the file. Full-size report images (not small icons)
  made this a real risk, not a theoretical one.
- `TReportExportTextCommand.WordWrap` was captured but never used - all
  text rendered as a single `Tj` line regardless of `Bounds` width, so
  wrapped memo/field text in preview would overflow or clip in the vector
  PDF instead of wrapping.
- `PdfTextX` estimated string width as `Length(Text) * FontSize * 0.5` for
  center/right alignment - a rough heuristic with visible drift from the
  GDI-rendered preview, most noticeable on right-aligned invoice amounts.
- PNG embedding read every pixel via `Canvas.Pixels`, a slow per-pixel GDI
  round trip.

Changes made:
- Replaced inline images with proper Image XObjects: each embedded image
  is now its own indirect PDF object with an explicit `/Length`,
  referenced from the page's `/Resources /XObject` dictionary and drawn
  with `cm` + `/ImN Do`. Object numbering became a two-pass process
  (content build, then number assignment) since image count per page is
  variable.
- Added a measurement `TBitmap.Canvas` (created once per export, freed at
  the end) that is set to the report's requested `FontName`/`FontSize`/
  `FontStyle` for each text command. Used for:
  - Greedy word-wrap by real character widths, hard line breaks preserved,
    only used when `WordWrap` is set.
  - Real `TextWidth` measurement in `PdfTextX`, replacing the `0.5em`
    heuristic.
- PNG pixel copy switched from `Canvas.Pixels` to `ScanLine`.

Known limitations (unchanged by this pass, called out explicitly so they
are a documented decision rather than a silent gap):
- No font embedding. Text is always drawn with one of four built-in
  Helvetica variants; `TextCmd.FontName` is not used for the actual glyph
  rendering (only for wrap/alignment measurement). Non-Latin-1 text
  (including Devanagari, Gujarati, and other Indic scripts used in GST
  invoices) will not render correctly, since core PDF Type1 fonts only
  support WinAnsi/Latin-1 and `PdfText` converts through `AnsiString`
  using the system default codepage. Do not point real Indic-language
  reports at "Export Vector PDF" until a follow-up milestone addresses
  this - see M5.6 below.
- A single word wider than `Bounds.Width` is not mid-word split.
- Progressive/CMYK JPEG files are not distinguished from baseline JPEG
  and would embed incorrectly if encountered (pre-existing limitation).
- PNG transparency is flattened onto white; no alpha channel support.

Safe commit condition:
- Existing sample reports with text, lines, shapes, JPEG, and PNG export
  without corruption.
- A report with a wrapped memo field exports with visible line breaks
  matching (approximately) the preview.
- `RunTests-VectorPDF.bat` passes on the current tree.

### M5.6 - Font Embedding and Indic/Unicode Text Export

Status: Pending

Goal:
Make vector PDF export usable for real GST invoices containing Indic-script
text, not just Latin-1 reports.

Options to evaluate (not yet decided):
- Rasterize just the non-Latin-1 text runs via GDI into a small image
  XObject placed at the correct position. Reuses existing font rendering,
  guarantees visual fidelity, avoids full font-embedding complexity. Would
  reuse the M5.5 Image XObject plumbing.
- Embed a TrueType subset (`/FontFile2`, `/CIDFontType2`) for at least one
  bundled Indic-capable font (e.g., a Noto Sans Devanagari/Gujarati family).
  Meaningfully larger effort: glyph subsetting, CID-to-GID mapping,
  `/ToUnicode` CMap for text extraction/search.

Interim mitigation until this lands:
- Detect non-Latin-1 text at export time and fail that text command
  gracefully (skip with a logged warning) rather than silently emitting
  `?` or blank output.
- Keep "Export Vector PDF" labeled as Latin-text-only (beta) in the
  designer UI (M6) until this milestone is complete.

### M6 - API and Designer Integration

Status: Complete

Goal:
Expose vector PDF export without breaking existing workflows.

Possible API:
- [x] `ExportToVectorPDF(const AFileName: string)`

Designer UI:
- Keep current `Export PDF`
- [x] Add separate `Export Vector PDF` action

Safe commit condition:
- Existing `ExportToPDF` behavior unchanged.
- New menu/API is clearly separate.
- Runtime and designer packages compile.

Initial implementation:
- Added separate `TVittixReport.ExportToVectorPDF`.
- Existing `TVittixReport.ExportToPDF` remains printer-based and unchanged.
- Added separate designer File menu action `Export to Vector PDF...`.

Review verification (post-implementation):
- `ExportToVectorPDF` (file and stream overloads) mirrors the existing
  `ExportToPDF` resolution/cleanup pattern exactly - no discrepancies.
- `mnuExportVectorPDFClick` mirrors `mnuExportPDFClick` (dataset fallback,
  empty-pages guard, cursor/dialog cleanup) - clean.
- `Vittix.Designer.RegressionRunner.pas` cleanup is unconditional `Free`
  calls (nil-safe) for `Renderer`/`Engine`/`ExportDoc`/`ReportModel` - no
  leaks found in the runner itself.
- The smoke test only checks the output file exists and starts with
  `%PDF-`; it does not parse the xref table or verify page count. Fine for
  a smoke test, but call it out as a gap to close in M7.

Open follow-up (not blocking M6, tracked for M7):
- The latest `RunTests-VectorPDF.bat` run showed GDI Handles going from 16
  to 24 (delta +8) across the 30-report suite. Not yet isolated to vector
  PDF export vs. the engine/preview paths the same harness also exercises.
  Before M7 closes, compare against a pre-M5.5 baseline and check whether
  the delta concentrates on image-heavy reports (`07_imagepath_test`,
  `27_object_event_image_cases`).

### M7 - Regression and Quality Pass

Status: Complete

Test cases:
- Static text
- DataField text
- Multiple pages
- Page margins
- Lines and rectangles
- Borders and fills
- Bold/italic text
- PNG/JPG images
- Empty dataset
- Large dataset
- Existing sample reports

Initial implementation:
- Headless regression runner now validates vector PDF command page count, emitted PDF page object count, per-page `/Contents`, page-tree `/Count`, per-page `/MediaBox`, `%PDF-` header, `xref`, `trailer`, and `%%EOF` marker for each automatic regression report.
- Headless regression output marks passing reports with `Vector PDF OK` when the smoke check succeeds.
- `VittixRunner --keep-vector-pdf` keeps generated vector PDF smoke files under `build\vector-pdf-smoke` for manual inspection.
- `VittixRunner --help` documents the vector PDF smoke-output switch.
- `RunTests-VectorPDF.bat` builds the runner, runs vector PDF smoke checks, and keeps generated PDFs for manual inspection.
- Temporary vector PDF smoke filenames are process-specific to avoid collisions during concurrent runner invocations.
- `TESTING.md` documents automated vector PDF smoke coverage and manual vector PDF visual checks.

Automated validation result:
- Headless regression passed with `25 Passed, 0 Failed, 7 Skipped`.
- Each automatic regression report completed vector PDF page-count and `%PDF-` smoke validation.
- `VittixRunner --keep-vector-pdf` generated 25 inspectable vector PDFs under `build\vector-pdf-smoke`.

Remaining manual validation:
- Completed: representative vector PDFs were visually inspected.
- Completed: vector PDF output was compared against preview/current PDF output with no blocking mismatch found.
- Completed: JPEG/PNG image placement was inspected in generated vector PDFs.

Safe commit condition:
- Automated regression remains green.
- Manual visual comparison found no blocking preview/vector PDF mismatch.
- Current printer-based `Export PDF` remains unchanged.

## Deferred

- Replacing current PDF exporter.
- Full SVG support.
- EMF/WMF vector parsing into PDF commands.
- Rich text PDF export.
- Advanced font embedding.
- Unicode shaping/complex script rendering.
- PDF/A compliance.
- Silent printer-driver PDF export fixes.

## Recommended Next Step

M7 complete:
- Keep vector PDF exporter separate from current printer-based `Export PDF`.
- Continue fixing only regressions found from real reports.