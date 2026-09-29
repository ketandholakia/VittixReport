# Phase 4 — Overall Checkpoint & Roadmap Reconciliation

Status: **read-only checkpoint, complete.** This document records the state of
the modernization effort at the close of Phase 4. It changes no production
code and is not a commitment to implement anything. HEAD remains `549e0c4`;
nothing is committed.

**Phase disposition**

```
Phase 4A       Characterization / compatibility contract   PASS / COMPLETE
Phase 4B-1     Compatibility evaluator                     PASS / COMPLETE
Phase 4B-2A    Modern semantics design                     PASS / COMPLETE
Phase 4B-2B    Modern evaluator implementation             PASS / COMPLETE
─────────────────────────────────────────────────────────────────────────
Phase 4 — Expression Architecture                          CLOSED
```

Detail per sub-phase: `docs/Phase4A-Expression-Compatibility-Contract.md`,
`docs/Phase4B-Compatibility-Evaluator.md`,
`docs/Phase4B2A-Modern-Expression-Semantics.md`,
`docs/Phase4B2B-Modern-Expression-Implementation.md`, and
`Phase4B-2B-ClosureAudit.md`.

---

## 1. Exactly measured baseline (this checkpoint)

```
Branch                 main
HEAD                   549e0c4  (no commits; modernization + audit untracked)
Working tree           tracked implementation work preserved, unmodified

DUnitX suite           620 found / 620 passed / 0 failed / 0 errored /
                       0 ignored / 0 leaked / 0 skipped
VittixRunner           41 passed / 0 failed / 1 skipped by design
                       (16_large_preview_warning.vrt)
Legacy corpus          42/42 reports/*.vrt byte-untouched
Legacy differential    PASS (~180-expression corpus, frozen reference, 0 divergence)

Legacy default         permanent; modern requires "ExpressionLanguageVersion": 1
Automatic migration    none, ever (serializer rejects unsupported versions)

Builds:
  DUnitX test project  ✅ clean
  VittixRunner         ✅ clean (0 errors)
  Runtime package      ❌ pre-existing QR stub search-path issue (BUILD-GAP-QR-001)
  Designer package     ❌ pre-existing QR stub search-path issue (BUILD-GAP-QR-001)
```

Note: an earlier closure-audit draft recorded "618 passed / 2 expected skips".
That was inaccurate — DUnitX has no `[Ignore]` tests and reports `0 skipped`;
the single by-design skip belongs to the headless runner. The figures above are
the measured truth, and `Phase4B-2B-ClosureAudit.md` has been corrected to
match. The phase passes on the stronger 620/620 result, so the disposition is
unchanged.

---

## 2. What Phase 4 delivered vs. the original roadmap

Two numbering schemes exist in the repository; the executed work follows the
**"Recommended roadmap with gates"** (`REPORTING_COMPONENT_ARCHITECTURE_ANALYSIS.md`,
"Recommended roadmap with gates") together with the **Phase4I-20** expression
design — not the document's §24 "Modernization Roadmap" list.

| Executed phase | Roadmap anchor | Delivered |
| --- | --- | --- |
| Phase 1 — Characterization & Safety | "0 - Baseline" + "1 - Correctness hardening" | 42-fixture load→save→reload contract; GAP-001/002/004/005/006 characterization; export-capture baseline; documented manual print procedure |
| Phase 2 — Data Capability & Traversal Diagnostics | "2 - Data boundary" | Data-operation capability contract; bookmark audit + `TNoBookmarkClientDataSet` policy; `TReportTraversalDiagnostics` |
| Phase 3 — Performance Foundations | "6 - Performance" (partial) | Aggregate result cache + subreport parsed-model cache; measured (scans 2→1, parses 2→1); modes-isolated later in 4B |
| Phase 4A/4B-1/4B-2A/4B-2B | Technical-evaluation "Quick Wins" (precedence, string functions, date functions) + Phase4I-20 design | Compatibility contract → compatibility evaluator → modern semantics design → modern evaluator, behind one boundary |

Phase 4 therefore **consumed the "expression engine enhancement" roadmap item**
in full (operator precedence, parentheses, Boolean logic, real NULL, function
catalogue, aggregate composition), plus the Phase 3 cache foundation it
depends on.

---

## 3. Original Phase 4 concerns now resolved

- **Expression correctness** — precedence (`1 + 2 * 3` → 7 modern), parentheses,
  `AND`/`OR`/`NOT`/`!=`, real NULL + Kleene logic, `UPPER/LOWER/TRIM/LEN/SUBSTR/
  ABS/ROUND/LEAST/GREATEST/IF/COALESCE`, aggregate composition
  (`SUM([Amount]) + 1` → 36.5). Proven through the real report pipeline, not
  only unit tests.
- **Non-regression of existing reports** — legacy is the permanent default;
  42/42 fixtures byte-untouched; differential corpus green against the frozen
  legacy reference.
- **Aggregate performance** — cached (Phase 3) and now mode-isolated
  (`#1'MODERN'#1` cache-key prefix).
- **Structured errors** — granular diagnostic codes; the evaluator propagates
  the real code (previously everything surfaced as `EvaluationError`).
- **Migration risk** — quantified (74/75 corpus expressions render identically;
  the two divergences already print blank/suppressed in legacy) and tooled
  (`TExpressionMigrationAnalyzer`, read-only, zero cache interaction).

---

## 4. Remaining GAPs and deferred items

### Expression domain (deferred by design)

- **OD-11** — aggregates over `TVittixUserDataSet` (modern: `UnsupportedDataSet`;
  legacy: silent literal text).
- **OD-12** — qualified aggregates (`SUM([Detail.Amount])`); depends on GAP-002.
- **OD-18** — date literals / date arithmetic / `YEAR`/`MONTH`/`DAY` /
  `DATEFORMAT`. *The only surviving expression-language feature request.*
- **Parse cache** — explicitly "NOT RECOMMENDED" for the phase
  (`docs/Phase4I-20-ExpressionEngineDesign.md` §11/§13); remains a future
  performance option.

### Engine / data / output (from Phases 1–3)

- **GAP-002** — non-bookmark sources have no position-restoration fallback
  (documented degraded behavior; source left at EOF).
- **GAP-004 (partial)** — subreport parse cache done; **linked detail traversal
  and indexing still rescan**.
- **GAP-005** — page memory: engine + renderer + preview each retain page
  assets; no eviction policy.
- **GAP-006** — output fidelity has command-capture baselines but **no visual
  diff** for preview / Vector PDF / HTML / XLSX.
- **Residual (expression-adjacent, deliberately not changed):**
  `ReportTitle` / `ReportDate` are visible to the evaluator but are not aggregate
  cache-key fields (Phase 4A "Phase 3 cache interaction"; 4B-1 §7). Adding them
  is conservative (can only cause more misses) and is tracked as a separate
  optional hardening item — **not** part of 4B.
- **Phase 1 inventory discrepancy** — brief referenced 45 `.vrt`; repository
  contains 42. Not formally reconciled.

### Infrastructure

- **BUILD-GAP-QR-001** — package search path resolves
  `Vittix.Report.Objects.Barcode.pas` to the QR stub (`stub_qr`), which lacks
  `IQrCode`/`TEcc`/`IQrSegment`. Blocks runtime + designer package builds;
  unrelated to expressions. Supplying `DCC_UnitSearchPath` with
  `source\ThirdParty\QRCodeGenLib\…` builds the package cleanly
  (`docs/Phase4B-Compatibility-Evaluator.md` §8).
- **BUILD-GAP-SCRIPT-001** — `build_runtime_dpk.ps1` places `param()` after a
  statement (invalid PowerShell). Not fixed, by instruction.
- **XLSX `Access is denied`** — 22 errors observed in Phases 2/3 did **not**
  reproduce in Phase 4B-1/4B-2B; environment-dependent, never formally closed.

---

## 5. Roadmap numbering divergence and Phase 5 scope

There is **no single canonical "Phase 5"** in the repository. Two candidates
exist, and Phase 4 changed the answer for both:

- **§24 "Phase 5: Polish"** — test-suite expansion, performance benchmarks,
  memory-leak detection, documentation/ADRs, CI/CD. **Still valid and largely
  unstarted** (test expansion is well advanced: 507 → 620; leak detection
  exists as DUnitX `Leaked: 0` + runner GDI/USER deltas; CI/CD and benchmarks
  are absent).
- **§24 architectural "Expression engine enhancement (IIF/IF/ELSE, date
  functions)"** — **superseded by Phase 4B**, except for OD-18 date
  functionality.
- **"Designer decoupling"** — a distinct architectural track, unrelated to
  expressions; to be kept separate.

### Recommended roadmap decision

```
Phase 4 — Expression Architecture          COMPLETE
        ↓
Phase 4 — Checkpoint                       COMPLETE (this document)
        ↓
Phase 5 — Quality, Benchmarking & CI Foundation
        ↓
Phase 6+ — remaining architectural tracks
          (Designer decoupling; data boundary / GAP-002; layout contract;
           output fidelity / GAP-006; page memory / GAP-005)
```

> Status note (added after Phase 4 closed): Phase 5 —
> Quality, Benchmarking & CI Foundation has since been **implemented**; see
> `docs/Phase5-Quality-Benchmark-CI.md`. The Phase 4 record above is unchanged.
>
> Expression roadmap closed: **OD-18 (`YEAR`/`MONTH`/`DAY`)** was the only
> expression item carried forward from 4B-2A §19 and is now implemented
> (modern mode only, additive, default-off). `DATE(...)` literals, date
> arithmetic and `DATEFORMAT` remain **deliberately Future** — the roadmap is
> complete without them, and they are not owed.
> See `docs/Phase4B2B-Modern-Expression-Implementation.md` §10.

- Define the next phase as **Phase 5 — Quality, Benchmarking & CI Foundation**.
- Mark the old expression-enhancement item **superseded by Phase 4B**, with
  **OD-18 (dates)** carried forward as the sole outstanding expression feature.
- Keep **Designer Decoupling** as a separate track, not part of Phase 5.

---

## 6. Pre-Phase-5 prerequisites and Phase 5 acceptance template

Recommended before any Phase 5 production-code change (none are expression work):

1. **Protect the work (state capture, no commit).** The Phase 4 output is
   untracked (`docs/Phase4*.md`, `Phase4B-2B-ClosureAudit.md`,
   `tests/Test.Vittix.Report.Phase4*.pas`, `tests/fixtures/modern/`,
   `source/Vittix.Report.Expression.*`). A snapshot/tag is the highest-value
   action before implementation begins.
2. **Roadmap wording updated** — Phase 5 renamed; expression item marked
   superseded (done in §5 above).
3. **Build gaps decided** — until `BUILD-GAP-QR-001` is cleared, the packages
   do not build and CI cannot run; `BUILD-GAP-SCRIPT-001` blocks the scripted
   package build.
4. **Optional cheap residual** — add `ReportTitle`/`ReportDate` to the
   aggregate cache key, only if deliberately chosen as pre-Phase-5 hardening.

Acceptance criteria cannot be finalized until the Phase 5 scope is confirmed.
Template to apply once it is:

- **If Quality / Benchmark / CI:**
  DUnitX stays ≥620 passing with 0 leaked; `BUILD-GAP-QR-001` and
  `BUILD-GAP-SCRIPT-001` are cleared so the runtime and designer packages build
  green; a benchmark harness produces reproducible rows/sec and aggregate-scan
  counts on the existing 100-row / 10 000-row fixtures; a CI job runs the
  DUnitX suite + `VittixRunner` and fails on any page-count regression.
- **If Designer decoupling:** the existing public designer APIs, DFM persistence
  and shortcuts are frozen by characterization tests first; selection, painting
  and undo behavior are unchanged as observed through those tests; the full
  suite stays green.
- **If deferred GAPs (002/005/006):** each gets its own characterization →
  design → implementation → differential gate; none may alter `.vrt`
  compatibility or legacy expression semantics.

---

## 7. Non-actions (explicit)

- No commits were made; HEAD is `549e0c4`.
- No QR / build-script fix was applied (`BUILD-GAP-QR-001`,
  `BUILD-GAP-SCRIPT-001` remain open).
- No aggregate cache-key change was made (`ReportTitle`/`ReportDate` residual
  remains tracked, not implemented).
- No production code was modified while producing this checkpoint.
