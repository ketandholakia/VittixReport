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

## 11) Undo/Redo stabilization checklist

### Basic object actions
- Add object -> Undo/Redo.
- Delete object -> Undo/Redo.
- Mouse move -> Undo/Redo.
- Mouse resize -> Undo/Redo.
- Keyboard `Ctrl+Arrow` move -> Undo/Redo.
- Keyboard `Shift+Arrow` resize -> Undo/Redo.

### Property actions
- Property panel Apply -> Undo/Redo.
- Expression Helper OK -> Undo/Redo.
- Font dialog OK -> Undo/Redo.
- Font dialog Cancel -> no undo entry.
- Apply with no change -> no undo entry.
- Edit Report Title -> commit boundary -> Undo/Redo.
- Edit Report Author -> commit boundary -> Undo/Redo.
- Edit Title + Author before same commit boundary -> one Undo/Redo step.
- Tabbing out of Title/Author does not create separate undo entries.
- Save after metadata already committed does not create duplicate undo entry.

### Band actions
- Add Band -> Undo/Redo.
- Delete selected band -> Undo/Redo.
- Delete child object inside band -> band remains.
- Delete band with children -> Undo/Redo restores children.

### Page Setup
- Page Setup OK with changes -> one Undo/Redo step.
- Page Setup OK with no changes -> no undo entry.
- Page Setup Cancel -> no undo entry.
- Page Setup Undo/Redo preserves earlier undo history.

### Band Manager
- Band Manager Cancel after edits -> no report change and no undo entry.
- Band Manager OK with no changes -> no undo entry.
- Band Manager OK with mixed changes -> one Undo/Redo.
- Previous undo history remains reachable after Band Manager OK.

### Undo/Redo UX
- Edit menu captions show next action name.
- Toolbar hints show next action name.
- Empty stack shows plain disabled Undo/Redo.

### Safety
- Structure tree refreshes after Undo/Redo.
- Property panel does not point to stale/deleted object.
- Preview works after deep Undo/Redo sequence.

### Undo history policy
- New/Open/Load report clears undo history.
- Regression/demo/sample report loading clears undo history.
- Band Manager OK preserves prior undo history and adds one command when changed.
- Band Manager Cancel creates no undo entry.
- Page Setup and Report Metadata commits are undoable.
- Sample dataset / Reload Sample Dataset / Live Database Connection are not document undo actions.
