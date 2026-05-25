# Text / DataField / Expression Editor Development Plan

## Goal

Add a unified designer dialog for editing report text, data field bindings, and expressions.

The editor should help users insert fields, variables, and common functions without changing the existing report file format or expression engine.

## Scope Rules

- Keep existing report object properties unchanged.
- Do not change saved report JSON format.
- Do not rewrite the expression parser.
- Do not replace the existing script editor.
- Keep each implementation stage small and commit only after compile/manual validation.
- Preserve existing property grid editing behavior.

## Target Properties

Initial supported properties:

- `Text`
- `DataField`
- `Expression`
- `PrintWhen`

Deferred properties:

- `OnBeforePrint`
- `OnAfterPrint`
- `BeforePrintScript`
- `AfterPrintScript`

Scripts should continue using the existing script editor until the unified editor is stable.

## Milestone M1 - Planning and Tracking

Status: Completed

Tasks:

- Create this development plan.
- Define safe milestone order.
- Confirm first implementation stage.

Validation:

- Markdown file exists at project root.
- No code changes.

Commit:

`docs(editor): add text expression editor plan`

## Milestone M2 - Basic Editor Dialog

Status: Completed

Goal:

Create a reusable modal dialog with a text editing area and OK/Cancel buttons.

Implementation:

- Add `vittixdesigner/Frm.TextExpressionEditor.pas`.
- Use runtime-created VCL controls first, no DFM dependency.
- Main editor uses `TMemo`.
- Dialog exposes a class function like:

```pascal
class function EditValue(const ATitle: string; var AValue: string): Boolean;
```

Validation:

- Designer compiles.
- Dialog can open independently from a simple test call.
- Cancel does not mutate the value.
- OK returns edited text.

Commit:

`feat(designer): add basic text expression editor dialog`

## Milestone M3 - Property Grid Integration

Status: Completed

Goal:

Open the new editor from the existing property grid for text-like report properties.

Implementation:

- Wire editor into existing property edit button/double-click flow.
- Support rows:
  - `Text`
  - `DataField`
  - `Expression`
  - `PrintWhen`
- Preserve existing direct inline editing.
- Do not change object serialization.

Validation:

- Selecting a `TReportTextObject` opens the editor for `Text`.
- Edited value is written back to property grid.
- Apply updates the selected object as before.
- Cancel leaves property value unchanged.
- Existing color/font/script editors still work.

Commit:

`feat(designer): open text expression editor from properties`

## Milestone M4 - Field Insertion Panel

Status: Completed

Goal:

Add a right-side Data tab that inserts dataset fields into the editor.

Implementation:

- Add right panel with tabs.
- Add `Data` tab.
- Reuse current designer field list source.
- Double-click field inserts token at cursor.

Token rules:

- For `Expression` and `PrintWhen`: insert `[FieldName]`.
- For `DataField`: insert `FieldName`.
- For `Text`: insert literal `FieldName`; current runtime does not interpolate field tokens stored in `Text`.

Validation:

- Current dataset fields appear.
- Double-click inserts at cursor.
- Existing typed text remains intact.
- Unknown/no fields state is handled without exception.

Commit:

`feat(designer): insert dataset fields in text editor`

## Milestone M5 - Variable Insertion Panel

Status: Completed

Goal:

Add a Variables tab for system variables.

Initial variables:

- `Date`
- `Time`
- `Page`
- `Page#`
- `TotalPages`
- `TotalPages#`
- `ReportTitle`
- `ReportDate`
- `DateTime`
- `RecNo`
- `RowNumber`

Validation:

- Variables insert at cursor.
- Tokens match current expression support.
- Preview still resolves inserted variables.
- Variables are insertable only into evaluated properties (`Expression` and `PrintWhen`).

Commit:

`feat(designer): insert variables in text editor`

## Milestone M6 - Function Snippets

Status: Completed

Goal:

Add a Functions tab with common expression snippets.

Initial snippets:

- `SUM([FieldName])`
- `COUNT([FieldName])`
- `AVG([FieldName])`
- `MIN([FieldName])`
- `MAX([FieldName])`

Deferred:

- `IF(condition, trueValue, falseValue)` because it is not supported by the current evaluator.

Validation:

- Snippets insert at cursor.
- User can edit placeholders manually.
- Existing expression engine behavior is unchanged.
- Aggregate snippets are inserted only for `Expression`; aggregate conditions in `PrintWhen` are not supported safely by the current evaluator.

Commit:

`feat(designer): add expression function snippets`

## Milestone M7 - Named Dataset Tree

Status: Deferred

Goal:

Improve the Data tab to show named datasets when available.

Decision:

- Deferred after implementation review.
- The report model currently stores `DataSetNames`, but field metadata is a single global `FieldNames` list.
- The designer cannot reliably show child fields for each named dataset.
- Expressions currently resolve `[FieldName]` in the active band dataset context; `Dataset.FieldName` syntax is not supported.
- Adding a dataset tree now would imply unsupported field selection behavior.

Implementation:

- Show dataset nodes and child fields.
- Preserve current single dataset list behavior when named datasets are unavailable.
- Insert either `FieldName` or `Dataset.FieldName` based on supported syntax.

Risk:

- Must not invent syntax unsupported by renderer/export.
- If named dataset expression syntax is incomplete, keep display-only dataset grouping and insert plain field names.

Validation:

- Single dataset reports still work.
- Named dataset reports show available datasets.
- Inserted tokens are supported by preview/export.

Prerequisites before implementation:

- Define per-dataset field metadata for standalone report files, preserving old files.
- Expose named dataset field discovery from hosted/designtime components.
- Decide whether fields remain band-contextual only or add and test explicit dataset-qualified expression syntax.

Commit:

`feat(designer): show named datasets in text editor`

## Milestone M8 - Usability Polish

Status: Completed

Goal:

Improve editing comfort without changing behavior.

Possible tasks:

- Keyboard shortcuts: Ctrl+Enter OK, Esc Cancel.
- Monospace editor font.
- Remember dialog size.
- Basic status bar with line/character count.
- Insert buttons for selected Data/Variable/Function item.

Deferred:

- Syntax highlighting.
- Autocomplete.
- Line-number gutter.

Commit:

`feat(designer): polish text expression editor usability`

## Milestone M9 - Regression Validation

Status: In Progress

Checklist:

- Designer compiles.
- Runtime package compiles.
- Design package compiles.
- Existing reports open.
- Text object editing works.
- DataField object editing works.
- Expression editing works.
- PrintWhen editing works.
- Preview renders edited values.
- Vector PDF export renders edited values.
- Cancel does not modify selected object.
- Undo behavior is not worsened compared with current property-grid flow.

Commit:

`docs(editor): complete text expression editor validation`

### Automated Validation Record - 2026-05-25

Completed:

- Designer application builds successfully.
- Runtime package builds successfully.
- Design package builds successfully.
- Headless runner builds successfully.
- Vector PDF regression run passed: 25 passed, 0 failed, 7 skipped.

Observed:

- Existing compile warnings remain; no new build errors were introduced.
- Headless runner reported `GDI Handles: 16 -> 24 (Delta: 8)`. This requires separate resource investigation or baseline confirmation and is not attributed to the editor dialog by this test.

Manual validation still required:

- Open a text object property and verify the editor opens for `Text`.
- Edit `DataField` through double-click and verify the existing pick list still works.
- Insert a field/variable/function into `Expression`, apply, and verify preview output.
- Edit `PrintWhen` using an inserted field or variable and verify visibility in preview.
- Cancel an edited value and verify the object remains unchanged.
- Apply an edit, then use undo/redo and verify property/display restoration.
- Export the edited report to vector PDF and verify the edited value matches preview.

## Current Next Step

Complete the M9 manual validation checklist in the designer.

Do not mark M9 completed until preview, vector PDF export, cancel, and undo/redo behavior have been checked interactively.
