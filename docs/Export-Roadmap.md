# VittixReport Export Roadmap

Status: Planned  
Scope: VittixReport export subsystem  
Roadmap: E0–E10

---

## 1. Purpose

This document defines the modernization and expansion roadmap for the VittixReport
export subsystem.

The objective is to expand VittixReport from its current set of PDF, HTML, XLSX,
text, vector-PDF and email-related exporters into a broader, well-known format
family while preserving the existing rendering architecture and minimizing
third-party dependencies.

The roadmap is based on the export architecture currently present in the
repository.

---

# 2. Current Export Architecture

VittixReport already has a functioning export subsystem.

The existing architecture includes:

- `IReportExporter`
- `TVittixReport.ExportWith(...)`
- PDF export
- Vector PDF export
- HTML export
- XLSX export
- Text export
- Email/MAPI export
- export capture infrastructure
- vector export command model
- engine-level progress/cancellation support
- export-specific test fixtures

The export capture architecture is particularly important.

Conceptually:

```text
VittixReport
     │
     ▼
Report Engine
     │
     ▼
Export Capture
     │
     ▼
TReportExportDocument
     │
     ├── TReportExportPage
     │       │
     │       ├── Text
     │       ├── Line
     │       ├── Rectangle
     │       ├── Fill Rectangle
     │       ├── Ellipse
     │       └── Image
     │
     ▼
Exporter
```

This command-document model should remain the primary rendering abstraction for
fixed-layout exporters.

---

# 3. Existing Exporters

| Export     | Current status                      | Notes                                    |
| ---------- | ----------------------------------- | ---------------------------------------- |
| PDF        | Existing                            | Printer-based implementation             |
| Vector PDF | Existing / Beta                     | Native vector implementation             |
| XLSX       | Existing                            | Hand-built using `System.Zip`            |
| HTML       | Existing                            | Report-oriented HTML writer              |
| Text       | Existing                            | Plain-text export                        |
| Email/MAPI | Existing                            | Delivery/export integration              |
| CSV        | Not implemented                     | Existing CSV class is a data-source stub |
| JSON       | Not implemented                     | No exporter                              |
| XML        | Not implemented                     | No exporter                              |
| Markdown   | Not implemented                     | No exporter                              |
| DOCX       | Not implemented                     | No exporter                              |
| RTF        | Not implemented                     | No exporter                              |
| ODT        | Not implemented                     | No exporter                              |
| XLS        | Not implemented                     | No exporter                              |
| ODS        | Not implemented                     | No exporter                              |
| SVG        | Partial backend                     | Present under VectorPDF infrastructure   |
| PNG        | Not implemented as general exporter | Needs fixed-layout export path           |
| JPEG       | Not implemented                     | Needs fixed-layout export path           |
| EMF        | Partial backend                     | Present under VectorPDF infrastructure   |
| WMF        | Not implemented                     | Needs fixed-layout export path           |

---

# 4. Architectural Principles

## 4.1 Preserve the existing exporter interface

`IReportExporter` already exists and should not be replaced with an interface
that directly depends on `TVittixReport`.

The existing interface is suitable for the fixed-layout export architecture.

Future work should extend it with:

* capabilities
* format metadata
* export context
* options
* command-document support where appropriate

without unnecessarily coupling every exporter to the report component.

---

## 4.2 Reuse the existing export command model

The existing:

```text
TReportExportDocument
TReportExportPage
TReportExport*Command
```

model is the preferred abstraction for fixed-layout rendering.

New exporters should consume this model where the format is fundamentally
render-oriented.

This avoids duplicating the report rendering logic in every exporter.

---

## 4.3 Separate export families

VittixReport exports should be treated as three primary families.

### Fixed-layout

```text
PDF
SVG
PNG
JPEG
EMF
WMF
```

These prioritize visual fidelity.

### Document

```text
HTML
DOCX
RTF
ODT
Markdown
TXT
```

These prioritize document representation.

### Data / interchange

```text
CSV
XLSX
XLS
ODS
JSON
XML
```

These prioritize structured data.

---

# 5. Dependency Policy

VittixReport should remain **stdlib-first**.

The current repository deliberately minimizes third-party dependencies.
XLSX is already implemented using `System.Zip`, and the exporter roadmap should
preserve this philosophy wherever practical.

Third-party libraries should only be introduced when:

1. the required format cannot reasonably be implemented using Delphi/platform
   facilities;
2. the library has a compatible license;
3. maintenance risk is acceptable;
4. the dependency provides substantial value over an internal implementation.

Every new dependency requires explicit review before adoption.

---

# 6. Roadmap

---

## E0 — Export Baseline & PDF Decision

### Objective

Establish the current export baseline and resolve the architectural direction
for PDF.

### Existing issue

The repository currently has two PDF paths:

```text
Export.PDF
    └── printer-based PDF generation

VectorPDF
    └── native vector PDF
        ├── VectorPDF.EMF
        └── VectorPDF.SVG
```

The printer-based implementation depends on the literal:

```text
Microsoft Print to PDF
```

and therefore has an environment dependency.

The vector implementation is currently Beta and has documented limitations,
including Latin-only text support.

### Work

* document both implementations;
* characterize their current behavior;
* identify feature differences;
* identify Unicode/text limitations;
* determine the supported production PDF path;
* define whether the printer-based path remains:

  * supported;
  * compatibility-only;
  * deprecated;
  * or retired.

### Deliverables

```text
docs/ADR-Export-PDF.md
```

### Tests

Existing PDF tests plus targeted regression coverage for the selected contract.

---

# E1 — Export Foundation

### Objective

Formalize the existing export infrastructure without replacing the current
architecture.

### New components

Potential new unit:

```text
Vittix.Report.Export.Manager.pas
```

Supporting types:

```text
TReportExportManager
TReportExportOptions
TReportExportCapabilities
TReportExportContext
TReportExportFormat
```

### Manager responsibilities

```text
Format registration
Format discovery
Exporter lookup
Extension lookup
MIME metadata
Capability discovery
By-format dispatch
```

Example conceptual API:

```pascal
ExportManager.Export(
  Report,
  Format,
  FileName,
  Options
);
```

The manager should internally resolve the appropriate exporter rather than
forcing callers to instantiate concrete exporter classes.

### Capabilities

Capabilities should describe format support such as:

```text
MultiPage
Text
Images
Shapes
Tables
Charts
Barcodes
Unicode
Hyperlinks
Transparency
StructuredData
FixedLayout
```

### Options

Common options should include, where applicable:

```text
OverwritePolicy
Encoding
BOM
Delimiter
DecimalFormat
DateFormat
PageRange
Quality
```

Format-specific options should remain format-specific rather than bloating the
common options object.

---

# E2 — Data Export Family

### Objective

Implement the missing structured-data export family.

### Order

```text
CSV
JSON
XML
```

This is the highest-value near-term expansion because none of these exporters
currently exists.

---

## E2.1 CSV

New unit:

```text
Vittix.Report.Export.Csv.pas
```

Support:

```text
Delimiter
Quote character
Encoding
UTF-8
BOM
Decimal formatting
Date formatting
Header row
```

Potential modes:

```text
Visible fields
All fields
Tabular dataset
Report data
```

Important distinction:

`TCsvReportDataSource` is a data-source component and is not a CSV exporter.

CSV export must therefore be implemented independently.

### Tests

```text
Test.Vittix.Report.Export.CSV
```

Test:

* headers
* quoting
* commas
* quotes inside values
* Unicode
* empty values
* numeric values
* dates
* multiline values
* encoding/BOM

---

# E2.2 JSON

New unit:

```text
Vittix.Report.Export.Json.pas
```

Two possible representations should be explicitly distinguished:

### Data JSON

```json
{
  "columns": [...],
  "rows": [...]
}
```

### Report JSON

```json
{
  "report": "...",
  "pages": [...]
}
```

The initial implementation should select and document one canonical contract
rather than silently producing multiple incompatible representations.

### Tests

Validate:

* valid JSON syntax
* Unicode
* null values
* numbers
* dates
* nested structures where applicable
* deterministic output

---

# E2.3 XML

New unit:

```text
Vittix.Report.Export.Xml.pas
```

Define a stable XML schema before implementation.

Tests should validate:

* well-formed XML;
* escaping;
* Unicode;
* null/empty values;
* deterministic structure.

---

# E3 — XLSX Hardening

XLSX already exists and should be treated as an existing exporter rather than
a new format implementation.

### Current implementation

The exporter uses Delphi `System.Zip` and does not require a third-party XLSX
library.

### Planned improvements

Evaluate and add, where supported by the existing architecture:

```text
Page setup
Freeze panes
Hyperlinks
Column widths
Row heights
Number formats
Print areas
Repeating headers
Multiple worksheets
```

### Tests

Extend:

```text
Test.Vittix.Report.Export.XLSX
```

Use structural ZIP/XML verification rather than relying only on file existence.

---

# E4 — HTML Export Expansion

### Objective

Separate visual report HTML from semantic tabular HTML.

### Existing

```text
TReportHTMLExporter
```

### Add

```text
HTML Report
HTML Table
```

### HTML Report

Preserve report-oriented layout.

### HTML Table

Produce semantic HTML suitable for:

* web pages;
* email;
* accessibility;
* downstream processing.

Example:

```html
<table>
  <thead>...</thead>
  <tbody>...</tbody>
</table>
```

### Tests

Validate:

* valid HTML;
* headers;
* rows;
* escaping;
* Unicode;
* report/table mode differences.

---

# E5 — Document Export Family

### Objective

Add document-oriented formats behind a shared document abstraction.

### Formats

```text
RTF
DOCX
ODT
```

### Order

```text
RTF
  ↓
DOCX
  ↓
ODT
```

The common abstraction should represent document concepts rather than report
rendering commands.

Possible concepts:

```text
Document
Section
Paragraph
Run
Table
Image
PageBreak
Header
Footer
```

The abstraction should not attempt to model every feature of every document
format.

---

# E6 — Vector PDF Graduation

### Objective

Move Vector PDF from Beta toward a documented production capability.

### Areas requiring verification

```text
Unicode
Font handling
Text measurement
Tables
Images
Barcodes
Multiple pages
Transparency
Clipping
Line/shape fidelity
```

The existing export capture architecture should remain the source of rendering
commands.

### Required result

A documented Vector PDF capability matrix should identify what is supported,
partially supported, or unsupported.

---

# E7 — Fixed-layout Export Family

### Formats

```text
SVG
PNG
JPEG
EMF
WMF
```

### Architecture

These should consume the existing fixed-layout/export command infrastructure
where practical.

### SVG

Prioritize:

* text
* shapes
* images
* clipping
* multiple pages or page-per-file behavior

### Raster

Provide:

```text
PNG
JPEG
```

with options such as:

```text
DPI
Quality
Page selection
Background
```

### Windows vector

Provide:

```text
EMF
WMF
```

where platform-specific implementation is appropriate.

---

# E8 — Export Manager UI

### Objective

Expose the export registry through the application/designer UI.

### UI responsibilities

```text
Format selection
File name
Extension
Format filters
Common options
Format-specific options
Overwrite confirmation
Export progress
Cancellation
Error reporting
```

The UI should obtain format information from `TReportExportManager` rather than
maintaining a separate hard-coded format list.

---

# E9 — Progress & Cancellation

### Existing infrastructure

The engine already provides:

```text
IReportProgress
    SetTotal
    Advance
    IsCancelled
```

### Objective

Connect this infrastructure to export operations.

Conceptually:

```text
ExportManager
    ↓
Exporter
    ↓
Engine / Capture
    ↓
IReportProgress
```

Cancellation must be cooperative and must not leave partially written output
presented as a successful export.

### Tests

Validate:

* progress callbacks;
* cancellation before export;
* cancellation during export;
* exporter cleanup;
* partial output handling.

---

# E10 — Export Conformance Suite

### Objective

Establish a common regression framework for every exporter.

Existing tests:

```text
Test.Vittix.Report.Export.HTML
Test.Vittix.Report.Export.XLSX
Test.Vittix.Report.ExportCapture
Runner.ExportVerification
```

should be extended rather than replaced.

### Test categories

#### Structural

```text
File exists
File readable
Format valid
Expected metadata
Expected page count
```

#### Content

```text
Text
Numbers
Dates
Images
Shapes
Tables
Barcodes
Unicode
```

#### Layout

For fixed-layout formats:

```text
Page dimensions
Object positions
Text placement
Margins
Scaling
```

#### Determinism

Where practical:

```text
Same report
+
Same options
=
Equivalent output
```

Binary formats should use structural comparison rather than blindly comparing
entire binary files when metadata or compression makes byte-for-byte equality
unstable.

### Golden fixtures

Create a small canonical export corpus covering:

```text
Simple text
Master/detail
Images
Tables
Barcodes
Unicode
Multiple pages
Headers/footers
Expressions
```

Each exporter should consume the same logical fixtures wherever the format
supports the corresponding feature.

---

# 7. Proposed Format Matrix

| Format   | Family   |    Phase | Primary goal             |
| -------- | -------- | -------: | ------------------------ |
| PDF      | Fixed    |    E0/E6 | Print/share              |
| XLSX     | Data     |       E3 | Spreadsheet              |
| CSV      | Data     |       E2 | Data exchange            |
| JSON     | Data     |       E2 | API/integration          |
| XML      | Data     |       E2 | System integration       |
| HTML     | Document |       E4 | Web                      |
| RTF      | Document |       E5 | Office compatibility     |
| DOCX     | Document |       E5 | Word documents           |
| ODT      | Document |       E5 | OpenDocument            |
| SVG      | Fixed    |    E6/E7 | Vector                   |
| PNG      | Fixed    |       E7 | Image                    |
| JPEG     | Fixed    |       E7 | Image                    |
| EMF      | Fixed    |       E7 | Windows vector           |
| WMF      | Fixed    |       E7 | Legacy Windows vector    |
| XLS      | Data     |   Future | Legacy Excel             |
| ODS      | Data     |   Future | OpenDocument spreadsheet |
| Markdown | Document |   Future | Documentation            |
| TXT      | Document | Existing | Plain text               |

---

# 8. Dependency Strategy

The preferred implementation strategy is:

```text
Delphi RTL / VCL
        ↓
Existing VittixReport infrastructure
        ↓
Small internal format writers
        ↓
Third-party dependency only where justified
```

No third-party dependency should be added merely for convenience.

Before adding a dependency, document:

* license;
* source availability;
* maintenance status;
* Delphi compatibility;
* redistribution requirements;
* static/dynamic linking implications;
* impact on VittixReport distribution.

---

# 9. Implementation Rules

Every export phase must:

1. Preserve existing exporter behavior unless explicitly changing it.
2. Add regression tests before declaring the phase complete.
3. Avoid modifying report-object `Draw()` contracts for export-specific needs.
4. Reuse the existing export command model where appropriate.
5. Keep data exports separate from fixed-layout rendering.
6. Keep format-specific options out of generic APIs where possible.
7. Preserve Unicode correctness as a first-class requirement.
8. Avoid unnecessary third-party dependencies.
9. Document unsupported features explicitly.
10. Never silently produce an incomplete export while reporting success.

---

# 10. Phase Completion Criteria

An export phase is complete only when:

```text
Implementation       PASS
Unit tests           PASS
Regression suite     PASS
Format validation    PASS
Unicode validation   PASS
Existing exporters   PASS
Build                PASS
Documentation        PASS
Git diff review      PASS
```

For GUI-related export functionality:

```text
Interactive smoke test    PASS
```

must also be recorded separately from automated verification.

---

# 11. Recommended Near-Term Sequence

The practical implementation order is:

```text
E0  PDF decision / baseline
 ↓
E1  Export manager + capabilities + options
 ↓
E2  CSV
 ↓
    JSON
 ↓
    XML
 ↓
E3  XLSX hardening
 ↓
E4  HTML semantic-table mode
 ↓
E5  RTF
 ↓
    DOCX
 ↓
    ODT
 ↓
E6  Vector PDF graduation
 ↓
E7  SVG / PNG / JPEG / EMF / WMF
 ↓
E8  Export Manager UI
 ↓
E9  Progress / cancellation
 ↓
E10 Conformance suite
```

This ordering deliberately does **not** treat PDF as the first new exporter:
PDF already exists and currently represents an architectural decision/risk.

Likewise, XLSX is an existing capability and should be hardened rather than
rebuilt.

The largest currently missing export family is the structured data family:

```text
CSV
JSON
XML
```

which therefore becomes the first major new-format implementation target.
