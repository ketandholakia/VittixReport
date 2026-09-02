unit Test.Vittix.Report.Objects;

{
  Phase 4G-1: render-global removal tests.

  These tests pin the new per-render reentrancy-guard behavior after
  eliminating the four unit-level render globals (GNamedDataSets,
  GBeforeObjectPrint, GAfterObjectPrint, GPrecheckedObjectForPrintWhen)
  from Vittix.Report.Objects.pas.

  The tests cover the four preflight-defined contracts:

  1. A default TExpressionContext has PrecheckedObjectForPrintWhen = nil
     (preserves the pre-R1 behavior for callers that build a context by
     hand without going through DrawReportObjectWithHooks).

  2. ShouldPrintObject short-circuits to True when AObj matches the
     prechecked object stored in the context (the actual reentrancy guard).

  3. ShouldPrintObject does NOT short-circuit for a different object; it
     evaluates the object as a normal PrintWhen expression. This proves
     the guard is per-object, not a global escape hatch.

  4. DrawReportObjectWithHooks sets Context.PrecheckedObjectForPrintWhen
     to the object before calling AObject.Draw and clears it in the
     matching finally. The capture is done by a derived class whose Draw
     records the pre/post value observed inside the call.

  The tests intentionally do not exercise the engine, the renderer, the
  designer, or any IReportRenderHooks path. They isolate the per-render
  reentrancy-guard contract that replaces the previous global.
}

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics,
  System.Classes,
  System.SysUtils,
  Data.DB,
  Vittix.Report.Context,
  Vittix.Report.Objects;

type
  [TestFixture]
  TRenderObjectInternalsTests = class
  private
    FCapturedDuringDraw: TObject;
    procedure ResetCapture;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_DefaultContext_HasNilPrechecked;

    [Test]
    procedure Test_ShouldPrintObject_ReentrancyGuardRespected;

    [Test]
    procedure Test_ShouldPrintObject_GuardDoesNotApplyToOtherObject;

    [Test]
    procedure Test_DrawReportObjectWithHooks_SetsAndClearsContextField;
  end;

  { Minimal TReportObject derivative whose Draw records the
    pre-checked-object value observed during the call. Only used to
    test the reentrancy guard and the DrawReportObjectWithHooks
    field-bookkeeping. }
  TCaptureObject = class(TReportObject)
  public
    Owner: TRenderObjectInternalsTests;
    constructor Create(AOwner: TRenderObjectInternalsTests);
    procedure Draw(C: TCanvas; const Context: TExpressionContext); override;
  end;

implementation

{ TCaptureObject }

constructor TCaptureObject.Create(AOwner: TRenderObjectInternalsTests);
begin
  inherited Create;
  Owner := AOwner;
  // Use an expression that, IF evaluated, would raise (no engine / no
  // dataset) so a successful test run proves the guard short-circuited
  // the evaluation.
  // An expression that, IF evaluated, would attempt to resolve a token
  // that does not exist (no engine / no dataset). A successful test
  // proves the guard short-circuited the evaluation. We use a string
  // literal that the expression parser does not interpret as a directive
  // (no leading '@' characters, which trigger Delphi compiler directives).
  // PrintWhen intentionally empty: the initial ShouldPrintObject check
  // in DrawReportObjectWithHooks must pass BEFORE the guard is set.
  // The reentrancy guard is exercised by the dedicated unit test.
end;

procedure TCaptureObject.Draw(C: TCanvas; const Context: TExpressionContext);
begin
  // Record the value the render-path just placed in the context. If R1
  // is correctly wired, this is Self (i.e. this TCaptureObject).
  Owner.FCapturedDuringDraw := Context.PrecheckedObjectForPrintWhen;
  inherited Draw(C, Context);
end;

{ TRenderObjectInternalsTests }

procedure TRenderObjectInternalsTests.Setup;
begin
  ResetCapture;
end;

procedure TRenderObjectInternalsTests.TearDown;
begin
  ResetCapture;
end;

procedure TRenderObjectInternalsTests.ResetCapture;
begin
  FCapturedDuringDraw := nil;
end;

procedure TRenderObjectInternalsTests.Test_DefaultContext_HasNilPrechecked;
var
  Ctx: TExpressionContext;
begin
  // Default-initialized record: every field is zero/nil/empty.
  Ctx := Default(TExpressionContext);
  Assert.IsNull(Ctx.PrecheckedObjectForPrintWhen);
end;

procedure TRenderObjectInternalsTests.Test_ShouldPrintObject_ReentrancyGuardRespected;
var
  Ctx: TExpressionContext;
  Obj: TCaptureObject;
begin
  Obj := TCaptureObject.Create(Self);
  try
    Ctx := Default(TExpressionContext);

    // Pre-R1: GPrecheckedObjectForPrintWhen := Obj; => guard returns True.
    // Post-R1: Context.PrecheckedObjectForPrintWhen := Obj; => same effect.
    // Use a non-empty PrintWhen so the guard check is reached
    // (empty PrintWhen would short-circuit before the guard).
    Obj.PrintWhen := 'unresolved_token_name_that_cannot_be_evaluated';
    Ctx.PrecheckedObjectForPrintWhen := Obj;

    // The PrintWhen expression is intentionally invalid; if the guard
    // short-circuits, ShouldPrintObject returns True without ever
    // attempting to parse the expression. If the guard is broken, the
    // expression engine is called and the test fails (exception or
    // non-True result).
    Assert.IsTrue(ShouldPrintObject(Obj, Ctx));
  finally
    Obj.Free;
  end;
end;

procedure TRenderObjectInternalsTests.Test_ShouldPrintObject_GuardDoesNotApplyToOtherObject;
var
  Ctx: TExpressionContext;
  Guarded, Other: TCaptureObject;
begin
  Guarded := TCaptureObject.Create(Self);
  Other   := TCaptureObject.Create(Self);
  try
    Ctx := Default(TExpressionContext);

    // Give Other a non-empty PrintWhen so the guard check is reached.
    Other.PrintWhen := 'unresolved_token_name_that_cannot_be_evaluated';

    // The guard is set for Guarded, not for Other.
    Ctx.PrecheckedObjectForPrintWhen := Guarded;

    // Guarded is short-circuited.
    Assert.IsTrue(ShouldPrintObject(Guarded, Ctx));

    // Other is NOT short-circuited: it must attempt to evaluate
    // PrintWhen. The expression is invalid, so ShouldPrintObject must
    // return False (not True). A True return here would mean the guard
    // leaked or was applied globally.
    Assert.IsFalse(ShouldPrintObject(Other, Ctx));
  finally
    Guarded.Free;
    Other.Free;
  end;
end;

procedure TRenderObjectInternalsTests.Test_DrawReportObjectWithHooks_SetsAndClearsContextField;
var
  Ctx: TExpressionContext;
  Bitmap: TBitmap;
  Obj: TCaptureObject;
begin
  Bitmap := TBitmap.Create;
  Obj := TCaptureObject.Create(Self);
  try
    Bitmap.SetSize(64, 64);
    Ctx := Default(TExpressionContext);
    Assert.IsNull(Ctx.PrecheckedObjectForPrintWhen);

    DrawReportObjectWithHooks(Obj, Bitmap.Canvas, Ctx);

    // During Draw, the reentrancy guard was set to Obj (captured by the
    // TCaptureObject.Draw override).
    Assert.AreEqual(TObject(Obj), FCapturedDuringDraw);

    // After Draw returns, the finally cleared the field.
    Assert.IsNull(Ctx.PrecheckedObjectForPrintWhen);
  finally
    Obj.Free;
    Bitmap.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRenderObjectInternalsTests);

end.
