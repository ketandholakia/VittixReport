# Demo Report Files

These 25 `.vrt` files are hand-authored (JSON, matching `Vittix.Report.Serializer`
schema v2) to back every entry already defined in `Frm.DemoMain.BuildDemoCatalog`.
Field names in each file's `FieldNames` array match the SQL column aliases in
`Frm.DemoMain.pas` exactly, so `PrepareDataForDemo` → `TVittixReport.Execute`
should bind cleanly against the Northwind SQLite dataset with no "missing
field" fallbacks.

## Feature coverage

| File | Engine features exercised |
|---|---|
| `simple_list.vrt` | Flat list, page header, `TReportFieldObject` |
| `simple_group.vrt` | `btGroupHeader`/`btGroupFooter`, group-change banding |
| `nested_group.vrt` | Two-level nested groups (`GroupLevel` 0 and 1) |
| `master_detail_subdetail.vrt` | 3-level group nesting + `SUM()` aggregate in group footer |
| `master_detail_detail.vrt` | Classic invoice layout: group header as invoice header, `SUM()` grand total in group footer |
| `multi_column_list.vrt` / `multi_column_band.vrt` | Compact row layout for column-band experiments |
| `memos_pictures.vrt` | `TReportImageObject` (field-bound), `TReportMemoObject`, conditional `DisplayFormat` |
| `split_bands.vrt` | `CanGrow` band + memo can-grow/can-shrink |
| `subreports.vrt` / `side_by_side_subreports.vrt` | Aggregated summary sources intended as subreport panels (flat layout — wire an actual `TReportSubReportObject` with nested `ReportJSON` in the designer if true nesting is needed) |
| `title_page_report.vrt` | Report-title-only page, single aggregate summary row |
| `interactive_report.vrt` | `FontColorCondition` / `BackgroundCondition` conditional formatting |
| `charts.vrt`, `employee_sales.vrt`, `category_sales.vrt` | `TReportChartObject` (bar/pie) bound to `DataSetName`/`DataFieldLabel`/`DataFieldValue` |
| `xtab_no_rows.vrt` … `xtab_2values.vrt` | `TReportCrossTabObject`: 0/1/2 row dims × 0/1/2 col dims, single and dual cell-value variants |
| `product_inventory.vrt` | Grouped report + conditional formatting (`NeedsReorder`) |
| `orders_by_shipper.vrt`, `supplier_products.vrt` | Group header/footer master-detail over joined Northwind tables |

## Known simplification
`subreports.vrt` and `side_by_side_subreports.vrt` ship as flat summary
layouts rather than true nested `TReportSubReportObject` instances (that
requires an embedded, separately-bound `ReportJSON` string best produced by
saving a child report from the designer and pasting its JSON in). Everything
else is feature-complete against the engine's object model as of the
"close modernization roadmap" commit.

Generated to accompany `VittixReportDemo.dpr` — drop straight into
`demo/vrt/` (already done if you unzipped there).
