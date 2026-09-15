# Phase 3 — Performance Foundations

Status: implemented. This phase makes two execution-local caching changes only:
aggregate results and parsed subreport models. It does not change report
serialization, public report APIs, expression semantics, pagination, linked
dataset matching, rendering, printing, or export behavior.

## Baseline

- Branch: `main`
- Starting HEAD: `549e0c4`
- Phase 2 suite: 515 tests.
- This environment compiles the full suite but has 22 pre-existing XLSX
  `Access is denied` errors. There are no assertion failures.

## Hotspot validation

`TReportAggregates.TryEvaluate` scanned from its group start (or dataset first
row) on every successful evaluation. `TReportSubReportObject.MeasuredBottom`
and `Draw` each parsed `ReportJSON`; normal rendering can call `Draw` once per
master row. Phase 2 already measured each subreport traversal independently.

## Aggregate cache design

The engine owns an aggregate cache and clears it immediately before each
`ExecutePass`. An entry is valid only for the same:

- `TDataSet` instance;
- exact expression text;
- group-start and group-end bookmark byte ranges;
- page number, total pages, row number, and counting/rendering pass state;
- parameter and variable text; and
- dataset filter text and filtered state.

The value is stored only after a successful evaluation. Aggregate evaluation
continues to own its bookmark, control suppression, scan, and restoration
logic, so a cache miss preserves prior cursor behavior and a cache hit does not
move the cursor at all. The cache is engine-owned, not global, and cannot
survive an engine destruction, a new `Prepare`, or a two-pass boundary.

## Subreport cache design and invalidation

The engine owns parsed subreport models in an owning list. The key is the
subreport object instance plus its current `ReportJSON` text. Object identity
avoids conflating independent embedded reports with equal JSON; the text check
invalidates a replaced JSON value during a running execution.

Entries are cleared before every pass and freed with the engine. Nested
subreports retain the same render hooks and therefore receive the same
execution-local ownership policy. A malformed JSON value is not cached; its
existing failure behavior is retained.

## Benchmark fixtures and measurements

The deterministic `Test.Vittix.Report.Phase3` fixtures use in-memory
`TClientDataSet` sources and structural counters rather than elapsed time.

| Fixture | Metric | Before | After |
| --- | --- | ---: | ---: |
| Repeated `SUM([Amount])`, 20 rows | aggregate evaluations / scans / rows | 2 / 2 / 40 (two pre-cache loop executions) | 2 / 1 / 20 |
| Two master rows with one subreport | JSON parses | 2 (one per draw) | 1 |
| Two master rows with one subreport | scans / visited rows | 2 / 4 | 2 / 4 |

The aggregate fixture also checks the result (`2100`) and the original cursor
row. The report-execution fixture proves the cache is cleared for a second
`Prepare`. The subreport fixture proves model caching reduces parsing without
silently introducing a traversal or detail index cache.

## Diagnostics

`Vittix.Report.TraversalDiagnostics` now also observes aggregate evaluations,
cache hits/misses, scans, and visited rows, plus subreport cache hits/misses.
It remains process-local, diagnostic-only, and has no control-flow effect.

## Compatibility and ownership verification

The focused fixtures cover repeated aggregate reuse, cursor preservation,
execution reset, model reuse, and unchanged subreport scan counts. The full
suite build succeeds with zero compiler errors. In this environment it reports
518 tests: 496 passed, 0 failed, and the same 22 XLSX access-denied errors
observed before Phase 3.

## Deferred optimizations

- Subreport measurement caching: deferred. Measurement depends on current
  data/link state and page layout; no safe compact key was established.
- Detail/master indexing: deferred. Phase 2's repeated scans remain measured,
  but null, conversion, ordering, mutation, memory, and bookmark policy need a
  dedicated design.
- Page streaming and page-retention changes: deferred.

## GAP status

- GAP-003 aggregate result cache: implemented and measured.
- GAP-004 subreport parsed-model cache: implemented and measured; linked
  traversal/indexing remains deferred.
- GAP-005 page memory duplication: deferred.

## Phase 4 input

The next safe step is the separately designed expression-engine work. It
should retain the cache boundary: cache only values whose expression semantics
and execution context are fully represented by the key.
