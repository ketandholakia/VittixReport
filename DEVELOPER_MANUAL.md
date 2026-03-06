# VittixReport Developer Manual

## Architecture Overview
VittixReport is a modular reporting framework for Delphi (VCL) with a visual designer, runtime engine, and extensible object model.

### Key Components
- **TVittixReport**: Non-visual component for embedding reports in VCL forms.
- **TReportModel**: In-memory representation of a report (bands, objects, settings).
- **TReportEngine**: Processes a `TReportModel` and a `TDataSet` to generate report pages.
- **TReportRenderer**: Renders pages to bitmaps/metafiles for preview/export.
- **TReportPDFExporter**: Exports pages to PDF using Windows Print to PDF.
- **TVittixReportPreview**: VCL control for displaying report pages.

### File Structure
- `source/`: Core units (engine, model, objects, designer, serializer, etc.)
- `vittixdesigner/`: Standalone designer app (forms, main window, dialogs)
- `demos/FullFeaturedDemo/`: Example host app
- `packages/`: Delphi package files

## Integration Guide
1. Add the `source/` folder to your Delphi project search path.
2. Install the runtime and design packages from `packages/`.
3. Drop `TVittixReport` on your form. Assign a `TDataSource`.
4. Use `Execute`, `Print`, or `ExportToPDF` methods as needed.

## Extending the Framework
- **Custom Objects**: Register new object types via `Vittix.Report.ObjectRegistry`.
- **Custom Exporters**: Implement `IReportExporter` for new export formats.
- **Designer Extensions**: Extend the designer by adding new tools or property bridges.

## File Format
- Reports are JSON (`.vrt`). See `Vittix.Report.Serializer` for schema.

## Coding Standards
- Follows Delphi OOP best practices.
- Uses generics, interfaces, and modern VCL patterns.

## Troubleshooting
- Ensure all dependencies from `source/` are included.
- For PDF export, Windows 10+ is required.
- See comments in each unit for detailed documentation.

## Contributing
- Fork the repo and submit pull requests.
- Report issues via GitHub.

## License
See [LICENSE](LICENSE).
