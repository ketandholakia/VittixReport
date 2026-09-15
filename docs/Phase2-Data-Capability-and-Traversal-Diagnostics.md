# Phase 2 — Data Capability & Traversal Diagnostics

Status: implemented. This phase adds observability and characterization only;
it does not alter report template format, serialization, expression semantics,
pagination, printing, grouping, or public `TVittixReport` APIs.

## Baseline

- Branch: `main`
- HEAD: `549e0c4`
- Starting test baseline: 507 passed, 0 failed, 0 errors.
- The working tree contained preserved Phase 1 and user-created untracked files.
  No reset or cleanup was performed.

## Data operation map

| Data operation | Calling unit/class | Why it is required | Capability required |
| --- | --- | --- | --- |
| Active check | `Vittix.Report.Utils` / engine | Avoid rendering an inactive source | active state |
| `First`, `Next`, `Eof` | `TReportEngine` master/detail loops; `TVittixUserDataSet` | Sequential master, detail, grouping, and user-source traversal | forward navigation |
| `FindField`, field value | `Utils`, engine, objects | Expressions, grouping, master/detail link comparison | field lookup/current value |
| `GetBookmark`, `GotoBookmark`, `FreeBookmark` | layout bookmarks, engine, aggregates, subreport | Preserve caller position; group boundaries; aggregate ranges | bookmark plus restore |
| `DisableControls`, `EnableControls` | engine, aggregates, subreport | Suppress visual dataset notifications during scans | optional UI-notification suppression |
| `RecordCount` | `SafeRecordCount` / progress and large-report checks | Progress and warning heuristics | optional count |
| User source callbacks | `TVittixUserDataSet` | Adapt first/next/eof/value access | forward navigation and current value |

## Actual capability contract

| Capability | Required by | Mandatory? | Current implementation | Failure behavior |
| --- | --- | --- | --- | --- |
| Active source | all execution | yes | `TDataSet.Active` or `TVittixUserDataSet` callbacks | engine exits or raises its existing inactive-source error |
| Forward navigation | master/detail/subreport/grouping | yes | `First`, `Next`, `Eof` | no generic fallback |
| Field access | expressions, links, groups | context dependent | `FindField`/`FieldByName`, or `GetValue` callback | safe utilities return `Null`/skip where applicable |
| Bookmark | caller-state restore and aggregate ranges | mandatory only for preservation/range semantics | `DataSetSupportsBookmarks` probe in engine/layout paths | engine proceeds sequentially but cannot restore cursor |
| Bookmark in aggregates | aggregate evaluation | currently assumed | direct bookmark calls in `TReportAggregates` | evaluates sequentially on the test source and leaves it at EOF |
| Count | progress/warnings | no | `SafeRecordCount` | zero when unavailable |

`TVittixUserDataSet` already supplies a small common forward-navigation/value
surface (`First`, `Next`, `Eof`, `GetValue`). It has no bookmark or caller-state
restoration contract. Adding a second general data-cursor abstraction in this
phase would duplicate that surface without changing any current call site, so
no adapter was introduced.

## Bookmark audit and policy

The engine and layout bookmark helpers probe capability before capture. Group
bookmark capture does likewise. Aggregate evaluation remains the exception: it
calls bookmark APIs directly. Subreport draw/measurement probe before saving a
bookmark, then still scan sequentially when one is unavailable.

The deterministic `TNoBookmarkClientDataSet` tests establish current behavior:

| Operation | Current behavior | Policy |
| --- | --- | --- |
| Master traversal | completes; source is left at EOF | B — supported with degraded caller-state behavior |
| Grouping | completes; source is left at EOF | B — supported with degraded caller-state behavior |
| Aggregate | returns the aggregate; source is left at EOF | B — supported with degraded caller-state behavior; direct bookmark assumption remains a documented gap |
| Master/detail | completes; master and detail sources are left at EOF | B — supported with degraded caller-state behavior |
| Subreport | completes; source is left at EOF | B — supported with degraded caller-state behavior |

No fallback was introduced because preserving caller state without bookmarks
would require buffering or a provider-specific repositioning contract, which
would be a behavior and resource-policy change. A future phase must explicitly
choose that contract before attempting restoration.

## Traversal diagnostics

`Vittix.Report.TraversalDiagnostics` is an internal process-local snapshot.
It records, but never changes:

- detail scan starts and visited rows, including look-ahead scans used by
  page-fit calculation;
- subreport JSON parse attempts;
- subreport scan starts and visited rows, including measurement scans.

For the two-master/three-detail-row one-pass fixture, current execution records
four detail scans and nine visited rows: one and two rows in the look-ahead
scans, then two full three-row print scans. This provides a measured baseline
for a future caching/indexing decision without introducing caching now.

## Deferred work

- Define an explicit position-restoration fallback only with compatibility and
  memory limits approved.
- Instrument/benchmark large linked datasets before selecting a detail index.
- Add subreport parse caching only with invalidation semantics and a migration
  plan.
- Consider a unified cursor capability contract only when a second production
  source requires it; preserve direct `TDataSet` support.
