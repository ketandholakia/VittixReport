# Reports Catalog

## Automatic Regression Reports

These reports are included in the standalone designer's **Run Regression Test Reports** flow.
They are lightweight, non-interactive, and expected to render deterministically with sample data.

- `01_simple_masterdata.vrt` - basic master data
- `03_grouped_report.vrt` - grouping
- `05_cangrow_remarks.vrt` - CanGrow remarks
- `06_barcode_test.vrt` - barcode
- `07_imagepath_test.vrt` - image path
- `11_exact_fit_boundary.vrt` - exact-fit pagination
- `12_summary_new_page_header.vrt` - summary page header
- `13_group_header_pagebreak.vrt` - group header page break
- `14_group_footer_pagebreak.vrt` - group footer page break
- `15_large_preview_stress.vrt` - multi-page preview stress
- `17_object_printwhen_core.vrt` - core object PrintWhen
- `18_barcode_printwhen.vrt` - barcode PrintWhen
- `19_displayformat_values.vrt` - DisplayFormat/EditMask
- `20_printwhen_boolean_coercion.vrt` - PrintWhen boolean coercion
- `21_condition_color_boolean_coercion.vrt` - conditional color boolean coercion
- `22_expression_usage_demo.vrt` - expression usage demo
- `23_invalid_datafield_diagnostics.vrt` - invalid DataField diagnostics

## Manual-only Reports

These reports are intentionally not part of automatic regression and should be run manually.

- `16_large_preview_warning.vrt` - intentionally interactive/heavy preview warning test

## Dev/Test Artifacts

- `reports/test*.vrt` files are development artifacts.
- Do not commit new `test*.vrt` files unless they are promoted to official regression reports.
