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

Status: In Progress

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
- Barcode/table/memo export should be deferred until text/line MVP works.

Safe commit condition:
- Documentation only.
- No runtime behavior changes.

Status result:
- M1 is complete after this document update.

### M2 - Export Command Model

Status: In Progress

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
- Added first object command capture for `TReportLineObject`.
- Text, shape, image, barcode, table, and memo command capture are still pending.
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

Status: Pending

Goal:
Create a direct PDF writer for simple vector content.

Possible new unit:
- `Vittix.Report.Export.VectorPDF.pas`

Initial support:
- PDF header
- Page tree
- Content streams
- Cross-reference table
- Trailer
- Page size mapping
- Basic coordinate conversion

Safe commit condition:
- Exports a valid blank PDF with correct page count and page size.
- Existing PDF exporter unchanged.

### M4 - Text and Line Export

Status: Pending

Goal:
Export the most important report primitives as vector PDF commands.

Initial support:
- Static text
- DataField text after engine resolution
- Font size
- Basic font style mapping
- Font color
- Lines
- Rectangles
- Borders

Safe commit condition:
- Simple sample report exports with selectable/sharp text.
- Multi-page output works.
- Existing preview/export still compiles and runs.

### M5 - Image Export

Status: Pending

Goal:
Support common raster images while keeping vector report primitives sharp.

Initial support:
- PNG image embedding or raster fallback
- JPEG image embedding or raster fallback
- EMF/WMF fallback policy documented
- SVG deferred unless a runtime-safe renderer is selected

Safe commit condition:
- Reports with images export without crashing.
- Unsupported images fail gracefully.
- Raster images do not break vector text output.

### M6 - API and Designer Integration

Status: Pending

Goal:
Expose vector PDF export without breaking existing workflows.

Possible API:
- `ExportToVectorPDF(const AFileName: string)`

Designer UI:
- Keep current `Export PDF`
- Add separate `Export Vector PDF` action

Safe commit condition:
- Existing `ExportToPDF` behavior unchanged.
- New menu/API is clearly separate.
- Runtime and designer packages compile.

### M7 - Regression and Quality Pass

Status: Pending

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

Safe commit condition:
- No regression in preview.
- No regression in current PDF exporter.
- New vector PDF output is sharper for text/lines than printer-based output.

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

Complete M1:
- Review and document affected units.
- Decide on command-capture architecture.
- Commit this planning file only.
