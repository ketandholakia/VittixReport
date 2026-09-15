# Phase 6 — Widened Regression Coverage

Status: **implemented (test-only).** Phase 6 closes the most important
regression-coverage gaps that the Phase 6 audit revealed. It changes **no**
production code.

Plan of record: `~/.commandcode/plans/phase6-prioritization-and-plan.md`.
Predecessors: `docs/Phase5-Quality-Benchmark-CI.md`,
`docs/Phase4-Checkpoint.md`.

---

## 1. Result at a glance

```
Baseline entering Phase 6   DUnitX 624 / 624, 0 leaked; gate exit 0
After Phase 6               DUnitX 630 / 630, 0 leaked; gate exit 0
Production code changed     none
Legacy corpus               42/42 byte-untouched
HEAD                        549e0c4 — no commits
```

Six tests were added (4 detail-traversal characterization, 2 output coverage).

---

## 2. Why Phase 6 was re-targeted (the GAP-004 finding)

The approved plan selected **GAP-004 (linked-detail traversal indexing)** as
Phase 6, scored highest on the audit's weighted criteria. Implementing it
surfaced evidence that materially weakened that choice.

### 2.1 The detail path has two transports, and only one is corpus-exercised

`Vittix.Report.Engine.pas` reaches detail rows two ways:

- **User-dataset transport** — `ResolveBandUserDataSet` → `TVittixUserDataSet`,
  used when the band's `DataSetName` is registered as a named user dataset.
- **TDataSet transport** — `ResolveBandDataSet` → `TDataSet`.

`Vittix.Runner.Execution.pas:310` builds the engine for `39_detail_bands.vrt`
with `InvoiceNamedDataSets`, a `TDictionary<string, TVittixUserDataSet>`.
`ResolveBandUserDataSet` therefore finds `DetailData` and the detail band takes
the **user-dataset** path. `ResolveBandUserDataSet` is checked *before* the
`TDataSet` scan in both `ComputeFirstDetailRowsHeight` and
`PrintDetailBandRecords`, so the user-dataset transport always wins when the
name is registered.

### 2.2 The index is structurally impossible on the corpus transport

`TVittixUserDataSet` exposes only `First` / `Next` / `Eof` / `GetValue`
(`Vittix.Report.UserDataSet.pas`) — **no bookmarks**. An index makes matching
rows reachable *without rescanning*, which requires either bookmarks or random
access. Neither exists on the user-dataset transport.

### 2.3 Consequences

- The index would only accelerate the **`TDataSet` transport**, which **no
  checked-in report exercises**. The report the optimization targeted
  (`39_detail_bands.vrt`) uses the user-dataset transport and would not improve.
- The CI gate **could not validate** the change: the corpus does not reach that
  path, so a row-matching regression there would pass the gate silently.
- The "four divergent detail loops" identified in the audit are **inherent to
  the two transports**, not accidental drift: the `TDataSet` variant can probe
  field existence (`TryGetField`) and the user-dataset variant cannot. The audit
  overstated this as a latent defect.

**Decision (confirmed with the project owner): defer the index and re-target
Phase 6 to widen the safety net first.** The detail-index work is recorded as a
narrow, currently-unvalidatable optimization; it should be revisited only if a
production report binds a detail band to a named `TDataSet` (or the
user-dataset transport gains a revisitable cursor, which is GAP-002 territory).

### 2.4 GAP-004 characterization kept as evidence

`tests\Test.Vittix.Report.Phase6.DetailTraversal.pas` locks the current,
pre-optimization behavior so any future attempt has a baseline:

| Case | Traversals | Rows visited |
| --- | ---: | ---: |
| 10 masters × 10 details, no match | 20 | 200 |
| 1 master, match at last of 10 | 2 | 20 |
| 1 master, match at first of 10 | 2 | 11 |
| **200 masters × 50 details, no match** | **400** | **20 000** |

Two scans run per master row (a height look-ahead plus the print scan), and the
print scan always visits every detail row.

---

## 3. What Phase 6 delivered

`tests\Test.Vittix.Report.Phase6.OutputCoverage.pas` (test-only):

1. **User-dataset detail transport** — the transport the checked-in corpus
   actually uses. Builds a 3-master / 6-detail linked report through
   `TVittixUserDataSet` + a named-user-dataset map and asserts the structural
   contract (2 detail scans per master, rows visited, ≥1 rendered page). This
   path previously had no direct DUnitX coverage.

2. **Renderer page shape in dimensions** — for a multi-page report, asserts
   `Renderer.Pages.Count = Engine.PageCount`, that each page bitmap's width and
   height equal the page size, and that each metafile carries non-zero
   dimensions. Phase 1 asserted object *presence*; this adds the *shape*.

Both use deterministic structural assertions, deliberately **not** pixel
comparison, so the gate stays flake-free.

### 3.1 Documented coverage limitation (preview)

`TVittixReportPreview` is a windowed `TCustomControl`. Instantiating it in a
console DUnitX run fails with `Control '...' has no parent window`, so preview
page-ownership independence cannot be asserted without a VCL Forms harness.
This was attempted, confirmed, and removed rather than faked.

**The preview path therefore remains outside the automated gate** and must be
covered by the manual checklist in `TESTING.md` (§9 memory/GDI stress, §3.1
vector PDF checks). Closing it requires an explicit windowed test harness — a
deliberate future decision, not a drive-by change.

### 3.2 Also still outside the gate (unchanged from Phase 5)

- The physical print path (printer-driver dependent).
- Visual/pixel output fidelity (GAP-006 proper — no comparator exists).
- The `--strict` failure exit path is proven **manually** (Phase 5 perturbation
  test); an automated process-spawning test was not added, because it would
  depend on the runner executable being present next to the test run.

---

## 4. Revised ranking after Phase 6

The GAP-004 finding changes the ordering. Benefit is now weighted toward work
that affects **both** transports and **all** reports, and away from work that
only touches a path the corpus cannot validate.

| Rank | Candidate | Note |
| ---: | --- | --- |
| 1 | **GAP-005 page memory / print fidelity** | Affects every report: ~5 page-sized objects per page (engine metafile + renderer metafile + renderer bitmap + preview metafile + preview bitmap), and `TReportRenderer.Print` rasterizes via `StretchDraw` while the preview print path prefers the metafile. |
| 2 | **GAP-006 visual/pixel guard** | Enables GAP-005 to be attempted safely; needs a tolerance-based comparator and a curated fixture set to avoid flakiness. |
| 3 | GAP-002 bookmark capability contract | Unblocks a revisitable detail cursor (which would in turn make the GAP-004 index viable) and OD-11/OD-12. |
| 4 | GAP-004 index | Deferred; narrow benefit until #3 lands. |
| 5+ | OD-18, cache residual, OD-11 | Unchanged. |

**Sequencing recommendation:** GAP-006 (guard) **then** GAP-005 (page memory +
metafile print), because GAP-005 changes internals that Phase 1 characterizes
and changes printed pixels, and the guard is what makes that safe.

---

## 5. Out of scope for Phase 6 (unchanged)

- Any production behavior change.
- The detail index (deferred, §2).
- GAP-005 / GAP-006 implementation (now the Phase 7 candidates).
- GAP-002, OD-11, OD-12, OD-18, the `ReportTitle`/`ReportDate` cache residual.
- Committing the accumulated work.

---

## 6. Verification

1. DUnitX: **630 found / 630 passed / 0 failed / 0 errored / 0 leaked.**
2. `tools\ci_gate.ps1`: exit **0** (DUnitX + `VittixRunner --strict` + resource
   thresholds).
3. `VittixRunner --strict`: exit 0; 41 passed / 0 failed / 1 skipped.
4. `git status reports` clean; **42/42** `.vrt` byte-untouched.
5. **No production file changed** in Phase 6 — the diff is test units and
   documentation only.
6. `HEAD` remains **549e0c4**; no commits.
