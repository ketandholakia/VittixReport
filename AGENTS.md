# VittixReport Codex Instructions

## ⛔ V1.0 FEATURE FREEZE (active since 2026-09-28)

The freeze baseline is tagged `v1.0-freeze-start`. Until `v1.0.0` is tagged, ONLY these changes are allowed:

- `[fix]` Bug fixes (P0/P1 from `VittixReport_BugQueue.md`, or bugs found during soak)
- `[test]` Tests, golden files, failing-test reproductions
- `[chore]` Documentation corrections for existing behavior only

FORBIDDEN during the freeze:

- New features
- New plan files
- Refactors not attached to a bug
- "Small improvements"
- Finishing deferred plan items merely for completeness

Commit prefixes during the freeze: `[fix] ...`, `[test] ...`, `[chore] ...` only. No `[feature]` commits.

Feature-vs-bug test:

> Does the report render what the designer says it should?
>
> - YES → not a bug → add to `BACKLOG_v1.1.md` and stop.
> - NO → bug → write a failing test → fix it.

Parked ideas and deferred plan work live in `BACKLOG_v1.1.md`. Do not start them until v1.0.0 ships.

## Project Type

This repository is a Delphi VCL report component/library named VittixReport.

It is not a business application.

The goal is to improve the reusable reporting engine, designer, preview, print, and export system.

## Main Priorities

1. Stability
2. Backward compatibility
3. Rendering correctness
4. Pagination correctness
5. Memory and GDI resource safety
6. Performance
7. Clean component API
8. Designer usability
9. Export/print consistency

## Hard Rules

- Do not rewrite the full component.
- Do not change public APIs without explaining why.
- Do not rename public classes, methods, properties, units, or file formats unless required.
- Do not remove existing features.
- Keep changes small and incremental.
- Prefer bug fixes before new features.
- Separate analysis from code changes.
- Ask before large refactoring.
- Always explain risky changes before applying them.
- Preserve compatibility with existing report files where possible.

## Delphi Rules

- Use try/finally for owned objects.
- Avoid memory leaks.
- Avoid GDI leaks.
- Free TBitmap, TFont, TStream, TObjectList, and temporary canvases safely.
- Be careful with TCanvas and Printer.Canvas.
- Do not assume datasets are active.
- Check Assigned before using optional objects/events.
- Avoid repeated FieldByName calls inside large loops.
- Avoid blocking UI during long report preparation where possible.

## Report Engine Rules

Check carefully:
- Band layout
- Page breaks
- CanGrow / CanShrink
- KeepTogether
- Page header/footer
- Group header/footer
- Detail band repetition
- Text wrapping
- Long text
- Null field values
- Empty datasets
- Large datasets
- Image scaling
- Margins
- DPI conversion
- Preview/print/export mismatch

## Preferred Workflow

For every task:

1. Analyze first.
2. List risks.
3. Suggest small changes.
4. Modify only after clear plan.
5. Keep commits logically grouped.
6. Provide testing steps.

## Testing Expectations

After changes, verify:
- Existing demo reports still open.
- Existing reports still render.
- Preview works.
- Print path still works.
- PDF/export output matches preview as much as possible.
- Empty dataset report works.
- Large dataset report works.
- Long text wrapping works.
- Images render correctly.
- No obvious memory or GDI leaks.
