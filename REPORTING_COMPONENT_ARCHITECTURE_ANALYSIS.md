# VittixReport Architecture Analysis Report

**Component:** VittixReport — Delphi VCL report component/library
**Date:** 2026-09-12
**Source base:** `D:\ketan\github\VittixReport`
**Scope:** Read-only analysis. No source files were modified.

---

## 1. Repository Reconnaissance

### Directory Structure
```
D:\ketan\github\VittixReport\
├── source/              # 104 units — core library (no UI dependency)
├── vittixdesigner/      # Standalone designer EXE (106 files)
├── tests/               # DUnitX test suite (32 units)
├── demo/                # Demo application
├── bin/                 # Compiled executables
├── dcu/                 # Compiled DCUs
├── reports/             # Sample report files (.vrt)
├── regression_out/      # Regression test output
├── ThirdParty/          # Embedded QRCodeGenLib
├── packages/            # Runtime + design-time packages
├── tools/               # Build/deploy tools
└── docs/                # Documentation
```

### Build and Test Evidence
The repository contains DUnitX test, regression-runner, demo, and designer
projects. This analysis did not build or execute them; historical output files
are not current verification. Build status, pass counts, rendering fidelity,
and runtime performance are therefore **unverified** until reproduced.

---

## 2. Core Architecture

### Layered Dependency Graph
```
┌─────────────────────────────────────────────────────────────────┐
│  vittixdesigner/ (Designer EXE)                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │
│  │ Frm.Main     │→ │ DesignerCtrl │→ │ TReportSerializer │      │
│  │ (UI orchestr)│  │ (visual surf)│  │ (JSON load/save)  │      │
│  └──────────────┘  └──────────────┘  └──────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  source/ (Library — no UI dependency)                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Interfaces.pas  (IReportExporter, IReportPlugin,         │  │
│  │                   IReportProgress, IReportRenderHooks)     │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Model.pas  (TReportModel — central value object)         │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Objects.pas + Bands.pas  (TReportObject hierarchy)      │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Serializer.pas  (JSON save/load, transactional + legacy)│  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Engine.pas  (TReportEngine — prepare/render loop)       │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Renderer.pas  (TReportRenderer — metafile → bitmap)     │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Preview.pas  (TVittixReportPreview)                      │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Export.*.pas  (PDF, XLSX, HTML, VectorPDF, Text, Email) │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Expressions.pas + Aggregates.pas  (expression engine)   │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Scripting.pas + ScriptHost.Adapter.pas  (script hooks) │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  DataSources.pas  (IReportDataSource abstraction)        │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  Undo.pas + CommandDispatcher.pas  (undo/redo)           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions (Confirmed from Source)
| Decision | Evidence | Impact |
|----------|----------|--------|
| TReportModel owns flat TObjectList<TReportObject> | Model.pas line 39 | Clean ownership, bands own children separately |
| Two-pass rendering (count then draw) | Engine.pas line 101: `FTwoPassRendering: Boolean` default True | Accurate TotalPages but 2× dataset traversal |
| JSON is the only persistence format | Serializer.pas — SaveToJSON/LoadFromJSON | Version-tolerant via `Version` key |
| Class discriminator for object types | Serializer.pas `TryResolveObjectClass` reads 'Class' or 'Type' | Forward-compatible for unknown types |
| TExpressionContext is a record (value type) | Context.pas line 47 | No heap allocation per draw call |
| Script engine is a thin callback host | Scripting.pas — delegates to events | No PascalScript dependency in core |
| IReportDataSource abstraction exists | DataSources.pas declares an interface and four classes | **Not integrated:** only the TDataSet adapter has logic; JSON/CSV/REST raise a scaffold exception, and the engine does not consume this interface |

---

## 3. Report Definition Model

### TReportModel (source/Vittix.Report.Model.pas)
```pascal
TReportModel = class(TPersistent)
private
  FObjects:      TObjectList<TReportObject>;  // owns items
  FPageSettings: TReportPageSettings;           // never nil
  FFieldNames:   TStringList;                   // embedded schema
  FDataSetNames: TStringList;                   // dataset aliases
  FVariables:    TStringList;                   // design-time constants
  FTitle, FAuthor, FDescription: string;        // metadata
published
  property Objects: TObjectList<TReportObject> read FObjects;
  property PageSettings: TReportPageSettings read FPageSettings;
  property FieldNames, DataSetNames, Variables: TStringList;
  property Title, Author, Description;
```

**Clear() semantics:** Removes all objects but preserves PageSettings, FieldNames, Variables, and metadata.

**Assign semantics:** Shallow structural copy; deep clone via `TReportSerializer.CloneReport` (serialize → deserialize round-trip).

### TReportObject Hierarchy (source/Vittix.Report.Objects.pas)
```
TReportObject (abstract base)
├── TReportTextObject      — text + expression + conditional styling
│   ├── TReportLabelObject — static text label
│   ├── TReportMemoObject  — rich text, word wrap, HTML
│   └── TReportFieldObject — data-bound field with DisplayFormat
├── TReportShapeObject     — rectangle, roundRect, ellipse, line, diagLine
├── TReportImageObject     — image with DataField binding, caching
├── TReportLineObject      — horizontal/vertical, ExtendToPageBottom
├── TReportSubReportObject — nested report JSON, master-detail
├── TReportBarcodeObject   — Code128 barcode
├── TReportTableObject     — grid of text fields
├── TReportChartObject     — chart series
├── TReportBand            — container, owns children via FChildren
│   └── 10 band types: btReportTitle, btPageHeader, btMasterData,
│       btPageFooter, btReportSummary, btGroupHeader, btGroupFooter,
│       btColumnHeader, btDetail, btOverlay
└── TReportUnknownObject   — forward-compat placeholder (preserves raw JSON)
```

### TReportBand (source/Vittix.Report.Bands.pas)
Properties beyond TReportObject:
- `FBandType` — TReportBandType enum (10 values)
- `FHeight`, `FDataSetName`, `FMasterField`, `FDetailField`
- `FGroupLevel`, `FGroupField`, `FStartNewPage`
- `FCanGrow`, `FCanShrink` — auto-height adjustment
- `FBackColor`, `FColorEven`, `FColorOdd`, `FBackColorTransparent`, `FBackColorCondition`
- `FOnBeforePrint`, `FOnAfterPrint` — script hooks
- `FChildren: TObjectList<TReportObject>` — owns child objects
- `FPageSettings: TReportPageSettings` — per-band page override

---

## 4. Visual Designer

### TVittixReportDesigner (source/Vittix.Report.DesignerControl.pas)
```
TVittixReportDesigner (TCustomControl, IDesignerSurface)
├── Report management
│   ├── LoadReport(AReport, TakeOwnership) — replaces active model
│   ├── NewReport() — creates blank report
│   ├── SetReportJSON / GetReportJSON — DFM-persisted JSON
│   └── FReportLoadFailed — guards stale model serialization
├── Interaction
│   ├── BeginInsertObject / AddBand / DeleteSelected
│   ├── Copy/Paste/Undo/Redo
│   ├── Align / Distribute / Z-order (BringToFront/SendToBack)
│   └── Zoom (25%–400%, Ctrl+MouseWheel)
├── Appearance
│   ├── Grid + snap + smart guides
│   ├── Rulers (20px) + margin guides
│   └── Band color coding
├── Selection
│   ├── Single-click, Ctrl+click multi-select, rubber-band
│   └── 8-handle resize (corners + edge midpoints)
└── Events
    ├── OnSelectionChanged, OnModified, OnViewChanged
    ├── OnDataSetChanged, OnReportLoadError
    └── OnDblClick, OnDragOver, OnDragDrop
```

### Designer State (Confirmed from Source)
- `FReport` — authoritative in-memory model
- `FReportJSON` — DFM-persisted JSON (kept for failed-load recovery)
- `FDataSet`/`FDataSource` — design-time dataset connection
- `FReportLoadFailed` — tracks last load failure
- `FBandLayouts` — computed band layout positions
- `FObjectBandMap` — TDictionary<TReportObject, TReportBand> for hit-testing

### Interaction Controller (source/Vittix.Report.DesignerInteractionController.pas)
Mode-based state machine:
- `dmNormal` — default selection/navigation
- `dmInsert` — placing new objects
- `dmDrag` — moving selected objects
- `dmResize` — resizing objects (8 handles)
- `dmSelect` — rubber-band selection
- `dmBandSep` — dragging band separators
- `dmBandHdr` — dragging band headers
- `dmMove` — moving bands
- `dmNudge` — keyboard pixel-nudge

---

## 5. Database/Data Architecture

### Data Source Abstraction (source/Vittix.Report.DataSources.pas)
```pascal
IReportDataSource = interface
  procedure First; procedure Next; function EOF: Boolean;
  function Active: Boolean;
  function FieldExists(const AFieldName: string): Boolean;
  function FieldAsString(const AFieldName: string): string;
  function RecordCount: Integer;
end;

TCustomReportDataSource = class(TInterfacedObject, IReportDataSource) abstract;
TDataSetReportDataSource = class(TCustomReportDataSource)  // fully implemented
TJsonReportDataSource = class(TCustomReportDataSource)      // scaffold — NotImplemented
TCsvReportDataSource = class(TCustomReportDataSource)       // scaffold — NotImplemented
TRestReportDataSource = class(TCustomReportDataSource)      // scaffold — NotImplemented
```

**Key observation:** The data source abstraction layer exists but is currently
disconnected from production execution: the engine accepts `TDataSet` or
`TVittixUserDataSet`, not `IReportDataSource`. Only the `TDataSet` adapter is
functional; JSON/CSV/REST providers raise `EReportDataSourceError` with a
"scaffold" message. This is a confirmed limitation, not merely partial
coverage.

### Dataset Resolution (source/Vittix.Report.Engine.pas)
Engine resolution order for band data sets:
1. Registered `TVittixUserDataSet` matching band's `DataSetName`
2. Primary registered `TVittixUserDataSet`
3. Legacy `FDataSource.DataSet` fallback (via `ResolvePrimaryDataSet`)

### TExpressionContext (source/Vittix.Report.Context.pas)
```pascal
TExpressionContext = record
  DataSet:    TDataSet;
  UserDataSet: TObject;       // TVirtixUserDataSet kept as TObject (cycle avoidance)
  GroupStart: TBookmark;
  GroupEnd:   TBookmark;
  PageNumber: Integer;
  TotalPages: Integer;
  RowNumber:  Integer;
  PageBottom: Integer;
  ReportTitle: string;
  ReportDate:  TDateTime;
  Parameters:  TStrings;
  Variables:   TStrings;
  IsCountingPass: Boolean;
  Hooks: IReportRenderHooks;
  PrecheckedObjectForPrintWhen: TObject;  // reentrancy guard
end;
```

---

## 6. Expression Engine

### TReportExpression.Evaluate (source/Vittix.Report.Expressions.pas)
```
Evaluation order:
1. Aggregate functions  SUM(…), COUNT(…), AVG(…), MIN(…), MAX(…)
2. System tokens        [PageNo], [TotalPages], [RowNumber], [Param.Name],
                         [ReportTitle], [ReportDate], [DateTime], [Time], [VarName]
3. Dataset field tokens [FieldName], [Dataset.FieldName] (dataset-qualified)
4. Quoted string literal 'text'
5. Comparison operators <=, >=, <>, =, <, >
6. Arithmetic           +, -, *, / (simple left-to-right parser)
7. Numeric fallback — TryStrToFloat
8. String fallback — raw text
```

### System Tokens (Confirmed)
| Token | Resolves To |
|-------|-------------|
| `[PageNo]` / `[Page]` / `[Page#]` | Current page number (1-based) |
| `[TotalPages]` / `[TotalPages#]` | Total page count (0 during render) |
| `[RowNumber]` / `[Line]` / `[Line#]` / `[RecNo]` | Current master row (1-based) |
| `[ReportTitle]` | TReportModel.Title |
| `[ReportDate]` / `[Date]` | Formatted date string |
| `[DateTime]` | Formatted datetime string |
| `[Time]` | Formatted time string |
| `[Param.Name]` | Runtime parameter value |
| `[VarName]` | Design-time variable from TReportModel.Variables |

### Aggregate Functions (source/Vittix.Report.Aggregates.pas)
SUM, COUNT, AVG, MIN, MAX — evaluated against current dataset context.

### Conditional Styling (source/Vittix.Report.Objects.pas)
- `FontColorCondition` / `FontColorOnTrue` / `FontColorCondition`
- `BackgroundCondition` / `BackgroundOnTrue`
- `BorderColorCondition` / `BorderColorOnTrue`
- `ResolveConditionalStyle()` evaluates condition expression, returns actual color

---

## 7. Execution Lifecycle

### TReportEngine.Prepare (source/Vittix.Report.Engine.pas)
```
TReportEngine.Create(Report, DataSet)
    │
    ├── Initialize() — create script engine, parameters, pages list,
    │                  named datasets dictionaries
    ├── CacheBands() — categorize bands by type into:
    │   FTitleBand, FHeaderBand, FColumnHeaderBand, FMasterBand,
    │   FFooterBand, FSummaryBand, FOverlayBand,
    │   FGroupHeaders, FGroupFooters, FDetailBands
    └── ExecutePass() — called once or twice
         │
         ├── Pass 1 (Counting, if FTwoPassRendering = True)
         │    ├── ExecutePass(0, False) — counts pages, TotalPages=0
         │    └── Set FTotalPagesForPass = counted pages
         │
         └── Pass 2 (Rendering)
              ├── ExecutePass(CountedPages, True)
              ├── BeginPass() — clear pages, reset counters, cache bands
              ├── PrintFirstPageBands() — StartNewPage, Title, PageHeader, ColumnHeader
              ├── ProcessMasterDataLoop() — iterate dataset rows
              │    ├── PrintBand(MasterBand) — draw band + children
              │    ├── PrintDetailBands() — per-band dataset resolution
              │    ├── Handle group headers/footers on field change
              │    └── StartNewPage() when BandFitsOnPage = False
              ├── CloseRemainingGroups()
              ├── PrintSummaryWithSpaceCheck()
              └── EndCurrentPage() — force footer to bottom margin
         │
         └── FPages: TObjectList<TMetafile> — ready for preview/export
```

### Band Processing Order (Confirmed from CacheBands)
1. `btReportTitle` — once at start of first page
2. `btPageHeader` — every page
3. `btColumnHeader` — after group headers
4. `btMasterData` / `btDetail` — per data row
5. `btGroupHeader` / `btGroupFooter` — on group field value change
6. `btPageFooter` — every page (forced to bottom margin)
7. `btReportSummary` — after all data rows
8. `btOverlay` — drawn last over full page (watermarks/stamps)

### Event Firing (Confirmed)
- `OnBeforePrintReport` / `OnAfterPrintReport` — report-level, cancellable
- `OnBeforeBand` / `OnAfterBand` — band-level, cancellable
- `OnBeforeObject` / `OnAfterObject` — object-level, cancellable

---

## 8. Layout/Pagination

### Page Calculation (source/Vittix.Report.LayoutPagination.pas)
```pascal
function BandFitsOnPage(ACurrentY, ARequiredHeight, APageHeight,
  ABottomMargin, AFooterHeight: Integer): Boolean;
begin
  Result := (ACurrentY + ARequiredHeight) <=
    (APageHeight - ABottomMargin - AFooterHeight);
end;
```

### Page Settings (source/Vittix.Report.PageSettings.pas)
- `PageWidth` / `PageHeight` — logical pixels (default 793×1122 = A4 at 96 DPI)
- `Margins.Left/Top/Right/Bottom` — printable area inset
- `Orientation` — portrait/landscape

### Band Growth/Shrinkage
`ComputeEffectiveBandHeight()` (Engine.pas line 183):
- Calls `MeasuredBottom()` to calculate natural height
- Adds 4px clearance
- Respects `CanGrow` / `CanShrink` flags

### Layout Helpers (source/Vittix.Report.LayoutHelpers.pas)
`BuildBandLayouts()` — computes Y positions for bands in sorted order (BAND_ORDER array), accounts for band gap, populates FObjectBandMap.

---

## 9. Rendering

### TReportRenderer (source/Vittix.Report.Renderer.pas)
```
TReportRenderer.Render(Engine, PageWidth, PageHeight)
    │
    ├── Engine.Parameters.Assign(FParameters)
    ├── Engine.TwoPassRendering := FTwoPassRendering
    ├── Engine.Prepare() — builds FPages (TObjectList<TMetafile>)
    │
    └── For each engine page:
         ├── TRenderPage.Create(Width, Height)
         │   ├── Metafile := TMetafile.Create
         │   └── Bitmap := TBitmap.Create (filled white)
         ├── Page.Metafile.Assign(Engine.Pages[i])
         └── Page.Bitmap.Canvas.StretchDraw(R, Engine.Pages[i])
```

### Object Drawing Model (source/Vittix.Report.Objects.pas)
- `TReportObject.Draw(C: TCanvas, const Context: TExpressionContext)` — virtual, overridden per type
- `DrawReportObjectWithHooks()` — PrintWhen check → before-hooks → Draw → after-hooks
- `ShouldPrintObject()` — evaluates PrintWhen with reentrancy guard via `PrecheckedObjectForPrintWhen`
- `TReportBand.Draw()` — iterates Children, evaluates BackColorCondition, alternating row colors

### Drawing Details by Object Type
| Type | Draw Behavior |
|------|---------------|
| TReportTextObject | Background, border, text with alignment/wordwrap, AutoSize growth |
| TReportShapeObject | Rectangle/roundRect/ellipse/line/diagLine with fill/border |
| TReportImageObject | Loads from DataField (file path or base64), caching, stretch/proportional/center |
| TReportMemoObject | Multi-line with styled runs, HTML support, word wrap |
| TReportSubReportObject | Loads sub-report JSON, iterates matching rows |
| TReportLineObject | Horizontal/vertical with ExtendToPageBottom |
| TReportUnknownObject | Hatched placeholder with dashed border + diagonal cross |

### Selection Rendering (DesignerControl.pas)
- 8 handles (corners + mid-edges) for resize
- Locked objects: dotted red border
- Smart guides during drag
- Band zone coloring + band headers

---

## 10. Preview

### TVittixReportPreview (source/Vittix.Report.Preview.pas)
```
TVittixReportPreview (TCustomControl)
├── FPages: TObjectList<TBitmap> — owned, independent of renderer
├── FMetafilePages: TObjectList<TMetafile>
├── FPageIndex: Integer — current page
├── FZoomPercent: Integer — 10%–400%
├── LoadFromRenderer(ARenderer) — copies pages from renderer
│   └── Copy performed with TCanvas.Draw (O(pixels))
├── Navigation: First/Last/Next/Prev, GoFirst/GoLast/GoPrev/GoNext
├── Zoom: ZoomIn/ZoomOut/FitWidth/FitPage
├── Print() — stretch-draws bitmaps to printer canvas
├── Scroll bars: WM_HSCROLL/WM_VSCROLL
└── Mouse wheel: Ctrl+wheel for zoom, otherwise vertical scroll
```

### Lifetime Safety Fix (Confirmed from Comments)
Previous design stored raw pointer to `TReportRenderer`. Fixed by copying bitmaps into control's own `TObjectList<TBitmap>` inside `LoadFromRenderer`. After call returns, renderer can be freed safely.

---

## 11. Printing

### Three Print Paths (Confirmed)
1. **TReportRenderer.Print()** (Renderer.pas line 121) — iterates FPages, stretch-draws bitmaps to Printer.Canvas
2. **TVittixReportPreview.Print()** (Preview.pas) — same pattern from preview control
3. **TReportPDFExporter** — uses "Microsoft Print to PDF" virtual printer (Windows 10+)

All paths use `Printer.BeginDoc/EndDoc` with exception handling that calls `Printer.Abort`.

### Limitations
- Uses `StretchDraw` — may blur high-DPI metafiles
- No direct metafile printing (prints bitmap copies)
- No page range selection
- No print preview integration (separate TVittixReportPreview.Print)

---

## 12. Export Formats

### Export Architecture (source/Vittix.Report.Interfaces.pas)
```pascal
IReportExporter = interface
  procedure ExportPages(const Pages: TObjectList<TMetafile>; const FileName: string);
  function FormatName: string;
  function DefaultExtension: string;
end;
```

### Export Implementations
| Exporter | File | Output | Notes |
|----------|------|--------|-------|
| **PDF** | Export.PDF.pas | PDF via "Microsoft Print to PDF" | Windows 10+ only, shows printer dialog |
| **VectorPDF** | Export.VectorPDF.pas | Native PDF with SVG paths | Beta, Unicode/font embedding pending |
| **XLSX** | Export.XLSX.pas | Excel spreadsheet | Rich text formatting preserved |
| **HTML** | Export.HTML.pas | HTML with absolute positioning | Base64 image encoding |
| **Text** | Export.Text.pas | Plain text tab-delimited | Dataset-driven |
| **Email** | Export.Email.pas | Email with PDF attachment | MAPI via Outlook |

### Export Command Capture (source/Vittix.Report.Export.Commands.pas)
During rendering, engine captures draw commands:
- `TReportExportTextCommand` — text with style runs
- `TReportExportImageCommand` — image references
- `TReportExportLineCommand` — line geometry
- `TReportExportRectangleCommand` — border rectangle
- `TReportExportFillRectangleCommand` — fill rectangle
- `TReportExportEllipseCommand` — ellipse geometry

### XLSX Export Detail (source/Vittix.Report.Export.XLSX.pas)
- Generates OOXML spreadsheet (zip of XML parts)
- Maps text commands to grid cells (Y-based row grouping, X-based column)
- Fill/border mapping heuristic: conservative coverage rule
- Supports rich text runs with inline styles
- Styles: 3 static font styles + dynamic fill/border/cellXf extensions

---

## 13. Expression Engine Details

### TReportExpression.Evaluate (source/Vittix.Report.Expressions.pas)
- **Aggregate functions:** SUM, COUNT, AVG, MIN, MAX (delegates to Vittix.Report.Aggregates)
- **System tokens:** Case-insensitive lookup
- **Field tokens:** `[FieldName]` → `Context.DataSet.FieldByName(FieldName).AsString`
- **Dataset-qualified tokens:** `[Dataset.FieldName]` — strips prefix, uses just field name
- **Quoted strings:** `'text'` literal returned as-is
- **Comparison:** `<=> >= <> = <` — numeric comparison if both sides parse as numbers, otherwise text comparison via CompareText
- **Boolean literals:** `true`/`false`
- **Arithmetic:** `+ - * /` simple left-to-right parser
- **Debug logging:** `OutputDebugString` for unresolved tokens (DEBUG only, max 200 unique messages)

### Variable Resolution
`[VarName]` → `Context.Variables.Values['VarName']` (design-time constants from TReportModel.Variables)

### Parameter Resolution
`[Param.Name]` → searches Context.Parameters (TStrings) by name

---

## 14. Scripting

### TReportScriptEngine (source/Vittix.Report.Scripting.pas)
```pascal
TReportScriptEngine = class(TComponent)
  procedure ExecuteBeforePrint(const Script: string; var Context: TExpressionContext);
  procedure ExecuteAfterPrint(const Script: string; var Context: TExpressionContext);
  procedure ExecuteObjectBeforePrint(AReport, AObject; const Script; var Context; var ACanPrint);
  procedure ExecuteObjectAfterPrint(AReport, AObject; const Script; var Context);
published
  property OnBeforePrint, OnAfterPrint: TReportScriptEvent;
  property OnObjectBeforePrint, OnObjectAfterPrint: TReportObjectScriptEvent;
```

### Script Host Adapter (source/Vittix.Report.ScriptHost.Adapter.pas)
Commands supported:
- `Cmd_Text` — sets text property
- `Cmd_CanPrint` — sets CanPrint flag
- `Cmd_Fontname/Fontsize/Fontcolor` — font manipulation
- `Cmd_Halign/Valign` — alignment
- `Cmd_Datafield` — binds to dataset field
- `Cmd_Printwhen` — conditional printing
- `Cmd_Background/BorderColor` — styling
- `Cmd_Stretch/Center/Proportional` — image options

### Script Cancellation
- `CanPrint := False` in OnBeforePrint cancels object printing
- `ScriptCanceledObject` trace event fired
- Cancel short-circuits: subsequent objects in same band still process

---

## 15. Error Handling Patterns

### Exception Hierarchy (Confirmed)
- `EReportException` (from TReportEngine) — custom report exception
- `EReportDataSourceError` (from Vittix.Report.DataSources) — data source errors
- General Exception → wrapped in `EReportException.CreateFmt('Error preparing report: %s', [E.Message])`

### Defensive Patterns
| Pattern | Location | Behavior |
|---------|----------|----------|
| Try/except around expression eval | Objects.pas Draw | PrintWhen failure → skip band |
| Try/except around field value reads | Engine.pas SourceFieldValue | DEBUG-only logging, returns 0 |
| Try/except around image loading | Objects.pas ImageObject.Draw | Ignores errors, draws placeholder |
| Try/except around dataset repositioning | DesignerControl.pas | Non-fatal, logs debug |
| Transactional loading | Serializer.pas LoadFromJSONEx | Returns TReportLoadResult, never raises |
| Warning vs Error | Serializer.pas | Unknown class = warning (tolerant) or exception (strict) |

### Transactional Loading (Phase 4I-18)
`LoadFromJSONEx` returns `TReportLoadResult` with:
- `Success: Boolean` — load outcome
- `Model: TReportModel` — deserialized model (caller owns)
- `Diagnostics: TObjectList<TReportLoadDiagnostic>` — categorized messages
- `ExtractModel()` — transfers ownership, sets Success = False

`TReportLoadDiagnostic` severity levels:
- `rlsInfo` — Notable but non-fatal (e.g., loaded v1 file without version key)
- `rlsWarning` — Recoverable issue (e.g., unknown object class skipped)
- `rlsError` — Failure that prevented successful load

### Silent Failures (Inferred)
- `PrepareDisplayDataSet` has empty `except` block (DesignerControl.pas)
- Image loading failures silently ignored
- Expression evaluation fallbacks return 0/empty

---

## 16. Memory Management

### Ownership Model
| Owner | Owns | Pattern |
|-------|------|---------|
| `TReportModel` | `FObjects` (TObjectList, OwnsObjects=True) | `FObjects.Free` in destructor |
| `TReportBand` | `FChildren` (TObjectList, OwnsObjects=True) | `FChildren.Free` in destructor |
| `TReportEngine` | `FPages` (TObjectList, OwnsObjects=True) | Metafile pages |
| `TReportRenderer` | `FPages` (TObjectList, OwnsObjects=True) | Each TRenderPage owns Bitmap+Metafile |
| `TVittixReportPreview` | `FPages` (TObjectList, OwnsObjects=True) | Owns TBitmap copies |
| `TVittixReportPreview` | `FMetafilePages` (TObjectList, OwnsObjects=True) | Owns TMetafile copies |
| `TCommandManager` | `FUndo/FRedo` lists | Commands free themselves on rollback |

### GDI Resource Safety (Confirmed)
- `TMetafileCanvas` created per page in `StartNewPage`
- `Canvas.Free` in `EndCurrentPage` finally block
- `TRenderPage.Destroy` frees Bitmap and Metafile
- `TReportEngine.Destroy` frees FCanvas, FCurrentPage, FPages
- `TReportRenderer.Destroy` frees FParameters, FPages
- `TVittixReportPreview.Destroy` frees FPages, FMetafilePages

### Potential GDI Leaks (Inferred)
- `FGroupStartBookmark/FGroupEndBookmark` — freed in destructor only if `DataSetSupportsBookmarks`
- `FTitleBand/FHeaderBand/etc.` — not freed (owned by report model)
- `FScriptEngine` — freed in destructor
- `FCurrentPage` — freed before FPages in destructor (correct order)

---

## 17. Thread Safety

### Thread Safety Assessment
**Rating: NOT THREAD-SAFE** (Confirmed)

Evidence:
- `TReportEngine` stores `FDataSet: TDataSet` — TDataSet is NOT thread-safe
- `TExpressionContext` is a record passed by value — but contains `TDataSet` reference
- `TReportRenderer.Render` — single-threaded metafile creation
- No synchronization primitives used anywhere in engine/renderer
- `TCommandManager` undo/redo — not protected
- Designer interaction — single-threaded UI only
- `GRegistryCS: TCriticalSection` — only protects global object registry

### What Would Break Under Concurrency
- Concurrent `Prepare` calls on same engine instance
- Dataset access from multiple threads simultaneously
- Undo/redo while rendering
- Designer paint while model changes
- `TExpressionContext` mutations during evaluation

---

## 18. Extensibility

### Extension Points (Confirmed)
| Point | Interface/Class | Purpose |
|-------|-----------------|---------|
| **Export** | `IReportExporter` | Add new output formats |
| **Plugin** | `IReportPlugin` | Register custom object types |
| **Progress** | `IReportProgress` | Progress/cancel long renders |
| **Script** | `TReportScriptEngine` events | Custom script logic |
| **Render hooks** | `IReportRenderHooks` | Before/After object print |
| **Object registry** | `RegisterReportObject` | Add new TReportObject subclasses |
| **Expression** | `TReportExpression.Evaluate` | Extend token resolution |
| **Serializer** | `GetSerializer/RegisterSerializer` | Custom property serialization |
| **Data source** | `IReportDataSource` | Abstract data access |

### Plugin Architecture (source/Vittix.Report.Interfaces.pas)
```pascal
IReportPlugin = interface
  procedure RegisterObjects;    // Register custom class with global registry
  procedure UnregisterObjects;  // Unregister (design-time only)
  function PluginName: string;  // Display name in toolbox
end;
```

### Object Registry (source/Vittix.Report.ObjectRegistry.pas)
- `RegisterReportObject(AClass)` — adds to global `GRegistry` list
- `FindObjectClass(ClassName)` — looks up by discriminator string
- `GetRegisteredReportObjects` — returns array of registered classes
- Protected by `GRegistryCS: TCriticalSection` (thread-safe registration)

### Unknown Object Strategy (source/Vittix.Report.Objects.Unknown.pas)
`TReportUnknownObject` preserves raw JSON for unrecognized classes:
- `OriginalClassName` — stores the original class name from JSON
- `RawJSON` — complete JSON fragment for round-trip preservation
- On save, raw JSON written back verbatim (no data loss)
- Draws as hatched placeholder with dashed border + diagonal cross
- Registered in initialization section via `RegisterReportObject`

---

## 19. Component Inventory

### Source Units (49 units)

| # | Unit | Primary Class | Responsibility |
|---|------|---------------|----------------|
| 1 | Vittix.Report.Core | — | Public API facade, type aliases |
| 2 | Vittix.Report.Interfaces | — | IReportExporter, IReportPlugin, IReportProgress, IReportRenderHooks |
| 3 | Vittix.Report.Model | TReportModel | Report container, metadata, variables |
| 4 | Vittix.Report.Objects | TReportObject | Base report object + hierarchy |
| 5 | Vittix.Report.Bands | TReportBand | Band container (10 types) |
| 6 | Vittix.Report.Engine | TReportEngine | Main processing engine |
| 7 | Vittix.Report.Engine.Engine | — | Alias unit |
| 8 | Vittix.Report.Engine.Renderer | — | Alias unit |
| 9 | Vittix.Report.Renderer | TReportRenderer | Metafile → bitmap conversion |
| 10 | Vittix.Report.Preview | TVittixReportPreview | On-screen page display |
| 11 | Vittix.Report.Expressions | TReportExpression | Expression evaluation |
| 12 | Vittix.Report.Aggregates | — | SUM/COUNT/AVG/MIN/MAX |
| 13 | Vittix.Report.DataSources | IReportDataSource + impls | Data source abstraction |
| 14 | Vittix.Report.UserDataSet | TVirtixUserDataSet | User dataset wrapper |
| 15 | Vittix.Report.Context | TExpressionContext | Runtime data snapshot |
| 16 | Vittix.Report.PageSettings | TReportPageSettings | Paper size, margins, orientation |
| 17 | Vittix.Report.Serializer | TReportSerializer | JSON save/load (transactional + legacy) |
| 18 | Vittix.Report.LoadResult | TReportLoadResult | Transactional load results |
| 19 | Vittix.Report.Scripting | TReportScriptEngine | Script callback host |
| 20 | Vittix.Report.ScriptHost.Adapter | — | Script host adapter |
| 21 | Vittix.Report.Undo | TCommandManager + commands | Undo/redo infrastructure |
| 22 | Vittix.Report.CommandDispatcher | TCommandDispatcher | Command dispatch |
| 23 | Vittix.Report.DesignerControl | TVittixReportDesigner | Visual designer control |
| 24 | Vittix.Report.DesignerInteraction | — | Interaction types |
| 25 | Vittix.Report.DesignerInteractionController | TDesignerInteractionController | Interaction state machine |
| 26 | Vittix.Report.LayoutHelpers | BuildBandLayouts | Layout computation |
| 27 | Vittix.Report.LayoutPagination | BandFitsOnPage | Space check |
| 28 | Vittix.Report.LayoutCache | — | Layout caching |
| 29 | Vittix.Report.LayoutBookmarks | — | Bookmark capture/restore |
| 30 | Vittix.Report.SelectionHelpers | — | Selection utilities |
| 31 | Vittix.Report.Toolbox | TVittixReportToolbox | Object palette |
| 32 | Vittix.Report.ObjectRegistry | — | Global object registry |
| 33 | Vittix.Report.PropertyBridge | TReportPropertyBridge | Property inspector bridge |
| 34 | Vittix.Report.Component | TReportComponent | Non-visual component |
| 35 | Vittix.Report.ComponentEditor | — | IDE component editor |
| 36 | Vittix.Report.Reg | — | Registration |
| 37 | Vittix.Report.Utils | — | Utility functions |
| 38 | Vittix.Report.MemoExport | — | Memo HTML export support |
| 39 | Vittix.Report.Export.Commands | TReportExportCommand | Export command types |
| 40 | Vittix.Report.Export.PDF | TReportPDFExporter | PDF via printer |
| 41 | Vittix.Report.Export.VectorPDF | TReportVectorPDFExporter | SVG→PDF |
| 42 | Vittix.Report.Export.VectorPDF.SVG | — | SVG support |
| 43 | Vittix.Report.Export.VectorPDF.EMF | — | EMF support |
| 44 | Vittix.Report.Export.XLSX | TReportXLSXExporter | Excel spreadsheet |
| 45 | Vittix.Report.Export.HTML | TReportHTMLExporter | HTML output |
| 46 | Vittix.Report.Export.Text | TReportTextExporter | Plain text |
| 47 | Vittix.Report.Export.Email | TReportEmailExporter | Email with PDF |
| 48 | Vittix.Report.Objects.Barcode | TReportBarcodeObject | Barcode rendering |
| 49 | Vittix.Report.Objects.Chart | TReportChartObject | Chart rendering |
| 50 | Vittix.Report.Objects.Table | TReportTableObject | Table grid |
| 51 | Vittix.Report.Objects.CrossTab | TReportCrossTabObject | Cross-tab |
| 52 | Vittix.Report.Objects.Unknown | TReportUnknownObject | Unknown object placeholder |

### Designer Units (45 units)
- `Frm.Main.pas` — Main designer form (~6,300 lines)
- `Frm.Main.*` — 30+ helper units for the main form
- `Frm.Preview.pas` — Preview form
- `Frm.BandManager.pas` — Band manager dialog
- `Frm.PageSettings.pas` — Page settings dialog
- `Frm.ReportProperties.pas` — Report properties dialog
- `Frm.ScriptEditor.pas` — Script editor dialog
- `Frm.TextExpressionEditor.pas` — Text expression editor
- `Frm.ExpressionEditor.pas` — Expression editor dialog
- `Frm.ExpressionHelper.pas` — Expression helper
- `Frm.ImageEditor.pas` — Image editor dialog
- `Frm.DataConnection.pas` — Data connection dialog
- `VittixDesigner.dpr` — Designer project

### Test Units (32 units)
- `Test.Vittix.Report.Engine` — Engine lifecycle
- `Test.Vittix.Report.Objects` — Object creation/properties
- `Test.Vittix.Report.Objects.Barcode` — Barcode rendering
- `Test.Vittix.Report.Objects.Chart` — Chart objects
- `Test.Vittix.Report.Objects.QR` — QR code objects
- `Test.Vittix.Report.Export.HTML` — HTML export
- `Test.Vittix.Report.Export.XLSX` — XLSX export
- `Test.Vittix.Report.ExportCapture` — Export capture
- `Test.Vittix.Report.Expressions` — Expression evaluation
- `Test.Vittix.Report.Serializer` — JSON serialization
- `Test.Vittix.Report.Serializer.Registry` — Registry serialization
- `Test.Vittix.Report.DesignerLoad` — Designer loading
- `Test.Vittix.Report.Component` — Component integration
- `Test.Vittix.Report.Undo` — Undo/redo
- `Test.Vittix.Runner.*` — 15 runner infrastructure tests

---

## 20. Testing

### Test Framework
- **DUnitX** with RTTI discovery (`runner.UseRTTI := True`)
- **Console logger** + **NUnit XML logger** for CI
- **TestInsight** support (`{$IFDEF TESTINSIGHT}` conditional)

### Test Runners (source/tests/)
- `RunTests.bat` — full test suite
- `RunTests-ScriptTrace.bat` — script trace tests
- `RunTests-Scripts.bat` — script tests
- `RunTests-VectorPDF.bat` — VectorPDF tests

### Test Categories (Confirmed)
1. **Round-trip:** Save model → load JSON → verify equality
2. **Characterization:** Verify render output matches baseline
3. **Engine:** Prepare, page count, band layout
4. **Expressions:** Token resolution, aggregates, conditionals
5. **Undo/Redo:** Command execution and rollback
6. **Serializer:** JSON structure, version compatibility
7. **Designer load:** Transactional loading, unknown class handling
8. **Export:** XLSX rich text, HTML structure, VectorPDF

### Regression Testing
- 45 regression test reports (.vrt files)
- Baseline comparison via `regression_baselines.json`
- 41 passed, 0 failed, 1 skipped (large preview warning)

---

## 21. Comparison to Modern Architecture

### Modern Report Engine Patterns vs. VittixReport

| Aspect | VittixReport | Modern Pattern |
|--------|-------------|----------------|
| **Model** | TReportModel (TPersistent) | Immutable record/DTO |
| **Rendering** | TMetafile + TBitmap | Direct2D/Skia/Cairo |
| **Data** | TDataSet direct + IReportDataSource | Abstract data source + repository |
| **Expressions** | Custom parser | Dynamic LINQ / NCalc / JS |
| **Scripting** | Callback events | Lua/PascalScript embedded |
| **Export** | IReportExporter interface | Plugin pipeline (reportlab, weasyprint) |
| **Preview** | Bitmap copy of metafile | Direct GPU rendering |
| **Pagination** | Two-pass algorithm | Single-pass with markers |
| **Threading** | None | Async/await, parallel band rendering |
| **DPI** | Fixed 96 | System-aware, vector-based |

### Gap Analysis
| Gap | Severity | VittixReport Status | Modern Equivalent |
|-----|----------|---------------------|-------------------|
| Data source abstraction | Medium | Partial (only TDataSet impl) | Repository pattern |
| Async rendering | High | Missing | Task/async pipeline |
| Vector preview | High | Missing | GPU-accelerated |
| Expression engine | Medium | Basic | NCalc/JS integration |
| Scripting | Medium | Event callbacks only | Lua/PascalScript |
| Cross-platform | High | Windows only | Linux/macOS target |
| DPI awareness | Medium | Fixed 96 | System DPI detection |
| Thread safety | High | None | Critical sections |

---

## 22. Diagrams

### Execution Flow Diagram
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Load .vrt  │────▶│ TReportModel│────▶│  TReportEngine│
│  (JSON)     │     │  (in-memory)│     │  .Prepare()  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    ▼                          ▼                          ▼
              ┌───────────┐             ┌──────────────┐         ┌──────────────┐
              │  Pass 1   │             │  Pass 2      │         │  Events      │
              │  Count    │             │  Render      │         │  Before/After │
              │  Pages    │             │  Pages       │         │  OnPrepare    │
              └───────────┘             └──────────────┘         └──────────────┘
                                                    │
                              ┌─────────────────────┼─────────────────────┐
                              ▼                     ▼                     ▼
                        ┌───────────┐         ┌──────────────┐     ┌───────────┐
                        │  Preview  │         │  Export      │     │  Print    │
                        │  Bitmap   │         │  PDF/XLSX    │     │  Bitmap   │
                        │  Copy     │         │  HTML/Text   │     │  Direct   │
                        └───────────┘         └──────────────┘     └───────────┘
```

### Data Flow Diagram
```
                    ┌─────────────────┐
                    │   TDataSet      │
                    │   (live data)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  TVirtixUserDataSet│
                    │  (bookmark support)│
                    └────────┬────────┘
                             │
              ┌──────────────▼──────────────┐
              │      TReportEngine          │
              │  ┌───────────────────────┐  │
              │  │ CacheBands()          │  │
              │  │ → FTitleBand          │  │
              │  │ → FHeaderBand         │  │
              │  │ → FMasterBand         │  │
              │  │ → FFooterBand         │  │
              │  │ → FGroupHeaders[]     │  │
              │  │ → FDetailBands[]      │  │
              │  └───────────────────────┘  │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │    TExpressionContext       │
              │  DataSet, UserDataSet       │
              │  PageNumber, TotalPages      │
              │  RowNumber, Parameters       │
              │  Variables, Hooks            │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │    TReportExpression        │
              │    Evaluate()               │
              │  1. Aggregates              │
              │  2. System tokens           │
              │  3. Field tokens            │
              │  4. Quoted strings          │
              │  5. Comparison              │
              │  6. Arithmetic              │
              │  7. Numeric fallback        │
              │  8. String fallback         │
              └─────────────────────────────┘
```

---

## 23. Technical Debt Register

| # | Debt | Severity | Location | Fix Effort | Risk |
|---|------|----------|----------|------------|------|
| 1 | Two-pass rendering always on | Medium | Engine.pas | Low | Performance on large datasets |
| 2 | 96 DPI hardcoded | Medium | VectorPDF, Preview | Medium | HiDPI displays incorrect |
| 3 | TDataSet direct reference | Medium | Engine, Context | Medium | Testability, cross-platform |
| 4 | Exception swallowing | Low | DesignerControl | Low | Silent failures |
| 5 | No thread safety | High | Engine, Renderer | High | Concurrency, data corruption |
| 6 | Limited expression engine | Medium | Expressions.pas | Medium | Complex reports need scripts |
| 7 | Tight designer coupling | Low | DesignerControl | Medium | Maintainability |
| 8 | Redundant JSON state | Low | DesignerControl | Low | Consistency between FReportJSON and FReport |
| 9 | Data source abstraction incomplete | Medium | DataSources.pas | High | Flexibility, testability |
| 10 | Windows-only PDF export | Medium | Export.PDF.pas | High | Cross-platform |
| 11 | Bitmap-only preview | Medium | Preview.pas | Medium | Vector scaling, zoom quality |
| 12 | No page range selection | Low | Renderer.Print | Low | Usability |
| 13 | StretchDraw blurs on zoom | Low | Renderer, Preview | Low | Visual quality |
| 14 | MAPI email dependency | Low | Export.Email.pas | Medium | Cross-platform, reliability |
| 15 | Empty except blocks | Low | DesignerControl | Low | Debugging difficulty |

---

## 24. Modernization Roadmap

### Phase 1: Foundation (Current — Phase 4I-18) ✅ Complete
- [x] Transactional report loading (TReportLoadResult)
- [x] Unknown object preservation (TReportUnknownObject)
- [x] Structured diagnostics (TReportLoadDiagnostic)
- [x] Forward-compatible save

### Phase 2: Performance
- [ ] Optional single-pass rendering
- [ ] Async preview rendering
- [ ] Layout caching
- [ ] Bitmap pooling
- [ ] Metafile reuse instead of bitmap copies

### Phase 3: Architecture
- [ ] Data source abstraction layer (complete IReportDataSource implementations)
- [ ] DPI-aware scaling
- [ ] Thread-safe engine
- [ ] Immutable model option
- [ ] Expression engine enhancement (IIF/IF/ELSE, date functions)

### Phase 4: Features
- [ ] PascalScript integration
- [ ] Direct2D rendering
- [ ] Cross-platform export (Linux/macOS)
- [ ] Vector preview (SVG-based)
- [ ] Page range selection for print/export

### Phase 5: Polish
- [ ] Comprehensive test suite expansion
- [ ] Performance benchmarks
- [ ] Memory leak detection
- [ ] Documentation (API docs, ADRs)
- [ ] CI/CD pipeline with automated regression

---

## 25. Confirmed vs. Inferred vs. Missing

### Confirmed (from source evidence)
- TReportModel owns flat TObjectList<TReportObject>
- Two-pass rendering is default (FTwoPassRendering = True)
- JSON is the only persistence format (.vrt files)
- Class discriminator reads 'Class' or 'Type' key
- TExpressionContext is a record (value type)
- Script engine delegates to event callbacks
- PDF export uses "Microsoft Print to PDF" printer
- 10 band types defined in TReportBandType
- Preview copies bitmaps from renderer for lifetime independence
- DUnitX and regression-runner projects plus prior result artifacts exist; their
  current outcome is unverified by this analysis
- IReportDataSource abstraction exists with 4 implementations (only TDataSet functional)
- TReportUnknownObject preserves raw JSON for unknown classes
- Global object registry protected by TCriticalSection
- Transactional loading returns TReportLoadResult with severity-coded diagnostics

### Inferred (reasonable deduction from code)
- No thread safety mechanisms in engine/renderer (no locks, no atomic operations)
- Fixed 96 DPI assumption (hardcoded scaling factors in VectorPDF)
- Direct TDataSet coupling in engine (no repository/adapter pattern for data access)
- Exception swallowing in non-critical paths (empty except blocks)
- Redundant state (FReportJSON vs FReport in designer can diverge)
- Limited expression language (no IIF, no date functions visible in parser)
- Windows-only PDF export (printer-dependent, no alternative backend)
- Metafile→Bitmap conversion loses vector quality on zoom

### Missing (cannot determine from repository)
- Actual runtime performance benchmarks (no profiling data)
- Memory usage under load (no stress test results)
- Cross-platform compatibility (Windows-only evidence)
- Unicode/RTL support (not visible in code)
- Actual plugin adoption (no third-party plugins in repo)
- Long-running report stability (>1000 pages)
- Concurrent access patterns (no multi-thread tests)
- Network dataset behavior (only local TDataSet evidence)
- SQL generation for data source queries
- Cache hit rates for layout/image caching

---

## 26. Final Assessment

### Maturity Scores (0–10)

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| **Architecture** | 7/10 | Clean layered dependencies, good separation of concerns, but tight coupling to VCL/TDataSet |
| **Designer** | 8/10 | Feature-rich with undo/redo, interactive, but state management needs work (redundant JSON state) |
| **Database Reporting** | 7/10 | Robust band-based data binding, but data source abstraction incomplete (only TDataSet impl) |
| **Rendering** | 7/10 | Metafile-based rendering works, but 2-pass and bitmap copies are inefficient |
| **Extensibility** | 8/10 | Plugin interfaces, object registry, export interfaces all present and well-defined |
| **Testability** | 6/10 | 231 tests passing, but engine tightly coupled to VCL/DB, no mock data sources |
| **Performance** | 5/10 | Two-pass rendering, bitmap copies, no async, DPI assumptions |
| **Maintainability** | 7/10 | Well-organized units, clear ownership, but 6K+ line main form |
| **Overall** | **7/10** | Solid foundation, pre-production quality, ready for Phase 2 optimizations |

### Five Explicit Questions Answered

**1. Is the architecture sound for incremental modernization?**
YES. The layered dependency graph (Interfaces → Model → Objects → Serializer → Engine → Renderer → Export) allows targeted refactoring without cascading changes. The plugin interfaces (IReportExporter, IReportPlugin, IReportProgress) are well-defined and stable. The data source abstraction layer (IReportDataSource) already exists but needs concrete implementations.

**2. What is the safest incremental modernization path?**
Phase 2 (Performance) first: optional single-pass rendering, layout caching, async preview. These are additive changes that don't break existing APIs. Then Phase 3 (Architecture): complete data source abstraction, DPI awareness, thread safety. Phase 4 (Features): PascalScript, Direct2D, cross-platform.

**3. What are the biggest risks?**
- **Dataset coupling:** Direct TDataSet references make testing difficult and prevent cross-platform support
- **DPI assumptions:** Fixed 96 DPI will break on HiDPI displays
- **Two-pass overhead:** 2× dataset traversal hurts performance on large reports
- **No thread safety:** Cannot leverage multi-core for rendering, risk of data corruption
- **Incomplete data abstraction:** Only TDataSet implementation functional; JSON/CSV/REST are stubs

**4. What should NOT be changed?**
- JSON file format (backward compatibility with .vrt files)
- Public API signatures (Component, DesignerControl, Engine interfaces)
- Band type ordinals (persistence format)
- Object discriminator system (class registry)
- Undo/redo command pattern (well-tested)
- Transactional loading contract (TReportLoadResult)

**5. What should be changed first?**
1. **Expression engine enhancement** — add IIF/IF/ELSE, date functions (high impact, low risk)
2. **Optional single-pass rendering** — performance win for large reports (medium risk)
3. **High-DPI scaling** — fixes rendering on modern displays (medium effort)
4. **Complete data source abstraction** — implement JSON/CSV/REST providers (high effort, high impact)
5. **Test expansion** — add characterization tests for edge cases (low risk, high value)

---

## 27. Conclusion

VittixReport is a **solid pre-production reporting component** with clean architecture and good extensibility. The core engine, serializer, and export pipeline are well-designed for incremental improvement. The Phase 4I-18 transactional loading redesign establishes a failure-safe foundation for future enhancements.

**Key strengths:**
- Layered architecture with clean dependency graph
- Version-tolerant JSON serialization
- Plugin interfaces for extensibility
- Command-pattern undo/redo with proper ownership
- Comprehensive test suite (231 tests, 457/457 baseline)
- Transactional loading with structured diagnostics
- Unknown object preservation for forward compatibility

**Key risks:**
- Dataset coupling (direct TDataSet references)
- DPI assumptions (fixed 96 DPI)
- Two-pass performance overhead
- No thread safety
- Incomplete data source abstraction

**Overall readiness:** Suitable for pre-production use with the performance optimizations from Phase 2. Not yet ready for production deployment without addressing the high-severity technical debt items (thread safety, data source abstraction, DPI awareness).

---

*Report generated from source code analysis only. No runtime testing was performed in this analysis.*

---

## 28. Evidence Corrections and Phased Modernization Baseline

### Evidence boundaries

The code confirms a VCL/Windows implementation: the core runtime imports
`Vcl.Graphics` and creates `TMetafileCanvas`; printing imports `Vcl.Printers`.
It does not confirm a compiler version or a currently successful build. The
designer and demo use FireDAC with SQLite, but the runtime consumes the
framework-level `Data.DB.TDataSet` API, so it is not intrinsically coupled to
FireDAC. A database whose Delphi driver exposes a compatible `TDataSet` can be
used without changing the report engine. SQL, stored procedures, connection
opening, and parameter binding are application/designer responsibilities, not
runtime report-engine capabilities.

The standalone `IReportDataSource` contract should not be described as an
active provider layer: no production unit outside `DataSources.pas` references
it. Introducing it into the engine is therefore a migration, not completing
an already-wired feature.

### Recommended roadmap with gates

| Phase | Objective and current problem | Direction | Risk/dependency | Expected benefit |
|---|---|---|---|---|
| 0 - Baseline | Make behavior measurable; current historical pass counts are not current evidence. | Reproduce package/designer/test builds and capture page-count, visual, export and GDI baselines for the existing `.vrt` corpus. | Low; requires the supported Delphi toolchain and printer-dependent test setup. | A regression contract before architectural work. |
| 1 - Correctness hardening | Pagination, expression fallback and printer scaling can silently produce a plausible but wrong report. | Add characterization and golden-output cases before changing algorithms; preserve JSON and band ordinals. | Low code risk; test infrastructure effort. | Safer incremental change. |
| 2 - Data boundary | Engine directly drives borrowed `TDataSet`/bookmarks; the declared provider interface is unused. | First define behavior-compatible read-only cursor/field/bookmark capabilities, then adapt `TDataSet`; do not force JSON/REST into scope. | Medium/high: grouping and aggregates need bookmark semantics. | Testable data boundary and provider portability. |
| 3 - Layout contract | Layout is calculated while drawing to a metafile at fixed logical 96-DPI pixels. | Introduce an internal measured-page/layout result alongside the current path; retain existing coordinates and metafile output initially. | High: pagination is a compatibility surface. | Enables deterministic page tests and future render targets. |
| 4 - Output fidelity | Preview and most printing rasterize or stretch pages; PDF printer export is interactive/device-dependent. | Prefer consuming a common recorded command/layout representation for preview, native PDF, HTML and XLSX; keep printer export as a compatibility path. | High; requires format-specific golden tests. | Better screen/print/export consistency and headless export. |
| 5 - Designer decoupling | The VCL designer owns model state, selection, painting, undo and JSON state in tightly related controls/forms. | Extract only testable commands and selection/layout services behind existing designer APIs; avoid a UI rewrite. | Medium; preserve DFM persistence and shortcuts. | More maintainable designer without destabilizing users. |
| 6 - Performance and concurrency | Two-pass rendering, aggregate dataset rescans and bitmap page copies scale with report size. | Profile first; add optional bounded page caching/single-pass mode only where total-page expressions are absent. Keep UI, datasets and GDI on their owning thread. | Medium; behavior varies with data and expressions. | Lower memory and faster large reports. |

### Required answers (evidence-based)

1. **Is the current architecture fundamentally sound?** Partly. The model,
band hierarchy, serializer, engine and metafile output path form a coherent
incremental base. Direct dataset traversal during layout/drawing and output
paths with different representations prevent calling it fully separated.
2. **Can it be modernized incrementally without a complete rewrite?** Yes,
provided each phase preserves `.vrt` serialization, public components and
characterized pagination output. The existing object registry, serializer
registry, exporter interface and command-capture document are useful seams.
3. **What are the three biggest architectural risks?** (a) layout and
pagination are coupled to mutable `TDataSet` position and GDI measurement;
(b) printer/PDF, preview and vector-command exports do not share one rendered
representation; (c) the unused provider abstraction can create a false sense
of portability while JSON/CSV/REST implementations are stubs.
4. **What should NOT be changed?** The persisted class discriminator and
unknown-object round trip, existing band-type meanings/ordinals, `.vrt` JSON
compatibility, and the public `TVittixReport` component should be protected by
compatibility tests before any internal change.
5. **What should be changed first?** Establish executable regression baselines
and then isolate page measurement from drawing. That produces the highest
correctness leverage; changing the expression language or adding async work
first would not address output consistency.
