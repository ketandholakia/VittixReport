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

### M7 - Regression and Quality Pass

Status: In Progress

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
- Headless regression runner now validates vector PDF command page count, emitted PDF page object count, `%PDF-` header, `xref`, `trailer`, and `%%EOF` marker for each automatic regression report.
- Headless regression output marks passing reports with `Vector PDF OK` when the smoke check succeeds.
- `VittixRunner --keep-vector-pdf` keeps generated vector PDF smoke files under `build\vector-pdf-smoke` for manual inspection.
- `VittixRunner --help` documents the vector PDF smoke-output switch.
- `RunTests-VectorPDF.bat` builds the runner, runs vector PDF smoke checks, and keeps generated PDFs for manual inspection.
- `TESTING.md` documents automated vector PDF smoke coverage and manual vector PDF visual checks.

Automated validation result:
- Headless regression passed with `25 Passed, 0 Failed, 7 Skipped`.
- Each automatic regression report completed vector PDF page-count and `%PDF-` smoke validation.
- `VittixRunner --keep-vector-pdf` generated 25 inspectable vector PDFs under `build\vector-pdf-smoke`.

Remaining manual validation:
- Compare vector PDF visual output against preview for representative reports.
- Compare vector PDF sharpness against the current printer-based PDF exporter.
- Inspect JPEG/PNG image placement in an actual PDF viewer.

Safe commit condition:
- Automated regression remains green.
- Manual visual comparison finds no blocking preview/vector PDF mismatch.
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

Continue M7:
- Manually export representative reports with `Export to Vector PDF...` or `RunTests-VectorPDF.bat`.
- Compare vector PDF output against preview and current printer-based PDF output.
- Fix only regressions found during that pass.
