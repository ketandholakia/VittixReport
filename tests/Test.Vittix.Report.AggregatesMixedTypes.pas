unit Test.Vittix.Report.AggregatesMixedTypes;

{
  Aggregate accumulator split bug (v1.0 freeze fix).

  TReportAggregates accumulates SUM/AVG/MIN/MAX rows whose evaluated value is
  a Currency variant into the Currency accumulators (SumC/MinC/MaxC) once
  UseCurrency flips on, while every other numeric row accumulates into the
  Double accumulators (Sum/MinVal/MaxVal).  Result selection read only ONE
  accumulator, so rows that landed in the other one were silently dropped,
  and AVG divided a shared Count by a split numerator.

  Fix contract: when UseCurrency flips to True mid-scan, the Double
  accumulators are folded into the Currency ones and every later numeric row
  (Currency or not) goes through the Currency path.  The all-Double path and
  the exact bare-BCD-field path are behaviorally unchanged - those are pinned
  by Test.Vittix.Report.AggregatesCurrency.

  Test entry: TReportAggregates.TryEvaluate is public.

  Reachability (verified by probe, 2026-10-25): the BUILT-IN evaluators
  flatten every numeric value to varDouble before it reaches
  TReportAggregates (modern TExpressionValue has no Currency kind; the
  legacy evaluator stringifies tokens and converts via TryStrToFloat), so a
  mixed scan cannot be produced through them today.  The varCurrency flip
  IS reachable through the public IReportRenderHooks surface, though: in
  legacy mode a cache hit hands the stored Variant straight back, and an
  aggregate over a bare currency field stores varCurrency.  The Hook*
  tests below use a test hook to deliver varCurrency rows mid-scan and pin
  the fold fix red->green.  The IF()-based mixed-order tests pin correct
  totals over per-row branch selection between a currency and a float
  field (all-Double today).
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Variants,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Context,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Aggregates;

type
  { Serves a varCurrency cached value for the INNER aggregate expression
    'SUM([F] + 0)' but only from row ID >= AFromId on.  The public
    IReportRenderHooks.TryGetAggregateCache contract hands the stored
    Variant straight back in legacy mode, so this makes the outer aggregate
    receive varCurrency rows mid-scan - the mixed-scan defect's entry
    point.  For rows before AFromId the hook declines and the inner
    expression evaluates for real over the Double path (varDouble). }
  TCurrencyCacheHook = class(TInterfacedObject, IReportRenderHooks)
  private
    FDataSet: TClientDataSet;
    FFromId: Integer;
    FCachedValue: Currency;
  public
    constructor Create(ADataSet: TClientDataSet; AFromId: Integer;
      ACachedValue: Currency);
    procedure InvokeBeforeObjectPrint(Sender: TObject;
      const Context: TExpressionContext; var CanPrint: Boolean);
    procedure InvokeAfterObjectPrint(Sender: TObject;
      const Context: TExpressionContext);
    function GetNamedDataSet(const AName: string): TDataSet;
    function TryGetAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; out AValue: Variant): Boolean;
    procedure StoreAggregateCache(const AExpression: string;
      const AContext: TExpressionContext; const AValue: Variant);
    function GetSubReportModel(AObject: TObject; const AJSON: string): TObject;
  end;

  [TestFixture]
  TAggregatesMixedTypesTests = class
  private
    { Dataset with ID (ftInteger), C (ftCurrency) and F (ftFloat).  Each
      triple is appended as one row: (ID, C, F). }
    function BuildTable(const ARows: TArray<TArray<Variant>>): TClientDataSet;
    function BuildContext(ADataSet: TClientDataSet): TExpressionContext;
  public
    [Test] procedure Test_Sum_DoubleFirst_Keeps_Double_Rows;
    [Test] procedure Test_Sum_CurrencyFirst_Keeps_Currency_Rows;
    [Test] procedure Test_Avg_DoubleFirst_Counts_All_Rows;
    [Test] procedure Test_Avg_CurrencyFirst_Counts_All_Rows;
    [Test] procedure Test_MinMax_DoubleFirst_Keeps_Double_Rows;
    [Test] procedure Test_MinMax_CurrencyFirst_Keeps_Currency_Rows;
    [Test] procedure Test_AllDouble_Path_Unchanged;
    [Test] procedure Test_AllCurrency_Path_Unchanged;
    [Test] procedure Test_HookCurrencyFlip_Sum_Folds_Double_Rows;
    [Test] procedure Test_HookCurrencyFlip_Avg_Counts_All_Rows;
    [Test] procedure Test_HookCurrencyFlip_MinMax_Folds_Double_Rows;
  end;

implementation

{ TCurrencyCacheHook }

constructor TCurrencyCacheHook.Create(ADataSet: TClientDataSet; AFromId: Integer;
  ACachedValue: Currency);
begin
  inherited Create;
  FDataSet := ADataSet;
  FFromId := AFromId;
  FCachedValue := ACachedValue;
end;

procedure TCurrencyCacheHook.InvokeBeforeObjectPrint(Sender: TObject;
  const Context: TExpressionContext; var CanPrint: Boolean);
begin
end;

procedure TCurrencyCacheHook.InvokeAfterObjectPrint(Sender: TObject;
  const Context: TExpressionContext);
begin
end;

function TCurrencyCacheHook.GetNamedDataSet(const AName: string): TDataSet;
begin
  Result := nil;
end;

function TCurrencyCacheHook.TryGetAggregateCache(const AExpression: string;
  const AContext: TExpressionContext; out AValue: Variant): Boolean;
begin
  Result := False;
  AValue := Null;
  // Serve only the inner aggregate, only from the flip row on.  The outer
  // aggregate's own cache probe (a different expression text) is declined,
  // as is every probe before the current row reaches FFromId.
  if (AExpression = 'SUM([F] + 0)') and Assigned(FDataSet) and
     FDataSet.Active and (FDataSet.FieldByName('ID').AsInteger >= FFromId) then
  begin
    AValue := FCachedValue;
    Result := True;
  end;
end;

procedure TCurrencyCacheHook.StoreAggregateCache(const AExpression: string;
  const AContext: TExpressionContext; const AValue: Variant);
begin
end;

function TCurrencyCacheHook.GetSubReportModel(AObject: TObject;
  const AJSON: string): TObject;
begin
  Result := nil;
end;

function TAggregatesMixedTypesTests.BuildTable(
  const ARows: TArray<TArray<Variant>>): TClientDataSet;
var
  Row: TArray<Variant>;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('C', ftCurrency);
  Result.FieldDefs.Add('F', ftFloat);
  Result.CreateDataSet;
  for Row in ARows do
    Result.AppendRecord([Row[0], Row[1], Row[2]]);
  Result.First;
end;

function TAggregatesMixedTypesTests.BuildContext(
  ADataSet: TClientDataSet): TExpressionContext;
begin
  Result := Default(TExpressionContext);
  // emModern so the IF() inner expression evaluates per row and can return
  // varCurrency ([C] is an ftCurrency field) or varDouble ([F]).
  Result.ExpressionMode := emModern;
  Result.DataSet := ADataSet;
  // Hooks stay nil: no aggregate cache, every call traverses for real.
end;

procedure TAggregatesMixedTypesTests.Test_Sum_DoubleFirst_Keeps_Double_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // Rows 1-2 evaluate to Double (the [F] branch), row 3 to Currency ([C]).
  SetLength(Rows, 3);
  Rows[0] := [1, 9.99, 2.50];
  Rows[1] := [2, 9.99, 3.50];
  Rows[2] := [3, 0.25, 9.99];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'SUM(IF([ID] > 2, [C], [F]))', Ctx, V), 'SUM must evaluate');
    Assert.IsTrue(Double(V) = 6.25,
      Format('SUM must include the Double rows: expected 6.25, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_Sum_CurrencyFirst_Keeps_Currency_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // Rows 1-2 evaluate to Currency, rows 3-4 to Double.
  SetLength(Rows, 4);
  Rows[0] := [1, 0.25, 9.99];
  Rows[1] := [2, 0.75, 9.99];
  Rows[2] := [3, 9.99, 2.50];
  Rows[3] := [4, 9.99, 3.50];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'SUM(IF([ID] > 2, [F], [C]))', Ctx, V), 'SUM must evaluate');
    Assert.IsTrue(Double(V) = 7.0,
      Format('SUM must include the Currency rows: expected 7.0, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_Avg_DoubleFirst_Counts_All_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 3);
  Rows[0] := [1, 9.99, 2.50];
  Rows[1] := [2, 9.99, 3.50];
  Rows[2] := [3, 0.25, 9.99];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'AVG(IF([ID] > 2, [C], [F]))', Ctx, V), 'AVG must evaluate');
    // 12.75 / 3 - the shared Count must cover the Double rows too.
    Assert.IsTrue(Abs(Double(V) - 6.25 / 3) < 1e-12,
      Format('AVG must divide the full sum by all rows: expected %.15f, got %.15f',
        [4.25, Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_Avg_CurrencyFirst_Counts_All_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 4);
  Rows[0] := [1, 0.25, 9.99];
  Rows[1] := [2, 0.75, 9.99];
  Rows[2] := [3, 9.99, 2.50];
  Rows[3] := [4, 9.99, 3.50];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'AVG(IF([ID] > 2, [F], [C]))', Ctx, V), 'AVG must evaluate');
    Assert.IsTrue(Double(V) = 1.75,
      Format('AVG must be exactly 1.75, got %.15f', [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_MinMax_DoubleFirst_Keeps_Double_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 3);
  Rows[0] := [1, 9.99, 2.50];
  Rows[1] := [2, 9.99, 3.50];
  Rows[2] := [3, 0.25, 9.99];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MIN(IF([ID] > 2, [C], [F]))', Ctx, V), 'MIN must evaluate');
    Assert.IsTrue(Double(V) = 0.25,
      Format('MIN must see the Currency row: expected 0.25, got %.15f',
        [Double(V)]));
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MAX(IF([ID] > 2, [C], [F]))', Ctx, V), 'MAX must evaluate');
    Assert.IsTrue(Double(V) = 3.50,
      Format('MAX must see the Double rows: expected 3.50, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_MinMax_CurrencyFirst_Keeps_Currency_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 4);
  Rows[0] := [1, 0.25, 9.99];
  Rows[1] := [2, 0.75, 9.99];
  Rows[2] := [3, 9.99, 2.50];
  Rows[3] := [4, 9.99, 3.50];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MIN(IF([ID] > 2, [F], [C]))', Ctx, V), 'MIN must evaluate');
    Assert.IsTrue(Double(V) = 0.25,
      Format('MIN must see the Currency rows: expected 0.25, got %.15f',
        [Double(V)]));
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MAX(IF([ID] > 2, [F], [C]))', Ctx, V), 'MAX must evaluate');
    Assert.IsTrue(Double(V) = 3.50,
      Format('MAX must see the Double rows: expected 3.50, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_AllDouble_Path_Unchanged;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 2);
  Rows[0] := [1, 0.25, 2.50];
  Rows[1] := [2, 0.75, 3.50];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'SUM(IF(False, [C], [F]))', Ctx, V), 'SUM must evaluate');
    Assert.IsTrue(VarType(V) = varDouble,
      'an all-Double scan must keep the historical Double result type');
    Assert.IsTrue(Double(V) = 6.0,
      Format('all-Double SUM must stay 6.0, got %.15f', [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_AllCurrency_Path_Unchanged;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 2);
  Rows[0] := [1, 0.25, 2.50];
  Rows[1] := [2, 0.75, 3.50];

  DS := BuildTable(Rows);
  try
    Ctx := BuildContext(DS);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'SUM(IF(True, [C], [F]))', Ctx, V), 'SUM must evaluate');
    // The modern evaluator flattens field values to Double before they reach
    // the aggregate, so the result keeps the historical Double type here;
    // the exact-Currency result type is pinned by the bare-BCD-field tests
    // in Test.Vittix.Report.AggregatesCurrency.
    Assert.IsTrue(Double(V) = 1.0,
      Format('all-Currency-branch SUM must stay 1.0, got %.15f', [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_HookCurrencyFlip_Sum_Folds_Double_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // Rows 1-2: the inner aggregate evaluates for real over the float
  // column (varDouble 6.25 = full-group sum, both rows).  Row 3: the hook
  // serves a varCurrency value -> mid-scan flip.  Pre-fix the two Double
  // rows vanished from the result (SUM 0.25); post-fix they fold in
  // (12.5 + 0.25 = 12.75).
  SetLength(Rows, 3);
  Rows[0] := [1, 2.50, 2.50];
  Rows[1] := [2, 3.50, 3.50];
  Rows[2] := [3, 0.25, 0.25];

  DS := BuildTable(Rows);
  try
    Ctx := Default(TExpressionContext);
    Ctx.ExpressionMode := emLegacy;   // cache hits pass the Variant straight back
    Ctx.DataSet := DS;
    Ctx.Hooks := TCurrencyCacheHook.Create(DS, 3, 0.25);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'SUM(SUM([F] + 0))', Ctx, V), 'SUM must evaluate');
    Assert.IsTrue(Double(V) = 12.75,
      Format('flipped SUM must fold the Double rows: expected 12.75, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_HookCurrencyFlip_Avg_Counts_All_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 3);
  Rows[0] := [1, 2.50, 2.50];
  Rows[1] := [2, 3.50, 3.50];
  Rows[2] := [3, 0.25, 0.25];

  DS := BuildTable(Rows);
  try
    Ctx := Default(TExpressionContext);
    Ctx.ExpressionMode := emLegacy;
    Ctx.DataSet := DS;
    Ctx.Hooks := TCurrencyCacheHook.Create(DS, 3, 0.25);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'AVG(SUM([F] + 0))', Ctx, V), 'AVG must evaluate');
    // 12.75 / 3 - the shared Count must cover the Double rows too.
    Assert.IsTrue(Double(V) = 4.25,
      Format('flipped AVG must divide the folded sum by all rows: expected 4.25, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

procedure TAggregatesMixedTypesTests.Test_HookCurrencyFlip_MinMax_Folds_Double_Rows;
var
  Rows: TArray<TArray<Variant>>;
  DS: TClientDataSet;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 3);
  Rows[0] := [1, 2.50, 2.50];
  Rows[1] := [2, 3.50, 3.50];
  Rows[2] := [3, 0.25, 0.25];

  DS := BuildTable(Rows);
  try
    Ctx := Default(TExpressionContext);
    Ctx.ExpressionMode := emLegacy;
    Ctx.DataSet := DS;
    Ctx.Hooks := TCurrencyCacheHook.Create(DS, 3, 0.25);
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MIN(SUM([F] + 0))', Ctx, V), 'MIN must evaluate');
    Assert.IsTrue(Double(V) = 0.25,
      Format('flipped MIN must see the Currency row: expected 0.25, got %.15f',
        [Double(V)]));
    Assert.IsTrue(TReportAggregates.TryEvaluate(
      'MAX(SUM([F] + 0))', Ctx, V), 'MAX must evaluate');
    Assert.IsTrue(Double(V) = 6.25,
      Format('flipped MAX must keep the Double rows: expected 6.25, got %.15f',
        [Double(V)]));
  finally
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAggregatesMixedTypesTests);

end.
