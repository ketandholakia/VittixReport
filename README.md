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

## Getting Started

### Prerequisites
* Delphi 12.2 (VCL, Win32/Win64)
* Windows 10+ (Required for native "Microsoft Print to PDF" functionality)

### Building the Standalone Designer
1. Open `vittixdesigner/VittixDesigner.dproj` in the Delphi IDE.
2. Build and run (`F9`). 
3. Use the tool palette on the left to drag objects onto the canvas, edit properties on the right, and use `F5` to preview.

### Using the Runtime Components
To integrate VittixReport into your own VCL application:

1. Install the packages from the `packages/` folder.
2. Add the `source/` directory to your Delphi Library Path.
3. Drop a `TVittixReport` component onto your form.
4. Assign a `TDataSource` to bind your data.

### Example: Exporting a Report to PDF

The engine operates completely independently of the designer, allowing for silent background generation:

```delphi
uses
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Export.PDF;

procedure GenerateInvoicePDF;
var
  Report: TReportModel;
  Engine: TReportEngine;
begin
  // 1. Load the JSON report definition
  Report := TReportSerializer.LoadFromFile('C:\Reports\Invoice.vrt');
  
  // 2. Initialize the engine with the report and your live dataset
  Engine := TReportEngine.Create(Report, qryInvoiceData);
  try
    // 3. Process the bands and evaluate expressions
    Engine.Prepare;
    
    // 4. Export the rendered pages
    TReportPDFExporter.ExportToFile(Engine.Pages, 'C:\Output\Invoice_001.pdf');
  finally
    Engine.Free;
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
