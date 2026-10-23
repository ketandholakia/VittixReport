# VittixReport Developer Manual

## Architecture Overview
VittixReport is a modular reporting framework for Delphi (VCL) with a visual designer, runtime engine, and extensible object model.

### Key Components
- **TVittixReport**: Non-visual component for embedding reports in VCL forms.
- **TReportModel**: In-memory representation of a report (bands, objects, settings).
- **TReportEngine**: Processes a `TReportModel` and a `TDataSet` to generate report pages.
- **TReportRenderer**: Renders pages to bitmaps/metafiles for preview/export.
- **TReportPDFExporter**: Compatibility PDF exporter (prints to Windows Print to PDF). The default PDF export is the native vector writer (`Vittix.Report.Export.VectorPDF`), used by `ExportToPDF` / the designers' Export PDF actions.
- **TVittixReportPreview**: VCL control for displaying report pages.

### File Structure
- `source/`: Core units (engine, model, objects, designer, serializer, etc.)
- `vittixdesigner/`: Standalone designer app (forms, main window, dialogs)
- `packages/`: Delphi package files

## Integration Guide
1. Add the `source/` folder to your Delphi project search path.
2. Install the runtime and design packages from `packages/`.
3. Drop `TVittixReport` on your form. Assign a `TDataSource`.
4. Use `Execute`, `Print`, or `ExportToPDF` methods as needed.

## Master-Detail Linking (FireDAC + Firebird)

VittixReport supports two master-detail patterns. Both produce the same
output; they differ in who does the matching.

### Pattern 1 — FireDAC `MasterSource` (recommended for large data)

Let FireDAC do the linking, and leave the detail band's `MasterField`
and `DetailField` properties **empty**. Choose one of these mutually
exclusive mechanisms; do not combine them:

**(a) Parameterized query, linked through `MasterSource`**

```pascal
// Master
FDQueryMaster.Open('SELECT ID, NAME FROM CUSTOMER ORDER BY NAME');
// FireDAC re-runs the query with the new :ID on each master cursor move.
// The WHERE clause filters rows, so IndexFieldNames is not needed.
FDQueryDetail.MasterSource := dsMaster;
FDQueryDetail.Open('SELECT * FROM INVOICE WHERE CUSTOMER_ID = :ID');
```

**(b) Unfiltered query, with local master-detail filtering**

```pascal
FDQueryMaster.Open('SELECT ID, NAME FROM CUSTOMER ORDER BY NAME');
FDQueryDetail.MasterSource := dsMaster;
FDQueryDetail.MasterFields := 'ID';              // master link field
FDQueryDetail.IndexFieldNames := 'CUSTOMER_ID';  // detail range field
FDQueryDetail.Open('SELECT * FROM INVOICE');
```

```pascal
VittixReport.Execute;   // detail band: DataSetName='Details',
                        // MasterField='' DetailField='' -> prints ALL
                        // rows the detail dataset currently holds
```

When `MasterField`/`DetailField` are empty the engine prints **every row
the detail dataset currently exposes**, which is exactly the FireDAC-
filtered set. No engine-side scanning happens at all.

### Pattern 2 — Engine-side matching (`MasterField`/`DetailField`)

Give the detail band both field names and let the engine match rows:

```pascal
DetailBand.DataSetName := 'Details';
DetailBand.MasterField := 'ID';        // field on the master dataset
DetailBand.DetailField := 'CUSTOMER_ID'; // field on the detail dataset
```

The engine builds a **key index once per pass** (`TDetailBandKeyIndex`):
each distinct `DetailField` value is mapped to the bookmarks of the rows
carrying it, so each master row is a direct lookup instead of a
`First..Eof` scan - O(master + detail rows) instead of
O(master x detail). Match semantics are identical to the historical
scan: `NULL` matches only `NULL`, numbers compare by value across their
subtypes, and numeric strings coerce the way `VarSameValue` did. Row
order within a key is preserved. The index is rebuilt at the start of
every pass, so data changed between passes is picked up. Datasets
without bookmarks (e.g. `TVittixUserDataSet`, or a `TFDQuery` with
`FetchOptions.Unidirectional := True`) automatically keep the historical
scan.

Do not combine Pattern 2 with a FireDAC master-linked detail dataset:
the visible detail rows change as the master moves, so the engine uses the
historical scan instead of indexing that dataset.

Reports that need aggregates, cross-tab or chart objects require
a bookmark-capable main dataset; the engine raises a clear
`EReportException` at `Prepare` otherwise (for TFDQuery set
`FetchOptions.Unidirectional := False`). Grouping does not impose this
requirement: group bookmarks are captured only when supported, and grouped
reports continue without bookmarks.

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
