# VittixReport

VittixReport is a Delphi-based reporting framework and designer suite for building, previewing, and exporting complex reports. It includes a full-featured standalone report designer, a runtime engine, and a set of extensible components for integration into Delphi VCL applications.

## Features
- Visual report designer (standalone app)
- Band-oriented report model (title, headers, footers, master data, summary)
- Drag-and-drop object placement (labels, fields, images, tables, barcodes, shapes, etc.)
- Full undo/redo, alignment, and property inspector
- Print preview and PDF export (via Windows Print to PDF)
- JSON-based report file format (`.vrt`)
- No third-party dependencies (Delphi RTL + VCL only)

## Project Structure
- `source/` — Core reporting engine, designer, and object units
- `vittixdesigner/` — Standalone report designer application
- `demos/FullFeaturedDemo/` — Example host application
- `packages/` — Delphi package files for design/runtime

## Getting Started
### Prerequisites
- Delphi 12.2 (VCL, Win32/Win64)

### Building the Designer
1. Open `vittixdesigner/VittixDesigner.dproj` in Delphi 12.2
2. Build and run (F9)

### Using the Runtime Components
- Drop `TVittixReport` on a form (like TfrxReport in FastReport)
- Assign a `TDataSource` and call `Execute`, `Print`, or `ExportToPDF`

### Example: Exporting a Report to PDF
```delphi
uses
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Export.PDF;

var
  Report : TReportModel;
  Engine : TReportEngine;
begin
  Report := TReportSerializer.LoadFromFile('MyReport.vrt');
  Engine := TReportEngine.Create(Report, MyADOQuery);
  try
    Engine.Prepare;
    TReportPDFExporter.ExportToFile(Engine.Pages, 'output.pdf');
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
