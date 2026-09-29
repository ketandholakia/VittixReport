# Phase 5 — Quality, Benchmarking & CI Foundation

Status: **implemented — PASS / COMPLETE.** Phase 5 adds a deterministic benchmark
harness, a single regression gate, and real CI wiring. It changes **no**
report-engine, expression, serialization, pagination, rendering, print or export
behavior.

Disposition: `BUILD-GAP-QR-001` and `BUILD-GAP-SCRIPT-001` are **CLOSED**. The
two remaining open items after Phase 5 are the Phase 6+ architectural GAPs
(GAP-002, GAP-004, GAP-005, GAP-006), the expression items (OD-11, OD-12,
OD-18), and the documented `ReportTitle`/`ReportDate` cache-key residual. The
XLSX `Access is denied` errors seen in Phases 2/3 remain **environment-dependent
and not reproduced** in Phases 4B/5 — they are documented, not a confirmed
defect.

Plan of record: `~/.commandcode/plans/phase5-quality-benchmark-ci.md`
(approved). Predecessor: `docs/Phase4-Checkpoint.md`.

---

## 1. Result at a glance

```
Baseline (start of Phase 5)
  DUnitX          620 found / 620 passed / 0 failed / 0 errored / 0 leaked / 0 skipped
  VittixRunner    41 passed / 0 failed / 1 skipped
  Builds          DUnitX OK  VittixRunner OK  designer OK  runtime pkg FAIL  design pkg FAIL

After Phase 5
  DUnitX          624 found / 624 passed / 0 failed / 0 errored / 0 leaked / 0 skipped
  VittixRunner    41 passed / 0 failed / 1 skipped   (--strict exit 0)
  Builds          DUnitX OK  VittixRunner OK  designer OK  runtime pkg OK  design pkg OK
  Gate            tools\ci_gate.ps1  ->  exit 0 (all gates passed)
  Legacy corpus   42/42 reports/*.vrt byte-untouched
```

The +4 tests are the new Phase 5 benchmark fixture. Nothing else changed
behaviorally.

---

## 2. Two genuine defects found and fixed

Phase 5 was scoped as infrastructure, but building the gate surfaced two real
defects that would have made the gates meaningless.

### 2.1 `BUILD-GAP-QR-001` — the two package project files were missing the QR search path

**Symptom:** `packages\VittixReportRuntime.dproj` and
`packages\VittixReportDesign.dproj` failed with
`Vittix.Report.Objects.Barcode.pas(134) E2003 Undeclared identifier: 'IQrCode'`
(also `TEcc`, `IQrSegment`, `MakeSegments`, `EncodeSegments`).

**Root cause (not a search-path accident):** `Vittix.Report.Objects.Barcode.pas`
needs the real QRCodeGenLib API, which is vendored in-tree at
`source\ThirdParty\QRCodeGenLib`. Three projects already declare it via
`DCC_UnitSearchPath` — `VittixRunner.dproj`, `tests\VittixReportTests.dproj` and
`vittixdesigner\VittixDesigner.dproj`. The **two package project files declared
no `DCC_UnitSearchPath` at all**, so they resolved the QR units from the ambient
global IDE library path, where the untracked, incomplete `stub_qr\` directory
(`unit QlpIQrCode; ... TQrCode = class end;` — no `IQrCode`) shadowed the real
library. On a clean machine the same omission yields
`F2613 Unit 'QlpIQrCode' not found`.

**Fix:** added the same `DCC_UnitSearchPath` the designer app already declares to
both package `.dproj` files (`..;..\source;..\source\ThirdParty\QRCodeGenLib\src\{QRCodeGen,Interfaces,Utils,Include};$(DCC_UnitSearchPath)`).
This is a project-file **consistency** fix, not a hack: `stub_qr` is not a
dependency boundary and was not adopted.

**Verification:** both packages now build with **0 errors** and produce
`VittixReportRuntime.bpl` / `VittixReportDesign.bpl`. The compiler output shows
the real units (`QlpIQrCode`, `QlpQrCode`, `QlpQrSegment`, …) being linked.

### 2.2 The `--strict` CI gate was silently non-functional (double-free)

**Symptom:** `VittixRunner --strict` printed `Strict result: FAIL` for a
deliberately wrong page count and then **exited 0**, with
`EAccessViolation ... Read of address 000204AC` on the last line.

**Root cause:** `Vittix.Runner.Console.pas` freed `StrictBaseline` once after
reconciliation *without* nilling the reference, and then freed it **again** in
the enclosing `finally` — a use-after-free. The access violation occurred on
**both** the pass and fail paths, after the verdict was printed. The DPR's
top-level `except` swallowed it, so the process fell through to a normal exit and
always returned **0**. A CI job wired to `--strict` would therefore have passed
unconditionally — worse than having no gate.

**Fix:** removed the premature free; the `finally` block is the sole owner (it
frees and nils). Comment added explaining why.

**Verification (manual, as the plan requires for the failure path):**

```
unperturbed baseline   -> exit 0, "Strict result: PASS", no AV
perturbed baseline     -> exit 1, "Strict result: FAIL", no AV
```

The perturbed baseline was a **copy** (`build\gate\perturbed-baseline.json`) so
the tracked `reports\regression_baselines.json` was never modified.

**Why this fix was in scope (explicitly preserved).** This is not scope creep.
The CI gate is only meaningful if a page-count regression actually fails the
build. Before the fix, `--strict` returned **0 unconditionally** — so wiring CI
to it would have produced a gate that *always* passes, which is strictly worse
than having no gate at all, because it manufactures false confidence. Repairing
the exit-status path was therefore a **prerequisite for the gate to have
semantic validity**, not an optional extra.

---

## 3. What Phase 5 delivered

### 3.1 Benchmark harness — `tests\Test.Vittix.Report.Phase5.Benchmark.pas`

Four deterministic tests extending the Phase 3 pattern to the sizes the plan
calls for. They assert **structural counters only**; timing is recorded, never
asserted.

| Test | Rows | Asserts |
| --- | ---: | --- |
| `Test_Benchmark_AggregateCache_100Rows` | 100 | 2 evaluations, 1 miss, 1 hit, 1 traversal, 100 rows, cursor preserved |
| `Test_Benchmark_AggregateCache_10000Rows` | 10 000 | same invariants at scale (1 traversal, 10 000 rows) |
| `Test_Benchmark_RenderPass_AggregateReuse_1000Rows` | 1 000 | a real `Prepare` shares one traversal between two summary aggregates |
| `Test_Benchmark_SubReportModelCache_100Rows` | 100 | 1 parse attempt / 1 miss regardless of master rows; scans still scale (GAP-004 partial, by design) |

Informational timings (append-only, gitignored `build\phase5-benchmark-timings.txt`):

```
aggregate 2x SUM, 100 rows                        0 ms
aggregate 2x SUM, 10000 rows                     13 ms
render pass, 1000 rows, 2 summary aggregates     20 ms
render pass, 100 rows, 1 subreport               11 ms
```

### 3.2 Regression gate — `tools\ci_gate.ps1`

One PowerShell 5.1-compatible command that runs every gate in order and fails
fast:

1. build the DUnitX test project
2. run it → require **exit 0** and **`Tests Leaked : 0`**, and parse the found /
   passed / failed / errored counts
3. build `VittixRunner`
4. run `VittixRunner --strict --keep-vector-pdf --output build\gate` → require
   **exit 0**, then assert **USER delta = 0** and a bounded **GDI delta**
   (default limit 16; observed 8). Memory is reported, not gated.
5. optional `-IncludePackages` → build runtime package, design package and the
   standalone designer (packaging smoke; exercises the §2.1 fix)

Switches: `-SkipRunner`, `-IncludePackages`, `-Config`, `-Platform`,
`-GdiDeltaLimit`. Exit codes: `0` pass, `1` gate failure, `2` environment error.
Logs are written under `build\gate\`.

**Known incremental-build hazard (recorded, not changed).** The gate builds with
`/t:Build`. Because MSBuild's incremental check uses timestamp granularity, an
edit made within the same second as a prior build can be missed and leave a
stale binary, producing failures that do not exist in the source. Observed during
GAP-005/P2 (a reverted mutation appeared to persist until `/t:Rebuild`). CI is
unaffected (fresh checkout). Switching the gate to `Rebuild` would significantly
increase CI duration and is therefore left as a deliberate future
CI-determinism decision; for now the hazard is documented here and in
`TESTING.md` §0.

### 3.3 CI — `.github/workflows/build-and-test.yml`

Rewritten from the non-functional stub (it previously used the .NET
`setup-msbuild` action, which cannot build Delphi, and never ran the corpus
runner). Now: `runs-on: [self-hosted, windows, delphi]` → invoke
`tools\ci_gate.ps1 -IncludePackages` → upload `tests\dunitx-results.xml`,
`build\gate\**` and the benchmark timings.

**The runner must be self-hosted with RAD Studio installed**; there is no
GitHub-hosted Delphi toolchain. The gate script locates `rsvars.bat`
(Studio 23.0, then 22.0) or uses `msbuild` from `PATH`.

### 3.4 Leak / resource thresholds (enforced, not just reported)

- DUnitX `Tests Leaked : 0` → gate failure otherwise.
- Runner `USER` handle delta must be `0`.
- Runner `GDI` handle delta bounded by `-GdiDeltaLimit` (default 16).
- Memory (`AllocMemSize`) informational only — process-global and coarse.

### 3.5 `BUILD-GAP-SCRIPT-001` — PowerShell `param()` placement

`build_runtime.ps1` and `build_runtime_dpk.ps1` both began with
`$ErrorActionPreference = 'Stop'` **before** `param(...)`, which is invalid
PowerShell (the `param` block must be first). Both now declare `param(...)` first.
Both scripts remain untracked; a future decision should either adopt them into
the repo or retire them in favour of `tools\ci_gate.ps1`.

---

## 4. Gate contract (what CI enforces)

| Gate | Command | Pass condition |
| --- | --- | --- |
| Unit/integration suite | `tests\Win32\<Config>\VittixReportTests.exe -xml:tests\dunitx-results.xml` | exit 0; `Tests Leaked : 0`; 0 failed; 0 errored |
| Pagination baseline | `VittixRunner --strict` | exit 0 (0 mismatches, 0 missing, 0 orphan, 0 execution errors) |
| Resources | same run | USER delta = 0; GDI delta ≤ limit |
| Packaging (optional) | `-IncludePackages` | runtime pkg, design pkg, designer build with 0 errors |

Run locally:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages
```

---

## 5. Inventory resolution (Phase 1 "45 vs 42")

The Phase 1 brief referenced 45 `.vrt` fixtures; the repository contains **42**.
The Phase 1 test locks the actual checked-in inventory and flags any change.
Resolution: **42 is the intended inventory**; the "45" figure was stale. The
checkout count is 42, the runner discovers 42 (`Reports discovered : 42`,
41 checked + 1 skipped by design), and `reports\regression_baselines.json`
holds 41 entries. No fixtures are missing.

---

## 6. Explicitly out of scope for Phase 5 (carried to Phase 6+)

- Any engine, pagination, layout, rendering, print or export behavior change.
- Expression work: OD-11 (`TVittixUserDataSet` aggregates), OD-12 (qualified
  aggregates), **OD-18 (date functions)**, parse cache.
- GAP-002 (non-bookmark fallback), GAP-004 (linked detail indexing),
  GAP-005 (page memory), GAP-006 visual-diff implementation.
- Designer decoupling (separate architectural track).
- The `ReportTitle`/`ReportDate` cache-key residual — remains a documented GAP,
  not touched.
- Introducing an ADR framework (the per-phase doc convention is kept).
- Committing the accumulated Phase 4/5 work (no commits were made).

---

## 7. Verification performed

1. DUnitX: **624 found / 624 passed / 0 failed / 0 errored / 0 leaked / 0 skipped.**
2. `VittixRunner --strict`: exit **0**; 41 passed / 0 failed / 1 skipped; page
   counts equal `reports\regression_baselines.json`.
3. Gate script: exit **0** end-to-end (including `-IncludePackages` path is
   available); failure path proven by baseline perturbation (exit 1).
4. Packages: runtime + design build with **0 errors** (QR root cause fixed).
5. `git status reports` clean; **42/42** fixtures byte-untouched.
6. `HEAD` still **549e0c4**; no commits made; all prior modernization preserved.
