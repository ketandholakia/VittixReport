# VittixReport documentation

VittixReport is a reporting framework and standalone visual designer for Delphi
VCL applications. It ships a band-oriented report model, a runtime engine, a
drag-and-drop designer, a print preview, and a set of exporters.

Reports are stored as source-control-friendly JSON (`.vrt`), not binary blobs.

!!! note "Where this site comes from"
    Every page under **Modernization**, **Analysis** and the reference pages is
    generated from documents that already live in the repository. The build
    pulls files from outside `docs/` in with MkDocs snippets rather than moving
    them, so there is exactly one copy of each document. See
    `mkdocs.yml` for the mapping.

## What is in the tree

| Path | Contents |
|---|---|
| `source/` | The core framework: object model, band layout, pagination engine, expression engine, serializer, designer control, exporters |
| `vittixdesigner/` | The standalone Windows report designer application |
| `packages/` | Delphi runtime and design-time packages (`VittixReportRuntime.dpk`, `VittixReportDesign.dpk`) |
| `demo/` | The VCL demo application plus 25 hand-authored report templates in `demo/vrt/` |
| `tests/` | The DUnitX suite and its fixtures |
| `docs/` | Phase reports, audits and design contracts — the source of this site |
| `reports/` | 42 regression report fixtures (41 checked + 1 skipped by design) and the pagination baseline |
| `tools/` | The regression gate script |

## Report objects

Text, data field, memo (rich text), image, shape, line, barcode (including QR
and EAN-13), table, chart, cross-tab, and nested sub-reports.

## Expressions

Two engines coexist. The legacy evaluator remains the compatibility contract,
and the modern expression language (Phase 4B-2A/2B) adds its own tokenizer,
evaluator, diagnostics and migration path. The compatibility rules are recorded
in the Phase 4A and Phase 4B documents under **Modernization**.

## Export

Vector PDF (with SVG and EMF sub-backends; Latin-text-only beta), raster PDF via the Windows printing
system, XLSX, HTML, plain text and email.

## Getting started

=== "Build everything"

    ```bat
    build.bat
    ```

    Builds the runtime package and the design-time package (Win32), and the standalone
    designer for Win32 and Win64 (Release). Requires RAD Studio / Delphi on
    `PATH`, or it will locate `rsvars.bat` for Studio 23.0 or 22.0 itself.

=== "Run the regression gate"

    ```powershell
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages
    ```

    Builds the DUnitX suite, runs it, builds `VittixRunner` and runs it with
    `--strict` (pagination baseline plus handle thresholds), then smoke-builds
    the packages and the designer. `-SkipRunner` stops after the test suite.

=== "Use the runtime in your own application"

    Add `source/` to the library search path, load a `.vrt` with
    `TReportSerializer`, attach a dataset, then prepare and export:

    ```delphi
    uses
      Vittix.Report.Model,
      Vittix.Report.Engine,
      Vittix.Report.Serializer,
      Vittix.Report.Export.PDF;

    procedure GenerateInvoicePDF;
    var
      Report: TReportModel;
      Engine: TReportEngine;
    begin
      Report := TReportSerializer.LoadFromFile('C:\Reports\Invoice.vrt');
      try
        Engine := TReportEngine.Create(Report, qryInvoiceData);
        try
          Engine.Prepare;
          TReportPDFExporter.ExportToFile(Engine.Pages, 'C:\Output\Invoice_001.pdf');
        finally
          Engine.Free;
        end;
      finally
        Report.Free;
      end;
    end;
    ```

## Verification status

Recorded against `96197c1` (`main`), with the modernization baseline tagged
`vittixreport-modernization-closed` at `cebb7e4`.

| Check | Result |
|---|---|
| DUnitX suite | 652 found, 652 passed, 0 failed, 0 errored, 0 leaked |
| `VittixRunner --strict` | PASS — 41 reports checked, 41 matched, 0 mismatches, 1 skipped |
| Resource thresholds | USER handle delta 0, GDI handle delta 8 (limit 16) |
| Build from a clean clone | All targets build: runtime package, design package, designer, demo, tests, runner |

!!! warning "Continuous integration is not yet a usable signal"
    `.github/workflows/build-and-test.yml` requires a self-hosted
    `windows` + `delphi` runner, and none is registered on the repository, so
    push-triggered runs queue and never execute. Treat the local gate above as
    the authoritative verification until a runner exists.

## Requirements

- Delphi 12.2 or later, RAD Studio 23.0 is what the project files are built with
- Windows 10 or later, Win32 or Win64
- PDF export through the Windows printing system needs a PDF printer such as
  *Microsoft Print to PDF*

## Documentation map

- **Project** — the repository [README](readme.md), the [user manual](user-manual.md), the [developer manual](developer-manual.md) and
  the [testing guide](testing.md).
- **Reference** — [report events](EVENTS.md), the [designer](designer.md), its [icon map](designer-icon-map.md), the [demo
  application](demo-app.md), the [demo templates](demo-templates.md), the [regression fixtures](regression-fixtures.md) and the [branding
  assets](branding.md).
- **Roadmap** — TODO, the bug queue, the designer UX roadmap and the feature
  plans.
- **Modernization** — the Phase 1 to Phase 6 programme documents, the expression
  engine design and the residual audit.
- **Analysis** — the architecture analysis, the technical evaluation, the code
  reviews and the GAP-005 audits.

## Local preview

```powershell
python -m mkdocs serve      # http://127.0.0.1:8000
python -m mkdocs build      # writes build/site/
python -m mkdocs gh-deploy  # publishes to the gh-pages branch
```

Requires `pip install mkdocs-material`.
