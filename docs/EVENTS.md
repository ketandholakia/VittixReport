# VittixReport Events

## Table of Contents
- [Event / Script Policy](#event--script-policy)
- [Runtime Lifecycle Callback Wiring](#runtime-lifecycle-callback-wiring)
- [Quick Start Callback Template](#quick-start-callback-template)
- [Persisted Event Text vs Runtime Callbacks](#persisted-event-text-vs-runtime-callbacks)
- [Execution Order](#execution-order)
- [Expected Callback Trace Sample](#expected-callback-trace-sample)
- [Safe Skip Examples](#safe-skip-examples)
- [Notes and Limitations](#notes-and-limitations)

## Event / Script Policy
- Runtime Delphi lifecycle callbacks are assigned by the host application.
- Runtime callbacks are not stored in `.vrt`.
- Persisted event text is stored in `.vrt`.
- Designer does not validate or execute persisted event text.
- Persisted event text meaning is defined by the host application's callback/script layer.

## Runtime Lifecycle Callback Wiring

Illustrative Delphi example (adjust signatures to match current event declarations):

```pascal
procedure TMyHost.ConfigureEngineEvents(AEngine: TReportEngine);
begin
  if AEngine = nil then
    Exit;

  AEngine.OnBeforePrintReport := EngineBeforePrintReport;
  AEngine.OnAfterPrintReport := EngineAfterPrintReport;
  AEngine.OnBeforeBand := EngineBeforeBand;
  AEngine.OnAfterBand := EngineAfterBand;
  AEngine.OnBeforeObject := EngineBeforeObject;
  AEngine.OnAfterObject := EngineAfterObject;
end;

procedure TMyHost.EngineBeforePrintReport(Sender: TObject; var ACancel: Boolean);
begin
  Log('BeforeReport');
  // Optional: ACancel := True;
end;

procedure TMyHost.EngineAfterPrintReport(Sender: TObject);
begin
  Log('AfterReport');
end;

procedure TMyHost.EngineBeforeBand(Sender: TObject; ABand: TReportBand; var ACanPrint: Boolean);
begin
  Log('BeforeBand: ' + ABand.Name);

  // Example skip by name/type
  if SameText(ABand.Name, 'DebugBand') then
    ACanPrint := False;
end;

procedure TMyHost.EngineAfterBand(Sender: TObject; ABand: TReportBand);
begin
  Log('AfterBand: ' + ABand.Name);
end;

procedure TMyHost.EngineBeforeObject(Sender: TObject; AObject: TReportObject; var ACanPrint: Boolean);
begin
  Log('BeforeObject: ' + AObject.Name);

  // Example skip by class/name
  if AObject is TReportImageObject then
    ACanPrint := False;
end;

procedure TMyHost.EngineAfterObject(Sender: TObject; AObject: TReportObject);
begin
  Log('AfterObject: ' + AObject.Name);
end;
```

Notes:
- Callbacks are optional; unassigned handlers are nil-safe.
- Keep handlers fast and deterministic for large reports.

## Quick Start Callback Template

Use this minimal wiring pattern in a host application:

```pascal
procedure TMyHost.AttachReportEvents(AEngine: TReportEngine);
begin
  if AEngine = nil then
    Exit;

  AEngine.OnBeforePrintReport := EngineBeforePrintReport;
  AEngine.OnAfterPrintReport := EngineAfterPrintReport;
  AEngine.OnBeforeBand := EngineBeforeBand;
  AEngine.OnAfterBand := EngineAfterBand;
  AEngine.OnBeforeObject := EngineBeforeObject;
  AEngine.OnAfterObject := EngineAfterObject;
end;

procedure TMyHost.EngineBeforeBand(Sender: TObject; ABand: TReportBand; var ACanPrint: Boolean);
begin
  // Example: skip an optional debug band
  if SameText(ABand.Name, 'DebugBand') then
    ACanPrint := False;
end;

procedure TMyHost.EngineBeforeObject(Sender: TObject; AObject: TReportObject; var ACanPrint: Boolean);
begin
  // Example: skip one object by name
  if SameText(AObject.Name, 'objInternalOnly') then
    ACanPrint := False;
end;
```

Quick notes:
- Keep handlers side-effect-light.
- `ACanPrint=False` skips printing for the current band/object.
- Adjust signatures to match current event declarations in your runtime package version.

## Persisted Event Text vs Runtime Callbacks
- Band `OnBeforePrint` / `OnAfterPrint` text is saved in `.vrt`.
- Object `OnBeforePrint` / `OnAfterPrint` text is saved in `.vrt`.
- Object event text fields are serialized only when non-empty.
- Empty object event text fields are omitted from serialization.
- Runtime callbacks are assigned in Delphi host code and are not serialized.
- Persisted event text is passed to host script handling.
- The designer does not guarantee a built-in script grammar.
- The designer does not validate, compile, or execute persisted event text.
- Object event text is stored for both text and non-text objects, but the host script layer may only support a subset of commands per object type.

### Object script-host contract
- The engine does not interpret object event text directly.
- The host can assign script-host callbacks through `TReportScriptEngine`:
- `OnObjectBeforePrint(AReport, AObject, Script, Context, var ACanPrint)`
- `OnObjectAfterPrint(AReport, AObject, Script, Context)`
- `OnObjectBeforePrint` can set `ACanPrint := False` to cancel printing that object.
- A minimal demo-safe parser can be implemented by the host (not by the engine core).
- Current demo host parser subset:
- `CanPrint := False`
- `Text := 'literal'` (for `TReportTextObject` only)
- `Text := Field('FieldName')` (for `TReportTextObject`, using current `Context.DataSet`)
- `Visible := False|True`
- `AnchorRight := False|True`
- `AnchorBottom := False|True`
- `Background := clColorName` (for `TReportTextObject` only)
- `FontColor := clColorName` (for `TReportTextObject` only)
- `FontSize := <integer>` (for `TReportTextObject` only)
- `FontName := <string>` (for `TReportTextObject` only)
- `FontBold := False|True` (for `TReportTextObject` only)
- `FontItalic := False|True` (for `TReportTextObject` only)
- `HAlign := Left|Center|Right` (for `TReportTextObject` only)
- `VAlign := Top|Center|Bottom` (for `TReportTextObject` only)
- `PrintWhen := <string>` (for `TReportTextObject` only)
- `DataField := <string>` (for `TReportTextObject` only)
- `Expression := <string>` (for `TReportTextObject` only)
- `DisplayFormat := <string>` (for `TReportFieldObject` only)
- `EditMask := <string>` (for `TReportFieldObject` only)
- `FontColorCondition := <string>` (for `TReportTextObject` only)
- `BorderColor := clColorName` (for `TReportTextObject` only)
- `Stretch := False|True` (for `TReportImageObject` only)
- `Center := False|True` (for `TReportImageObject` only)
- `Proportional := False|True` (for `TReportImageObject` only)
- `BorderColor := clColorName` (for `TReportImageObject` only)
- `BorderVisible := False|True` (for `TReportImageObject` only)
- `BorderWidth := <integer>` (for `TReportImageObject` only)
- `Transparent := False|True` (for `TReportTextObject` only)
- `AutoSize := False|True` (for `TReportTextObject` only)
- `WordWrap := False|True` (for `TReportTextObject` only)
- `BorderVisible := False|True` (for `TReportTextObject` only)
- `BorderWidth := <integer>` (for `TReportTextObject` only)
- `PaddingLeft := <integer>` (for `TReportTextObject` only)
- `PaddingTop := <integer>` (for `TReportTextObject` only)
- `PaddingRight := <integer>` (for `TReportTextObject` only)
- `PaddingBottom := <integer>` (for `TReportTextObject` only)
- `FontColorOnTrue := clColorName` (for `TReportTextObject` only)
- `BackgroundOnTrue := clColorName` (for `TReportTextObject` only)
- `BorderColorOnTrue := clColorName` (for `TReportTextObject` only)
- `BackgroundCondition := <string>` (for `TReportTextObject` only)
- `BorderColorCondition := <string>` (for `TReportTextObject` only)
- `ScriptUnsupported[ObjectType]` is emitted when a command is not valid for the current object class.
- Bounded multi-command form is supported with semicolon separators, executed left-to-right:
- `Visible := True; Text := Field('CustomerName')`
- `CanPrint := False` short-circuits remaining commands for that object.
- Statement splitting is quote-aware for single-quoted literals:
- `Text := 'A;B'; Visible := True` keeps `A;B` as one text literal.
- Escaped single quotes in literals are preserved:
- `Text := 'O''Reilly'`
- Whitespace around assignments/separators is normalized by adapter parsing:
- `  Visible   :=   True ;   Text := 'WS'   `
- Trailing empty semicolon segments are ignored safely:
- `Text := 'Tail'; ; ;`
- Unknown commands are treated as unsupported text (logged by host/demo), not executed by engine core.
- Unsupported command diagnostics include explicit reason tags:
- `ScriptUnsupported[UnknownCommand]`
- `ScriptUnsupported[FieldSyntax]`
- `ScriptUnsupported[FieldName]`
- `ScriptUnsupported[ColorValue]`
- `ScriptUnsupported[VisibleValue]`
- `ScriptUnsupported[ObjectType]`
- `ScriptUnsupported[TextLiteral]`
- In the designer demo, this parser is implemented via reusable shared adapter unit (`source/Vittix.Report.ScriptHost.Adapter.pas`), not engine scripting logic.

## Execution Order

Object-level execution order:
1. `PrintWhen`
2. Persisted object `OnBeforePrint` text (if non-empty)
3. Runtime `OnBeforeObject`
4. Draw object
5. Persisted object `OnAfterPrint` text (if non-empty)
6. Runtime `OnAfterObject`

`PrintWhen` gating rule:
- If `PrintWhen=False`, the object is skipped.
- When skipped by `PrintWhen`, persisted object event text and runtime object callbacks are not executed.

`CanPrint` rule:
- If script-host `OnObjectBeforePrint` sets `ACanPrint=False`, the engine skips:
- Runtime `OnBeforeObject`
- Object draw
- Persisted object `OnAfterPrint` text
- Runtime `OnAfterObject`

### Demo coverage notes
- Runtime Event Callback Demo covers object script-host runtime execution, cancel behavior, parser edge cases, and unsupported-command diagnostics.
- The demo includes a non-text object mismatch path so `ScriptUnsupported[ObjectType]` is exercised instead of skipped.
- The demo keeps counting-pass inflation checks to confirm callbacks only run in the final render pass.

Band/report order:
- Report lifecycle callbacks wrap report execution (`OnBeforePrintReport` -> render -> `OnAfterPrintReport`).
- Band persisted before/after text and band runtime before/after callbacks run around actual band printing as implemented by the engine.

## Expected Callback Trace Sample

Illustrative final-render trace for one printable object:

```text
BeforeReport
BeforeBand: MasterData
PrintWhen=True: objCustomerName
PersistedBeforeText: objCustomerName
BeforeObject: objCustomerName
DrawObject: objCustomerName
PersistedAfterText: objCustomerName
AfterObject: objCustomerName
AfterBand: MasterData
AfterReport
```

When `PrintWhen=False`, the object-level lines above are skipped for that object:
- No persisted object `OnBeforePrint` text execution
- No runtime `OnBeforeObject`
- No draw
- No persisted object `OnAfterPrint` text execution
- No runtime `OnAfterObject`

## Safe Skip Examples

Skip a band:
```pascal
if SameText(ABand.Name, 'MasterData') then
  ACanPrint := False;
```

Skip an object:
```pascal
if (AObject is TReportFieldObject) and SameText(AObject.Name, 'fldInternalOnly') then
  ACanPrint := False;
```

Simple order logging:
```pascal
Log('BeforeBand:' + ABand.Name);
Log('BeforeObject:' + AObject.Name);
Log('AfterObject:' + AObject.Name);
Log('AfterBand:' + ABand.Name);
```

## Notes and Limitations
- Runtime callbacks fire in final render pass only.
- Preview and export use the same engine event path.
- VittixReport does not provide filesystem/network/shell scripting.
- Host application owns script interpretation and safety policy.
- Persisted object event fields can be performance-sensitive on large reports.

## Runtime Demo Subtests
- Runtime Event Callback Demo includes explicit host-script command subtests:
- `Text := Field('CustomerName')`
- `Text := Field('NoSuchField')` (logs `ScriptFieldResolveMiss: NoSuchField`; does not count as unsupported)
- `Text := Field('NoSuchField'); Foo := 1` (resolve-miss and unsupported can coexist; unsupported count increments only for `Foo := 1`)
- `Background := clYellow`
- `Visible := False`
- `Foo := 1` (invalid command expected to be reported as `UnknownCommand`)
- `Text := Field(CustomerName)` (invalid field syntax -> `FieldSyntax`)
- `Text := Field('   ')` (blank field name -> `FieldName`)
- `Background := clNotAColor` (invalid color token -> `ColorValue`)
- `Visible := Maybe` (invalid boolean token -> `VisibleValue`)
- `Text := Demo` (unquoted literal -> `TextLiteral`)
- `CanPrint := Maybe` (invalid cancel token -> `CanPrintValue`)
- `Foo := 1; Visible := Maybe; Text := Demo; Foo := 1` (multi-invalid sequence; validates duplicate reason aggregation)
- `Text := 'OK'; Foo := 1; Visible := True; Text := Demo` (mixed valid+invalid sequence; validates left-to-right execution with unsupported tagging)
- `CanPrint := False; Foo := 1; Text := Demo` (short-circuit sequence; later commands are not evaluated)
- `Text := 'A;B'; Foo := 1` (quoted semicolon literal remains intact; following unsupported command is still tagged)
- `FontColor := clNavy` (text-object font color command)
- `BorderColor := clOlive` (text-object border color command)
- `FontSize := 14` (text-object font size command)
- `AnchorRight := True` (text-object right-anchor command)
- `AnchorBottom := True` (text-object bottom-anchor command)
- `FontName := Arial` (text-object font name command)
- `FontBold := True` (text-object bold toggle command)
- `FontItalic := True` (text-object italic toggle command)
- `HAlign := Center` (text-object horizontal alignment command)
- `VAlign := Bottom` (text-object vertical alignment command)
- `PrintWhen := Value > 0` (text-object print-when expression command)
- `DataField := CustomerName` (text-object data-field binding command)
- `Expression := Value + 1` (text-object expression command)
- `DisplayFormat := #,##0.00; EditMask := '!99;0;_'` (field-object formatting command)
- `FontColorCondition := Value > 0` (text-object conditional font color expression)
- `Stretch := False; Center := True; Proportional := False` (image-object fit command)
- `Transparent := False` (text-object transparency command)
- `AutoSize := True` (text-object auto-size command)
- `WordWrap := True` (text-object word-wrap command)
- `BorderVisible := True` (text-object border toggle command)
- `BorderWidth := 3` (text-object border width command)
- `PaddingLeft := 12` (text-object left padding command)
- `PaddingTop := 7` (text-object top padding command)
- `PaddingRight := 9` (text-object right padding command)
- `PaddingBottom := 4` (text-object bottom padding command)
- `FontColorOnTrue := clMaroon` (text-object conditional font color command)
- `BackgroundOnTrue := clYellow` (text-object conditional background command)
- `BorderColorOnTrue := clRed` (text-object conditional border color command)
- `BackgroundCondition := Value > 0` (text-object conditional background expression)
- `BorderColorCondition := Value < 100` (text-object conditional border color expression)
- Keys are case-insensitive for supported commands (for example `text := 'lower'`, `cAnPrInT := False`)
- Non-text object with `Text := 'X'; Background := clYellow` (both commands report `ObjectType` unsupported)
- Each subtest reports PASS/FAIL in the demo output summary.
- Demo output also includes an unsupported-command diagnostics block grouped by subtest.
- Demo output includes a compact unsupported-reason summary block with per-reason counts.


