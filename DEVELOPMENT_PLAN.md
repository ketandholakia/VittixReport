# VittixReport — Development Plan (Execution Schedule)

> **Document status — EXECUTION SCHEDULE derived from the source of truth (2026-09-29).**
> The canonical analysis is [`VittixReport_FullCodeAnalysis.md`](https://github.com/ketandholakia/VittixReport/blob/main/VittixReport_FullCodeAnalysis.md);
> this document turns its §5 (Issues by Severity) and §12 (Refactoring Plan) into a
> sequenced, tracked work list. The report wins on *what and why*; this plan owns
> *when, in what order, and how each item is verified*. Update both as items close.
>
> Created at the project owner's direction. All items are classified under the
> active v1.0 freeze as `[fix]` (bug: the report does not render what the designer
> says), `[test]`, or `[chore]` — no features, no unattached refactors.

---

## 0. How to work an item

Every `[fix]` item follows the same micro-cycle (mirrors AGENTS.md "Preferred Workflow"):

1. **Red** — write the failing test that reproduces the bug. Commit as `[test] ...`.
   The repo convention: failing tests may land red (see commit `dcf31bc` for the pattern).
2. **Green** — apply the minimal fix. Commit as `[fix] ...` referencing the finding ID,
   e.g. `[fix] vectorpdf+engine: ... (H-1)`.
3. **Gate** — run `powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages`.
   Must end green: 693+ DUnitX tests pass with `Tests Leaked : 0`, `VittixRunner --strict`
   reconciles all 41 baselines, USER handle delta 0, GDI delta ≤ 16.
4. **Baselines** — if a fix *intentionally* changes pagination, update
   `reports/regression_baselines.json` in the same `[fix]` commit and state the reason
   in the commit body. An unexplained baseline change is a bug, not a fix.
5. **Bookkeeping** — tick the item here and in the report's §5 if the issue text needs
   a "fixed in <commit>" note. `[chore]` commit for the bookkeeping, or fold it in.

**Effort scale:** S ≤ 2 h · M ≤ 1 day · L = 2–3 days (solo-developer, includes tests).

**Status vocabulary:** ⬜ pending · 🟨 in progress · ✅ done · ⏸ parked (post-v1.0) ·
⛔ blocked on an open question (see §OQ).

---

## 1. Milestones

| Checkpoint | Content | Exit criteria |
|---|---|---|
| **CP-A — Hygiene & packaging** (Wave 0) | Repo cleanup, package correctness, CI additions | No W1033/W1050 warnings; no tracked junk; `ci_gate.ps1 -IncludePackages` green on a clean checkout |
| **CP-B — Correctness** (Wave 1) | All Critical + High findings fixed test-first | Every Wave-1 item ✅; gates green; no baseline changes except documented |
| **CP-C — Robustness** (Waves 2–3) | Medium batch + consistency work | All scheduled M items ✅; manual checklist (TESTING.md) run once fully |
| **CP-D — Soak & release** (Wave 4) | Freeze-compliant hardening, soak, tag | 1–2 weeks soak with no new P0/P1; then tag `v1.0.0` |
| **Post-v1.0** (Wave 5) | Parked backlog | Started only after `v1.0.0` is tagged (AGENTS.md rule) |

Suggested sequencing is strictly serial between waves (each wave shrinks the risk the
next wave touches), but items inside a wave are independent and can be taken in any order.

---

## 2. Wave 0 — Hygiene & packaging `[chore]`

*No runtime behavior changes. Do this first so later diffs are clean and the
packaging warnings stop burying real ones.*

### DP-01 ✅ Remove tracked junk and backup files — Effort S
- **Files:** `vittixdesigner/bugreport.txt` (tracked crash dump), `source/Vittix.Report.Export.VectorPDF.pas.bak`, `tests/Test.Vittix.Runner.JsonFormatter.pas.bak/.clean/.tmp`, stray local-only clutter (root logs, `1788278426566_n6cw8.json`, one-off bat/ps1 duplicates — untracked, just delete).
- **Action:** `git rm` the tracked ones; delete untracked clutter locally. Add `.bak`/`.clean`/`.tmp` to `.gitignore` if not covered.
- **Done when:** `git ls-files | grep -E "\.(bak|clean|tmp)$|bugreport"` is empty; working tree has no stray logs.

### DP-02 ⬜ (blocked on OQ-3) Replace committed 24.7 MB `demo/db/northwind.db` with the SQL seed — Effort S
- **Files:** `demo/db/northwind.db` (untrack), `demo/db/vittix_demo_sqlite.sql` (already present), `demo/README.md`.
- **Action:** `git rm --cached demo/db/northwind.db`, ignore `*.db` except the small documented `vittixreportdemodb.db` (or that one too — decide), document "run the SQL seed to create northwind.db" in `demo/README.md`.
- **Risk:** demo first-run experience needs one extra step — acceptable for −24 MB repo.
- **Done when:** repo clone size drops; demo README explains regeneration.

### DP-03 ✅ Runtime package: declare implicit units, add `{$RUNONLY}` — Effort S
- **Files:** `packages/VittixReportRuntime.dpk`, `VittixReportRuntime.dproj`.
- **Action:**
  1. Add `{$RUNONLY}` to the .dpk and `<RuntimeOnlyPackage>true</RuntimeOnlyPackage>` to the .dproj.
  2. Add to `contains`: `Vittix.Report.LoadResult`, `Vittix.Report.Objects.Unknown`, and the 17 `Qlp*` QRCodeGenLib units (kills all 19 live `W1033` implicit-import warnings and the consumer duplicate-symbol hazard). Alternative: keep QRCodeGenLib out and add a single facade unit `Vittix.Report.QR` that uses the `Qlp*` units — pick one, don't do both.
- **Done when:** `ci_gate.ps1 -IncludePackages` builds with zero W1033.

### DP-04 ✅ Package project hygiene — Effort S
- **Files:** `packages/VittixReportRuntime.dproj`, `VittixReportDesign.dpk/.dproj`.
- **Action:** add the missing `Vittix.Report.Export.VectorPDF.Subset` DCCReference (dpk has 58 units, dproj 57); drop the vestigial `adortl` require from the design package; point `DCC_BplOutput`/`DCC_DcpOutput` at a repo-relative `build\bpl` path so the F2039 machine-global-output failure seen during analysis can't happen; decide on `LibSuffix` (adding one breaks existing consumers' install paths — default: defer, record decision in `docs/`).
- **Done when:** packages build from a fresh checkout without depending on `C:\Users\Public\Documents\Embarcadero` write access.

### DP-05 ✅ Documentation corrections `[chore]` — Effort S
- **Files:** `README.md`, `source/Vittix.Report.Component.pas:582-584`, `docs/index.md`.
- **Action:** README feature list: add crosstabs, charts, QR codes (they exist and are tested); qualify the "Win32 or Win64" requirement (packages are built Win32; designer also Win64 via `build.bat`); add Getting-Started pointers to `build.bat`, `tools/ci_gate.ps1`, `TESTING.md`, `reports/` corpus, `tests/`. Fix the stale comment in `Component.pas` (`Render` does **not** free the engine internally — verified against `Renderer.pas:186-214`; the caller's `finally Engine.Free` is correct).
- **Done when:** README matches reality; comment no longer misleads.

### DP-06 ✅ CI additions `[chore]` — Effort S
- **Files:** `.github/workflows/build-and-test.yml`.
- **Action:** add `concurrency:` group and `timeout-minutes:`; publish `tests/dunitx-results.xml` as a test result (NUnit format) instead of a blob artifact; add the demo `VittixReportDemo.dproj` to the `-IncludePackages` build list in `tools/ci_gate.ps1`; note Win64 designer build (`build.bat`) as a manual gate or add a second platform pass if the self-hosted runner allows.
- **Done when:** PRs show test annotations; workflow has timeout+concurrency.

### DP-07 ✅ Make madExcept conditional in the designer `[chore]` — Effort M
- **Files:** `vittixdesigner/VittixDesigner.dpr:8-12`, `VittixDesigner.dproj` (defines `madExcept`).
- **Action:** wrap the madExcept units in `{$IFDEF USE_MADEXCEPT}` and move the define to an opt-in (environment variable in the dproj or a paired .dproj). Designer keeps full crash reporting for licensed builds; licensees without madExcept can still build.
- **Done when:** `VittixDesigner.dproj` builds with and without the define.

**Wave 0 exit:** run the full gate once; commit any baseline drift discovered as its own `[fix]` before starting Wave 1.

---

## 3. Wave 1 — Critical & High `[fix]` (test-first)

*Every item here is a user-visible correctness bug. Order within the wave: DP-08 → DP-09 → DP-10 first (worst blast radius), rest in any order.*

### DP-08 ✅ Undo/redo use-after-free (finding **C-1**) — Effort M — fixed in `1a3feae` + `3e46df0`; DP-22 exception safety landed with it
- **Files:** `source/Vittix.Report.Undo.pas` (`TCommandManager.DoCommand` :276-281, command classes :96-155), `vittixdesigner/Frm.Main.Commands.pas:209-222` **and its twin** `vittixdesigner/Vittix.Designer.Commands.pas:190-203` (both `TReportSnapshotCommand` copies), trigger sites `Frm.Main.pas:5099/5413`.
- **Bug:** a snapshot command replaces the whole `TReportModel`; older undo commands hold raw `TReportObject` pointers into the freed model; `TMoveObjectCommand.Rollback` (`Undo.pas:357-358`) then writes through a dangling pointer. Repro: Band Manager → OK → Undo ×2.
- **Fix approach (minimal, no API break):**
  1. Add a virtual property to `TUndoableAction`: `function InvalidatesObjectRefs: Boolean; virtual;` — `TReportSnapshotCommand` (both copies) overrides it to return `True`.
  2. In `TCommandManager.DoCommand`, when `C.InvalidatesObjectRefs`, call `FUndo.Clear; FRedo.Clear;` *before* `C.Execute`, then `FUndo.Add(C)`.
  3. While there, make `DoCommand`/`UndoLast`/`RedoLast` exception-safe (see DP-22 — fine to land together).
- **Test plan (`[test]` first):** extend `tests/Test.Vittix.Report.Undo.pas`: build a model + two objects; push a `TMoveObjectCommand` per object; push a snapshot-style command marked `InvalidatesObjectRefs`; assert `CanUndo` reflects **only** the snapshot (older entries dropped), and that undoing does not touch the pre-snapshot objects. Use objects owned by a local `TObjectList` so any post-fix dangling access would still be caught by the leak checker/FastMM in debug.
- **Also:** add a defensive `if Assigned(FObj)` guard in `TMoveObjectCommand.Execute/Rollback` (defense-in-depth; the structural fix is the clearing).
- **Done when:** repro sequence no longer corrupts memory (verify in designer manually: Band Manager OK → Undo ×2 → Save → reopen renders identically); test green; gate green.

### DP-09 ✅ — Aggregate cache-key collision (finding **H-1**) — Effort S — fixed in `d0eeed4` + `826bbdf`
- **Files:** `source/Vittix.Report.Expression.Evaluator.pas:1156` (key build), `:1256` (store).
- **Bug:** cache key is the whole expression text, so in `SUM([Amount]) + COUNT([ID])` the COUNT lookup hits SUM's cached entry — silently wrong numbers through the engine (the only path with `Hooks`).
- **Fix:** key on the aggregate node, not the expression: `CacheKey := CModernCacheKeyPrefix + <FuncName> + '(' + <inner-node source text or node identity> + ')' + '@' + IntToStr(ANode.Position);`. Keep the mode prefix. (Snippet and rationale: report §5 H-1.)
- **Test plan:** engine-level test in `tests/Test.Vittix.Report.Phase4B2B.pas` (end-to-end section) with `ExpressionLanguageVersion = 1`, an in-memory dataset, and a text object whose expression is `SUM([Amount]) + COUNT([ID])`; assert the combined value. The existing `Test_Modern_AggregateComposition` misses this because its context has `Hooks = nil` — the new test must go through `TReportEngine`.
- **Done when:** new test red→green; all Phase4B2B + Engine suites green; gate green.

### DP-10 ✅ — Memo segments lose Color/FontName/Size (finding **H-3**) — Effort S — fixed in `478ef24` + `765d11e`
- **Files:** `source/Vittix.Report.Objects.pas:1439-1443` (`AddLineSegment` else-branch), draw path :1646-1658.
- **Bug:** only `Text/Style/Width` are stored; zero-initialized records mean every segment draws `clBlack` with the object's base font, and run advance widths (measured with the *intended* fonts) mismatch what is drawn. Affects HTML memos (`<font color|face|size>`) and conditional font colors, in preview **and** exports.
- **Fix (3 lines, from report §5 H-3):**
```pascal
SetLength(Line.Segments, L + 1);
Line.Segments[L].Text  := S;
Line.Segments[L].Style := Style;
Line.Segments[L].Color := Color;        // missing
Line.Segments[L].FontName := FontName;  // missing
Line.Segments[L].Size := Size;          // missing
Line.Segments[L].Width := W;
```
- **Test plan:** new `tests/Test.Vittix.Report.Objects.Memo.pas`: render a `TReportMemoObject` (`AllowHTML = True`) containing `<font color="clRed">R</font>G` onto a white `TBitmap` via `Draw`; assert at least one pixel has R ≫ G,B (red text present) and at least one dark-grey/black pixel for the unstyled run. Also add an ExportCapture case pinning the memo **runs** carry per-run colors (43_memo_html variant) so the PDF path stays aligned.
- **Done when:** red→green; 43_memo_html baseline unchanged; gate green.

### DP-11 ✅ — CrossTab crash-hardening (finding **H-5**) — Effort M — fixed in `48c0a65` + `7e215df`
- **Files:** `source/Vittix.Report.Objects.CrossTab.pas:235-237` (`FieldByName` ×3 in the record loop), :164-201 (unguarded Variant arithmetic), `PrepareMatrix`.
- **Bug:** a missing RowField/ColumnField/CellField raises `EDatabaseError` and kills the render; a non-numeric cell with `caSum/caAverage/caMin/caMax` raises a Variant conversion error; both unguarded.
- **Fix:** replace `FieldByName` with the `TryGetField` family (`Vittix.Report.Utils`) — on a missing field, emit a diagnostic (reuse the `TReportTraversalDiagnostics` or a `TRenderDiagnostic` channel — pick the lightest existing one) and render the empty-table representation instead of raising. Guard aggregate arithmetic: only numeric `TField` types (or `VarIsNumeric`-style checks) participate; non-numeric cells are skipped and counted for a one-line diagnostic.
- **Test plan:** new `tests/Test.Vittix.Report.Objects.CrossTab.pas`: (a) crosstab whose CellField doesn't exist → render completes, no exception; (b) string cell values with `caSum` → render completes; (c) happy path unchanged vs. current golden output.
- **Done when:** red→green; 42_crosstab_object baseline unchanged; gate green.

### DP-12 ✅ — Chart/CrossTab stale data caches (finding **H-6**) — Effort S — fixed in `8369008` + `c53ed87` (incl. ResetImageCache FPicture latent-bug fix the wider walk exposed)
- **Files:** `source/Vittix.Report.Objects.Chart.pas:109` (`FDataPrepared`), `CrossTab.pas:213` (`FMatrixPrepared`), engine reset loop `Engine.pas:784-786`.
- **Bug:** data caches latch for the object's lifetime; re-running a report against refreshed data draws stale charts/crosstabs.
- **Fix:** add `procedure ResetDataCache; virtual;` (name it consistently with `ResetImageCache`) on `TReportChartObject`/`TReportCrossTabObject`; call it in the same `BeginPass` loop in `Engine.BeginPass` that resets image caches.
- **Test plan:** extend `tests/Test.Vittix.Report.Engine.pas`: render twice against a UserDataSet whose rows change between renders; assert the second render's export-capture commands reflect the new values (chart/crosstab go through `CaptureRenderableObjectAsImage` — assert via the captured image bounds/content hash or expose the prepared data via a test hook).
- **Done when:** red→green; 44_chart_object + 42_crosstab_object baselines unchanged; gate green.

### DP-13 ✅ — Command-line output-write gate (finding **H-7**) — Effort S — fixed in `29a3f8e` (incl. the TReportLoadResult leak on the fallback path); manual steps in TESTING.md §2.1 pending execution
- **Files:** `vittixdesigner/Frm.Main.pas:1215-1217` (silent blank fallback), `:1340-1356` (`FormCloseQuery` writes `FCmdLineOutputFile` unconditionally).
- **Bug:** if the input `.vrt` fails to load in component-editor mode, closing overwrites the source file with a blank report.
- **Fix:** add `FCmdLineInputLoaded: Boolean`; set it on successful load (both the normal and the tolerant fallback path at :1195-1213 — while there, fix the `TReportLoadResult` leak on that path: free `LR` before the fallback re-load); in `FormCloseQuery`, write the output only when `FCmdLineInputLoaded`. Surface the load failure with a non-fatal message (reuse the Problems panel load-diagnostics channel `FLoadDiagnostics`).
- **Test plan:** designer has no automated harness — verify manually per TESTING.md (open designer with a corrupt `.vrt` as cmdline input → close → file untouched; open with a valid file → file updated). Add the steps to TESTING.md §manual.
- **Done when:** manual repro shows the file is preserved; gate green.

### DP-14 — 96-DPI measurement correctness (finding **H-4**) — Effort L — ⛔ gated on OQ-1
- **Files:** `source/Vittix.Report.Engine.pas:566` (metafile canvas ref DC), `source/Vittix.Report.Export.VectorPDF.pas:1690` (`MeasureBmp`), `PageSettings.pas:10` (contract), all font-realization paths.
- **Bug:** the geometry model assumes 96-dpi pixels while fonts realize at the *screen's* DPI — wrapping, CanGrow, and PDF measurement drift on any scaled display.
- **Pre-step (spike, `[test]`/`[chore]`):** on a 125%/150% machine (or with `SetProcessDpiAwareness` forced in the demo), capture before/after renders of reports 05, 41, 43 — record the drift. If drift is invisible (app manifests are DPI-unaware), downgrade this item to post-v1.0 documentation and unblock the wave.
- **Fix direction (report §5 H-4):** create the engine metafile canvas and the VectorPDF measure bitmap against a forced 96-dpi reference (dedicated `CreateDC` with overridden `LOGPIXELS*`, or set `Font.PixelsPerInch := 96` on every measurement font). Keep it contained: one helper in `Vittix.Report.Utils` used by both sites.
- **Test plan:** golden test rendering a wrapped memo with a known font at forced-DPI reference canvas and asserting identical `MeasuredBottom` regardless of the machine's `Screen.PixelsPerInch` (mock via the helper's parameter). All 41 baselines must reconcile unchanged on the 96-dpi CI machine.
- **Done when:** helper lands; measurement independent of screen DPI (test proves); spike machine shows matching preview/PDF.

### DP-15 ✅ — Legacy qualified-field diagnostics (finding **H-2**) — Effort S — behavior-preserving — fixed in `7c9c9d9` + `a1c605f`
- **Files:** `source/Vittix.Report.Expressions.Compat.pas:206-224` (`FieldNameFromToken` discards the `[DS.Field]` qualifier).
- **Bug:** `[Orders.Company]` silently reads the *current* dataset's `Company` — wrong-dataset values in legacy reports.
- **Fix (compat-safe):** do **not** change resolution semantics (the compat evaluator is frozen by contract and differentially tested). Instead: when the qualifier names a dataset that differs from the active one (resolvable via `Context.Hooks.GetNamedDataSet`), emit a diagnostic through the same channel the designer Problems panel already consumes (`OutputDebugString` + a `TReportTraversalDiagnostics` counter), so the new full-analysis-driven workflow can turn hits into report migrations.
- **Test plan:** characterization addition in `Test.Vittix.Report.Phase4B.pas`: qualified token still resolves exactly as before (oracle unchanged) + diagnostic counter incremented.
- **Done when:** oracle tests stay green; diagnostic observable; gate green.

---

## 4. Wave 2 — Medium batch: rendering & data correctness `[fix]`

*Each is small; they batch naturally. Order doesn't matter.*

| ID | Finding | Item | Files / approach | Test | Effort |
|---|---|---|---|---|---|
| DP-16 ✅ (`edf8968`+`2ba0e6c`) | M-6 | Group-break Variant compare — strict identity (original Null-transition claim corrected: Delphi `<>` vs Null is truthy; the real defect was coercion, e.g. `1` vs `'1'` merging groups; `VarSameValue` alone still coerces numeric strings → explicit `VarType` guard) | `Engine.pas:878`: `VarIsNull(FLast) or VarIsNull(New) or (VarType(New) <> VarType(FLast)) or not VarSameValue(New, FLast)` | Engine tests: NULL-transition behavior pin (green before+after) + UDS type-flap test (red→green) | S |
| DP-17 ✅ (`bc5cbe8`+`b2a3e8b`) | M-7 | `DrawText` missing `DT_NOPREFIX` — `&` swallowed | `Objects.pas:819, 829, 901`, `Objects.Unknown.pas:102` | Bitmap render of `AT&T Co`: assert no glyph drop (pixel-width vs. `TextWidth('AT&T Co')` with prefix processing off) | S |
| DP-18 ✅ (`f07ee22`+`a85f2fe`) | M-8 | Crosstab counting pass under-measures; Draw unclipped (fixed: Draw clips to the object bounds; the counting-pass under-measure stays, content is cut at the designer bounds instead of bleeding) | `CrossTab.pas:356-357` vs `:370-481`: wrap Draw in `SaveDC`/`IntersectClipRect` to the measured rect (mirror Memo :1630-1666) | Crosstab taller than its band in a small band → no bleed into the next band (pixel probe below the band bottom is page background) | S |
| DP-19 ✅ (`1e68f6c`+`0e86204`) | M-10 | Chart/CrossTab/Unknown Draw lacked the `ShouldPrintObject` self-guard (original "invisible chart still prints" claim corrected: the engine path was already guarded by `DrawReportObjectWithHooks`; the real gap was direct-draw paths - the designer content layer painted suppressed charts with no hook context) | Added the same `ShouldPrintObject(Self, Context)` self-guard every other class carries to `Chart.pas`, `CrossTab.pas`, `Unknown.pas`; capture re-draw prechecked (`Engine.pas`) so the guard cannot re-evaluate PrintWhen at capture | Direct-draw suppression contract for all three classes (Visible/PrintWhen, pixel probe) + designer content-layer ink probe + engine capture pin (already green, pinned) | S |
| DP-20 ✅ (`b4ae47d`) | M-11 | Chart `DS.Bookmark` leak | `Chart.pas:120`: free via `finally` using `RestoreDataSetBookmark` (`LayoutBookmarks.pas`), matching SubReport (`Objects.pas:1868-1871`) | Covered by the DUnitX leak counter — assert no growth across renders of 44_chart fixture | S |
| DP-21 ✅ (`dbb058e`+`a8b8c79`) | M-9 (part 1) | Barcode scannability minimums (corrections: no repo `.vrt` stores Symbology — compatibility comes from the loader's missing-key default bsLegacy, deliberately unchanged; and the QR quiet zone was vertical-only — the horizontal axis had none at all) | Enforced ≥4-unit quiet zones both sides in the canvas variants and the engine capture (kept in step; full extraction is DP-31); ≥1px bar guard in all three 1D canvas drawers (capture floor geometry is already ≥1px); new-object default bsCode39 | Barcode unit tests: quiet-zone padding present; 100px Code39 renders every bar (was 48/60); designer-created object defaults to Code39; QR quiet zone ≥4 modules (QR rect geometry test updated to the 4-module spec). Visual: `06_barcode_test` fixture scans (manual; fixture renders Code39 via `b0c227a`) | M |
| DP-22 ✅ (landed with DP-08, `3e46df0`) | M-1 (part) | `TCommandManager` exception safety | `Undo.pas:276-297`: `DoCommand` frees the command if `Execute` raises; `UndoLast`/`RedoLast` re-add on failure or free — never leak or strand | Undo unit test: raising command doesn't leak (leak counter) and leaves stacks consistent | S |
| DP-23 ✅ (`e6f62df`+`d3d6263`) | M-1 (part 2) + M-2 | Undo memory growth (fixed: `FUndo` capped at 100, oldest dropped FIFO; `FRedo` implicitly bounded; plain click no longer pushes the no-op `TMultiMoveCommand` - the MouseUp path applies the MouseMove drag threshold) | Cap `FUndo` at N=100 (drop oldest); `DesignerInteractionController.pas`: apply the same drag-threshold used in `MouseMove` before pushing `TMultiMoveCommand` | Undo tests: cap enforced (150 → 100, exactly the survivors undoable); controller tests with a fake `IDesignerSurface`: plain click adds no history entry; real drag still adds one | S |
| DP-24 ✅ (`038f13c`) | M-19 | Atomic save + Save-As/close flow (fixed: temp-file write + swap; path adopted only after success; close decision explicit — cancelled Save-As or failed write keeps the designer open; the Abort/EAbort escape is gone, every prompt caller acts on an explicit result) | `Frm.Main.pas`: `SaveReportTo` (temp file + `TFile.Replace`/`TFile.Move`); `SaveReportAsInteractive` sets `FCurrentFile` only on success; `DialogHelpers.ConfirmSaveIfModified` now returns Boolean; close path uses explicit `CanClose := False` | Manual per TESTING.md 2.2 added (read-only dir → original intact, no `.tmp` left; cancelled Save-As → app stays open; New/Open/template/recent abort on cancel) | S |
| DP-25 ✅ (`038f13c`) | M-20 | Sample dataset written into install dir at startup (fixed: generated data cached under `%LOCALAPPDATA%\VittixDesigner`; load falls back to the cache; writes wrapped and non-fatal; corrupt cache regenerates) | `Frm.Main.pas` + `Frm.Main.SampleDataHelpers.pas`: cache-path helper, non-fatal write, guarded load | Manual per TESTING.md 2.3 added (no `reports\sample_data.json` → cache written under LOCALAPPDATA, nothing next to the exe; read-only location → starts; corrupt cache → regenerates) | S |
| DP-26 ✅ (`4e71171`+`ae38043`) | M-21 | Reject unknown future `.vrt` versions | `Serializer.pas:1399-1401`: `Version > 2` → structured error `UNSUPPORTED_VERSION` (forward-compat, never silently load as v2) | Serializer registry test: v3 document yields the precise error; v1/v2 unchanged | S |
| DP-27 ✅ (`0bc99a6`+`cc887b0`) | M-23 | Parser depth budget too small | `Language.pas:616`: raise `MaxParserDepth` 32 → 256 (stack-safety check still bounds recursion; ~8 increments per paren level today rejects legal 5-deep expressions) | Expression test: 12-level nested parens parse & evaluate | S |
| DP-28 ✅ (`756d819`+`27eeb60`) | M-24 | Locale-dependent number literals | `Tokenizer.pas:149-153`: invariant `TryStrToFloat` (`TFormatSettings.Invariant`); on failure emit `InvalidNumber` diagnostic instead of silent 0 | Tokenizer test with `DecimalSeparator=','` format settings: `1.5` and `1,5` both parse per spec, malformed emits diagnostic | S |
| DP-29 ✅ (`01a7377`+`f6bbde9`) | M-3 | Aggregate cache unbounded growth / O(n²) scan (fixed: row-scoped duplicates collapse into the most recent matching entry; everything else capped at 4096 FIFO; linear scan kept per plan) | `Engine.pas`: collapse in `StoreAggregateCache` via `MatchesExceptRowNumber`; cap `FAggregateCache` at 4096 entries; cache size sampled into `TReportTraversalDiagnostics.AggregateCacheEntries` | Engine tests: 10000 row-scoped evaluations leave 1 entry (was 10000) with same value and a same-row cache hit; 5000 distinct evaluations end at exactly 4096; Phase3/Phase5 cache semantics unchanged | S |

**Wave 2 exit:** full gate + one complete manual pass of `TESTING.md` (preview, print, exports, empty/large dataset, long text, images).

---

## 5. Wave 3 — Consistency & robustness `[fix]` (needs care / small design calls)

| ID | Finding | Item | Approach & cautions | Effort |
|---|---|---|---|---|
| DP-30 | M-14 | Vector PDF: ANSI text drawn in Helvetica while measured with the report font | `VectorPDF.pas:349-355, 749-759`: route ANSI text through the same embedded-font shaping path as Unicode (shaping accepts Latin trivially; the machinery — `EnsureUnicodeFontResource`/`TryShapeUnicodeTextLine` — already exists). Keep `/F1..F4` as fallback if shaping/embedding fails. Verify with 41-report suite + Indic tests; watch PDF size growth (subsetting already active) | M |
| DP-31 | M-13 | Extract export capture into per-object virtuals | `Engine.pas:1637-2370` → virtual `CaptureExportCommands(const Context)` on `TReportObject` subclasses; deletes the duplicated Code39 table (`Engine.pas:1684-1734`) and divergent geometry. **Freeze rule:** this refactor is attached to the DP-21 divergence bug — do it only as the follow-up that removes the second copy, with the preview-vs-PDF barcode test from DP-21 as the guard | L |
| DP-32 | M-18 | Preview memory multiplication + warning math | `Preview.pas:177-188`: keep the metafile only (lazy raster already exists in `TRenderPage`); `Frm.Preview.pas:518-542`: warning estimate counts retained bytes accurately. Synchronous render (P2) stays until post-v1.0 background work | S |
| DP-33 | M-12 | `TReportTextObject.Font` direct-reference write | `Objects.pas:150`: change to setter with `Assign` (CrossTab pattern, `CrossTab.pas:127-135`). **API-behavior change — justification required per Hard Rules:** current write path leaks the old font and aliases the caller's; no in-repo caller relies on aliasing. Note it in the commit body | S |
| DP-34 | M-22 | Engine destructor frees bookmarks on an externally-owned dataset | `Engine.pas:481-487`: guard by tracking "we hold bookmarks" AND clearing them in a new public `DetachDataSet` called by `TVittixReport` paths; document the lifetime contract on `TReportEngine.Create` XML doc | S |
| DP-35 | M-17 | Designer content metafile rebuilt per repaint; model Bounds mutated during paint | `DesignerControl.pas:1801, 2454, 1905-1911`: cache metafile by a dirty-generation counter; paint via DC transform instead of swapping `Obj.Bounds`. **Conditional:** schedule only if designer lag is observed in soak (it is perf, not correctness) | M |
| DP-36 | M-4 / M-5 | BUG-005 (UDS aggregates → fallback text) and legacy empty-range zeros | Both are frozen legacy semantics characterized by tests. **Decision needed from owner** (report §14.5): keep fully parked (current state) or add designer-Problem-panel diagnostics like DP-15. No code until decided | S |

---

## 6. Wave 4 — Soak & v1.0.0 release checklist

1. All Wave 0–3 items ✅ (or explicitly re-parked with a note here and in the report).
2. Freeze compliance audit: `git log --grep="^\[feature\]"` empty since `v1.0-freeze-start`.
3. Full manual pass of `TESTING.md` on a clean machine (not just the dev box).
4. Soak: run the 41-report strict suite + the designer interactively for 1–2 weeks of normal use; watch for new P0/P1 → they enter Wave 1 as new findings.
5. `VittixReport_FullCodeAnalysis.md` §5: mark every closed finding; move anything still open to Wave 5 with a reason.
6. Tag `v1.0.0`. Then (and only then) unpark Wave 5.

---

## 7. Wave 5 — Post-v1.0 backlog (⏸ parked, do not start before the tag)

From report §12 long-term + unscheduled Lows (each needs its own analysis-first pass):

- **Undo identity refactor:** replace pointer-holding commands with model-path identity (band index + object path) — structural fix beyond DP-08's clearing.
- **`Frm.Main.pas` decomposition:** finish the helpers migration; delete the duplicated command classes (`Frm.Main.Commands.pas` vs `Vittix.Designer.Commands.pas` — uses-order shadowing at `Frm.Main.pas:67/102`), the verbatim sample-dataset copy (:7377-7525), the 4× `BandTypeName`; move the 2,608-line `RunRuntimeEventCallbackDemo` (:2061-4669) out of the production form (a dead twin already exists in `Vittix.Designer.RuntimeDemo.pas`); delete the non-compilable orphan `Frm.Main.PropertyEditHelpers.pas`.
- **Background/progressive rendering** behind `IReportProgress` with cancellation; preview thumbnails; print page-range/collate.
- **BUG-005 proper fix** (aggregates over `TVittixUserDataSet`) per DP-36's decision.
- **RTL PDF text** (M-15): proper bidi placement instead of rasterization fallback.
- **Aggregate performance:** keyed (dictionary) cache, cached `TField` resolution, optional detail-dataset index to kill the O(master × detail) rescan (`Engine.pas:1320-1399`).
- **Schema evolution:** real version migration hooks once v3 semantics exist (DP-26 is the guard rail).
- **PDF polish:** compress content streams (M-16), per-glyph `Tj` batching, RTL, `/W` width-metric verification (report §14.2).
- **Designer UX:** single INI session (fewer open/write cycles), `%APPDATA%` hive, icon-index robustness, high-DPI designer pass if OQ-1 shows impact.
- **Designer test harness:** DUnitX coverage for `TCommandManager` + designer command classes (insurance for the undo contract) — could be pulled into Wave 1 if DP-08 lands without it.
- **Low items not scheduled above:** renderer print stretch mode decision, single-line text ellipsis/clip (`Objects.pas:847-849`), subreport per-draw reparse when `Hooks = nil` (`Objects.pas:1816-1821`), image copy duplication + HALFTONE stretching, `W1050` `CharInSet` cleanup (`Objects.pas:1081`), unused-variable hint sweep (`ScriptHost.Adapter` `Cmd_*` templates), `PropertyBridge` enum/-1 guard.

---

## 8. Open questions that gate items (from report §14)

| OQ | Question | Gates | Resolution path |
|---|---|---|---|
| OQ-1 | How visible is the 96-DPI drift on scaled displays (125%/150%), and which app manifests make it visible? | DP-14 | Spike on a scaled machine before DP-14; if negligible, park DP-14 with the evidence |
| OQ-2 | Do any real-world reports depend on legacy qualified-field discard / empty-range zeros? | DP-15, DP-36 | Search installed/user `.vrt` corpora; compat oracle keeps behavior frozen meanwhile |
| OQ-3 | `northwind.db` provenance — generated test data or real data? | DP-02 | Owner confirms; if real, remove immediately regardless of wave |
| OQ-4 | `LibSuffix` on packages — support multi-version side-by-side installs? | DP-04 | Owner decision; default defer |

---

## 9. Traceability matrix (finding → plan item)

| Report finding | Plan item(s) | Wave |
|---|---|---|
| C-1 | DP-08 (+ DP-22/DP-23 supporting) | 1 |
| H-1 | DP-09 | 1 |
| H-2 | DP-15 | 1 |
| H-3 | DP-10 | 1 |
| H-4 | DP-14 (⛔ OQ-1) | 1 |
| H-5 | DP-11 | 1 |
| H-6 | DP-12 | 1 |
| H-7 | DP-13 | 1 |
| M-1 | DP-22, DP-23 | 2 |
| M-2 | DP-23 | 2 |
| M-3 | DP-29 | 2 |
| M-4 / M-5 | DP-36 (decision) | 3 |
| M-6 | DP-16 | 2 |
| M-7 | DP-17 | 2 |
| M-8 | DP-18 | 2 |
| M-9 | DP-21 (+ DP-31 extraction) | 2 / 3 |
| M-10 | DP-19 | 2 |
| M-11 | DP-20 | 2 |
| M-12 | DP-33 | 3 |
| M-13 | DP-31 | 3 |
| M-14 | DP-30 | 3 |
| M-15 | Wave 5 (RTL) | 5 |
| M-16 | Wave 5 (PDF polish) | 5 |
| M-17 | DP-35 (conditional) | 3 |
| M-18 | DP-32 (+ Wave 5 background render) | 3 / 5 |
| M-19 | DP-24 | 2 |
| M-20 | DP-25 | 2 |
| M-21 | DP-26 | 2 |
| M-22 | DP-34 | 3 |
| M-23 | DP-27 | 2 |
| M-24 | DP-28 | 2 |
| Lows (hygiene, docs, packaging) | DP-01…DP-07 | 0 |
| Lows (behavioral, unscheduled) | Wave 5 | 5 |
| §12 long-term program | Wave 5 | 5 |

---

*Keep this document's status column current with every `[fix]`/`[test]` commit that
closes an item. When this plan and the report disagree, fix whichever is wrong —
the report is the source of truth on findings; this plan is authoritative on order
and completion state.*
