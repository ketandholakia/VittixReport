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
- Edit Report Description -> Undo/Redo.
- Edit Title + Author before same commit boundary -> one Undo/Redo step.
- Edit Title + Author + Description before same commit boundary -> one Undo/Redo step.
- Tabbing out of Title/Author does not create separate undo entries.
- Save after metadata already committed does not create duplicate undo entry.
- Report Properties Cancel with Description change -> no report change.
- Save/Reopen preserves Title, Author, and Description.

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

## 12) Structure Tree checklist

### Selection sync
- Select object on canvas -> matching tree node highlights.
- Select band on canvas -> matching tree node highlights.
- Click object node -> designer selects object.
- Click band node -> designer selects band.
- Double-click object/band node -> designer keeps focus/selection.

### Refresh safety
- Add object -> tree updates.
- Delete object -> tree updates.
- Undo/Redo object delete -> tree updates.
- Add band -> tree updates.
- Delete selected band -> tree updates.
- Undo/Redo band delete -> tree updates.
- New/Open/Load report -> tree resets cleanly.

### Context menu
- Right-click object node -> node selected, Delete enabled.
- Right-click band node -> node selected, Delete enabled.
- Right-click Report root -> Delete disabled.
- Right-click empty area -> Delete disabled/no crash.
- Context Delete object -> Undo/Redo works.
- Context Delete band -> Undo/Redo works.
- Expand All / Collapse All -> no undo entry.

### Deferred/not implemented
- Tree rename is not implemented.
- Tree drag/drop reorder is not implemented.
- Tree Add Band/Add Object context actions are not implemented.

## 13) UI/Toolbar checklist

### Toolbar SVG icons
- Main toolbar loads without SVG/ImageList errors.
- Toolbar SVG icons are visible and readable.
- Toolbar SVG icons use dark neutral color, not pale/low-contrast color.
- Existing toolbar buttons still call the same actions.
- Undo/Redo buttons still enable/disable correctly.

### View toggles
- Grid / Snap / Ruler / Margin toggles appear horizontally in one row.
- Grid / Snap / Ruler / Margin toggles are not clipped at normal window size.
- Grid toggle shows/hides grid immediately.
- Snap toggle changes snap behavior.
- Ruler toggle shows/hides ruler immediately.
- Margin toggle shows/hides margin guides immediately.
- View toggles do not create undo entries.
- View toggles do not mark report modified.
- Preview/export output is unchanged by view toggle state.

### Toolbar zoom selector
- Toolbar zoom dropdown appears near Zoom In / Zoom Out.
- Dropdown includes 25%, 50%, 75%, 100%, 150%, 200%, Page width, Whole page.
- Selecting each percentage changes canvas zoom correctly.
- Page width fits visible page width.
- Whole page fits full page in visible area.
- Zoom In / Zoom Out update the dropdown text.
- Mouse-wheel zoom updates the dropdown text.
- Right-panel zoom Apply still syncs with toolbar dropdown if right-panel zoom remains.
- Zoom changes do not create undo entries.
- Zoom changes do not mark report modified.
- Preview/export output is unchanged by zoom state.

## 14) Designer UI / Property Panel checklist

- Selecting an object loads its properties.
- Header shows selected object/band type.
- Header shows object Name when available.
- Apply is disabled when no pending property edits.
- Editing a real property enables Apply.
- Clicking visual group rows does not mark panel dirty.
- Applying property changes creates one undoable batch.
- Apply disables again after successful Apply.
- Changing selection clears/reloads dirty state safely.
- Enter applies only when dirty and does not create noisy no-op undo.
- Property hint/status text appears for common rows.
- Property hint/status text covers DataField.
- Property hint/status text covers Expression.
- Property hint/status text covers PrintWhen.
- Property hint/status text covers DisplayFormat.
- Property hint/status text covers FontColor / BackgroundColor / BorderColor.
- Expression Helper still works.
- Font dialog still works.
- Color picker still works.
- DataField picklist still works.

### Designer Event Fields
- Select a band -> [Events] group appears in property panel.
- OnBeforePrint appears once under/near [Events].
- OnAfterPrint appears once under/near [Events].
- OnBeforePrint hint explains persisted band script hook.
- OnAfterPrint hint explains persisted band script hook.
- Hints clarify these fields are different from runtime Delphi callbacks.
- Open OnBeforePrint helper from property ellipsis button.
- Open OnAfterPrint helper from property ellipsis button.
- Band Event Script dialog shows multiline editor.
- Editing OnBeforePrint / OnAfterPrint enables Apply.
- Cancel in Band Event Script dialog keeps property value unchanged.
- Applying event text creates one undoable property batch.
- Undo/Redo restores event text.
- Save/Reopen persists event text.
- Expression Helper still works for expression fields.
- Runtime Event Callback Demo remains unaffected.
- Select object -> [Events] group appears in property panel.
- Object OnBeforePrint / OnAfterPrint appear once under/near [Events].
- Object event helper opens as Object Event Script.
- Object event text saves/reopens.
- Object event text helper remains editor-only (no designer-side validation or execution).
- Band event helper still works.

### Band Event Script Helper
- Select a band and verify [Events] group appears.
- OnBeforePrint has helper/ellipsis editor.
- OnAfterPrint has helper/ellipsis editor.
- Opening helper shows multiline editor.
- Helper shows concise help text.
- Snippet combo/list is visible.
- Insert button inserts selected snippet at caret.
- Snippet text is clearly marked as host-script example/text only.
- Helper shows line/char count.
- Line/char count updates while typing.
- Line/char count updates after snippet insertion.
- Fixed-width editor font is used.
- OK writes edited text back to property grid only.
- OK enables Apply / dirty state.
- Ctrl+Enter closes helper with OK.
- Enter inside editor inserts newline.
- Cancel leaves property value unchanged.
- Dialog does not execute script.
- Dialog does not validate script syntax.
- Snippet insertion does not execute or validate script.
- Cancel discards inserted snippet text.
- Dialog does not auto-apply.
- Applying creates one undoable property batch.
- Undo/Redo restores event script text.
- Apply/Undo/Redo behavior remains unchanged.
- Save/Reopen preserves event script text.
- Expression Helper still works for Expression / PrintWhen / condition fields.
- Font / Color / DataField editors still work.

### Band Event Script Snippets
- Snippet combo/list is visible.
- Snippet label clearly says host-script example / text only.
- Insert button is visible.
- Header / note snippet inserts plain text at caret.
- Visibility placeholder snippet inserts plain text at caret.
- Variable placeholder snippet inserts plain text at caret.
- If / then template inserts plain text at caret.
- Host callback note inserts plain text at caret.
- Snippet insertion updates Lines / Chars count.
- Cancel after snippet insertion leaves property value unchanged.
- OK after snippet insertion writes text back to property grid only.
- Dialog does not validate snippets.
- Dialog does not execute snippets.
- Dialog does not auto-apply.
- Apply / Undo / Redo behavior remains unchanged.

## 15) Event / Script Policy

- See host callback wiring and execution notes in `docs/EVENTS.md`.
- Related runtime persistence/execution checks: `## 16) Object Event Fields Phase A (Persistence Only)` and `## 17) Object Event Fields Phase C (Runtime Execution)`.

### Current supported items
- Runtime Delphi lifecycle callbacks:
- OnBeforePrintReport
- OnAfterPrintReport
- OnBeforeBand
- OnAfterBand
- OnBeforeObject
- OnAfterObject
- Persisted band event text:
- TReportBand.OnBeforePrint
- TReportBand.OnAfterPrint
- Band event text is stored in `.vrt` and interpreted by the host application callback/script layer.
- Designer does not validate or execute script text.
- Runtime Delphi callbacks are not stored in `.vrt`.

### Object event fields
- Persisted object `OnBeforePrint` / `OnAfterPrint` fields are supported.
- Object event text is stored in `.vrt` when non-empty and omitted when empty.
- Runtime callback assignment remains host-side and is not stored in `.vrt`.
- Designer editing remains text-only (no validation/compilation/execution).

## 16) Object Event Fields Phase A (Persistence Only)
- Old `.vrt` files load unchanged.
- Empty object `OnBeforePrint` / `OnAfterPrint` fields are omitted on save.
- Non-empty object `OnBeforePrint` / `OnAfterPrint` values save and reload correctly.
- Persistence-only baseline validated before runtime execution phase.

## 17) Object Event Fields Phase C (Runtime Execution)
- Object event fields appear under `[Events]` in property panel.
- Object Event Script helper opens for object `OnBeforePrint` and `OnAfterPrint`.
- Save/load preserves non-empty object event text.
- Empty object event fields are omitted from `.vrt` serialization.
- Empty object event fields keep output unchanged.
- Non-empty object `OnBeforePrint` executes during final render pass.
- Non-empty object `OnAfterPrint` executes during final render pass.
- Object event text does not execute during counting pass.
- Script host receives object `OnBeforePrint` text and object context during final render.
- Script host receives object `OnAfterPrint` text only when object draw completes.
- Script-host `OnObjectBeforePrint` and runtime `OnBeforeObject` can both cancel print;
- script-host cancel runs first and skips runtime `OnBeforeObject`.
- Demo host parser supports `CanPrint := False`.
- Demo host parser supports `Text := 'literal'` for `TReportTextObject`.
- Demo host parser supports `Text := Field('FieldName')` for `TReportTextObject`.
- Demo host parser supports `Visible := False|True`.
- Demo host parser supports `Background := clColorName` for `TReportTextObject`.
- Unsupported script commands are logged by host/demo and do not crash.
- Unsupported script diagnostics include reason tags (for example:
- `ScriptUnsupported[UnknownCommand]`, `ScriptUnsupported[FieldSyntax]`, `ScriptUnsupported[ColorValue]`).
- Demo parser command handling is routed through reusable host-side adapter logic (behavior unchanged).
- Runtime Event Callback Demo subtest `Text := Field('CustomerName')` reports PASS.
- Runtime Event Callback Demo subtest `Background := clYellow` reports PASS.
- Runtime Event Callback Demo subtest `Visible := False` reports PASS.
- Runtime Event Callback Demo subtest `Text := 'O''Reilly'` (escaped quote literal) reports PASS.
- Runtime Event Callback Demo subtest whitespace-normalized sequence `Visible := True ; Text := 'WS'` reports PASS.
- Runtime Event Callback Demo subtest trailing semicolon sequence `Text := 'Tail'; ; ;` reports PASS.
- Runtime Event Callback Demo subtest invalid command `Foo := 1` reports PASS for unsupported handling.
- Runtime Event Callback Demo subtest `Text := Field(CustomerName)` reports `FieldSyntax` unsupported PASS.
- Runtime Event Callback Demo subtest `Text := Field('   ')` reports `FieldName` unsupported PASS.
- Runtime Event Callback Demo subtest `Background := clNotAColor` reports `ColorValue` unsupported PASS.
- Runtime Event Callback Demo subtest `Visible := Maybe` reports `VisibleValue` unsupported PASS.
- Runtime Event Callback Demo subtest `Text := Demo` reports `TextLiteral` unsupported PASS.
- Runtime Event Callback Demo subtest `CanPrint := Maybe` reports `CanPrintValue` unsupported PASS.
- Runtime Event Callback Demo supports bounded semicolon command sequences and reports PASS.
- `CanPrint := False; ...` short-circuits remaining commands for that object.
- Quote-aware semicolon split works: `Text := 'A;B'; Visible := True`.
- Runtime Event Callback Demo shows compact parser edge-case summary (EscapedQuote/WhitespaceNormalization/TrailingSemicolon).
- Runtime Event Callback Demo shows unsupported-command diagnostics grouped by subtest.
- Runtime Event Callback Demo shows compact unsupported-reason summary with per-reason counts.
- Runtime Event Callback Demo unsupported reason summary includes `UnknownCommand` when invalid command subtest runs.
- Runtime Event Callback Demo unsupported reason summary includes:
- `UnknownCommand`, `FieldSyntax`, `FieldName`, `ColorValue`, `VisibleValue`, `TextLiteral`, `CanPrintValue`.
- Band script behavior remains unchanged.
- Preview and export use consistent object event execution behavior.

### Object Event / PrintWhen Ordering Regression
1. Create or use a report object with:
- `PrintWhen` expression that evaluates to `False`.
- Persisted `OnBeforePrint` text.
- Persisted `OnAfterPrint` text.
- Runtime `OnBeforeObject` callback.
- Runtime `OnAfterObject` callback.
2. Preview or export the report.
3. Confirm:
- Object is not drawn.
- Persisted `OnBeforePrint` text is not executed.
- Persisted `OnAfterPrint` text is not executed.
- Runtime `OnBeforeObject` callback is not called.
- Runtime `OnAfterObject` callback is not called.
4. Change `PrintWhen` so it evaluates to `True`.
5. Preview or export again.
6. Confirm execution order:
- `PrintWhen`.
- Persisted object `OnBeforePrint`.
- Runtime `OnBeforeObject`.
- Object draw.
- Persisted object `OnAfterPrint`.
- Runtime `OnAfterObject`.

Expected result:
- Object persisted event text and runtime object callbacks are gated by `PrintWhen`.
- Skipped objects must not execute before/after event logic.
- Preview and export follow the same object event execution path and order.
- If object script-host `OnBeforePrint` sets `CanPrint=False`, runtime `OnBeforeObject`, draw, persisted `OnAfterPrint`, and runtime `OnAfterObject` are skipped.

## 18) Designer UI / Variables checklist

### Variables panel
- Variables panel appears in the designer left area.
- System variables group appears.
- Variables list includes Date, Time, Page, Page#, TotalPages, TotalPages#, Line, Line#.
- Deferred variables CopyName#, TableRow, TableColumn are safely handled or marked unsupported.

### Insertion
- Double-click Date inserts supported token into Text/Expression row.
- Double-click Page inserts supported page token.
- Double-click TotalPages inserts supported total-pages token.
- Double-click Line inserts supported line/record token.
- Unsupported variable double-click shows safe message and does not insert misleading token.
- No compatible property row selected -> safe fallback/no crash.

### Runtime
- [Date] renders safely.
- [Time] renders safely.
- [Page] / [Page#] render page number.
- [TotalPages] / [TotalPages#] render total pages.
- [Line] / [Line#] render record/line value where dataset context exists.
- Existing legacy tokens still work:
- [PageNo]
- [TotalPages]
- [ReportTitle]
- [ReportDate]
- [DateTime]
- [RecNo]

### Regression
- Dataset Fields panel still works.
- Expression Helper still works.
- Property Apply undo still works.
- Preview/export still works.
- Regression Test Reports still run.

## 19) Engine / Runtime Events checklist

- Host application callback wiring examples are documented in `docs/EVENTS.md`.
- For object persisted event ordering checks, see `## 17) Object Event Fields Phase C (Runtime Execution)`.

### No-handler baseline
- Existing reports render unchanged when no event callbacks are assigned.
- Preview output unchanged.
- Export output unchanged.
- Regression Test Reports still pass.

### Report events
- OnBeforePrintReport fires once per final render/export.
- OnAfterPrintReport fires once after final render/export.
- OnBeforePrintReport cancel behavior is safe if implemented.

### Band events
- OnBeforeBand fires before actual band print.
- OnAfterBand fires after actual band print.
- OnBeforeBand CanPrint=False skips band safely if implemented.
- Existing band script-string OnBeforePrint/OnAfterPrint still executes.

### Object events
- OnBeforeObject fires before actual object print.
- OnAfterObject fires after actual object print.
- OnBeforeObject CanPrint=False skips object safely.
- Existing PrintWhen behavior remains unchanged.

### Pass behavior
- Events do not fire during measurement/counting pass.
- Events fire only during final render pass unless explicitly documented.
- TotalPages output remains stable.

### Safety
- Nil/unassigned event handlers are safe.
- Event exceptions behave consistently with engine policy.
- Preview and export use the same event path.
- No .vrt schema/serializer change is required for runtime callbacks.
