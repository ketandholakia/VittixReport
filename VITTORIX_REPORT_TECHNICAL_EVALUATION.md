# VittixReport — Technical Evaluation Report

**Date:** August 2026  
**Evaluator:** Solar Pro4 (Upstage AI)  
**Scope:** Full architectural, functional, and code-quality assessment of the VittixReport Delphi VCL reporting engine

---

## 1. Executive Summary

### Strengths

- **Clean separation of engine/renderer/serializer:** The TReportEngine, TReportRenderer, and TReportSerializer are well-isolated and testable in isolation.
- **Modern serialization format:** JSON-based `.vrt` files with versioning, field-name embedding, and clone support — significantly more portable than binary DFM.
- **Abstract data-layer interface:** `IReportDataSource`, `TVittixUserDataSet`, and named-dataset resolution decouple the engine from BDE/FireDAC/ADO.
- **Extensive object model:** Bands, text, labels, fields, shapes, images, memos, sub-reports, lines, tables, cross-tabs, charts, barcodes — competitive breadth.
- **Expression engine:** Custom parser with system tokens, field tokens, arithmetic, comparisons, boolean literals, and aggregate functions — all without external script dependencies.
- **Vector PDF exporter:** Hand-written PDF 1.4 generator with embedded TrueType fonts viausp10.dll shaping, PNG/JPEG image XObjects, and alpha masks — a serious engineering effort.
- **Undo/redo infrastructure:** Full command-pattern system with move, resize, insert, delete, z-order, property-change, font-change, page-settings, and metadata commands.
- **Designer integration:** VCL-based designer with toolbox, property panel, structure tree, align/distribute commands, zoom, grid/snap, rulers, and expression editors.
- **Test coverage:** DUnitX tests exist for engine dataset-state preservation, footer page-break recursion, and serializer round-trips/cloning/clipboard.

### Risks

- **PDF export fragility:** TReportPDFExporter depends on "Microsoft Print to PDF" virtual printer driver; silent failures when the driver is missing or reconfigured.
- **Print fidelity path:** Renderer uses StretchDraw of metafiles/bitmaps to printer canvas — not GDI-metafile playback — so printer-output sharpness depends on printer DPI and may diverge from preview.
- **Legacy data-source coupling remains:** TVittixReport still exposes DataSource and falls back to FDataSource.DataSet; dual paths duplicate resolution logic.
- **Expression engine limitations:** No parentheses, no functions beyond aggregates, no string manipulation, no date arithmetic, no user-defined variables beyond simple name/value pairs.
- **Chart/cross-tab/maturity:** Charts are GDI-drawn pie/bar/line only; cross-tab builds in-memory matrix with O(n²) dictionary lookups — fine for small data but not for large datasets.
- **64-bit pointer arithmetic risk:** Vector PDF exporter uses NativeInt/Int64 bookmark comparisons and some AnsiString Pascal scripting — must be audited for 64-bit.
- **Single-threaded engine:** No synchronization in engine; TReportEngine is not thread-safe; background generation would require a wrapper.

### Strategic Recommendations

1. **Replace printer-driver PDF with pure-vector path as default** once Vector PDF is production-ready; deprecate Microsoft Print to PDF path.
2. **Unify data resolution** to the UserDataSet path and remove legacy DataSource fallback or gate it behind a conditional symbol.
3. **Strengthen expression engine** with parentheses, string functions, date functions, and user variables scoped to band/group/page — without a full script engine.
4. **Formalize plugin/extension contract** with `IReportPlugin` already declared but not wired; expose object registration and export-filter registration.
5. **Add visual regression tests** for preview/export parity; automate comparison of metafile content across preview and export paths.

---

## 2. Detailed Findings

### 2.1 Architecture & Design Patterns

**Overall pattern:** Component-based layered architecture. The core layer (Model, Objects, Bands, Context, Expressions, Aggregates, PageSettings, Interfaces) sits at the bottom; the engine layer (Engine, LayoutPagination, LayoutCache, LayoutBookmarks, Scripting, UserDataSet, DataSources) builds on it; the rendering/export layer (Renderer, Export*) sits above; the designer and component layer (Component, DesignerControl, DesignerInteraction, Undo, PropertyBridge, Toolbox, Reg) sit at the top.

**Separation of concerns:**

- Engine owns pagination, band loop, group detection, and page construction. It does not draw — it emits metafiles and export commands.
- Renderer owns metafile→bitmap conversion and printer metafile playback.
- Serializer owns JSON persistence.
- Designer owns interactive manipulation, selection, undo/redo, property editing.

This is a healthy separation. The engine is testable without the designer; the serializer is testable without the engine.

**Delphi-specific patterns:**

- `TComponent` ownership is used for `TVittixReport` and `TVittixUserDataSet` — good.
- Streaming is JSON-based, not DFM-based — good for portability.
- RTTI is used in `TPropertyChangeCommand` and `TReportPropertyBridge` — appropriate for property editing and undo.
- Class-of registry (`TReportObjectClass`) and `RegisterReportObject` enable extensibility — good.

**Inheritance hierarchy:**

```
TPersistent
  TReportObject (published: Bounds, Visible, PrintWhen, OnBeforePrint, OnAfterPrint, AnchorRight, AnchorBottom, PageBreakBefore, PageBreakAfter, Locked)
    TReportTextObject (Font, HAlign, VAlign, Background, Transparent, Border*, WordWrap, AutoSize, Padding*, conditional styles)
      TReportLabelObject
      TReportFieldObject (DisplayFormat, EditMask)
      TReportMemoObject (AutoHeight, MinHeight, AllowHTML)
    TReportShapeObject
    TReportImageObject (Picture, cached image, DataField, Stretch, Center, Proportional, Border*)
    TReportSubReportObject (ReportJSON, DataSetName, MasterField, DetailField, Border*)
    TReportLineObject (Orientation, ExtendToPageBottom)
    TReportBarcodeObject (Value, DataField, Symbology, ShowText, BarColor, BackgroundColor)
    TReportTableObject (Rows, Cols, HeaderRows, GridColor, HeaderColor)
    TReportCrossTabObject (DataSetName, RowField, ColumnField, CellField, Aggregate, totals, fonts, CellFormat)
    TReportChartObject (ChartType, DataSetName, DataFieldLabel, DataFieldValue, Title, ShowLegend)
```

`TReportBand` also descends from `TReportObject` but adds children, band-type, data-binding, group, can-grow/shrink, background conditions, and page-override properties.

The hierarchy is shallow and composable. Bands contain children; objects are not nested otherwise. This is appropriate for reporting.

**Database coupling:** The engine primarily uses `TDataSet` and `TVittixUserDataSet`. `IReportDataSource` is declared with JSON/CSV/REST scaffolds that raise "not implemented" — showing intent but no production implementation. The engine knows about `Data.DB` directly, which is fine for VCL reporting, but limits cross-platform potential. The dual resolution path (UserDataSet first, DataSource fallback) creates two code paths.

**Verdict:** Clean layered architecture. Inheritance is shallow and extensible. Data abstraction exists but is incomplete.

---

### 2.2 Report Object Model

**Object catalog:**

- Bands: ReportTitle, PageHeader, MasterData, PageFooter, ReportSummary, GroupHeader, GroupFooter, ColumnHeader, Detail, Overlay — 10 band types.
- Text objects: Text, Label, Field, Memo — 4 types.
- Shapes: Rectangle, RoundRect, Ellipse, Line, DiagonalLine — 5 types.
- Image, SubReport, Line, Barcode — 4 types.
- Table, CrossTab, Chart — 3 advanced objects.

**Composite pattern:** Bands own children via `TObjectList<TReportObject>`. Objects are not nested beyond bands. This is a limited composite — appropriate for reporting but means no nested containers (e.g., grouped frames).

**Property serialization:**

- JSON with `Version` key (currently 2).
- Per-class serializers registered in `GSerializers` dictionary, with inheritance-aware lookup.
- Base serializer writes common properties; subclass serializers write specific ones.
- Versioning strategy: `LoadFromJSON` reads `Version` and passes it to `JSONToObjectEx`; v1 files without `Children` arrays still load.
- `CloneObject` and `CloneReport` provide deep cloning via JSON round-trip.

**Z-ordering:** The flat `Objects` list in `TReportModel` and `Children` list in `TReportBand` imply z-order = list order. `TZOrderCommand` supports bring-to-front/send-to-back. No explicit z-index property.

**Anchoring:** `AnchorRight` and `AnchorBottom` properties exist on `TReportObject` but are not actively applied during rendering — they are persisted but appear to be design-time/layout hints only.

**Layout constraints:** `CanGrow`/`CanShrink` on bands, `AutoSize`/`WordWrap` on text objects, `AutoHeight` on memos. These are rendering-time calculations, not constraints solved by a layout engine.

**Master-detail:** Supported via `MasterField`/`DetailField` on bands, with lookup by field value. Sub-reports have their own `DataSetName`/`MasterField`/`DetailField`. This is functional.

**Verdict:** Object model is comprehensive and serializable. Composite is band-scoped. Anchoring and layout constraints are present but limited.

---

### 2.3 Data Binding & Expression Engine

**Data binding:**

- Bands bind to datasets via `DataSetName` (named dataset lookup) or fall back to primary dataset.
- Text objects bind via `DataField` (reads `SafeSourceFieldAsString` / `SafeSourceFieldValue`).
- Field objects add `DisplayFormat` and `EditMask`.
- Images bind via `DataField` (file path or base64).
- Memos bind via `DataField` with multi-line support.
- Barcodes bind via `DataField`.
- Charts and cross-tabs bind via `DataSetName` + field selectors.

**Expression parser/evaluator:**

- Custom `TReportExpression.Evaluate` in `Vittix.Report.Expressions`.
- Evaluation order: aggregate functions → system tokens → field tokens → quoted strings → boolean literals → comparisons → arithmetic → numeric fallback → string fallback.
- Aggregate functions: `SUM`, `COUNT`, `AVG`, `MIN`, `MAX` — evaluated over dataset range bounded by group bookmarks.
- System tokens: `[PageNo]`, `[TotalPages]`, `[RowNumber]`, `[Param.Name]`, `[ReportTitle]`, `[ReportDate]`, `[DateTime]`, `[Time]`, `[RecNo]`.
- Field tokens: `[FieldName]` and qualified `[DataSetName.FieldName]`.
- Arithmetic: `+`, `-`, `*`, `/` on resolved numeric values.
- Comparisons: `<=`, `>=`, `<>`, `=`, `<`, `>` with numeric or string comparison.
- String literals: `'text'`.
- Boolean literals: `true`, `false`.

**Aggregate functions:**

- Implemented in `TReportAggregates.TryEvaluate`.
- Scoped by `GroupStart`/`GroupEnd` bookmarks — so aggregates can be group-local.
- The bookmark leak bug (calling `GetBookmark` in loop without freeing) was fixed.
- Performance: each aggregate call traverses the dataset from group start to group end — O(n) per call per row. No caching. For multiple aggregates on the same range, this is repeated traversal.

**Parameters and variables:**

- `TReportEngine.Parameters` (TStrings) for runtime parameters, referenced as `[Param.Name]`.
- `TReportModel.Variables` (TStrings name=value) for design-time constants, referenced as `[VarName]`.
- No page-level or group-level variable scoping beyond the group bookmark mechanism.

**Null handling:**

- `VarIsNull`/`VarIsEmpty` checks in expression evaluator and field resolution.
- `SafeSourceFieldAsString` and `SafeSourceFieldValue` in `Vittix.Report.Utils` guard against missing fields and inactive datasets.
- `FormatFieldDisplayValue` handles `VarIsNull` → empty string.
- Conditional expressions return `False` on exception.

**Data type coercion:**

- Field values read as string via `AsString`; for aggregates, `ValVar` is coerced to `Double` via `VarAsType`.
- `FormatFieldDisplayValue` handles `varDate` → `FormatDateTime`, numeric → `FormatFloat`, fallback to `Format`.
- `EditMask` applied via `FormatMaskText`.

**Verdict:** Expression engine is functional for common reporting needs but lacks parentheses, functions beyond aggregates, string/date manipulation, and advanced scoping. Aggregate performance could degrade with many aggregates on large datasets.

---

### 2.4 Rendering Engine

**Pipeline:**

1. `TReportEngine.Prepare` iterates bands/datasets, calling `PrintBand`.
2. `PrintBand` creates a metafile canvas (`TMetafileCanvas`) on a `TMetafile`, sets viewport origin to margins, clips to printable area, calls `ABand.Draw(FCanvas, Ctx)`.
3. Each object's `Draw` uses GDI `TCanvas` operations: `Rectangle`, `FillRect`, `TextOut`, `DrawText`, `StretchDraw`, `MoveTo`/`LineTo`, `Ellipse`, `Pie`, `RoundRect`.
4. After each page is complete, `EndCurrentPage` finalizes the metafile and adds it to `FPages`.
5. `TReportRenderer.Render` copies each engine metafile into a `TRenderPage` (bitmap + metafile), then `TReportRenderer.Print` stretches each bitmap onto the printer canvas.

**Output fidelity:**

- Designer uses the same `Draw` methods for preview (design-time canvas).
- Preview uses `TReportRenderer` with metafile→bitmap→canvas.
- Print uses `StretchDraw` of bitmaps to printer canvas — not metafile playback. This means print output is rasterized at printer DPI, which can cause blurring on high-DPI printers and divergence from preview.
- Vector PDF exporter captures export commands during rendering and writes true vector PDF — but this is a separate code path, not the print path.

**Pagination:**

- `BandFitsOnPage` checks if `CurrentY + RequiredHeight <= PageHeight - BottomMargin - FooterHeight`.
- `EnsurePageSpaceForBand` starts a new page if not enough space.
- `CanGrow`/`CanShrink` bands compute effective height via `MeasuredBottom` of children.
- `StartNewPage` increments `FPageNumber`, creates new metafile.
- Footer is forced to bottom of page in `EndCurrentPage`.
- Overlay band is drawn last over full page.
- `PageBreakBefore`/`PageBreakAfter` on objects trigger new pages.
- `StartNewPage` on bands forces new page.

**Widow/orphan control:** Not explicitly implemented. `EnsurePageSpaceForBand` prevents bands from starting if they don't fit, but there's no logic to keep a minimum number of lines together or move orphaned lines to next page.

**Keep-together:** Not implemented as a property. Bands with `CanGrow` can expand, but there's no "keep this object with the next" logic.

**DPI awareness:** All dimensions are in pixels at 96 DPI. `TReportPageSettings` uses 96 DPI presets. The vector PDF exporter converts pixels to PDF points via `PDF_POINTS_PER_PIXEL = 72/96`. Printer output uses `StretchDraw` which scales to printer DPI — so output is DPI-dependent.

**Background rendering:** Overlay band supports watermark/stamp use case. No explicit watermark object, but overlay band with text/image children can serve this purpose.

**Layers:** No explicit layer/z-index system beyond list order. Overlay band is a special full-page layer drawn last.

**Verdict:** Rendering pipeline is functional and uses metafiles for preview. Print path rasterizes via StretchDraw — this is the weakest link for print fidelity. Pagination is functional but lacks advanced widow/orphan/keep-together rules.

---

### 2.5 Designer Experience

**Visual designer:** `TVittixReportDesigner` (in `Vittix.Report.DesignerControl`) is a custom control hosting the canvas. Bands are laid out vertically with headers showing band type and height. Objects are drawn within bands.

**Drag-and-drop:** Toolbox items can be dragged onto the designer. Fields from the dataset fields panel can be double-clicked or dragged into bands. The `DesignerDragOver`/`DesignerDragDrop` events handle this.

**Alignment guides:** `DesignerSnapToObjects` implements snap-to-object guides with threshold. `DesignerSnapV` implements grid snap. Rulers, grid, and margins are toggleable view options.

**Property editors:** `TReportPropertyBridge` uses RTTI to load/save published properties to a `TValueListEditor`. Special handling exists for font, color, expression, and script properties via dedicated editors and clickable buttons.

**Component palette integration:** `TVittixReport` has a custom component editor (`TVittixReportComponentEditor`) with verbs to launch the designer. `TVittixReportToolbox` is a registered component. `TVittixUserDataSet` is registered in the palette.

**Undo/redo:** `TCommandManager` with `TUndoableAction` commands. Commands include: `TMoveObjectCommand`, `TMultiMoveCommand`, `TInsertObjectCommand`, `TDeleteObjectsCommand`, `TBandResizeCommand`, `TDeleteBandCommand`, `TZOrderCommand`, `TPropertyChangeCommand`, plus designer-level commands for font, image picture, page settings, report snapshot, and metadata.

**Script/expression editor:** `Frm.ExpressionEditor`, `Frm.TextExpressionEditor`, `Frm.ScriptEditor` forms provide expression and script editing. The script engine (`TReportScriptEngine`) is a stub that fires events — the actual script execution is implemented by the host (e.g., runtime demo). There is no built-in PascalScript/DWScript integration.

**Clipboard:** `TReportSerializer.SerializeObjectListToJSON`/`DeserializeObjectListFromJSON` implement clipboard serialization with `VittixClipboard.1.0` format. Copy/paste in designer uses this.

**Verdict:** Designer is functional with toolbox, property panel, structure tree, align/distribute, undo/redo, and expression editors. Script editor lacks a real scripting backend. No syntax highlighting for expressions is evident.

---

### 2.6 Export & Output Formats

**Supported formats:**

- PDF (via Microsoft Print to PDF printer driver)
- Vector PDF (pure-vector, beta)
- HTML (absolute-positioned divs, inline SVG for lines, base64-embedded images)
- XLSX (Open XML, single sheet, text-only cells, auto column widths)
- Text (tab-separated, band-ordered)
- Email (sends PDF via email — uses Microsoft Print to PDF path)

**PDF generation:**

- `TReportPDFExporter` prints to "Microsoft Print to PDF" virtual printer. This is fragile — depends on driver presence and configuration.
- `TReportVectorPDFExporter` is a hand-written PDF 1.4 generator. It captures export commands during rendering (text, lines, rectangles, fills, images), builds content streams, embeds TrueType fonts via `usp10.dll` ScriptItemize/ScriptShape/ScriptPlace, embeds JPEG/PNG images as XObjects, and writes cross-reference tables. This is a substantial engineering effort.

**Excel export:**

- `TReportXLSXExporter` creates a minimal XLSX with one sheet, styles.xml with 3 font styles (normal, bold, bold-italic), auto column widths, numeric/date detection.
- Does not preserve formulas, multiple sheets, cell merging, borders, or full formatting. Text-only.

**HTML export:**

- Absolute-positioned `div` elements for text, rectangles, fills, lines (SVG), images (base64 or file://).
- CSS for print media.
- No real flow layout; positions are pixel-exact from the report design.
- Modern browser compatible for viewing, but not a flowing HTML document.

**Streaming architecture:**

- PDF: file-based via printer driver; vector PDF supports stream-based output.
- HTML: file or stream via `TStreamWriter`.
- XLSX: file or stream via `TZipFile`.
- Text: file via `TStringList.SaveToFile`.

**Verdict:** Multiple export formats exist. Vector PDF is impressive but still beta. PDF via printer driver is fragile. Excel export is minimal. HTML export is pixel-positioned, not flowing.

---

### 2.7 Performance & Resource Management

**Memory management:**

- `TObjectList<T>` with `OwnsObjects=True` is used consistently for owned collections.
- `try/finally` blocks are used for `TFont`, `TPicture`, `TMetafile`, `TBitmap`, `TMemoryStream`, `TFileStream`.
- `TVittixUserDataSet` uses `TComponent` ownership and `FreeNotification`.
- `TVittixReport` cleans up `FUserDataSets`, `FParameters` in destructor.
- `TReportEngine` frees `FCanvas`, `FCurrentPage`, `FPages`, `FNamedDataSets`, `FNamedUserDataSets`, `FParameters`, `FScriptEngine`, `FGroupHeaders`, `FGroupFooters`, `FDetailBands`, and bookmarks.

**Potential leaks:**

- Image cache in `TReportImageObject` (`FCachedPicture`, `FCachedImagePath`, `FCachedImageValid`) — `ResetImageCache` is called at the start of each pass, which is good.
- `TReportCrossTabObject` owns several `TList<Variant>` and `TDictionary` objects — all freed in destructor. Good.
- `TReportChartObject` owns `TList<TChartDataPoint>` — freed in destructor. Good.
- `TReportExportDocument` and `TReportExportPage` own command lists — freed correctly.

**Dataset cursor strategy:**

- Engine uses `First`/`Next` iteration with `DisableControls`/`EnableControls`.
- Bookmarks used for group start/end and for detail band master-field matching.
- `SafeRecordCount` used for progress total — may fetch all records for some dataset types.
- `TVittixUserDataSet` can wrap any data source; for `TDataSet` backing, it uses the dataset directly.

**Report generation speed:**

- Two-pass rendering doubles the work for reports with `TwoPassRendering=True` (default).
- Aggregate functions traverse the dataset range on each evaluation — no caching.
- Cross-tab builds in-memory matrix via dictionary lookups — O(n) traversal with O(1) lookup per cell, but dictionary operations add overhead.
- Charts traverse dataset once to build data points.
- For 10k+ records, the main cost is the per-row band drawing and any per-row expression evaluation. The engine is single-threaded.

**Double-buffering:** Not used in the engine. Preview uses metafile playback. Designer uses direct canvas drawing with selection handles.

**Thread safety:** `TReportEngine` has no synchronization. `GRegistryCS` in `Vittix.Report.Objects` protects the object registry. `TReportScriptEngine` is a `TComponent` and not thread-safe. The engine cannot be used from background threads without external synchronization.

**Verdict:** Memory management is generally sound. Performance for large datasets is acceptable for GDI-based rendering but not optimized. Thread safety is not a design goal.

---

### 2.8 Grouping, Sorting & Advanced Layouts

**Grouping:**

- `TReportBand` with `btGroupHeader`/`btGroupFooter` types.
- `GroupField` specifies the field to group by.
- `GroupLevel` allows nested groups.
- Engine detects group breaks by comparing `FLastGroupValues` with current field value.
- Group start/end bookmarks bound aggregate ranges.
- Multiple group headers/footers supported via `FGroupHeaders`/`FGroupFooters` lists.
- `StartNewPage` on group headers forces page break.

**Sorting:** Not explicitly supported. Dataset sorting must be done before binding. No sort expression or sort order property on bands.

**Cross-tab/matrix:**

- `TReportCrossTabObject` with `RowField`, `ColumnField`, `CellField`, `Aggregate`.
- Builds in-memory matrix with row/column/value dictionaries.
- Supports row/column grand totals.
- Supports `caSum`, `caCount`, `caMin`, `caMax`, `caAverage`, `caNone`.
- Sorts row/column axes via `TComparer<Variant>.Default`.
- Draws grid with header row/column and cell values.

**Drill-down/interactive:** No hyperlink or drill-down support. No interactive report features.

**Multi-column/newspaper-style:** Not supported. `btColumnHeader` exists but is for repeating column headers after group breaks, not for multi-column layout.

**Label/sticker layout:** Not supported.

**Overflow handling:**

- `TReportMemoObject` with `AutoHeight` and `WordWrap` handles multi-line text with dynamic height.
- `TReportTextObject` with `AutoSize` and `WordWrap` can grow.
- `TReportBand` with `CanGrow`/`CanShrink` can adjust height based on child content.
- `MeasuredBottom` on memo/text objects computes text height for pagination.

**Verdict:** Grouping is functional with nested groups and aggregate scoping. Cross-tab is functional for moderate data. Sorting, drill-down, multi-column, and label layouts are not supported. Overflow handling is basic but functional for memos.

---

### 2.9 Extensibility & Plugin Architecture

**Custom component registration:**

- `RegisterReportObject` and `GetRegisteredReportObjects` in `Vittix.Report.Core` / `Vittix.Report.Objects`.
- `TVittixReportToolbox` reads from `GetRegisteredReportObjects` to populate toolbox.
- `GSerializers` dictionary in `Vittix.Report.Serializer` maps object classes to serializers — third-party objects need a serializer.
- `FindObjectClass` looks up by class name for deserialization.

**Event hooks:**

- `OnBeforePrintReport`, `OnAfterPrintReport`, `OnBeforeBand`, `OnAfterBand`, `OnBeforeObject`, `OnAfterObject` on `TReportEngine`.
- `OnBeforePrint`/`OnAfterPrint` on bands and objects (string properties holding script names).
- `OnBeforeObjectPrint`/`OnAfterObjectPrint` render hooks via `IReportRenderHooks`.
- `OnLargeReport` on `TVittixReport` for progress/cancellation.

**Plugin system:**

- `IReportPlugin` interface declared in `Vittix.Report.Interfaces` but not wired.
- `IReportExporter` interface for export filters — implemented by PDF, VectorPDF, HTML, XLSX, Text exporters. `ExportWith` on `TVittixReport` accepts any `IReportExporter`.
- `IReportProgress` for progress/cancellation.
- No dynamic plugin loading (packages/BPLs) — extensions are compile-time.

**Scriptable extension points:**

- `TReportScriptEngine` is a stub that fires `OnBeforePrint`, `OnAfterPrint`, `OnObjectBeforePrint`, `OnObjectAfterPrint` events. The host implements the actual script execution.
- `OnBeforePrint`/`OnAfterPrint` on bands/objects are strings that reference script names — resolved by the script engine.
- No built-in script engine (PascalScript, DWScript, FastScript) is integrated.

**Template/style inheritance:** No template system. No style inheritance. `CloneReport`/`CloneObject` provide copying but no inheritance hierarchy.

**Verdict:** Extension points exist (object registry, serializers, export interface, event hooks) but plugin system is incomplete. Scripting is stubbed. No template/style inheritance.

---

### 2.10 Delphi-Specific Considerations

**Unicode support:** Uses `System.UTF8` for file I/O (`TFile.ReadAllText`/`WriteAllText` with `TEncoding.UTF8`), `TNetEncoding.Base64` for image embedding, and `WideCharToMultiByte` in Vector PDF for font text mapping. `TReportExpression` uses `AnsiString` for some PDF text operations but the core is Unicode. The `AnsiString` usage in Vector PDF exporter should be audited.

**Platform support:** VCL-only. No FireMonkey (FMX) support. All rendering uses VCL `TCanvas`, `TBitmap`, `TMetafile`. No cross-platform path.

**64-bit compatibility:**

- `TReportEngine` uses `NativeInt` for bookmark comparisons in `TDeleteObjectsCommand` (sorting by `NativeInt(Pointer(L.OwnerList))`). This is 64-bit safe.
- Vector PDF exporter uses `Int64` for stream positions and `NativeInt` in some places.
- `usp10.dll` functions are declared with `stdcall` — should work in 64-bit but need verification.
- Some `AnsiString` usage in Vector PDF should be reviewed for 64-bit.
- No pointer arithmetic that would break in 64-bit is evident.

**VCL integration:**

- `TVittixReport` is a non-visual `TComponent` that appears in the component tray.
- `TVittixReportComponentEditor` launches the designer.
- `TVittixReportPreview` is a VCL control for preview.
- `TVittixReportDesigner` is a VCL control for design.
- `TVittixReportToolbox` is a VCL control.
- No ActiveX/COM exposure.

**Package architecture:**

- `VittixReportRuntime.dproj` — runtime package.
- `VittixReportDesign.dproj` — design-time package.
- `VittixDesigner.dproj` — standalone designer executable.
- `VittixReportTests.dproj` — test executable.
- `VittixReportDemo.dproj` — demo application.
- `VittixRunner.dproj` — console runner.

**Verdict:** VCL-only, Unicode-aware, likely 64-bit compatible with some Vector PDF auditing needed. Package structure is standard Delphi.

---

### 2.11 Comparison Benchmark

**vs. FastReport VCL:**

| Feature | VittixReport | FastReport |
|---------|--------------|------------|
| Bands | 10 types | 10+ types |
| Text/Field/Label/Memo | Yes | Yes |
| Shapes | Rectangle, RoundRect, Ellipse, Line, Diagonal | More shapes |
| Images | Yes, with caching | Yes |
| Sub-reports | Yes | Yes |
| Tables | Basic grid | Advanced |
| Cross-tab | Yes | Yes |
| Charts | Pie, Bar, Line (GDI) | More chart types |
| Barcodes | Legacy + Code39 | Many symbologies |
| Expressions | Custom, aggregate functions | FastScript-based |
| Scripting | Stub | Full script engines |
| PDF export | Printer driver + Vector (beta) | Multiple PDF engines |
| Excel export | Basic single-sheet | More features |
| HTML export | Pixel-positioned | More flowing |
| Undo/redo | Yes | Yes |
| Designer | VCL, toolbox, property panel | More polished |
| Data binding | UserDataSet + TDataSet | Multiple data sources |
| VAT/MSRP | Open-source/unknown | Commercial |

**vs. ReportBuilder:**

| Feature | VittixReport | ReportBuilder |
|---------|--------------|---------------|
| Bands | 10 types | 10+ types |
| Text/Field/Label/Memo | Yes | Yes |
| Shapes | Basic | More |
| Images | Yes | Yes |
| Sub-reports | Yes | Yes |
| Tables | Basic | Advanced |
| Cross-tab | Yes | Yes |
| Charts | Basic | More |
| Barcodes | Basic | More |
| Expressions | Custom | Robust |
| Scripting | Stub | Supported |
| PDF export | Printer + Vector | Multiple |
| Excel export | Basic | More |
| HTML export | Pixel-positioned | More |
| Undo/redo | Yes | Yes |
| Designer | Functional | More polished |
| Data binding | UserDataSet + TDataSet | Multiple |
| Commercial status | Open-source/unknown | Commercial |

**Gaps:**

- No interactive PDF forms.
- No advanced charting (scatter, area, stacked, 3D).
- No barcode symbologies beyond Code39/legacy.
- No sorting expressions.
- No drill-down/hyperlink support.
- No multi-column layout.
- No label/sticker layout.
- No drawing tools (freehand, arrow, etc.).
- No report templates/styles.
- No script engine integration.
- No RDBMS-specific dataset components.

**Competitive advantages:**

- JSON-based report files — portable and versionable.
- Vector PDF exporter with font embedding — impressive engineering.
- Clean separation of engine/renderer/serializer — testable.
- Abstract data layer — flexible data sources.
- Open-source/accessible code — modifiable.

**Migration path:** No FastReport/ReportBuilder template import. The JSON format is different. Migration would require a converter.

---

### 2.12 Code Quality & Maintainability

**Code metrics:**

- `Vittix.Report.Component.pas` — 977 lines. Large but mostly boilerplate export methods.
- `Vittix.Report.Objects.pas` — 1681+ lines. Large but contains many object implementations.
- `Vittix.Report.Engine.pas` — 1692+ lines. Large but contains the full engine.
- `Vittix.Report.Serializer.pas` — 1097 lines. Large but contains many serializers.
- `Vittix.Report.VectorPDF.pas` — 1478 lines. Large but contains the full PDF generator.
- Most other units are under 300 lines.

**Cyclomatic complexity:** Not formally measured, but `TReportEngine.Prepare`, `TReportEngine.PrintBand`, `TReportVectorPDFExporter.ExportDocument`, and `TReportSerializer` methods are long and contain many branches. Refactoring into smaller methods would improve readability.

**Test coverage:**

- `Test.Vittix.Report.Engine` — 2 tests (dataset state preservation, footer page break recursion).
- `Test.Vittix.Report.Serializer` — 5 tests (round-trip empty, round-trip with properties, clone report, clone object, clipboard).
- `Test.Vittix.Report.Objects.Chart` — exists but not read in detail.
- `Test.Vittix.Report.Expressions` — exists but not read in detail.
- `Test.Vittix.Report.Undo` — exists but not read in detail.
- `Test.Vittix.Report.Characterization` — exists but not read in detail.

Test coverage is minimal. No visual regression tests. No performance tests. No integration tests for full report generation.

**Documentation:**

- XMLDoc comments exist on some public methods (e.g., `TVittixReport.RegisterUserDataSet`, `TReportEngine.Prepare`).
- No comprehensive developer guide.
- No API reference documentation.
- `ops_extract.txt` appears to be an operation extract, not documentation.

**Error handling:**

- `EReportException` declared in `Vittix.Report.Engine`.
- `EReportDataSourceError` declared in `Vittix.Report.DataSources`.
- Most methods raise `Exception` with descriptive messages.
- `try/except` blocks in expression evaluation and field resolution catch and return safe defaults.
- `CheckLargeReport` event allows cancellation.
- `OnBeforePrintReport` can cancel via `ACancel`.

**Version control:** Git repository exists. Multiple regression test output directories (`regression_out_tests2`, `regression_out_tests3`, `regression_out_tests4`, `regression_out_tests_fixed`) suggest iterative test fixing. `scratch/` directory contains experimental code.

**Contribution patterns:** Single developer pattern evident. No CI configuration visible. No code review history evident.

**Verdict:** Code is functional and mostly well-organized. Test coverage is minimal. Documentation is sparse. Long methods in engine, serializer, and vector PDF exporter could benefit from refactoring.

---

## 3. Priority-Ranked Improvement Roadmap

### Quick Wins (Low effort, high impact)

1. **Add parentheses and operator precedence to expression parser** — Currently `2+3*4` evaluates left-to-right. Adding a simple recursive descent or shunting-yard parser would fix this without a full script engine.
2. **Add string functions to expressions** — `Upper`, `Lower`, `Trim`, `Substring`, `Length`, `Concat` — would significantly improve text manipulation without external dependencies.
3. **Add date functions to expressions** — `DateDiff`, `AddDays`, `FormatDateTime` — would help date-based reporting.
4. **Fix print path to use metafile playback instead of StretchDraw** — Replace `Printer.Canvas.StretchDraw(R, FPages[i].Bitmap)` with metafile playback for sharper print output.
5. **Add basic sorting support** — Add `SortField` and `SortOrder` properties to bands, with engine-side sorting via dataset `Sort` or in-memory sort for small datasets.
6. **Add hyperlink/drill-down support** — Add `Hyperlink` property to text objects and `OnObjectClick` event on preview.
7. **Add basic formula support to cross-tab** — Allow expressions in cell values, not just field references.
8. **Use Vector PDF exporter as default PDF path** — Once stable, make Vector PDF the default and deprecate printer-driver PDF.
9. **Fix PDF export to not depend on printer driver** — The Vector PDF path already exists; make it the primary path.

### Architectural (Medium effort, structural improvement)

10. **Unify data resolution** — Remove dual `DataSource`/`UserDataSet` paths. Make `UserDataSet` the primary path and deprecate `DataSource` or gate it behind a conditional symbol.
11. **Implement `IReportPlugin` wiring** — Wire the declared `IReportPlugin` interface to allow third-party object registration and toolbox integration.
12. **Integrate a script engine** — Integrate PascalScript, DWScript, or FastScript for `OnBeforePrint`/`OnAfterPrint` scripts. The current stub is not useful.
13. **Add report templates/styles** — Add a style system where objects can inherit font/color/formatting from a style object.
14. **Add multi-column layout** — Add `Columns` property to page settings and implement newspaper-style multi-column layout.
15. **Add label/sticker layout** — Add a label layout mode with repeated label frames.
16. **Add advanced widow/orphan/keep-together** — Add `KeepTogether` property on objects and implement widow/orphan control in pagination.
17. **Refactor long methods** — Break up `TReportEngine.Prepare`, `TReportEngine.PrintBand`, `TReportVectorPDFExporter.ExportDocument`, and `TReportSerializer` methods into smaller, named methods.
18. **Add barcode symbology expansion** — Add Code128, EAN-13, UPC-A, QR code support.

### Strategic (High effort, long-term value)

19. **Add FireMonkey (FMX) rendering path** — Abstract the rendering interface to support both VCL and FMX canvases for cross-platform reports.
20. **Implement visual regression tests** — Automate comparison of preview and export outputs to catch rendering regressions.
21. **Add performance profiling and optimization** — Profile large dataset rendering, cache aggregate results, optimize cross-tab matrix building.
22. **Add thread-safe report generation** — Make `TReportEngine` thread-safe or provide a wrapper for background generation.
23. **Add REST/JSON data source implementation** — Complete the `TRestReportDataSource` and `TJsonReportDataSource` scaffolds.
24. **Add FastReport/ReportBuilder template import** — Build a converter for competitive migration.
25. **Add interactive PDF forms** — Add form field support in Vector PDF exporter.
26. **Add charting expansion** — Add scatter, area, stacked bar, line with markers, and 3D chart types.
27. **Add RTL language support** — Vector PDF exporter already detects `SCRIPT_ANALYSIS_RTL` and rejects it. Proper RTL support would be a significant feature.
28. **Add accessibility support** — Add PDF/UA or accessibility tags to exported PDFs.

---

## 4. Risk Assessment Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| PDF export fails on systems without "Microsoft Print to PDF" driver | High | High | Use Vector PDF exporter as default |
| Print output diverges from preview due to StretchDraw rasterization | High | Medium | Use metafile playback for printing |
| Expression parser evaluates `2+3*4` as `20` instead of `14` | High | Medium | Add operator precedence |
| Aggregate performance degrades with many aggregates on large datasets | Medium | Medium | Cache aggregate results per group |
| Thread safety issues if engine used from background thread | Low | High | Document thread affinity; add synchronization |
| 64-bit issues in Vector PDF exporter (AnsiString, pointer arithmetic) | Medium | High | Audit and fix before 64-bit release |
| Dual DataSource/UserDataSet paths cause confusion | High | Low | Unify to single path |
| Script engine stub provides no real scripting capability | High | Medium | Integrate PascalScript/DWScript |
| No template import prevents FastReport/ReportBuilder migration | High | Medium | Build converter or document manual migration |
| Minimal test coverage misses regressions | High | Medium | Add visual regression and integration tests |
| Cross-tab memory usage for large datasets | Medium | Medium | Stream or chunk large matrices |
| JSON format changes break backward compatibility | Low | High | Maintain version field and forward-compatibility |
| VCL-only limits cross-platform adoption | High | Medium | Abstract rendering interface for FMX |
| No sorting support limits report flexibility | High | Low | Add sorting properties |
| No drill-down/hyperlink limits interactivity | High | Low | Add hyperlink support |

---

## Appendix A: Unit Dependency Graph (Simplified)

```
Interfaces (root)
  Context (root)
    Expressions
      Aggregates
    DataSources
    UserDataSet
    Bands
      Objects
        Table, CrossTab, Chart, Barcode
    PageSettings
    Model
    Serializer
      ObjectRegistry
    Engine
      LayoutPagination
      LayoutCache
      LayoutBookmarks
      Scripting
    Renderer
    Export*
      Export.Commands
      Export.PDF
      Export.VectorPDF (SVG, EMF)
      Export.XLSX
      Export.HTML
      Export.Text
      Export.Email
    Component
      ComponentEditor
    DesignerControl
    DesignerInteraction
    SelectionHelpers
    Undo
    PropertyBridge
    Toolbox
    Reg
    CommandDispatcher
    Interfaces (reused)
```

**Cycle check:** `Context` is clean (no VittixReport imports). `Interfaces` is clean. `Expressions` imports `Context` and `Aggregates`. `Bands` imports `Objects` and `Context`. `Objects` imports `Context` and `Expressions`. `Serializer` imports `Model`, `Objects`, `Bands`, `PageSettings`, and specific object units. `Engine` imports `Model`, `Bands`, `Objects`, `Context`, `PageSettings`, `Scripting`, `Layout*`, `UserDataSet`, `Export.Commands`, `Interfaces`. `Renderer` imports `Model`, `UserDataSet`, `Engine`. No cycles detected.

---

## Appendix B: Test Inventory

- `Test.Vittix.Report.Engine` (2 tests)
  - `Test_H01_DatasetStatePreservation`
  - `Test_C01_FooterPageBreakRecursion`
- `Test.Vittix.Report.Serializer` (5 tests)
  - `Test_RoundTrip_EmptyModel`
  - `Test_RoundTrip_ModelWithProperties`
  - `Test_CloneReport`
  - `Test_CloneObject`
  - `Test_Clipboard_SerializeDeserialize`
- `Test.Vittix.Report.Objects.Chart` — exists (contents not reviewed)
- `Test.Vittix.Report.Expressions` — exists (contents not reviewed)
- `Test.Vittix.Report.Undo` — exists (contents not reviewed)
- `Test.Vittix.Report.Characterization` — exists (contents not reviewed)

---

*End of evaluation.*
