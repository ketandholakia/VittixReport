# Modernization — Residual Audit and Roadmap Closure

Status: **audit complete; one narrow fix authorised (C).** Read-only apart from
that fix (recorded in §4). Tree: branch `main`, HEAD `549e0c4`, no commits.

Predecessors: `docs/Phase4-Checkpoint.md`, `docs/Phase5-Quality-Benchmark-CI.md`,
`docs/Phase6-Output-Coverage.md`, `docs/GAP-005-Page-Ownership-Audit.md`,
`docs/GAP-005-P3-Print-Audit.md`, `docs/GAP-005-Residual-Review.md`.

Purpose: apply the seven-point format to every remaining modernization concern
and give each an explicit **GO / DEFER / NOT-A-LIVE-DEFECT** verdict, so the
roadmap closes with reasons recorded rather than loose ends.

---

## 1. Candidate A — Layout / measurement contract

1. **Inventory.** `TReportEngine.ComputeEffectiveBandHeight` measures bands by
   *drawing*: `Child.MeasuredBottom(FCanvas, Ctx)` (Engine.pas 706), with an
   early exit when `FCanvas` is nil (678). Placement uses raw GDI viewport
   juggling (`SaveDC` / `SetViewportOrgEx` / `GetViewportOrgEx`, 611, 1223–1227,
   1919–1924, 1954).
2. **Defect / evidence.** Band height — and therefore pagination — is computed at
   fixed logical 96-DPI inside a metafile canvas. Measurement and drawing are the
   same operation, so layout is device-coupled.
3. **Impact.** Architectural, not currently user-visible. Two-pass rendering
   exists *because* measure == draw.
4. **Coverage.** Page counts for all 42 fixtures (`VittixRunner --strict`) and the
   Phase 1 pagination characterization. **No** device-independent layout
   equivalence coverage.
5. **Risk of intervention.** **High** — the architecture analysis itself rates
   pagination a compatibility surface.
6. **Smallest safe candidate.** Introduce an internal measured-page result
   *alongside* the current path — still a multi-phase effort.
7. **Verdict: DEFER.** Real debt; too large for one phase, and not verifiable
   beyond page counts with the present gate.

## 2. Candidate B — Data boundary / `IReportDataSource`

1. **Inventory.** `IReportDataSource` plus four implementations
   (`Vittix.Report.DataSources.pas`). `TDataSetReportDataSource` is complete;
   `TJsonReportDataSource`, `TCsvReportDataSource`, `TRestReportDataSource` are
   scaffolds whose every method raises (`NotImplemented`, DataSources.pas 85–88;
   21 raise sites).
2. **Defect / evidence.** A repository-wide search for `IReportDataSource`
   matches **only inside its own unit** — no engine, component, designer or test
   consumer. The engine takes `TDataSet` / `TVittixUserDataSet` directly.
3. **Impact.** None at runtime. It implies provider portability that does not
   exist, and ships as public API in the runtime package.
4. **Coverage.** None (nothing reachable to test).
5. **Risk of intervention.** Removing a public type is an **API break** — a
   deliberate decision, not free cleanup.
6. **Smallest safe candidate.** Mark it explicitly unsupported in the unit header
   and documentation, or remove it under an approved API removal.
7. **Verdict: NOT-A-LIVE-DEFECT.** Hygiene / API decision.

## 3. Candidate C — Legacy `ExportToPDF` printer dependency

1. **Inventory.** `TReportPDFExporter.ExportPages` requires the literal
   `'Microsoft Print to PDF'` device or raises (Export.PDF.pas 131–137), and on a
   page-size mismatch calls **modal `ShowMessage`** (112).
2. **Defect / evidence.** The project's own technical evaluation rates
   *"PDF export fails on systems without the Microsoft Print to PDF driver"*
   **High likelihood / High impact**; mitigation recorded as "use the Vector PDF
   exporter as default".
3. **Impact.** A missing driver is a hard failure; the modal **blocks or hangs
   non-interactive/server-side export**, which the project explicitly supports
   elsewhere (the vector exporter has stream output for silent use).
4. **Coverage.** None — printer-dependent, manual only.
5. **Risk of intervention.** Low for the modal. **The documented mitigation is
   blocked**: the vector exporter is labelled **Beta** with known gaps
   ("Full Unicode/font embedding is still pending"), so promoting it to default
   now would trade a printer dependency for a fidelity gap.
6. **Smallest safe candidate.** **De-modal only** — replace the interactive
   dialog with a programmatic diagnostic on the existing debug channel, and
   extract the mismatch decision as a pure, testable predicate. Nothing else
   changes.
7. **Verdict: GO (narrow, de-modal only).** The broader "vector by default" is
   **DEFER (blocked on vector Beta)**.

## 4. Candidate C — implementation (the only production change)

Scope honoured: **no redesign of PDF export, no change of default exporter, no
page-size policy change, no Vector PDF change.**

| File | Change |
| --- | --- |
| `source/Vittix.Report.PrintMapping.pas` | added the pure predicate `IsPrintSizeMismatch(...)` |
| `source/Vittix.Report.Export.PDF.pas` | uses that predicate; the modal `ShowMessage` is replaced by an `OutputDebugString` diagnostic on the existing debug channel; the **`Vcl.Dialogs` dependency is removed entirely** |
| `tests/Test.Gap005.PrintPath.pas` | deterministic tests for the predicate (tolerance boundaries, degenerate input) |
| `TESTING.md` | notes that the mismatch diagnostic is non-interactive |

Trade-off recorded honestly: interactive users no longer see a popup for a
page-size mismatch. The mismatch is still detected and now reported
programmatically; the report geometry is unchanged (full stretch remains the
default). Losing the UI dependency is itself a gain for a server-side exporter.

Verification: see §6.

## 5. Candidates D–E — already assessed

- **P5 (page memory / eviction / streaming)** → **DEFER.** The residual review
  measured the remaining duplication as preview-only, with no observed problem.
- **GAP-002 (bookmark repositioning contract)** → **DEFER.** Not a live defect;
  needs a deliberately chosen contract and can only be verified synthetically.
- **GAP-006 (pixel/visual harness)** → **NOT-A-LIVE-DEFECT now.** Prospective
  machinery; would add flakiness to a currently flake-free gate.

## 6. Verification of this audit and of C

Measured after the de-modalisation:

```
DUnitX        652 / 652 PASS   (651 before this change; +1 predicate test)
Failed        0
Errors        0
Leaked        0

Runner        41 PASS / 1 intentional SKIP / 0 FAIL
              strict mismatches 0; GDI +8, USER 0 (identical to before)

CI gate       exit 0

Packages      runtime      0 errors
              design       0 errors
              designer app 0 errors

Corpus        42 / 42 render; .vrt byte changes 0
HEAD          549e0c4        commits 0
```

Diff re-audit: production changes are confined to
`Vittix.Report.PrintMapping.pas` (new pure predicate) and
`Vittix.Report.Export.PDF.pas` (uses it; modal removed; `Vcl.Dialogs`
dependency dropped — net −43 lines in that unit). No engine, renderer, preview,
serializer, expression or `.vrt` change. `ShowMessage` no longer appears as a
call anywhere in the exporter (only in the comment recording its removal).

Honest limitation: the **absence of the modal** cannot be asserted
automatically (the printer path cannot run headlessly). The *decision* is
gate-covered by `Test_Mapping_SizeMismatchPredicate`; the non-interactive
behaviour is verified by inspection and must be re-checked by review if this
path is ever touched again.

## 7. Roadmap closure — the natural stopping point

```
VittixReport Modernization

Completed
  Phase 0–6 foundations
  Phase 4A   expression characterization
  Phase 4B-1 compatibility evaluator
  Phase 4B-2A modern semantics design
  Phase 4B-2B modern evaluator (parser/AST, NULL, Boolean, functions,
             aggregates, diagnostics, per-report language version,
             cache isolation, migration analyzer)
  OD-18      YEAR / MONTH / DAY
  GAP-005    Step 0 output guards
  GAP-005    P2 lazy rasterisation
  GAP-005    P3 print-path unification
  PDF export de-modalisation

Deliberately deferred
  Device-independent layout architecture            (Candidate A)
  P1 duplicate page ownership                       (reassessed; not worth the risk)
  P5 preview eviction / streaming
  GAP-002 bookmark repositioning contract
  Vector PDF as the default exporter                (blocked on Vector Beta)
  DATE(...) literals, date arithmetic, DATEFORMAT   (Future by design)

Not live defects
  IReportDataSource scaffolding                     (Candidate B)
  GAP-006 pixel harness
```

**This is the project's natural stopping point.** Every remaining item requires
one of the following before it should be started:

1. a **new product requirement** (the Future date features, template import),
2. an **observed production problem** (preview memory, non-bookmark providers),
   or
3. a **separately funded architectural initiative** (the layout contract).

None of the deferred items is an unfinished obligation, and none should be
resumed merely because it appears on a list. In particular, "Phase 4B-2A fully
implemented" does **not** mean all conceivable date functionality exists — the
three date features remain deliberately Future.

---

## 8. Post-closure maintenance — `BUILD-GAP-QR-001`, second instance (demo)

An **observed build failure** (the class of trigger §7 permits) surfaced after
closure: compiling `demo\VittixReportDemo.dproj` failed with
`Vittix.Report.Objects.Barcode.pas(134): E2003 Undeclared identifier: 'IQrCode'`
(also `TEcc`, `IQrSegment`, `MakeSegments`, `EncodeSegments`) and the cascading
`Vittix.Report.Serializer.pas(156): F2063`.

**Cause — the same defect class as the Phase 5 fix, in a sixth project file.**
Phase 5 corrected `packages\VittixReportRuntime.dproj` and
`packages\VittixReportDesign.dproj`, which declared **no** `DCC_UnitSearchPath`
at all. A systematic sweep of all six `.dproj` files after this report shows the
demo was a variant of the same problem: it *did* declare a search path, but one
without the vendored QR library —

```
demo\VittixReportDemo.dproj   .\;..\source;$(DCC_UnitSearchPath)          <- missing QR paths
the other five                ..;..\source;..\source\ThirdParty\QRCodeGenLib\src\{QRCodeGen,Interfaces,Utils,Include};...
```

So the demo fell back to the ambient library path, where the untracked
`stub_qr\` shadowed the real units.

**Fix.** Added the same vendor search path the other five projects declare, on
the same line (`demo\VittixReportDemo.dproj`). No code, package, test or `.vrt`
change.

**Verification.** `msbuild demo\VittixReportDemo.dproj /t:Rebuild` →
**Build succeeded, 0 errors**.

**Class closed.** All six project files now declare the vendor path
(`VittixRunner`, `tests`, `vittixdesigner`, both packages, `demo`), so this
recurrence is closed as a class rather than another instance.

This was a maintenance fix from the frozen baseline, not a resumption of the
modernization programme.
