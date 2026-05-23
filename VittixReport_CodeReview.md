# Vittix Report Engine � Full Code Review
**40 units reviewed � May 2026**

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Bugs � Critical](#2-bugs--critical)
3. [Bugs � Significant](#3-bugs--significant)
4. [Bugs � Minor / Edge Cases](#4-bugs--minor--edge-cases)
5. [Refactor Planning](#5-refactor-planning)
6. [Missing Features](#6-missing-features)
7. [Unit-by-Unit Notes](#7-unit-by-unit-notes)

---

## 1. Architecture Overview

The codebase is a well-structured, 40-unit Delphi VCL report engine. The dependency graph is clean and intentional:

```
Context / Utils / Interfaces (leaf � no circular refs)
    ?
Objects / Bands / PageSettings / Model
    ?
Expressions / Aggregates / Serializer
    ?
LayoutCache / LayoutPagination / LayoutHelpers
    ?
Engine / Renderer / Export.PDF / Scripting / ScriptHost.Adapter
    ?
Preview / Component / Designer (top layer)
```

The "Core.*" alias units, the thin `Engine.Engine` and `Engine.Renderer` wrappers, and the `ObjectRegistry` wrapper are all pure forwarding shims � they add no logic and exist only as import convenience aliases. This is a sound pattern but creates visual noise.

**Positive highlights:**
- Two-pass engine (count pages ? render with resolved `[TotalPages]`) is correct.
- Bookmark management is explicit and generally safe.
- Undo/redo command pattern is clean; ownership contract is documented.
- `TVittixUserDataSet` abstraction mirrors FastReport's pattern well.
- `TReportScriptHostAdapter` is thorough � covers ~35 object properties.
- Debug diagnostics (`OutputDebugString` with deduplication) are well-designed.
- `DataSetSupportsBookmarks` probe is correct; avoids the unreliable `CanBookmark`.

---

## 2. Bugs � Critical

### BUG-C1 � `TVittixReport.Execute` � `NamedDS` not passed to engine

**File:** `Vittix.Report.Component.pas` � `Execute` procedure

```pascal
Renderer.Render(Model, Primary);   // ? NamedDS is built but never forwarded
```

`BuildNamedDataSets` creates `NamedDS` which is freed in the `finally` block, but `TReportRenderer.Render` only accepts `(Model, DataSet)` � it creates its own `TReportEngine` with no named datasets. Any band with a `DataSetName` set gets `nil` data at runtime.

**Fix:** `TReportRenderer.Render` needs an overload that accepts `TDictionary<string, TDataSet>`, or `Execute` should build a `TReportEngine` directly (bypassing `TReportRenderer`) as `ExportToPDF` already does.

---

### BUG-C2 � `TVittixReport.Print` � `NamedDS` not passed, `InvokePreviewAction` called on wrong object

**File:** `Vittix.Report.Component.pas` � `Print` procedure

```pascal
InvokePreviewAction(Renderer, 'Print');  // ? Renderer has no 'Print' method with this signature
```

`TReportRenderer` does have a `Print` method, but `InvokePreviewAction` uses `APreview.MethodAddress` and passes `TObject`, making it RTTI-dependent. More critically, `NamedDS` is built and leaked (it's freed in `finally`) but never passed to the engine, same as BUG-C1.

**Fix:** Call `Renderer.Print` directly. Build and pass `NamedDS`.

---

### BUG-C3 � `TReportEngine.ExecutePass` � `FIsRenderingPass` assigned wrong value

**File:** `Vittix.Report.Engine.pas`

```pascal
FIsRenderingPass := AReportProgress;  // ? Pass 1 has AReportProgress=False ? FIsRenderingPass=False
                                       //   so OnBeforeBand/OnAfterBand never fire on pass 1 (OK)
                                       //   but pass 2 has AReportProgress=True ? FIsRenderingPass=True
```

Actually this is fine for the two-pass intent, **but** the naming is confusing and there is a real bug: in `Prepare`, pass 1 is called with `AReportProgress=False`, which means `FIsRenderingPass=False`. On pass 1, `SetReportObjectRenderHooks` still gets called (because `FIsRenderingPass` check is done *after* the call to `SetReportObjectRenderHooks` for pass 1 with `ClearReportObjectRenderHooks`). The real bug is:

In pass 1 (`AReportProgress=False`), `ClearReportObjectRenderHooks` is called, which is correct. But `SetReportNamedDataSets` is called in **both** passes regardless, meaning named datasets are set up during the page-count pass. If a `TReportSubReportObject.Draw` is called during pass 1 (via `TReportBand.Draw` ? children), it will try to access live datasets during the counting pass. This is incorrect for any report that uses `TReportSubReportObject`.

**Fix:** In pass 1, skip rendering bands that contain subreport objects, or ensure `Draw` is not called on pass 1. The engine already skips band *drawing* (via `FIsRenderingPass` gating `OnBeforeBand`), but `ABand.Draw` is still called in `PrintBand` regardless � it just won't fire the event hooks.

---

### BUG-C4 � `TReportEngine.Prepare` � hard requirement for `btMasterData` band breaks reports without data

**File:** `Vittix.Report.Engine.pas`

```pascal
if not Assigned(FMasterBand) then
  raise EReportException.Create('Report must have a MasterData band');
```

`CacheReportBands` in `LayoutCache` promotes the first `btDetail` band to master if no master exists. But the engine then raises if master is still `nil`. A report that is pure static (title + summary, no data) is a valid use case but currently impossible.

**Fix:** Remove the hard raise. If `FMasterBand` is nil and the dataset is nil/inactive, skip the data loop entirely and still print title/header/footer/summary.

---

### BUG-C5 � `TDeleteObjectsCommand.Rollback` � index calculation is wrong

**File:** `Vittix.Report.Undo.pas`

```pascal
for BufIdx := FBuffer.Count - 1 downto 0 do
begin
  EntryIdx := High(FEntries) - BufIdx;   // ? This mapping is incorrect when Count > 1
```

`Execute` inserts into `FBuffer` in reverse order of `FEntries` (iterates `High(FEntries) downto 0`). So `FBuffer[0]` corresponds to `FEntries[High(FEntries)]`, not `FEntries[High(FEntries) - 0]` as the rollback assumes.

The correct mapping should be: `EntryIdx := High(FEntries) - (FBuffer.Count - 1 - BufIdx)`, which simplifies to `EntryIdx := BufIdx`.

**Fix:**
```pascal
for BufIdx := FBuffer.Count - 1 downto 0 do
begin
  EntryIdx := BufIdx;   // FBuffer[i] was placed from FEntries[High - (Count-1-i)]
  // recalculate correctly based on execute order
```

Actually the cleanest fix: during `Execute`, store `(Band, OrigIndex)` pairs in a parallel list so `Rollback` uses `FEntries[i].OrigIndex` directly without inference.

---

### BUG-C6 � `TReportBand.Draw` � `DrawReportObjectWithHooks` called but band is not inside engine context at design-time

**File:** `Vittix.Report.Bands.pas`

`TReportBand.Draw` calls `DrawReportObjectWithHooks` for each child. This function checks `GBeforeObjectPrint` / `GAfterObjectPrint` global hooks. These globals are set/cleared by the engine via `SetReportObjectRenderHooks` / `ClearReportObjectRenderHooks`. During designer preview (via `TReportRenderer`), the hooks are never set, so this is fine. But if `Draw` is ever called from the designer canvas paint path, the hooks from a previous engine run could still be live (since `ClearReportObjectRenderHooks` is called in `ExecutePass` finally, not in `Renderer.Render`). This is a latent race condition.

**Fix:** Call `ClearReportObjectRenderHooks` at the start of `TReportRenderer.Render`.

---

## 3. Bugs � Significant

### BUG-S1 � `EvalSimpleMath` � incorrect loop termination (off-by-one)

**File:** `Vittix.Report.Expressions.pas`

```pascal
while i < Length(Parts) - 1 do
begin
  Op := Parts[i][1];
  // uses Parts[i+1]
  Inc(i, 2);
end;
```

The last operator+operand pair is skipped when `Length(Parts)` is even (e.g., `"1 + 2 + 3"` ? Parts = `["1","+","2","+","3"]` ? Length=5, loop exits when i=3 because `3 < 4`, processes i=3 (`+` and `3`) correctly). Actually the issue is when input is `"1 + 2"` ? Parts=`["1","+","2"]`, Length=3, loop condition `i < 2` ? enters with i=1, processes correctly, exits. This appears correct but the condition should be `i <= Length(Parts) - 2` for clarity. The real bug is the arithmetic parser splits on **all** `-` characters including those in negative numbers: `"10 - -5"` ? `["10"," - ","-","5"]`, producing wrong results. Negative number operands are not handled.

**Fix:** Use a proper recursive-descent parser or at minimum handle unary minus.

---

### BUG-S2 � `TReportTextObject.Draw` � `AutoSize` mutates `FBounds` permanently

**File:** `Vittix.Report.Objects.pas`

```pascal
if FAutoSize and FWordWrap then
begin
  TxtH := DrawText(..., DT_CALCRECT);
  if TxtH > 0 then
    FBounds.Bottom := FBounds.Top + TxtH + ...;  // ? Permanent mutation
```

This permanently mutates the object's bounds during every Draw call. On a second render pass (or if the object is redrawn with different data), the bounds from the previous render are used as the starting point, causing cumulative drift. The engine's `PrintBand` already adjusts children's `Bounds` temporarily via `AdjustedObjs/OriginalBounds` for CanGrow bands, but `AutoSize` bypasses that mechanism.

**Fix:** Compute the auto-size in `MeasuredBottom` (already overridden on `TReportMemoObject`), not in `Draw`. Have `Draw` use a local rect without mutating `FBounds`.

---

### BUG-S3 � `TVittixReport.ComponentEditor` � BOM detection uses wrong character codes

**File:** `Vittix.Report.ComponentEditor.pas`

```pascal
if (Length(JsonOut) >= 3) and
   (JsonOut[1] = #$00EF) and (JsonOut[2] = #$00BB) and (JsonOut[3] = #$00BF) then
```

In Delphi's UnicodeString (UTF-16), the UTF-8 BOM bytes `EF BB BF` when read as `TEncoding.UTF8` are already decoded before you see them as characters. The byte-sequence check `#$00EF, #$00BB, #$00BF` will never match a properly decoded Unicode string � it would only match raw bytes misread as Unicode chars. The `#$FEFF` (U+FEFF) BOM check above it is correct.

The same incorrect BOM check appears in `TReportSerializer.LoadFromJSON`.

**Fix:** Remove the three-byte sequence checks. `TFile.ReadAllText(..., TEncoding.UTF8)` handles the BOM transparently; if a BOM is present it is consumed by the encoder. Only retain the `#$FEFF` check as a safety net.

---

### BUG-S4 � `TReportImageObject.Draw` � image cache keyed on path string, not invalidated on row change

**File:** `Vittix.Report.Objects.pas`

```pascal
FCachedImageAttempted: Boolean;
FCachedImagePath: string;
```

The cache is never reset between rows. If row 1 has `ImagePath = 'a.png'` and row 2 has `ImagePath = ''`, the empty-path branch correctly sets `FPicture.Assign(nil)`. But if row 3 has `ImagePath = 'a.png'` again, the cache is valid � correct. However if the underlying file on disk changes between report runs (same path, different content), the stale cache is used. More critically, the `FCachedImageAttempted` flag is never reset between `TReportEngine.Prepare` calls. Because `TReportObject` instances are owned by `TReportModel` which is deserialized fresh per `Execute` call, this is actually safe in practice. But if someone calls `TReportEngine.Prepare` twice on the same model (which is technically supported by the API), the stale `FCachedImagePath` can cause a miss.

**Fix:** Reset `FCachedImageAttempted := False` in a `BeforeRender` hook, or key the cache on both path + file modification time.

---

### BUG-S5 � `TReportEngine.PrintBand` � `AdjustedObjs` restore loop runs in finally but canvas is already restored

**File:** `Vittix.Report.Engine.pas`

```pascal
SaveDC(FCanvas.Handle);
try
  SetViewportOrgEx(...);
  ABand.Draw(FCanvas, Ctx);
  ...
finally
  for var I := AdjustedCount - 1 downto 0 do
    AdjustedObjs[I].Bounds := OriginalBounds[I];   // ? GOOD: runs before RestoreDC
  RestoreDC(FCanvas.Handle, -1);
end;
```

Actually this is correct � the bounds restore runs before `RestoreDC`. No bug here; noting for clarity.

---

### BUG-S6 � `TReportPreview.Paint` � margin overlay drawn **before** the white page rectangle

**File:** `Vittix.Report.Preview.pas`

```pascal
if FShowMarginOverlay then
begin
  Canvas.Brush.Color := $00FAFAF0;
  Canvas.FillRect(ContentR);    // ? drawn first
  ...
end;

Canvas.Brush.Style := bsSolid;
Canvas.Brush.Color := clWhite;
Canvas.Rectangle(R);             // ? white page drawn on top, covers ContentR
Canvas.StretchDraw(R, PageBmp);
```

The content-area background fill and its border line are painted before the white page and the bitmap, so they are immediately covered and never visible.

**Fix:** Move the margin overlay drawing to **after** `Canvas.StretchDraw(R, PageBmp)`.

---

### BUG-S7 � `TReportEngine.OpenGroupsForBreak` � `ColumnHeader` printed inside group open loop without space check

**File:** `Vittix.Report.Engine.pas`

```pascal
if Assigned(FColumnHeaderBand) then
  PrintBandWithSpaceCheck(FColumnHeaderBand);
```

`PrintBandWithSpaceCheck` calls `EnsurePageSpaceForBand` which itself calls `PrintPageHeader` on a new page. This is correct. However, it does NOT pass `True` for `PrintColumnHeader` in `EnsurePageSpaceForBand` � so if the column header forces a page break, the *new* page will not get a column header. This is a subtle missing re-print.

**Fix:** After every `StartNewPage` + `PrintPageHeader`, also print the column header if one exists.

---

### BUG-S8 � `TReportBarcodeObject` � duplicates the entire `DebugLogDataFieldIssue` function

**File:** `Vittix.Report.Objects.Barcode.pas`

The file copy-pastes the `DebugLogDataFieldIssue` proc, `GDataFieldDiagSeen`, `GDataFieldDiagCount`, and `DataSetStateText` verbatim from `Objects.pas`. This means there are now **two independent diagnostic counters and seen-sets**. The 200-message cap and deduplication work independently, so a field missing from a barcode object will not deduplicate against the same miss from a text object.

**Fix:** Move the shared diagnostic helpers into `Vittix.Report.Utils` and call from both units.

---

### BUG-S9 � `TReportObjectRegistry` / `Vittix.Report.Objects` � registry not thread-safe for read during write

**File:** `Vittix.Report.Objects.pas`

`EnsureRegistryInitialized` is not thread-safe:

```pascal
if not Assigned(GRegistryCS) then
  GRegistryCS := TCriticalSection.Create;  // ? TOCTOU race
if not Assigned(GRegistry) then
  GRegistry := TList<TReportObjectClass>.Create;
```

Two threads could both pass the `not Assigned` check and both create a `TCriticalSection`. The second creation leaks.

**Fix:** Use `TInterlocked.CompareExchange` or initialize in `initialization` section directly.

---

## 4. Bugs � Minor / Edge Cases

### BUG-M1 � `TReportAggregates` � `COUNT` increments for any non-null value but does not track `Count` for `SUM` correctly

In the SUM branch, `Count` is never incremented, so `AVG` (which reuses `Sum/Count`) works because `Count` is incremented only in the `AVG` branch. But if someone calls `AVG` on an all-null dataset, `Count` stays 0 and the final `Sum / Count` division guard catches it. Fine. However `SUM` leaves `Count=0` which is correct since `SUM` doesn't use it. This is not a bug but the code is misleading � `Count` means different things in different branches.

### BUG-M2 � `TReportDesignerControl` � `DrawBandZones` hardcodes `+14` header offset in band rect calculation

`BL.Y + BL.Height + 14` � the `14` is the `BAND_HDR_H` constant but is used literally instead of as the constant, creating a maintenance risk if the constant is ever changed.

### BUG-M3 � `TReportEngine.ProcessMasterDataLoop` � `DisableControls` / `EnableControls` not exception-safe for `FDataSet.First`

```pascal
FDataSet.DisableControls;
try
  FDataSet.First;      // ? If this raises, controls remain disabled
  while not FDataSet.Eof do ...
finally
  FDataSet.EnableControls;
end;
```

If `FDataSet.First` raises (e.g., network error), `EnableControls` is still called in `finally`, which is correct. This is actually fine. Not a bug.

### BUG-M4 � `TVittixReportPreview.SetZoomPercent` � silent no-op on out-of-range value

```pascal
if Value < 10  then Exit;
if Value > 400 then Exit;
```

Callers like `ZoomOut` subtract 10 and can go below 10 silently. The UI will appear to do nothing with no feedback. `ZoomIn`/`ZoomOut` should clamp, not silently ignore.

### BUG-M5 � `TReportSerializer.JSONToObject` � unhandled `TReportBarcodeObject` and `TReportTableObject`

Neither `TReportBarcodeObject` nor `TReportTableObject` have serializer branches in `ObjectToJSON` / `JSONToObject`. Their custom properties (`Value`, `ShowText`, `BarColor`, `Rows`, `Cols`, `HeaderRows`, etc.) are not persisted to `.vrt` files. Only the base class properties (`Bounds`, `Name`, `Visible`) survive a serialize ? deserialize round-trip.

**Fix:** Add dedicated `if Obj is TReportBarcodeObject then` and `if Obj is TReportTableObject then` branches in both functions.

### BUG-M6 � `TReportTableObject.Draw` � does not check `PrintWhen` / `Visible` via `ShouldPrintObject`

```pascal
procedure TReportTableObject.Draw(C: TCanvas; const Context: TExpressionContext);
begin
  if not Visible then Exit;  // ? only checks Visible, not PrintWhen
```

Every other object class calls `ShouldPrintObject(Self, Context)` which also evaluates `PrintWhen`. `TReportTableObject` bypasses this.

### BUG-M7 � `TReportLineObject.Draw` � similarly does not call `ShouldPrintObject`

Same as BUG-M6 for `TReportLineObject`.

### BUG-M8 � `TExpressionContext` � `GroupStart`/`GroupEnd` bookmarks are raw pointers with no ownership documentation

`TExpressionContext` is a record passed by value. If the engine frees `FGroupStartBookmark` while an aggregate function holds a copy of the context record, the copied bookmark pointer becomes dangling. Currently safe because aggregates are only called inside `PrintBand` which is inside the engine loop, but fragile.

### BUG-M9 � `TReportSerializer.SaveToJSON` � `OnBeforePrint`/`OnAfterPrint` not saved for non-band objects

```pascal
if not (Obj is TReportBand) then
begin
  if Trim(Obj.OnBeforePrint) <> '' then
    Result.AddPair('OnBeforePrint', Obj.OnBeforePrint);
  if Trim(Obj.OnAfterPrint) <> '' then
    Result.AddPair('OnAfterPrint', Obj.OnAfterPrint);
end;
```

This uses the conditional `Trim(...) <> ''` pattern (omit if blank). But `JSONToObject` uses `O.GetValue<string>('OnBeforePrint', '')` with a default � meaning it reads back fine. This is consistent and correct. Not a bug; just an asymmetric pattern worth noting.

### BUG-M10 � `TReportScriptHostAdapter.ExecuteSingleBeforeObject` � `background` key sets `TReportTextObject` even on `TReportImageObject`

```pascal
if Key = 'background' then
begin
  if not (AObject is TReportTextObject) and not (AObject is TReportImageObject) then
  begin ... Result.Unsupported ... Exit; end;
  try
    C := StringToColor(Value);
    TReportTextObject(AObject).Background := C;     // ? cast to TReportTextObject unconditionally
    TReportTextObject(AObject).Transparent := False; // ? even if AObject is TReportImageObject
```

If `AObject` is a `TReportImageObject` (not a subclass of `TReportTextObject`), the forced cast `TReportTextObject(AObject)` writes to the wrong memory layout. `TReportImageObject` does not inherit from `TReportTextObject`.

**Fix:** Add an `else if AObject is TReportImageObject then` branch for image-specific handling.

---

## 5. Refactor Planning

### R1 � Eliminate global mutable state from `Vittix.Report.Objects`

`GBeforeObjectPrint`, `GAfterObjectPrint`, and `GNamedDataSets` are unit-level globals. This means only one engine can run at a time (thread-safety issue) and the state bleeds between calls. These should be passed through `TExpressionContext` or via a per-render context object.

**Proposed approach:** Add `NamedDataSets: TDictionary<string, TDataSet>` and `BeforeObjectPrint`/`AfterObjectPrint` to `TExpressionContext` (or a new `TRenderContext` record). The engine passes a fully populated context to every `Draw` call. Remove all three globals.

### R2 � Unify `TReportRenderer` with `TReportEngine` API

`TReportRenderer.Render` creates its own `TReportEngine` internally, losing named datasets, progress, and all engine events. As a result:
- `TVittixReport.Execute` has to work around this (BUG-C1).
- Engine events (`OnBeforeBand`, `OnAfterBand`, etc.) are inaccessible from the preview path.

**Proposed approach:** `TReportRenderer.Render` should accept a fully configured `TReportEngine` parameter (already prepared), and simply iterate `Engine.Pages` to render bitmaps. The caller remains responsible for engine creation and configuration.

### R3 � Extract `TPropertyChangeCommand` RTTI context into instance field

```pascal
procedure TPropertyChangeCommand.Execute;
var ctx: TRttiContext; p: TRttiProperty;
begin
  ctx := TRttiContext.Create;      // ? created and destroyed every call
```

`TRttiContext` is cheap to create but allocating it per `Execute`/`Rollback` call adds unnecessary overhead when an undo sequence replays many property changes. Cache one `TRttiContext` per `TCommandManager` or use a module-level context.

### R4 � Replace `TDesignerInteractionState.Mode: Integer` with `TDesignerMode` typed field

`FInteractionState.Mode` is stored as `Integer` and cast to `TDesignerMode` everywhere. There is no reason for the type erasure � `TDesignerMode` is defined in `DesignerControl`. Move `TDesignerMode` to `DesignerInteractionController` so the state record can use it directly.

### R5 � Consolidate the three "Core.*" alias units

`Vittix.Report.Core.Bands`, `Vittix.Report.Core.Model`, `Vittix.Report.Core.Objects` are pure type-alias shims. They add 3 files, 3 compilation units, and 3 dependency edges for zero functional benefit. If the intent is to provide a stable public API surface, document this in a comment but otherwise merge them into a single `Vittix.Report.Core` unit.

### R6 � `TReportScriptHostAdapter` � replace the 700-line if-else chain with a dispatch table

`ExecuteSingleBeforeObject` is a 700-line chain of `if Key = 'xxx' then ... Exit` branches. This is hard to extend and impossible to enumerate at runtime. Replace with a `TDictionary<string, TScriptCommandProc>` where each key maps to a small anonymous method or procedure reference. This makes adding new script properties a single registration call.

### R7 � `TVittixReport.Execute` � preview form should be a standalone `TVittixReportPreviewForm` class

The 80-line inline TForm construction in `Execute` (creating Toolbar, 9 buttons, Preview control all in code) should be a proper `TForm` descendant in its own unit with a DFM. This would allow the form to be customized, themed, and localized without modifying `Component.pas`.

### R8 � `TReportMemoObject` HTML parsing � `ParseMemoRuns` is a hand-rolled mini-parser

It handles `<b>`, `<i>`, `<u>`, `<br>`, `<p>` tags only, with no attribute support, no nesting depth tracking, and no unknown-tag passthrough (unknown tags are included verbatim). This is fine for the current scope, but should be documented as "limited HTML subset" and its limitations commented clearly, particularly that `<span style="...">` and `<font color="...">` are not supported.

### R9 � `TReportSerializer` � `ObjectToJSON`/`JSONToObject` should use a registration pattern

Currently a long `if Obj is TXxx then` chain. Add an `ObjectSerializer` registration system parallel to the `RegisterReportObject` system, so custom object types registered via `IReportPlugin` can also provide their own serialization without modifying `Serializer.pas`.

---

## 6. Missing Features

### MF1 � No `[TotalPages]` support in Pass 1 (single-pass option)

The two-pass approach works but doubles execution time on large datasets. There is no option for a single-pass render where `[TotalPages]` is simply not resolved (shown as `?` or `0`). This matters for large Firebird result sets where a full table scan twice is expensive.

### MF2 � No `CanGrow`/`CanShrink` for Group Header/Footer bands

`CanGrow` and `CanShrink` on `TReportBand` are respected in `PrintBand` via `ComputeEffectiveBandHeight`. However, when `EnsurePageSpaceForBand` is called for group bands in `OpenGroupsForBreak` and `CloseGroupsForBreak`, it calls `PrintBandWithSpaceCheck` which does call `ComputeEffectiveBandHeight` � so this actually works. But the *engine's* `EnsurePageSpaceForBand` for the master data band calls `ComputeEffectiveBandHeight` only for the master band, not the combined height of master + any detail bands. A master + detail combination that together overflow a page will not trigger a new page proactively.

### MF3 � No page-break-before / page-break-after on individual objects

Objects have `PrintWhen` but no `PageBreakBefore`/`PageBreakAfter`. Forcing a page break at a specific content point requires a workaround band.

### MF4 � `TReportPDFExporter` � relies on "Microsoft Print to PDF" only

This is fragile (requires Windows 10+, may not be present in server/CI environments, may prompt the user on some Windows configurations). There is no alternative path: no Skia, no GDI+ metafile-to-PDF conversion, no third-party library integration point. The `IReportExporter` interface exists � a proper PDF exporter implementation is needed.

### MF5 � No export to XLSX, HTML, or plain text

`IReportExporter` interface is defined and `TReportPDFExporter` implements it, but no other exporters exist. Vittix already has a multi-format DBGrid export engine � the same streaming patterns should be applicable here.

### MF6 � `TVittixUserDataSet` � engine never actually calls it

`TVittixUserDataSet` has a clean API (`First`, `Next`, `Eof`, `GetValue`) but `TReportEngine` never calls these methods. The engine works exclusively with the raw `TDataSet` extracted via `FUserDataSets[0].DataSet`. The custom-event path (`OnFirst`, `OnNext`, `OnEof`, `OnGetValue`) is completely bypassed by the engine. This makes the entire non-dataset data source story (arrays, JSON, REST APIs advertised in the component's docstring) non-functional.

**Fix:** The engine must be refactored to iterate via `TVittixUserDataSet.First/Next/Eof` and resolve field values via `TVittixUserDataSet.GetValue`. This is a significant change but is the component's primary value proposition.

### MF7 � No `[RecNo]` / `[RowNumber]` tracking in engine context

`TExpressionContext` stores `PageNumber` and `TotalPages` but has no row counter. The expression engine does resolve `[RecNo]` via `Context.DataSet.RecNo`, which works for TDataSet but returns 0 or -1 for many drivers and is meaningless for custom UserDataSet sources. A proper `RowNumber: Integer` field in the context, incremented by the engine, would be reliable across all data sources.

### MF8 � No conditional formatting at the band level

Bands have `CanGrow`/`CanShrink`/`BackColor`/`PrintWhen` but no runtime color/style conditions equivalent to what `TReportTextObject` has (`FontColorCondition`, `BackgroundCondition`). A band-level `BackColorCondition` expression would allow alternating row colors without scripting.

### MF9 � `TVittixReportPreview` � no scrolling for tall pages at high zoom

The preview renders the page centered in `ClientRect` with `R.Top = 10`. At 200% zoom an A4 page is 2244px tall � but the preview control has no scrollbar. Content below the control's visible area is simply clipped.

### MF10 � Designer has no band-add UI

The designer supports inserting objects (`BeginInsertObject`) but has no exposed method to add a new band. `DeleteSelected` can delete the active band, but `AddBand(BandType: TReportBandType)` does not exist on `TVittixReportDesigner`. The designer application must manipulate `Report.Objects` directly.

### MF11 � No print preview page thumbnails / page navigator

`TVittixReportPreview` has Prev/Next page navigation but no thumbnail strip. For multi-page reports, jumping to a specific page requires clicking Prev/Next repeatedly.

### MF12 � No report parameters / input variables

There is no mechanism for runtime report parameters (e.g., date range, filter criteria) that the user enters before the report runs. FastReport accomplishes this with `TfrxReportPage` parameters. Vittix has no equivalent.

### MF13 � `TReportBarcodeObject` � barcode encoding is a visual approximation only

The barcode renderer iterates character bytes and draws vertical lines based on bit patterns. This is not a recognized barcode standard (Code 39, Code 128, EAN-13, QR, etc.). For production GST invoice use, a real barcode encoding library is needed, or at minimum, a pluggable `IBarcodeEncoder` interface so the application can supply one.

### MF14 � No cross-band / cross-page line objects

`TReportLineObject` is band-scoped. There is no way to draw a continuous vertical line spanning multiple bands (e.g., a left-border rule on every row). This is a common invoice layout requirement.

---

## 7. Unit-by-Unit Notes

| Unit | Status | Key Notes |
|---|---|---|
| `Context` | Clean | Record design is correct; consider adding `RowNumber` (MF7) |
| `Utils` | Clean | `DataSetSupportsBookmarks` probe is the right approach |
| `Interfaces` | Clean | `IReportProgress` is well-designed |
| `PageSettings` | Clean | Preset table at 96 DPI is correct for screen; add `MM_TO_PX` helper for metric-unit margin entry |
| `Model` | Clean | `FieldNames`/`DataSetNames` TStringList is functional; consider `TList<TFieldDef>` for richer field metadata |
| `Objects` | Significant bugs | BUG-S2, BUG-C6, BUG-S9, BUG-M2, BUG-M10; globals R1 |
| `Objects.Barcode` | Bugs | BUG-S8 (dup debug code), BUG-M13 (not real barcode), BUG-M5 (not serialized) |
| `Objects.Table` | Bugs | BUG-M5 (not serialized), BUG-M6 (no PrintWhen) |
| `Bands` | Minor | BUG-M2 hardcoded 14 offset; `DrawReportObjectWithHooks` hook latency (BUG-C6) |
| `Expressions` | Bugs | BUG-S1 (negative numbers in math); comparison operator chain could mis-fire on `<>` vs `<` ordering (currently `<>` is checked before `<` � correct) |
| `Aggregates` | Clean | Bookmark leak fixed; `COUNT` vs `AVG` count variable reuse is confusing but correct |
| `Serializer` | Bugs | BUG-S3 (BOM check), BUG-M5 (Barcode/Table not serialized), R9 |
| `LayoutCache` | Clean | Group header/footer sort is correct |
| `LayoutHelpers` | Clean | |
| `LayoutPagination` | Clean | Simple and correct |
| `Engine` | Critical bugs | BUG-C3, BUG-C4, BUG-S7; two-pass logic is sound |
| `Engine.Engine` | Shim | Alias only |
| `Engine.Renderer` | Shim | Alias only |
| `Renderer` | Bug | BUG-C1 (NamedDS lost); R2 |
| `Export.PDF` | Significant | MF4 (Print to PDF only); `ShowMessage` in export path is inappropriate for headless use |
| `DataSources` | Scaffold | `TJsonReportDataSource`, `TCsvReportDataSource`, `TRestReportDataSource` all raise `NotImplemented`; MF6 integration missing |
| `UserDataSet` | Not wired | Clean design; MF6 (engine never calls its methods) |
| `Scripting` | Thin | Just event dispatch; no built-in script execution |
| `ScriptHost.Adapter` | Bug | BUG-M10; R6 (if-else chain) |
| `CommandDispatcher` | Clean | Pure delegation; could be removed in favour of direct `TCommandManager` usage |
| `Undo` | Critical bug | BUG-C5 (Rollback index mapping) |
| `DesignerControl` | Bug | BUG-M2, BUG-S6; R4, R7 |
| `DesignerInteraction` | Clean | Good extraction of hit-testing logic |
| `DesignerInteractionController` | Clean | State record; R4 |
| `SelectionHelpers` | Clean | Well-factored |
| `LayoutHelpers` | Clean | |
| `PropertyBridge` | Clean | RTTI bridge works; does not handle `TColor` or `TFont` sub-properties |
| `Preview` | Bug | BUG-S6 (margin overlay order); MF9 (no scroll); MF11 |
| `Component` | Critical bugs | BUG-C1, BUG-C2; R7 |
| `ComponentEditor` | Bug | BUG-S3 (BOM check); otherwise sound |
| `Reg` | Clean | |
| `Toolbox` | Clean | `ToolImageNameForClass` order matters (more-specific classes checked first) � correct |
| `Core.Bands` | Shim | R5 |
| `Core.Model` | Shim | R5 |
| `Core.Objects` | Shim | R5 |
| `ObjectRegistry` | Shim | Three thin wrappers; could inline |

---

## Priority Summary

| Priority | Count | Key items |
|---|---|---|
| **Fix immediately** (crashes / data loss) | 6 | BUG-C1 through BUG-C6 |
| **Fix before release** (wrong output) | 8 | BUG-S1 through BUG-S8 |
| **Fix soon** (edge cases) | 10 | BUG-M1 through BUG-M10 |
| **Refactor** (maintainability) | 9 | R1 through R9 |
| **New features** (functionality) | 14 | MF1 through MF14 |

The single highest-impact fix is **BUG-C1 + BUG-C6 + MF6**: wiring `TVittixUserDataSet` through to the engine and passing `NamedDS` correctly. Without this, multi-dataset reports and all custom data sources are silently broken.
# Fixed Bugs

- BUG-C1 fixed in commit `0d49ea9` (`fix(renderer): forward named datasets to preview engine`).
- BUG-C2 fixed in commit `4e412d7` (`fix(component): forward named datasets during print`).
- BUG-C3 fixed in commit `ba7104d` (`fix(engine): skip subreport traversal during count pass`).
- BUG-C4 fixed in commit `8cbab36` (`fix(engine): allow static reports without master data`).
- BUG-C5 fixed in commit `91ee3ac` (`fix(undo): restore deleted objects by original order`).
- BUG-C6 fixed in commit `d12f962` (`fix(renderer): clear stale object render hooks`).
- BUG-S1 fixed in commit `0c84e61` (`fix(expressions): handle unary signs in math parser`).
- BUG-S2 fixed in commit `911b466` (`fix(objects): avoid mutating text bounds during draw`).
- BUG-S3 fixed in commit `a1a339d` (`fix(serializer): remove invalid utf8 bom checks`).
- BUG-S4 fixed in commit `d724f97` (`fix(objects): reset image cache for render passes`).
- BUG-S6 fixed in commit `99ab2a4` (`fix(preview): draw margin overlay above page bitmap`).
- BUG-S7 fixed in commit `4c4728e` (`fix(engine): preserve column header on group page breaks`).
- BUG-S8 fixed in commit `b20d1ac` (`fix(utils): share data field diagnostics`).
- BUG-S9 fixed in commit `076b5c4` (`fix(objects): initialize registry deterministically`).
- BUG-M2 fixed in commit `febc622` (`fix(designer): use band header constant for layout`).
- BUG-M4 fixed in commit `e17daa0` (`fix(preview): clamp zoom percentage`).
- BUG-M5 fixed in commit `fc4a7ab` (`fix(serializer): persist barcode and table properties`).
- BUG-M6 fixed in commit `469956d` (`fix(table): honor PrintWhen during draw`).
- BUG-M8 fixed in commit `ae96ad2` (`docs(context): document bookmark lifetime`).
- BUG-M10 fixed in commit `e6fab79` (`fix(script): reject image background assignment`).
