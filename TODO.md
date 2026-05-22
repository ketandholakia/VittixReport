# VittixReport TODO

## Refactor Roadmap
| Step | Area | Status | Notes |
|---|---|---|---|
| 1 | Designer preferences service | In progress | Grid, rulers, colors, and MRU persistence are split out; recent-files menu wiring is being separated next. |
| 2 | Selection manager | In progress | Tree sync and core selection mutators are extracted; drag selection and keyboard selection remain in the designer control. |
| 3 | Surface interaction controller | In progress | Hit-test/geometry helpers are split; interaction state container is added and mouse event migration is next. |
| 4 | Command dispatcher | Pending | Centralize undo/redo routing and command execution policy. |
| 5 | Layout/render tree | Pending | Introduce a layout stage between model and render. |

## 🟠 Important — Commonly Needed
| # | Feature | Detail | Dev Status |
|---|---------|--------|------------|
| 1 | SaveToJSON / LoadFromJSON | The Serializer only has SaveToFile/LoadFromFile. TVittixReport.ReportJSON and the component editor both call these — they don't exist yet, which means the component and component editor will fail to compile. | ✅ |
| 2 | TReportRenderer.Print | The renderer has no Print method. TVittixReport.Print works around it via TVittixReportPreview but that's a roundabout path. | ✅ |
| 3 | Native PDF Export (Stream-based) | **CRITICAL**. Currently uses "Microsoft Print to PDF". Need a native `TReportPDFWriter` class that generates PDF syntax directly to TStream. Allows silent export and server-side usage. | |
| 4 | Two-pass rendering for [TotalPages] | TotalPages is always 0 while the engine runs. FastReport renders twice — first pass counts pages, second pass fills in the total. | ✅ |

## 🟡 Designer Gaps
| # | Feature | Detail | Dev Status |
|---|---------|--------|------------|
| 5 | Sub-reports | A band object that contains its own nested TReportModel with its own dataset. Essential for master-detail layouts. | ✅ |
| 6 | Detail band with its own dataset | Currently the engine only loops one FMasterBand over one FDataSet. FastReport supports multiple detail bands each with their own linked dataset. | ✅ |
| 7 | Cross-tab / matrix object | Pivoted data table — rows and columns both come from data. | |
| 8 | Rich text / HTML memo | TReportMemoObject renders plain text only. No bold/italic mid-string, no HTML markup inside a cell. | ✅ |
| 9 | Format strings on fields | TReportFieldObject needs `DisplayFormat` property (e.g., `#,##0.00`). Use `FormatFloat`/`FormatDateTime` in engine. | ✅ |
| 10 | Conditional formatting / Expressions | Need a lightweight expression parser. Allow properties to be expressions, e.g., `Font.Color := IF(Value < 0, clRed, clBlack)`. | ✅ |
| 11 | OnBeforePrint / OnAfterPrint events on bands | TReportScriptEngine is a stub — events are declared but do nothing. Bands have no OnBeforePrint event property for user code to intercept. | ✅ |
| 12 | Export to Excel (XLSX) | Only PDF exists. No XLSX, CSV, HTML, or RTF exporter. | |
| 13 | Export to HTML | Very common requirement for web preview. | |

## 🟢 Nice to Have
| # | Feature | Detail | Dev Status |
|---|---------|--------|------------|
| 14 | Field list drag-and-drop | Currently double-click only. Drag from field list to band is the standard UX. | ✅ |
| 15 | Copy/paste between reports | Clipboard is internal to one designer session only. | |
| 16 | Snap to other objects (smart guides) | Only grid snap exists. No alignment guides relative to other objects. | |
| 17 | Property editor for Font | Font shows as a raw string in the value list editor, no font picker dialog. | ✅ |
| 18 | Colour picker for Color properties | No colour dialog in the property panel. | |
| 19 | Object locking | No Locked property to prevent accidental moves. | |
| 20 | Report variables / parameters | Add `Variables` dictionary to TReportModel. Allow syntax `[<VarName>]` in text objects. | |
| 22 | Chart object | Pie/bar/line chart bound to dataset. | |
| 23 | Subreport as a child band | Inline nested report in a band. | |
| 24 | [RecNo] system token | Current record number within the group or report. | |
| 25 | Alternating row colors | Odd/even row background on master data band. | |
| 26 | Print preview zoom + fit-page | The inline preview (Execute) has no zoom controls. | ✅ |
| 27 | Multiple paper sizes per section | Landscape summary page after portrait data. | |
| 28 | Email export | Send PDF directly via MAPI/SMTP. | |
