<div align="center">
  <h1>VittixReport</h1>
  <p><b>A modern, dependency-free reporting framework and standalone visual designer for Delphi VCL applications.</b></p>
</div>

VittixReport is a comprehensive reporting suite built entirely from the ground up for Delphi. It provides developers with a robust runtime engine, a band-oriented report model, and a full-featured visual designer. 

Unlike legacy reporting tools, VittixReport relies entirely on standard Delphi RTL and VCL components—**zero third-party dependencies required**. Reports are serialized into a clean, source-control-friendly JSON format (`.vrt`).

## Features

* **🎨 Standalone Visual Designer:** A powerful desktop application featuring drag-and-drop object placement, a property inspector, band management, and a live print preview.
* **⚡ Dependency-Free:** Built strictly with Delphi 12.2 RTL and VCL. No external component packs or libraries to install.
* **🔄 Unlimited Undo/Redo:** The designer implements a deep undo/redo stack for *every* action, including complex multi-object alignments, property changes, and band management.
* **📄 JSON Report Format (`.vrt`):** Say goodbye to binary blobs. Reports are stored in a human-readable, easily diffable JSON format.
* **🧩 Rich Object Library:** Out-of-the-box support for text labels, data fields, rich text, images, shapes, lines, barcodes, tables, and nested sub-reports.
* **🚀 Runtime Event Scripting:** Hook into the engine's rendering pipeline with `OnBeforePrint` / `OnAfterPrint` events at both the band and object level, driven by your host application's Delphi code.
* **📊 Band-Oriented Layout:** Supports standard structural bands including Report Title, Page Header/Footer, Master Data (with runtime `TDataSet` binding), and Report Summary.
* **🖨️ Print & Export:** Built-in PDF export (via Windows Print to PDF) and native system printing capabilities.

## Project Structure

* `source/` — The core framework (engine, object model, serializer, components, and designer UI controls).
* `vittixdesigner/` — The standalone Windows report designer application.
* `packages/` — Delphi runtime and design-time package files (`.dpk`).
* `docs/` — Additional technical documentation (e.g., Event Scripting Rules).

## Requirements
* Delphi 12.2 or later
* VCL application target
* Windows 10 or later
* Win32 or Win64 target platform

*PDF export currently relies on the Windows printing system, such as Microsoft Print to PDF.*

## Getting Started

### Building the Standalone Designer

1. Open the project: `vittixdesigner/VittixDesigner.dproj`
2. Build the project in Delphi.
3. Run the designer.

Use the designer to:
* Create reports
* Add bands
* Place report objects
* Bind fields
* Edit properties
* Preview reports
* Save `.vrt` files

### Using the Runtime Components
To use VittixReport in your own Delphi VCL application:

1. Add the `source/` folder to your Delphi library/search path.
2. Install the runtime/design-time packages from `packages/`, if required.
3. Load a `.vrt` report file using `TReportSerializer`.
4. Attach your dataset.
5. Prepare and preview, print, or export the report.

### Example: Export a Report to PDF

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

      TReportPDFExporter.ExportToFile(
        Engine.Pages,
        'C:\Output\Invoice_001.pdf'
      );
    finally
      Engine.Free;
    end;
  finally
    Report.Free;
  end;
end;
```

## File Format
- Reports are saved as JSON (`.vrt`). See `Vittix.Report.Serializer` for details.

## License
See [LICENSE](LICENSE).

## Documentation
- See `USER_MANUAL.md` for end-user instructions
- See `DEVELOPER_MANUAL.md` for developer integration and extension
