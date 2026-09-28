# VittixReport TODO

## ⛔ V1.0 FEATURE FREEZE (active since 2026-09-28)

See `AGENTS.md` for the full policy. Until `v1.0.0` is tagged, only `[fix]`, `[test]`, and
`[chore]` changes are allowed. New ideas and deferred plan work belong in `BACKLOG_v1.1.md`.

## Drain record (2026-09-28)

TODO.md was drained at the v1.0 feature freeze. Classification of every prior item:

- **A (actual bug):** none open in this file. Open bug work lives in `VittixReport_BugQueue.md`.
- **B (in-flight v1.0 work):** none — nothing was in flight at the freeze.
- **C (deferred feature/enhancement):** 2 items, moved to `BACKLOG_v1.1.md`:
  - Designer drag-gesture extraction (Refactor Roadmap step 2 residual, noted in the step's status line).
  - Mouse-event migration to the surface interaction controller (Refactor Roadmap step 3 residual, noted in the step's status line).
- **D (completed):** everything else. All entries in all four tables below were marked
  `Complete` before the freeze; they are preserved here in condensed form, and the full
  original tables remain retrievable at the freeze baseline:
  `git show v1.0-freeze-start:TODO.md`.

No item was discarded.

## Completed archive

### Refactor Roadmap (steps 1–5) — all Complete

Designer preferences service; selection manager (drag-gesture residual → backlog); surface
interaction controller (mouse-event migration residual → backlog); command dispatcher; layout/
render-tree helpers (band ordering, pagination/group flow, master/detail pass, bookmarks, finalization).

### Important — Commonly Needed (items 1–4) — all Complete

SaveToJSON/LoadFromJSON; TReportRenderer.Print; native stream-based PDF export; two-pass
rendering for `[TotalPages]`.

### Designer Gaps (items 5–13) — all Complete

Sub-reports; detail band with own dataset; cross-tab/matrix object; rich text/HTML memo;
field display formats; conditional formatting/expressions; OnBeforePrint/OnAfterPrint band
events; XLSX export; HTML export.

### Nice to Have (items 14–28, no 21) — all Complete

Field list drag-and-drop; copy/paste between reports; smart guides; font property editor;
colour picker; object locking; report variables/parameters; chart object; subreport child
band; `[RecNo]` token; alternating row colors; preview zoom/fit-page; multiple paper sizes
per section; email export.

## Open items

None. Do not add new feature items here during the freeze — use `BACKLOG_v1.1.md`.
