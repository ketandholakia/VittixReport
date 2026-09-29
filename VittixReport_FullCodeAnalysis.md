# VittixReport — Comprehensive Code Analysis Report

> **Document status — SOURCE OF TRUTH for development planning (2026-09-29).**
> This report is the canonical development plan: §5 (Issues by Severity) is the
> working bug queue for `[fix]` work, §12 (Refactoring Plan) is the backlog of
> parked/deferred work, and §14 lists open questions. The wave-by-wave execution
> schedule derived from it — item IDs, test plans, and completion tracking —
> lives in **[`DEVELOPMENT_PLAN.md`](https://github.com/ketandholakia/VittixReport/blob/main/DEVELOPMENT_PLAN.md)** (repository root). All superseded planning
> documents (backlogs, bug queues, per-feature development plans, phase
> documents, audits, code reviews) are archived under `docs/archive/` —
> historical record only. Where this report cites those documents by their
> pre-archive root paths (e.g. `BACKLOG_v1.1.md`), read them as
> `docs/archive/<name>`.

**Date:** 2026-09-29
**Scope:** Full repository (runtime engine, serializer, exporters, component wrapper, packages, designer, tests, CI, docs, dependencies)
**Method:** Static line-by-line review of core units + four deep sub-audits (designer/undo/preview, expression stack, object classes/renderers, packaging/CI/tests) + dynamic verification
**Delphi target:** 12.2+ (Studio 23.0), VCL, Win32/Win64

**Verification status:** Static analysis **and** dynamic verification. The repo's own CI gate (`tools/ci_gate.ps1 -IncludePackages`) was executed on the analysis machine: DUnitX suite **693/693 passed, 0 leaked**; `VittixRunner --strict` **41/41 report baselines matched, USER handle delta 0, GDI delta 8** (limit 16). The package build reached the linker but failed with `F2039: Could not create output file 'C:\Users\Public\Documents\Embarcadero\Studio\23.0\Bpl\VittixReportRuntime.bpl'` — an output-path/environment failure, not a compile error; the GitHub workflow is green on recent commits, so CI's self-hosted runner succeeds there.

---

## Top 10 Riskiest Files

| # | File | Why it's risky |
|---|------|----------------|
| 1 | `vittixdesigner/Frm.Main.Commands.pas:209-222` (+ twin `Vittix.Designer.Commands.pas:190-203`) | `TReportSnapshotCommand` replaces the whole model on undo, **invalidating raw object pointers held by every older undo command** → use-after-free on "Band Manager → OK → undo twice". The single worst correctness defect. |
| 2 | `source/Vittix.Report.Engine.pas` | 2,467-line god unit: layout, pagination, group logic, **plus a ~730-line `CaptureExportObjectCommand` (1637–2370) that re-implements rendering** (its own Code39 table, barcode and image geometry). Group-break Variant compare at :857 is Null-asymmetric; bookmark lifetime hangs off an externally-owned dataset (:481–487). |
| 3 | `vittixdesigner/Frm.Main.pas` | 7,554 lines / 224 methods; a **2,608-line method** (`RunRuntimeEventCallbackDemo`, 2061–4669); silent blank-report fallback (:1215) feeding **unconditional output overwrite** (:1340–1356) = IDE-integration data loss; half-finished helper extraction leaves duplicated and non-compilable units. |
| 4 | `source/Vittix.Report.Export.VectorPDF.pas` | 1,916 lines, ~1,760 of them one method with ~30 nested routines. Correct but fragile: Latin text always drawn in **non-embedded Helvetica** while measured with the report font (:349–355); RTL rejected (:571–572) → rasterized; per-glyph `BT/ET` blocks + uncompressed content streams; all measurement on a screen-DPI bitmap (:1690). |
| 5 | `source/Vittix.Report.Objects.pas` | `AddLineSegment` (:1418–1447) never stores Color/FontName/Size → **all memo text renders black** with mis-advancing runs (:1646–1658); `Font` property is a direct reference write (:150) — external assign leaks/double-frees; missing `DT_NOPREFIX`; text-resolution logic triplicated. |
| 6 | `source/Vittix.Report.Expression.Evaluator.pas` | Aggregate cache key is the **whole expression text** (:1156), so `SUM(..)+COUNT(..)` in modern mode returns the first aggregate's cached value for both — silently wrong numbers through the engine. |
| 7 | `source/Vittix.Report.Expressions.Compat.pas` | The frozen legacy evaluator: `[Dataset.Field]` qualifier silently discarded (:206–224) → reads from the **wrong dataset**; all errors degrade to text `'0'`; locale-dependent numerics. Frozen by contract, but it is the default mode for every existing report. |
| 8 | `source/Vittix.Report.Objects.CrossTab.pas` | Unguarded `FieldByName` ×3 inside the record loop (:235–237) **raises** on a typo'd field and kills the render; unguarded Variant arithmetic (:164–201); `FMatrixPrepared` latch never reset (:213) → stale tables across re-renders. |
| 9 | `source/Vittix.Report.Serializer.pas` | Sound transactional design, but: `Version` is read and never used for migration; unknown *properties* silently dropped (only unknown *classes* preserved); `GSerializers` lazily-created global dictionary (:319–351) — a lazy-init race if ever used off the main thread. |
| 10 | `packages/VittixReportRuntime.dpk` / `.dproj` | No `{$RUNONLY}`; component registration lives in runtime units; dproj is missing `VectorPDF.Subset`; **19 units implicitly imported** (confirmed by live `W1033` warnings for all `Qlp*`, `LoadResult`, `Objects.Unknown`) — the classic duplicate-symbol trap for consumers. |

---

## 1. Executive Summary

VittixReport is in **substantially better health than its age and size suggest**. The runtime engine core (model → engine → metafile pages → renderer → semantic export document → vector PDF) is cleanly layered, ownership is almost universally correct, and the project has an unusually strong safety net: 693 green DUnitX tests with an in-suite leak detector, 41 pinned pagination baselines executed by a console runner, and a CI gate that enforces USER/GDI handle deltas. That is more rigor than many commercial Delphi reporting libraries ship with.

The biggest risks cluster in four places:

1. **Designer undo/redo can corrupt memory** (snapshot commands vs. pointer-holding commands) — crash-class, user-triggerable in two clicks.
2. **Silently wrong output** rather than crashes: the modern-mode aggregate cache-key collision, legacy qualified-field discard, memo color/font loss, chart/crosstab stale caches, and the DPI-blind 96-dpi pixel model. These violate priority #3 (rendering correctness) without failing any test.
3. **A 96-DPI assumption baked into the entire geometry model** (`PageSettings.pas:10` states it) while fonts are point-sized on screen-referenced canvases — every wrap/CanGrow/PDF measurement is only exact at 96 DPI.
4. **Monoliths under active feature pressure**: `Frm.Main.pas` (7.5k lines), `Engine.CaptureExportObjectCommand` (730 lines), `VectorPDF.ExportDocument` (1,760 lines) each duplicate rendering knowledge that already exists elsewhere — the primary future-bug factory, and directly relevant to preview-vs-export consistency (priority #9).

The v1.0 feature freeze (AGENTS.md) is the right context for acting on this report: nearly everything below classifies as `[fix]` with a failing test, or `[chore]`/packaging hygiene; nothing requires new features.

---

## 2. Architecture Overview

```
                          ┌──────────────────────────────────────────────┐
                          │                Applications                  │
                          │  demo/VittixReportDemo  vittixdesigner EXE   │
                          │  VittixRunner.exe (console regression gate)  │
                          └───────────────┬──────────────────────────────┘
                                          │ uses
┌─────────────────────────────────────────▼─────────────────────────────────────┐
│ Component layer                                                              │
│  TVittixReport (Component.pas)  ── CreateEngine() ──► owns nothing, wires all │
│  TVittixUserDataSet (UserDataSet.pas)   Designer surface: DesignerControl,    │
│  TVittixReportPreview (Preview.pas)     Toolbox, PropertyBridge, Undo,        │
│                                         DesignerInteraction(Controller)       │
└─────────────────────────────────────────┬─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────▼─────────────────────────────────────┐
│ Model layer (dependency floor, no engine refs)                                │
│  TReportModel (Model.pas) ─► TReportObject tree (Objects.pas, Bands.pas)      │
│  TReportPageSettings (PageSettings.pas, 96-dpi pixel model)                    │
└─────────────────────────────────────────┬─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────▼─────────────────────────────────────┐
│ Persistence: TReportSerializer (Serializer.pas) — .vrt JSON v1/v2,            │
│ transactional TReportLoadResult, unknown-class preservation, class registry    │
└─────────────────────────────────────────┬─────────────────────────────────────┘
                                          │
┌─────────────────────────────────────────▼─────────────────────────────────────┐
│ Execution: TReportEngine (Engine.pas)                                          │
│  band cache → two-pass Prepare (count, render) → TMetafile pages              │
│  group logic (bookmarks), detail/subreport traversal, CanGrow/CanShrink,       │
│  aggregate cache, script host (ScriptHost.Adapter: closed property language), │
│  expressions: legacy compat pipeline / modern tokenizer→parser→AST evaluator   │
│  side-channel: captures semantic TReportExportDocument commands per object     │
└───────────────┬──────────────────────────────────────────────┬───────────────┘
                │                                              │
┌───────────────▼───────────────────────┐   ┌──────────────────▼─────────────────┐
│ Presentation                          │   │ Exporters (IReportExporter /       │
│  TReportRenderer (Renderer.pas)       │   │  command consumers)                │
│   metafile primary, lazy bitmap       │   │  VectorPDF (+Subset/SVG/EMF),      │
│  Print via PrintMapping (full stretch)│   │  HTML, XLSX, Text, PDF(printer),   │
│  Preview forms copy pages             │   │  Email (SMTP attach)               │
└───────────────────────────────────────┘   └────────────────────────────────────┘
```

The **semantic export command model** (`Export.Commands.pas`: text/line/rect/fill/ellipse/image commands per page) is the architectural keystone introduced during modernization: the engine captures commands during the render pass, and every exporter consumes the *same* command stream, which is what makes Vector PDF, HTML, and XLSX structurally consistent with the preview instead of screen-scraping it. The design is good; the capture implementation (in the engine) is where the duplication debt sits.

---

## 3. File/Unit Inventory (key units)

| Unit | Lines | Classes / role |
|---|---|---|
| `source/Vittix.Report.Engine.pas` | 2,467 | `TReportEngine`, aggregate cache, subreport cache, export capture |
| `source/Vittix.Report.Objects.pas` | 2,037 | `TReportObject` base + Text/Label/Field/Memo/Shape/Image/SubReport/Line |
| `source/Vittix.Report.Export.VectorPDF.pas` | 1,916 | `TReportVectorPDFExporter` — Uniscribe shaping, TTF subsetting, cp1252 |
| `source/Vittix.Report.Expression.Evaluator.pas` | 1,682 | modern recursive-descent parser + tree-walk evaluator |
| `source/Vittix.Report.Serializer.pas` | 1,582 | `.vrt` JSON v2, transactional load, per-class serializer registry |
| `source/Vittix.Report.ScriptHost.Adapter.pas` | 1,305 | `Prop := Value` property mini-language (~36 whitelisted commands) |
| `source/Vittix.Report.Component.pas` | 981 | `TVittixReport` non-visual component (Execute/Print/exports) |
| `source/Vittix.Report.Objects.Barcode.pas` | 963 | Code39/Code128/EAN13/QR + legacy decorative mode |
| `source/Vittix.Report.DesignerControl.pas` | 2,746 | designer surface control (runtime pkg) |
| `source/Vittix.Report.Expressions.Compat.pas` | 647 | frozen legacy 9-stage evaluator (differential-tested) |
| `source/Vittix.Report.Undo.pas` | 596 | command-pattern undo manager |
| `source/Vittix.Report.Renderer.pas` | 261 | metafile-primary renderer, lazy raster (GAP-005/P2) |
| `source/Vittix.Report.Export.Commands.pas` | 241 | semantic command document + temp-file registry |
| `vittixdesigner/Frm.Main.pas` | 7,554 | designer main form (+34 `Frm.Main.*` satellites) |
| `tests/` (43 units) | ~16,000 | DUnitX, 693 `[Test]`s |
| root `Vittix.Runner.*.pas` (14 units) | ~4,000 | console regression runner (strict baselines, resource deltas) |
| `source/ThirdParty/QRCodeGenLib` | 19 files | MIT-licensed QR generation (vendored) |
| `packages/` | 4 files | `VittixReportRuntime.dpk` (58 units), `VittixReportDesign.dpk` ({$DESIGNONLY}, 2 units) |

Total: ~29k lines of library source, ~75k including designer and tooling.

---

## 4. Strengths

- **Layering is real, not nominal.** `Model.pas` provably references nothing above it (stated and honored); deprecated alias shims (`Engine.Engine`, `Engine.Renderer`, 13 lines each) preserve old unit names instead of breaking consumers — textbook backward compatibility.
- **Ownership discipline.** Nearly every `Create` in the engine/renderer/exporters is inside `try..finally`; `TObjectList` ownership is explicit and commented (`Renderer.pas:200-212` even uses the `Page := nil` anti-double-free idiom); `TReportExportDocument` deletes captured temp PNGs on free (`Export.Commands.pas:213-226`).
- **Transactional, diagnostic-rich loading.** `LoadFromJSONEx` never corrupts the active model, returns structured error codes with JSON paths (`Serializer.pas:1355-1481`), preserves unknown classes as raw-JSON `TReportUnknownObject` for round-trip forward compatibility, and explicitly maps structural type mismatches to precise diagnostics instead of cast exceptions.
- **Expression engine hardening.** Modern parser is depth-limited (`Evaluator.pas:275-280, 1471-1476`), the tokenizer is iterative with hard caps (≤4,096 chars, ≤1,024 tokens), and the frozen legacy evaluator is kept as a **differential oracle** (`tests/Test.Vittix.Report.ExpressionLegacyReference.pas`) — a genuinely professional compatibility technique.
- **Script host is a closed namespace**, not an interpreter: ~36 whitelisted property setters, no file/OS/shell surface (`ScriptHost.Adapter.pas:214-292`). A hostile `.vrt` can hide or restyle objects but cannot execute code.
- **Two-pass rendering with cache isolation**: counting-pass vs render-pass aggregates are separated by `IsCountingPass` in the cache identity (`Engine.pas:362`); legacy vs modern by key prefix.
- **The CI gate is exemplary for a solo Delphi project**: leak-checked test run, strict pagination baselines, USER/GDI handle-delta thresholds, package smoke build, honest self-hosted-runner disclosure.
- **Renderer memory model** (GAP-005): metafile-primary with lazy rasterization means vector consumers never pay for page bitmaps.
- **Vector PDF correctness details done right**: explicit cp1252 byte mapping independent of system code page (`VectorPDF.pas:221-258`, recently fixed), embeddability check via `otmfsType` (:442-443), glyph subsetting with whole-font fallback, proper `/Length` accounting and binary-safe streams, 4-Bezier ellipse approximation.

---

## 5. Issues by Severity

### Critical

**C-1. Designer undo/redo use-after-free via snapshot commands**
- **Where:** `vittixdesigner/Frm.Main.Commands.pas:209-222`; `source/Vittix.Report.Undo.pas:96-155, 356-358`; triggered via Band Manager OK (`Frm.Main.pas:5099/5413`).
- **What:** `TReportSnapshotCommand.ApplyJSON` loads a brand-new `TReportModel` and `LoadReport(Model, True, False)` frees the old one. Older undo entries (`TMoveObjectCommand`, `TMultiMoveCommand`, insert/delete commands) hold **raw `TReportObject` pointers and list references into the freed model**; `TMoveObjectCommand.Rollback` writes `FObj.Bounds` with no `Assigned` guard (`Undo.pas:357-358`, verified first-hand).
- **Impact:** heap corruption / AV on a two-click sequence (Band Manager → OK → Undo ×2); intermittent, data-loss-class.
- **Fix (minimal, freeze-compatible):** when a snapshot command executes, clear the rest of the undo stack (`FUndo.Clear` before `FUndo.Add(C)`, or a `TCommandManager.InvalidateObjectRefs` that drops pointer-holding commands) and record a failing designer test first. Long-term: make every command hold model-relative identity (band index + object name/path) instead of pointers.

### High

**H-1. Modern-mode aggregate cache-key collision returns wrong values**
- **Where:** `source/Vittix.Report.Expression.Evaluator.pas:1156` (`CacheKey := CModernCacheKeyPrefix + FExpressionText;`) and :1256 (store). Verified first-hand.
- **Impact:** `SUM([Amount]) + COUNT([ID])` — the COUNT lookup hits the entry SUM stored under the *same whole-expression key* with an identical context and returns **SUM's value**. Silently wrong report numbers in modern-mode reports through the engine (the only path with `Hooks`). Existing tests miss it because the unit test builds a context with `Hooks = nil` and the end-to-end test uses a single aggregate.
- **Fix:** include the aggregate function and inner-node text (or node position) in the key: `CacheKey := Prefix + FuncName + '(' + InnerText + ')' + '@' + IntToStr(ANode.Position);` plus a failing engine-level test with two aggregates in one expression.

**H-2. Legacy `[Dataset.Field]` qualifier silently discarded**
- **Where:** `source/Vittix.Report.Expressions.Compat.pas:206-224` (`FieldNameFromToken` strips everything before the dot, "the current dataset is still the one being read").
- **Impact:** `[Orders.Company]` reads the *current* dataset's `Company` — wrong-dataset values in every legacy report that uses qualified tokens; missing field then degrades to `'0'` text. This is the default expression mode.
- **Fix:** at minimum, resolve the qualifier against `Context.Hooks.GetNamedDataSet` and emit a diagnostic when it names a *different* dataset than the active one; keep the fallback behavior behind that warning (legacy contract).

**H-3. Memo segments lose Color / FontName / Size — all memo text renders black**
- **Where:** `source/Vittix.Report.Objects.pas:1439-1443` — new-segment branch of `AddLineSegment` assigns only `Text/Style/Width`; zero-initialized `Color = 0 = clBlack`, `FontName = ''`, `Size = 0`. Draw path at :1646-1658 then forces black and default font, and advances by stored widths measured with the *intended* fonts, so mixed-size runs also overlap/gap. Verified first-hand.
- **Impact:** every HTML memo with `<font color|face|size>` and every memo using conditional font color renders incorrectly in preview **and** export (runs are re-captured for PDF in `Engine.pas:2000-2014`). The memo/HTML feature is effectively half-broken.
- **Fix:** three missing assignments in the `else` branch:
```pascal
SetLength(Line.Segments, L + 1);
Line.Segments[L].Text  := S;
Line.Segments[L].Style := Style;
Line.Segments[L].Color := Color;                 // missing
Line.Segments[L].FontName := FontName;           // missing
Line.Segments[L].Size := Size;                   // missing
Line.Segments[L].Width := W;
```
Plus a golden test with colored/multi-font HTML memo.

**H-4. DPI blindness across the geometry model**
- **Where:** `source/Vittix.Report.PageSettings.pas:10` ("all dimensions in pixels at 96 DPI"); `Engine.pas:566` creates `TMetafileCanvas.Create(FCurrentPage, 0)` (screen reference DC); no `PixelsPerInch`/`GetDeviceCaps`/`SetStretchBltMode(HALFTONE)` anywhere in the repo (grep-verified); the designer enables DPI awareness at startup (`VittixDesigner.dpr:79-83`).
- **Impact:** fonts are point-sized and realize at the *screen's* DPI, while all layout math assumes 96-dpi pixels. On a 144-dpi machine, 10pt text measures ~19px instead of ~13px: wrapping, `MeasuredBottom`, CanGrow heights, and VectorPDF spacing (`MeasureBmp` at `VectorPDF.pas:1690` uses the same screen DPI but `PDF_POINTS_PER_PIXEL = 72/96`) all disagree with the page model. Preview/PDF drift is priority #9 of the project. At exactly 96 DPI everything is exact — which is why the 693-test suite is green.
- **Fix direction:** create the metafile canvas against a 96-dpi reference DC, or set `Font.PixelsPerInch := 96` on all measurement fonts — a contained, testable change; needs a high-DPI machine to validate (see §14).

**H-5. CrossTab crashes the render on missing fields / non-numeric cells**
- **Where:** `source/Vittix.Report.Objects.CrossTab.pas:235-237` (`DS.FieldByName` ×3 in the record loop — raises `EDatabaseError`, unlike the `TryGetField` family used everywhere else) and :164-201 (unguarded `ACurrent + AValue` / `<` on Variants — string cells with caSum raise variant errors). `PrepareMatrix` has no guard.
- **Impact:** one typo'd RowField or one text value in a Sum cell aborts the whole report render with a raw database/variant exception.
- **Fix:** switch to `TryGetField` with a visible diagnostic (mirror `Utils.pas` helpers); guard the aggregate arithmetic with type checks, skipping non-numeric cells with a warning.

**H-6. Chart / CrossTab data caches latch forever — stale visuals**
- **Where:** `source/Vittix.Report.Objects.Chart.pas:109` (`FDataPrepared`) and `CrossTab.pas:213` (`FMatrixPrepared`) are set once and never reset; the engine resets only image caches per pass (`Engine.pas:784-786`).
- **Impact:** re-preparing the same model against changed data (typical in a host app that re-`Execute`s after a query refresh) draws the old chart/crosstab. Silent staleness — worse than a crash for a reporting tool.
- **Fix:** add a `ResetDataCache` analogous to `ResetImageCache` and call it in the same `BeginPass` loop, with a two-render test.

**H-7. Designer command-line mode can overwrite the source report with a blank one**
- **Where:** `vittixdesigner/Frm.Main.pas:1215-1217` (silent `except // ignore — start with blank report` on input load failure) + `FormCloseQuery` :1340-1356 (writes `FCmdLineOutputFile` **unconditionally**).
- **Impact:** in the IDE component-editor integration, a corrupt/unreadable input `.vrt` is silently replaced by a serialization of the empty report — user data loss.
- **Fix:** refuse to write the output file when the input failed to load (track `FCmdLineInputLoaded: Boolean`); surface the load error non-fatally.

### Medium

| ID | Where | Issue & impact | Fix |
|---|---|---|---|
| M-1 | `Undo.pas:276-281`; `Frm.Main.Commands.pas:168-186` | Undo history unbounded; snapshot stores 2 full JSON strings, image edit stores 2 full `TPicture`s (5 MB PNG × 20 edits = 200 MB); `DoCommand` leaks the command if `Execute` raises | Cap history (e.g. 100); free-on-exception in `DoCommand`/`UndoLast` |
| M-2 | `DesignerInteractionController.pas:535-556` | Every plain click pushes a no-op `TMultiMoveCommand` (Old=New bounds) — History panel noise + stack growth | Drag-threshold check at MouseUp, as MouseMove already has |
| M-3 | `Engine.pas:2397-2424` + `:359-361` | Aggregate cache linear scan, and `RowNumber` in `Matches` makes row-scoped aggregates append a new entry per row → O(n²) comparisons, unbounded growth within a render | Dictionary keyed on the (fixed) cache key; don't store row-unique entries |
| M-4 | `Aggregates.pas:68` + `docs/archive/BACKLOG_v1.1.md:19` | **BUG-005**: aggregates over `TVittixUserDataSet` return False → fallback text `SUM(10.5)` printed (documented, deferred) | Keep parked per freeze, but surface a designer problem-panel diagnostic |
| M-5 | `Aggregates.pas:152-157` | Legacy empty-range AVG/MIN/MAX return `0` as if real data (modern mode correctly returns NULL) | Characterized by tests already; align to NULL with a legacy-mode flag if the compat oracle allows |
| M-6 | `Engine.pas:857` | Group-break compare `NewValue <> FLastGroupValues[I]` is Null-asymmetric and relies on Variant coercion — a Null→value or type-flap can miss a group break | Use `VarSameValue` + explicit `VarIsNull` on both sides |
| M-7 | `Objects.pas:819, 829, 901`; `Unknown.pas:102` | `DrawText` without `DT_NOPREFIX`: `&` in data ("AT&T") is swallowed and underlines the next char; inconsistent with TextOut-based objects | Add the flag |
| M-8 | `CrossTab.pas:356-357` vs `:370-481` | Counting pass measures from an empty matrix while Draw has **no clipping** → under-measured crosstab overflows the band into following content | Clip in Draw or measure a pessimistic height in pass 1 |
| M-9 | `Barcode.pas:183-189, 825-839, 861`; `Engine.pas:1776-1884` | No quiet zones for 1D (spec ≈10 narrow modules), QR zone 2 vs required 4 modules; narrow bars can round to 0-width and vanish; `bsLegacy` **default** symbology is a decorative non-scannable pattern; export capture uses floor-unit geometry ≠ canvas proportional geometry → preview and PDF barcodes visibly differ | Enforce quiet zone + minimum bar width; change default to Code39; share the geometry module between `Barcode.pas` and `Engine.pas` (see M-13) |
| M-10 | `Chart.pas:146`, `CrossTab.pas:370`, `Unknown.pas:68` | These Draw methods ignore `Visible`/`PrintWhen` entirely (invisible chart still prints) | Route through the shared `DrawReportObjectWithHooks` (`Objects.pas:355-390`) |
| M-11 | `Chart.pas:120` | `Bmk := DS.Bookmark` never `FreeBookmark`ed (SubReport does it right at `Objects.pas:1868-1871`) — leak per PrepareData | Free in finally via `RestoreDataSetBookmark` |
| M-12 | `Objects.pas:150` | `property Font: TFont read FFont write FFont;` — direct reference write; external `Obj.Font := X` leaks old font and aliases caller's (double-free risk). CrossTab does it correctly (`SetFont` + `Assign`, `CrossTab.pas:127-135`) | Setter with `Assign` |
| M-13 | `Engine.pas:1637-2370` | `CaptureExportObjectCommand` duplicates an entire Code39 table (:1684-1734), barcode frame geometry, and image layout math from `Objects.*` — three divergent geometry sets already produce preview≠PDF barcodes | Move per-object capture into a virtual `CaptureExportCommands` on `TReportObject` subclasses (freeze-compatible as `[fix]` if driven by a divergence test) |
| M-14 | `VectorPDF.pas:349-355, 749-759` | ANSI text is *measured* with the report font but *drawn* with built-in Helvetica F1-F4 (acknowledged in comment) — right/center alignment and overall width drift from preview; a report in Times renders Latin text as Helvetica | Route ANSI text through the same embedded-font path as Unicode (shaping accepts Latin trivially) |
| M-15 | `VectorPDF.pas:571-572` | RTL runs (`SCRIPT_ANALYSIS_RTL`) are rejected → Hebrew/Arabic always rasterized (worse quality, unselectable) | Needs proper RTL placement (reverse glyph order, use `fRTL`/advance signs) — park for v1.1 |
| M-16 | `VectorPDF.pas:1424-1437, 1371-1387` | Every glyph gets its own `BT..Tm..<gid> Tj..ET` block; content streams uncompressed; all content built by `AnsiString` concatenation (O(n²) per page) | Run-length `Tj` with TJ arrays where positioning allows; compress content streams (`FlateDecode` — `CompressBytes` already exists); build via `TStringBuilder`/stream chunks |
| M-17 | `DesignerControl.pas:1801, 2454` | Content metafile rebuilt from scratch on *every* repaint (each mouse-move drag) — the "cache" never caches; `DrawBandContentLive` (:1905-1911) temporarily mutates model `Bounds` during painting (reentrancy hazard) | Cache by dirty generation counter; paint via DC transform instead of Bounds swap |
| M-18 | `Preview.pas:177-188`; `Frm.Preview.pas:506-550, 518-542` | Every page stored as bitmap **and** metafile (plus renderer originals transiently = 3×); the large-report warning dialog undercounts; render fully synchronous (UI freeze, no cancel) | Keep metafile only (lazy raster exists!); render behind a progress dialog with the existing `IReportProgress` cancel |
| M-19 | `Frm.Main.pas:1558, 1571-1578`; `DialogHelpers.pas:18-32` | Save is a direct overwrite — no temp-file+rename, no `.bak` (disk-full corrupts the only copy); SaveAs sets `FCurrentFile` before the save succeeds; "Yes then cancel SaveAs" still closes without saving | Atomic write helper; set path only on success; treat cancelled save-as as "don't close" |
| M-20 | `Frm.Main.pas:7442-7450, 1148-1149` | `ReloadSampleDataSet` ForceDirectories+Saves into the exe folder at startup — raises inside `FormCreate` under `Program Files` → app exits via the dpr fatal handler | Write to `%LOCALAPPDATA%`; guard with try/except |
| M-21 | `Serializer.pas:1399-1401` | `Version` read but never validated or branched on; unknown *properties* silently take defaults (only unknown classes are preserved) — a future v3 with changed semantics would load v3 files as if v2 | Reject `Version > 2` with a clear diagnostic (forward-compat, not silent) |
| M-22 | `Engine.pas:481-487` | Destructor frees bookmarks via `FDataSet.FreeBookmark` — if the dataset was freed before the engine (host ownership ordering), this is a use-after-free | Guard with the component's `Notification` pattern at the `TVittixReport` layer; document engine lifetime contract |
| M-23 | `Evaluator.pas:275-280` + `Language.pas:616` | One paren nesting level consumes ~8 depth increments of the 32 budget → legal expressions with ≥5 nesting levels rejected with a misleading "depth" error | Raise `MaxParserDepth` to ~256 (cost: nothing — the check exists for stack safety) |
| M-24 | `Tokenizer.pas:149-153` | Number literals parsed with locale `TryStrToFloat`, silently yielding 0 on failure — `1.5` misparses under comma-decimal locales with no diagnostic | Invariant parse + explicit diagnostic |

### Low

- **Dead/duplicated code:** identical command classes in `Frm.Main.Commands.pas` and `Vittix.Designer.Commands.pas` resolved by uses-order shadowing (`Frm.Main.pas:67` vs `:102`); `Frm.Main.PropertyEditHelpers.pas` references two **non-existent units** (`Vittix.Report.Objects.Text`, `Vittix.Report.Commands`) — cannot compile, orphaned; `Frm.Main.pas:7377-7525` duplicates `SampleDataHelpers` verbatim and uses the local copy; `BandTypeName` ×4; `EvalCall2` dead loop (`Evaluator.pas:1430`); ~40 `H2164` unused-variable hints in `ScriptHost.Adapter` `Cmd_*` handlers (copy-paste template residue — visible in the build log).
- **Stale comment:** `Component.pas:582-584` says Render "frees the engine internally" — it does not (`Renderer.pas:186-214` verified); the caller's `finally Engine.Free` is correct.
- **`TReportTextObject.Draw` overflow:** single-line text is position-clamped but never clipped/ellipsized (`Objects.pas:847-849`) — bleeds onto neighbors.
- **W1050 warning** `Objects.pas:1081` (WideChar in set — use `CharInSet`); build log shows it on every package build.
- **Icon index fragility** (`Frm.Main.pas:1037-1079` + constants at :658-668): per-icon silent `except`; one missing PNG shifts every subsequent index.
- **INI preferences in profile root** (`DesignerPreferences.pas:65-72`) instead of `%APPDATA%`; ~5 separate open/write sessions per save.
- **Renderer print is full-stretch** (`PrintMapping.pas`, `prsFullStretch`) — aspect ratio not preserved on printers with different page aspect; the preserve-aspect mode exists but nothing uses it.
- **`Frm.Preview.pas:518-542`** large-report memory estimate counts only 1 of the 2-3 copies held.
- **`Undo.pas:441-453, 553-563`** stale-index redo paths (`TDeleteObjectsCommand.Execute`, `TZOrderCommand`) without bounds clamps.
- **Subreport re-parse when `Hooks = nil`** (`Objects.pas:1816-1821`) — per-draw JSON parse cost.
- **`Engine.pas:1141-1143`** PrintWhen expression exceptions silently suppress the band (policy, but user-invisible; the object-level path logs via `ShouldPrintObject`).
- **`VectorPDF.pas` `/W` width math** (`:625`): `MulDiv(AdvancePx, 1000, FontSize)` conflates point size with pixel em — likely inflates reported glyph widths by the screen-DPI/72 factor; harmless to placement (explicit `Tm` per glyph) but degrades text extraction/copy width — **needs verification**.
- **Repo hygiene:** tracked 24.7 MB `demo/db/northwind.db` and a tracked crash dump `vittixdesigner/bugreport.txt`; ~60 ignored-but-present junk files at root (logs, `.dcu`, one-off scripts, `1788278426566_n6cw8.json`); `Vittix.Report.Export.VectorPDF.pas.bak` beside sources.

---

## 6. Memory & Resource Management Findings

**Overall: this is the codebase's strongest discipline.** Zero leaks reported by DUnitX's leak detector; runner enforces `USER delta = 0`, `GDI delta ≤ 16` (observed 8, explained as first-render font cache allocations). Specific verifications:

- Engine page lifecycle is exception-safe: `EndCurrentPage` frees the canvas in `finally`, drops the failed page on exception, and `StartNewPage` guards canvas creation (`Engine.pas:555-577, 586-662`). `SaveDC`/`RestoreDC` and `SetViewportOrgEx` pairs are all in `try..finally` (`Engine.pas:1223-1249`, `DesignerControl.pas:1833-1841`).
- Bookmark pairing is correct everywhere in the expression stack (legacy per-row bookmarks freed in `finally`, `Aggregates.pas:101-107`; cache deep-copies bookmarks, `Engine.pas:374-375`) — **except** the Chart leak (M-11).
- `TVittixReport` implements `Notification`/`FreeNotification` correctly for `DataSource` and UserDatasets (`Component.pas:266-332`).

**Genuine exceptions to the discipline** (all cited in §5): the undo-stack growth/leak-on-raise family (M-1), `DoCommand` ownership on exception, the designer's command-objects-without-`else Cmd.Free` at three call sites (`Frm.Main.pas:1419-1426, 5066-5068, 5413-5415`), the `TReportLoadResult` leak on the fallback exception path (`Frm.Main.pas:1195-1213`), and preview's 2-3× page-copy multiplication (M-18). Canvas-state bleed (Barcode/Unknown/Chart mutate shared canvas font/brush without restore — `Barcode.pas:945-951`, `Unknown.pas:93-94`, `Chart.pas:188-230`) is cosmetic-adjacent but violates the project's GDI rules.

---

## 7. Performance Findings

- **Per-master-row detail rescan:** `ComputeFirstDetailRowsHeight` (`Engine.pas:1320-1399`) bookmarks + `First`-scans every detail dataset per master row just to measure the first matching row; `PrintDetailBandRecords` scans again to print. O(master × detail) inherent to linked-detail without indexes on the detail side — acceptable for demo scale, quadratic for real volumes. Consider a keyed lookup or a precomputed pass.
- **Aggregate rescan cost:** every aggregate re-scans GroupStart→GroupEnd evaluating the inner expression per row, with per-row `GetBookmark`/`CompareBookmarks`/`FreeBookmark` and linear `FindField` (`Aggregates.pas:79-165`, `Evaluator.pas:1129-1257`); nested *legacy* aggregates degrade to O(n²). The engine cache (once M-3/H-1 are fixed) mitigates repeated identical calls only.
- **VectorPDF construction:** O(n²) `AnsiString` concatenation for content streams, per-glyph `BT/ET` blocks, uncompressed streams, bubble-sorted width arrays (`VectorPDF.pas:1601-1629`) — visible on the 75-page baseline (currently ~34 ms there, so tolerable, but image-heavy reports will feel it).
- **Designer repaint churn:** full-page EMF rebuild per paint including every mouse-move (M-17); `Canvas.Pixels` grid drawing (`DesignerControl.pas:1704-1732`); char-by-char `StyledTextWidth` for long unbreakable tokens (`Objects.pas:1537`).
- **Image objects keep two full decoded copies** (`FPicture` + `FCachedPicture`) with no downscale cap, and `StretchDraw` uses default COLORONCOLOR (no HALFTONE) — downscaled images alias (`Objects.pas:1231-1269`, `Renderer.pas:156`).
- **Positive:** two-pass rendering is cheap-pass-first with correct cache isolation; subreport models cached per owner (`Engine.pas:2426-2465`); the 41-report strict suite runs in ~5 s total on the analysis machine — the engine itself is fast at demo scale.

---

## 8. Security Findings

- **No code-execution surface in report files** — the script host is a closed property-assignment namespace (verified: no RTTI interpreter, no file/OS calls; `ScriptHost.Adapter.pas:96-292`). This is notably safer than FastReport-style PascalScript report files.
- **Host event handlers are trusted and uncontained**: `OnBeforeObject`/script engine callbacks fire with no try/except (`Engine.pas:1608, 1630`); a host handler exception aborts the render (acceptable, but a malicious `.vrt` can choose *which objects* fire host code).
- **Local file disclosure vector (low, worth documenting):** a `.vrt` can name arbitrary local image paths (`ImageCmd.Source`), and `VectorPDF/HTML` exporters will embed those files' contents into outputs; if users exchange report templates, a crafted template can exfiltrate local files via the exported document. Consider restricting image sources to a base directory (opt-in).
- **Temp-file handling:** export captures write GUID-named PNGs to `%TEMP%` and delete them on document free (`Export.Commands.pas:213-233`); crash mid-export leaves orphans; `TFile.Delete` failure inside a destructor would raise during destruction — wrap.
- **PDF font embedding** respects `otmfsType` restricted-license bit (`VectorPDF.pas:442-443`) — correct licensing behavior.
- **No registry use**; preferences are INI in the profile root. madExcept is linked into the designer (crash reports may contain paths/memory dumps — fine for a desktop tool, note for distribution).

---

## 9. Test Coverage Assessment

**Quantities (verified by running):** 43 test units, **693 `[Test]`s, 693 passed / 0 failed / 0 leaked**; regression corpus of 45 `.vrt` fixtures with **41 pinned page-count baselines** (`reports/regression_baselines.json`) enforced in `--strict` mode; resource-delta gates on the runner. DUnitX console + NUnit XML; conditional TestInsight path.

**Quality signals above average:** a frozen legacy evaluator kept as a **differential oracle** (`Test.Vittix.Report.ExpressionLegacyReference.pas`); characterization tests for known edge semantics (empty-range aggregates, UDS aggregates, PNG alpha); an ExportCapture suite (57 tests) pinning the semantic command stream; dedicated Indic-script VectorPDF tests; the leak detector as a gate.

**Gaps:**
- 22 of 62 source units have no direct test reference (`Export.Email`, `Preview`, `Toolbox`, `SelectionHelpers`, `Objects.Table`, `PropertyBridge`, most `Layout*`, `DataSources`); several are covered transitively, but `Export.Email` and `Preview` are effectively untested.
- The **designer application has no automated tests at all** — and it holds the Critical finding (C-1). The undo/redo contract is exactly the kind of thing a small DUnitX harness around `TCommandManager` + a stub designer could pin.
- Nothing exercises the engine through `TVittixReport.Execute`'s preview path, and nothing covers the H-1 two-aggregate scenario end-to-end (the existing tests structurally can't catch it — `Hooks = nil`).
- CI is Win32/Release-only, self-hosted, single Delphi version; the demo app and the Win64 designer build (`build.bat` builds it) are not gated; DUnitX XML is uploaded but never published as test results.

---

## 10. Packaging & Dependency Assessment

**Correct:** design package is `{$DESIGNONLY}`, requires the runtime package, and `DesignIntf`/`DesignEditors` appear in exactly one unit (`ComponentEditor.pas`) that lives only in the design package — no IDE-unit leakage. No `.dcu`/`.exe`/`.bpl` tracked.

**Defects (several confirmed live by the W1033 warnings in the build log):**
1. Runtime package lacks `{$RUNONLY}` / `<RuntimeOnlyPackage>` — installable into the IDE, contrary to the standard split.
2. `RegisterComponents` lives in runtime-contained units (`DesignerControl`, `Preview`, `Toolbox`, `UserDataSet`); `Vittix.Report.Reg.pas` documents the duplication workaround instead of owning registration.
3. **19 units implicitly imported** into the runtime BPL (all `Qlp*`, `LoadResult`, `Objects.Unknown` — W1033 for each in the build log): they're not in `contains`, so any consumer compiling them from source gets duplicate symbols.
4. `VittixReportRuntime.dproj` is missing `VectorPDF.Subset` from its DCCReference list (dpk has 58 units, dproj 57).
5. Design package requires `adortl` vestigially (only the designer EXE uses ADO).
6. No `LibSuffix` — multiple Delphi versions sharing a package dir will collide.
7. **No in-repo project consumes the packages** (demo/designer/tests compile via search paths); CI only compile-smokes them — BPL install-into-IDE is never verified.
8. The local package build failed at the linker on the default BPL output dir (F2039) — the dproj relies on the machine-global `Bpl` output path rather than a repo-relative one.

**Dependencies:** QRCodeGenLib (MIT, license vendored, cleanly isolated — but see implicit-import above); **madExcept is a hard build dependency of the designer** (commercial license required to compile `VittixDesigner.dpr:8-12`) — disclosed in README, but it makes the designer non-buildable for licensees without madExcept; FireDAC/ADO only in demo/designer as intended. The 24.7 MB `northwind.db` should be replaced by the already-present SQL seed.

---

## 11. Documentation Assessment

**Volume and honesty are unusual strengths:** 30+ docs including phase plans, ADRs (`docs/ADR-Export-PDF.md`), an events contract (`docs/EVENTS.md`), gap audits, and a mkdocs site. Docs deliberately record *known defects* (BUG-005 parked in the historical backlog, now `docs/archive/BACKLOG_v1.1.md`; PNG-alpha preview/PDF discrepancy; VectorPDF limitations) — recent `[chore]` commits correct stale claims rather than leaving rot.

**Problems:** documentation is scattered — ~20 plan/audit markdown files at repo root duplicate `docs/` copies (e.g., `VittixReport_CodeReview.md` vs `docs/code-review.md`), and several describe *plans* whose status is unclear (frozen? shipped?); the README omits crosstabs/charts/QR from the feature list, doesn't mention `build.bat`/`tools/ci_gate.ps1`/`TESTING.md` entry points, and its "Win32 or Win64" claim exceeds what's built (Win32 packages only); `Component.pas:582-584` carries a factually wrong ownership comment (verified against `Renderer.pas`); `VectorPDF.pas:349-355`'s "until font embedding lands" is stale for the Unicode path (embedding landed; the ANSI path is what still uses Helvetica). Root clutter (60+ junk files, `.bak` files, tracked `bugreport.txt`) undermines the otherwise professional presentation.

---

## 12. Refactoring Plan

Framed for the active **v1.0 freeze**: everything below is `[fix]`-with-failing-test, `[test]`, or `[chore]` — nothing needs new features.

**Short term (days) — correctness & safety:**
1. C-1: clear/drop pointer-holding undo commands when a snapshot executes; failing designer test first.
2. H-1: aggregate cache key includes function+inner node; engine-level two-aggregate test.
3. H-3: the three missing `AddLineSegment` assignments; colored-memo golden test.
4. H-5/H-6: CrossTab `TryGetField` + guarded arithmetic; reset Chart/CrossTab caches in `BeginPass`; two-render staleness test.
5. H-7: gate command-line output write on successful input load.
6. M-1/M-2: cap undo history at N; skip no-op click commands.
7. M-19: atomic save (temp+rename) and SaveAs ordering fix.
8. Hygiene `[chore]`: delete `bugreport.txt`, `*.bak`, root junk; untrack `northwind.db` in favor of the SQL seed.

**Medium term (weeks) — consistency & packaging:**
1. DPI: force a 96-dpi reference for measurement canvases (engine metafile canvas + VectorPDF `MeasureBmp`); validate on a 125/150% machine (§14).
2. M-13: extract `CaptureExportObjectCommand` into per-object virtual capture, eliminating the duplicated Code39/geometry tables; pin with a preview-vs-PDF barcode geometry test.
3. M-14: ANSI text through the embedded-font path (kills the Helvetica mismatch).
4. M-16: compress PDF content streams; batch glyph `Tj`.
5. Packaging: `{$RUNONLY}`, move registration to `Reg.pas`, declare the 19 implicit units (or one QR facade unit), sync dproj, drop `adortl`, add `LibSuffix`, repo-relative BPL output; add designer/demo/Win64 to CI; make madExcept conditional (`{$IFDEF USE_MADEXCEPT}`).
6. M-6/M-23/M-24: group-break `VarSameValue`; parser depth 256; invariant number literals.
7. Small DUnitX harness for `TCommandManager` and the undo contract (C-1 regression insurance).

**Long term (months, post-v1.0 — BACKLOG items):**
1. Replace pointer-based undo commands with model-path identity (the structural fix for C-1).
2. Split `Frm.Main.pas` (finish the helpers migration; delete dead duplicates; extract the 2,608-line demo harness out of the production form — it already exists as `Vittix.Designer.RuntimeDemo.pas`, currently dead).
3. Background/progressive rendering behind `IReportProgress` with cancellation (M-18), preview thumbnails.
4. BUG-005 (UDS aggregates) and RTL PDF shaping.
5. Aggregates: keyed cache, optional detail-dataset index for linked details.
6. Schema: reject `Version > 2`, then introduce real migration hooks when v3 semantics arrive.

---

## 13. Quick Wins

1. `AddLineSegment` — 3 lines, fixes all-black memos (H-3).
2. Aggregate cache key — 1 line + test (H-1).
3. `DoCommand`/undo-stack cap + no-op click filter — ~15 lines total.
4. `DT_NOPREFIX` on four DrawText call sites.
5. `{$RUNONLY}` + declare implicit units + dproj sync (kills 19 W1033 warnings, prevents consumer duplicate-symbol reports).
6. Atomic save helper + output-write gate for command-line mode (H-7/M-19).
7. `Chart.pas:120` — one `FreeBookmark` in a `finally`.
8. Delete tracked `vittixdesigner/bugreport.txt`, `*.bak` files, root junk; `git rm --cached` the 24.7 MB DB.
9. Fix the stale `Component.pas:583` comment and the README feature/entry-point gaps (`[chore]`).
10. Change default barcode symbology off `bsLegacy` (designer template default — one line where new objects are created).

---

## 14. Open Questions / Uncertainties

1. **High-DPI impact in practice (H-4):** the 96-dpi model is proven by code reading, but the *severity* on 125%/150% machines (and which app manifests make it visible) needs a live check — is the demo app DPI-aware? The designer explicitly is (`VittixDesigner.dpr:79-83`). Needs verification on a scaled display.
2. **VectorPDF `/W` width math** (Low): the reading is that widths are inflated by the screen-DPI factor; only affects text-extraction metrics, not placement — needs a PDF text-extraction check to confirm.
3. **CI package gate:** the local run failed at F2039 writing to the machine-global Bpl directory; the GitHub workflow is green on recent commits, so this is likely local-permission — but the underlying reliance on a machine-global output path is itself a packaging defect worth fixing.
4. **`TReportSerializer.LoadFromFileEx` diagnostic-transfer loop** (`Serializer.pas:1503-1507`) — read as correct but subtle (Extract-while-iterating); worth a unit test if diagnostics ordering matters to the designer's Problems panel.
5. **Whether any real-world reports rely on the legacy behaviors flagged in H-2/M-5** (qualified-field discard, empty-range zero) — the compat oracle freezes them, so *any* fix must be behind a diagnostic-first change; product decision needed on whether legacy diagnostics surface in the designer Problems panel.
6. **`demo/db/northwind.db` provenance** — assumed generated/test data; if it contains real data it should not be in a public MIT repo.
