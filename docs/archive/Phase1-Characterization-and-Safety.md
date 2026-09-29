# Phase 1 — Characterization & Safety

Status: implemented as a test-and-documentation baseline. No production report
engine, expression, serializer, renderer, designer, print, or export behavior
was changed in this phase.

## Scope and safety boundary

Phase 1 makes the existing runtime observable before corrective modernization.
The tests use `TClientDataSet`, in-memory export capture, and the checked-in
fixtures only. They do not require a printer, a network service, an interactive
designer session, or timing-based waits. The `.vrt` test loads every fixture,
serializes it in memory, reloads it, and never writes back to `reports/`.

The primary new test unit is `Test.Vittix.Report.Phase1`. Existing focused
units remain the baseline for expression edge cases, subreports, export command
capture, serializer registry behavior, undo, and designer-load transactions.

## Characterized contracts

| Area | Characterization evidence | Current behavior |
| --- | --- | --- |
| Expressions and aggregates | `Test_GAP001_BookmarkAggregate_RestoresCursor`; `Test.Vittix.Report.ExpressionAudit` | A bookmark-capable dataset is returned to its original row after `SUM([Amount])`. Arithmetic remains flat left-to-right (`1+2*3` is `9`); parentheses, boolean compositions, and aggregate composition have the previously documented limitations. |
| Aggregate non-bookmark datasets | source review of `TReportAggregates.TryEvaluate`; `DataSetSupportsBookmarks` tests in `Vittix.Report.Utils` | Aggregate evaluation directly calls `GetBookmark` and has no non-bookmark fallback. A realistic active non-bookmark test dataset is not available in the current test harness without a provider-specific dependency; this is recorded as a limitation, not silently treated as safe. |
| Master/detail traversal | `Test_GAP002_MasterAndDetailCursors_AreRestored` | The master cursor and a named detail cursor are restored after `Prepare` for bookmark-capable `TClientDataSet` sources. Detail matching still scans the detail dataset for each master record. |
| Subreports | `Test_SubReport_ParsesJSON_OnEveryDrawCall` in `Test.Vittix.Report.Characterization` | Subreport JSON is parsed during drawing/measuring rather than retained as a compiled subreport. The existing test verifies the executing path and successful output; exact parse-call counting needs an explicit production instrumentation seam and is deferred. |
| Pagination | `Test_GAP006_OneAndTwoPass_KeepPaginationAndExportPageCountsAligned`; existing pagination/CanGrow tests | For the deterministic fixture, one-pass and two-pass modes produce the same page count and each export document has one page per rendered page. |
| Page retention | `Test_GAP005_RendererRetainsOneBitmapAndMetafilePerEnginePage`; existing `Test_Renderer_StoresBothBitmapAndMetafile` | The engine owns metafiles, and the renderer retains one bitmap plus one metafile per page. Preview additionally copies pages; this phase measures the renderer boundary only and makes no memory-policy change. |
| Output fidelity | `Test_GAP006_OneAndTwoPass_KeepPaginationAndExportPageCountsAligned`; `Test.Vittix.Report.ExportCapture`, `Test.Vittix.Report.Export.HTML`, and `Test.Vittix.Report.Export.XLSX` | Captured vector/export commands are present and page counts align for the synthetic baseline. Physical printing remains manual because it depends on the installed printer driver. |
| `.vrt` compatibility | `Test_VRT_AllBundledFixtures_LoadSaveReload_PreserveModelShape` | All 42 currently checked-in reports are loadable and survive load → in-memory serialize → reload with top-level/nested object order, class, name, band type, dataset names, variables, and page dimensions preserved. Known serializer-loss behaviors remain covered separately. |
| Designer commands | `Test.Vittix.Report.Undo`, `Test.Vittix.Report.DesignerLoad` | Command-manager/undo behavior and transactional designer loading are automated. Mouse/keyboard interaction is intentionally not automated in this console suite. |

## GAP tracking

### GAP-001 — Expression compatibility

- Status: characterized; no semantic change.
- Evidence: `Test_GAP001_BookmarkAggregate_RestoresCursor`,
  `Test.Vittix.Report.Expressions`, and `Test.Vittix.Report.ExpressionAudit`.
- Characterization test: bookmark aggregate evaluation returns `60.0` and
  preserves the current dataset row.
- Current behavior: expression parsing is string-based and arithmetic is
  evaluated left-to-right; known unsupported or surprising forms are locked by
  the audit tests.
- Future phase: introduce a compatibility-mode expression implementation only
  after a migration plan and an expanded compatibility corpus are approved.

### GAP-002 — Aggregate and master/detail bookmarks

- Status: bookmark-capable paths characterized; non-bookmark fallback absent.
- Evidence: `Test_GAP002_MasterAndDetailCursors_AreRestored` and
  `Test_GAP001_BookmarkAggregate_RestoresCursor`.
- Characterization test: master and named-detail `TClientDataSet` cursors are
  restored after report preparation.
- Current behavior: normal engine traversal uses bookmark helpers; aggregate
  evaluation itself calls bookmark APIs directly.
- Future phase: add a provider-independent sequential-data contract and a
  no-bookmark aggregate/traversal strategy.

### GAP-004 — Subreport traversal

- Status: characterized; performance measurement deferred.
- Evidence: `Test_SubReport_ParsesJSON_OnEveryDrawCall`.
- Characterization test: a subreport follows the render/export traversal path
  without failure.
- Current behavior: its JSON is reparsed for draw/measurement work and linked
  detail traversal repeatedly scans the source.
- Future phase: add a narrowly scoped parsed-subreport cache with invalidation,
  then add measurable parse and traversal counters.

### GAP-005 — Page memory and retention

- Status: characterized at engine/renderer boundary.
- Evidence: `Test_GAP005_RendererRetainsOneBitmapAndMetafilePerEnginePage`.
- Characterization test: every engine page has exactly one retained renderer
  page with a bitmap and metafile.
- Current behavior: engine, renderer, and preview each retain page assets;
  preview duplicates renderer assets.
- Future phase: choose an explicit page-cache/eviction policy, preserving the
  preview/print API contract.

### GAP-006 — Output fidelity baseline

- Status: automated renderer/export baseline plus manual print procedure.
- Evidence: `Test_GAP006_OneAndTwoPass_KeepPaginationAndExportPageCountsAligned`
  and the export-specific test units.
- Characterization test: one- and two-pass page counts match, export pages
  match rendered pages, and captured draw commands exist.
- Current behavior: export capture and preview share engine traversal, while
  legacy physical PDF printing uses a printer driver.
- Future phase: build a fixture-based visual diff baseline for preview, vector
  PDF, HTML, and XLSX, then address differences individually.

## Manual print and preview procedure

1. Open `reports/41_twopass_totalpages.vrt` in the existing designer or demo.
2. Preview it and record page count, page-number text, header/footer placement,
   long-text wrapping, and image placement.
3. Export through vector PDF, HTML, and XLSX and compare those same features.
4. With a test printer installed, print to a non-production queue (or Microsoft
   Print to PDF) and compare the result with preview. Do not automate this step:
   printer selection and driver geometry are machine-specific.

## Deferred fixes and known limitations

- The Phase 1 brief references 45 `.vrt` fixtures; the repository currently
  contains 42. The test locks the actual checked-in inventory and flags any
  change until the missing three fixtures are identified or the inventory is
  formally updated.
- No non-bookmark aggregate fallback exists.
- Subreport parsing and detail linking are potentially expensive for large data.
- Retaining both bitmap and metafile pages has a linear memory cost; preview
  makes another copy.
- The baseline does not attempt a pixel-perfect print comparison or a physical
  printer test.
- Existing serializer characterization tests deliberately retain known losses
  such as selected font style and alternating band color properties; Phase 1
  does not normalize those behaviors.
