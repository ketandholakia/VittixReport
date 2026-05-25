# Embedded Image Data Development Plan

## Goal

Allow image objects to store image content inside the report file instead of requiring an external image path, while preserving existing dynamic `DataField` image behavior and existing report compatibility.

## Current State

- `TReportImageObject` already owns a `TPicture` instance through its `Picture` property.
- The serializer already writes non-empty static image content as Base64 `PictureData` with `PictureClass`.
- The serializer already restores `PictureData` when a report file is opened.
- A static embedded image can render when `DataField` is empty and `Picture` is assigned.
- Designer controls do not currently provide a clear workflow to load, replace, or clear embedded image data.
- Direct vector PDF export currently emits image commands only when an external file-backed source is available.

## Compatibility Rules

- Preserve existing `PictureData` and `PictureClass` report-file fields.
- Do not introduce a new file format for the first implementation.
- Keep `DataField` image binding behavior unchanged unless a separate fallback design is approved.
- If `DataField` is empty, an embedded `Picture` is the static image source.
- If `DataField` is set, dynamic row image resolution remains authoritative in the initial implementation.
- Existing image-path reports must continue to load and render unchanged.
- Existing reports without image data must continue to load unchanged.

## Scope Rules

- Implement incrementally and commit only at safe milestones.
- Do not redesign the image object or serializer without evidence that existing fields are insufficient.
- Do not combine embedded-image work with SVG/EMF vector-preservation work.
- Do not silently change how blank or invalid dataset image paths behave.
- Use owned streams and graphics with `try/finally`.
- Avoid holding temporary image objects or file handles after import/export.

## Affected Units

Existing runtime units:

- `source/Vittix.Report.Objects.pas`
- `source/Vittix.Report.Serializer.pas`
- `source/Vittix.Report.Engine.pas`
- `source/Vittix.Report.Export.Commands.pas`
- `source/Vittix.Report.Export.VectorPDF.pas`

Existing designer units:

- `vittixdesigner/Frm.Main.pas`
- `vittixdesigner/Frm.Main.PropertyPanelHelpers.pas`
- `vittixdesigner/Frm.Main.PropertyEditorHelpers.pas`

Possible new designer unit:

- `vittixdesigner/Frm.ImageEditor.pas`

## Milestone M1 - Planning and Existing Capability Confirmation

Status: Completed

Goal:

Confirm what is already supported before modifying code.

Findings:

- Report serialization already supports embedded static image bytes.
- `PictureData` contains Base64-encoded image content.
- `PictureClass` identifies the graphic type required when loading.
- Runtime image drawing already supports a static assigned `Picture` when `DataField` is empty.
- Designer assignment and vector PDF handling are the missing user-visible parts.

Validation:

- Review serializer save/load behavior.
- Review image object drawing behavior.
- Review vector PDF image command source requirements.
- No code behavior changes.

Safe commit condition:

- This development document only.

Suggested commit:

`docs(image): add embedded image development plan`

## Milestone M2 - Embedded Image Designer Import

Status: Completed and manually validated

Goal:

Allow a selected image object to load an image into its embedded `Picture` content.

Implementation:

- Add a designer action for an image object such as `Load Embedded Image...`.
- Load the selected graphic into `TReportImageObject.Picture`.
- Support formats currently loadable by the runtime image loader first.
- Preserve existing image layout properties: `Stretch`, `Center`, `Proportional`, and border settings.
- Do not automatically change `DataField` without an explicit user decision.
- Mark the report modified after a successful import.
- Refresh the design surface and property display after assignment.

Implemented:

- Add a synthetic `Picture` action row in the property inspector for image objects.
- Open an embedded image editor from the `Picture` ellipsis editor or by double-clicking an image on the design surface.
- Support file import and clipboard bitmap paste inside the editor.
- Store imported image content through the existing owned `TPicture`.
- Record import as an undoable designer command.
- Leave `DataField` unchanged.

Initial supported formats:

- BMP
- JPEG
- PNG
- GIF
- WMF
- EMF

Deferred:

- SVG import, unless the existing graphic stack supplies safe load/save serialization without extra runtime dependencies.

Risks:

- Imported graphic classes must be registered and reloadable through existing serialization.
- Large image files can substantially increase report-file size.
- Assigning an embedded image while `DataField` remains set can appear to have no effect at runtime because dynamic binding remains authoritative.

Validation:

- Import each initially supported format.
- Image appears in designer immediately.
- Save and reopen the report; image remains present.
- Preview and print display the embedded image when `DataField` is empty.
- Existing dynamic image reports remain unchanged.

Safe commit condition:

- Designer import works for static image objects.
- Runtime and designer packages compile.
- No vector PDF behavior change is required for this milestone.

## Milestone M3 - Embedded Image Clear and Replacement Workflow

Status: Pending

Goal:

Make embedded image ownership and replacement explicit in the designer.

Implementation:

- Add `Clear Embedded Image` for selected image objects.
- Allow `Load Embedded Image...` to replace a prior embedded image.
- Display a useful property/status indication such as `Embedded` or `None`.
- If both `DataField` and an embedded image exist, show that the dataset field is used at runtime.

Risks:

- Clearing only the embedded image must not clear `DataField` or layout properties.
- The designer must not leak the replaced `TGraphic`.

Validation:

- Replacing an image updates preview after save/reopen.
- Clearing an embedded image removes `PictureData` on the next save.
- Clearing does not mutate `DataField`.
- Canceling file selection makes no change.

Safe commit condition:

- Load, replace, and clear actions are reversible and validated.

## Milestone M4 - Static Embedded Image Regression Report

Status: Pending

Goal:

Provide a stable report artifact for embedded-image behavior.

Implementation:

- Add or update a regression report containing an image object with:
  - `DataField = ''`
  - Embedded `PictureData`
  - Known scaling and centering settings
- Keep the sample small enough for source control and quick testing.

Validation:

- Report opens in the designer.
- Image appears on design surface.
- Preview displays image.
- Print path displays image.
- Save/reopen does not corrupt image content.

Safe commit condition:

- Regression artifact and behavior verified manually.

## Milestone M5 - Vector PDF Export for Embedded PNG/JPEG

Status: Pending

Goal:

Render embedded raster images in direct vector PDF output without requiring a temporary external path.

Implementation direction:

- Extend `TReportExportImageCommand` to carry owned embedded image content or encoded source bytes in addition to `Source`.
- When `DataField` is empty and `Picture` contains a supported embedded graphic, emit an image export command using embedded data.
- Extend `Vittix.Report.Export.VectorPDF.pas` to write embedded PNG/JPEG content using the same sizing and placement behavior as file-backed images.
- Retain file-backed `Source` support without behavior change.
- Ensure command lifetime owns any copied stream or byte array needed after report rendering.

Initial support:

- Embedded PNG
- Embedded JPEG

Deferred:

- Embedded bitmap conversion policy.
- EMF/WMF preservation as vector PDF content.
- SVG vector import and PDF preservation.

Risks:

- Image byte ownership must not reference a report graphic after its owner is freed.
- PNG alpha/transparency handling must remain correct.
- Memory usage increases if many large embedded images are copied into export commands.
- Export output must match preview placement and scaling.

Validation:

- Embedded PNG renders in direct vector PDF.
- Embedded JPEG renders in direct vector PDF.
- Existing path-based PNG/JPEG PDF export remains unchanged.
- Multi-page reports do not duplicate, lose, or leak image data.
- Repeated exports remain stable.

Safe commit condition:

- Runtime package and runner compile.
- Embedded PNG/JPEG PDF regression passes.
- Existing vector PDF regressions pass.

## Milestone M6 - Optional Dynamic Image Fallback Policy

Status: Deferred

Goal:

Decide whether an embedded image should act as a placeholder when a `DataField` path is blank, missing, or invalid.

Reason For Deferral:

- Current dynamic behavior clears the previous row image when a dataset field has no valid image.
- Automatically using embedded image fallback would change report output for existing dynamic reports.
- This requires an explicit property or documented opt-in behavior rather than an implicit change.

Possible future property:

- `UseEmbeddedImageAsFallback: Boolean`

Compatibility requirement:

- Default must preserve current dynamic image behavior.

## Milestone M7 - Extended Image Formats

Status: Deferred

Goal:

Consider additional embedded image types only after basic embedded image workflow and PDF export are stable.

Candidates:

- BMP converted to PNG for PDF export
- WMF/EMF displayed and printed through existing VCL graphics
- WMF/EMF vector-preserving PDF export
- SVG import and rendering

Reason For Deferral:

- These formats introduce format-specific loaders, conversion behavior, and PDF rendering decisions.
- They should not increase the risk of the initial embedded PNG/JPEG workflow.

## Testing Checklist

- Import a BMP, JPEG, and PNG embedded image in the designer.
- Save report and reopen it.
- Confirm static embedded image displays when `DataField` is empty.
- Confirm `DataField` image reports remain dynamic and unchanged.
- Confirm replacing and clearing an embedded image works without leaking resources.
- Preview static image report.
- Print static image report.
- Export static image report through existing PDF path.
- Export embedded PNG/JPEG through direct vector PDF after M5.
- Test empty report and report without images.
- Test repeated open/save and repeated preview/export cycles.
- Check report-file size impact with large source images.
- Check for obvious memory and GDI handle growth.

## Commit Strategy

- Commit M1 as documentation only.
- Commit M2 and M3 independently unless their UI implementation is inseparable.
- Commit regression artifacts separately when practical.
- Commit vector PDF support only after static designer/runtime embedding is validated.
- Do not mix SVG/EMF work into embedded raster image commits.
