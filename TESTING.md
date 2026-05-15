# VittixReport Manual Testing Checklist

Use this checklist before releases or major engine changes.

## 1) Build checks
- Build runtime package/project in Debug.
- Build runtime package/project in Release.
- Build standalone designer.
- Confirm no compile errors.

## 2) Designer smoke test
- New report.
- Open report.
- Save / Save As.
- Preview.
- Export PDF.
- Use Sample Dataset.
- Reload Sample Dataset.

## 3) Regression runner
- Run: `Report -> Regression Tests -> Run Regression Test Reports`.
- Confirm all automatic reports pass.
- Confirm manual-only report `16_large_preview_warning.vrt` is not auto-run.

## 4) Manual key reports
- Preview:
- `15_large_preview_stress.vrt`
- `16_large_preview_warning.vrt`
- `22_expression_usage_demo.vrt`
- `23_invalid_datafield_diagnostics.vrt`

## 5) Keyboard tests
- Property panel `Ctrl+C` / `Ctrl+X` / `Ctrl+V` / `Delete`.
- Canvas `Delete`.
- Arrow nudge.
- `Ctrl+Arrow` move by 1.
- `Shift+Arrow` resize by 1.
- `Ctrl+Shift+Arrow` move by grid size.

## 6) Property panel tests
- Boolean dropdown.
- Enum dropdown.
- DataField dropdown.
- Color picker.
- Font dialog.
- Group rows not editable.

## 7) Rendering tests
- Grouped report.
- CanGrow memo report.
- Barcode report.
- ImagePath report.
- PrintWhen reports.
- Conditional color reports.
- DisplayFormat report.

## 8) Diagnostics tests
Debug build:
- Unresolved expression token logs once/deduped.
- Invalid DataField logs once/deduped.

Release build:
- No debug diagnostics emitted.

## 9) Memory/GDI stress
- Open/close preview repeatedly.
- Export PDF repeatedly.
- Watch Memory, GDI Objects, USER Objects.
- Large preview warning Yes/No path.

## 10) Git/release checklist
- `git status` clean.
- `reports/README.md` aligned with runner list.
- `TESTING.md` updated if reports/features change.
