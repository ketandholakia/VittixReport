unit Test.Vittix.Report.AggregatesCurrency;

{
  Exact decimal aggregate regressions (v1.0 freeze fix).

  These tests pin decimal scale, product magnitude, and accumulator range.
  Exact decimal paths use checked coefficient arithmetic through 64 digits
  and fractional places. Floating fields retain the historical Double path.

  Note: an "equivalent SQL SUM" cross-check was considered via FireDAC
  Local SQL and deliberately dropped - Local SQL drags the SQLite engine
  and its driver into the test binary for one assertion.  Exact equality
  against the analytical result is the stronger pin anyway.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Variants,
  Data.DB,
  Datasnap.DBClient,
  Data.FmtBcd,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Export.Commands,
  Vittix.Report.Expressions,
  Vittix.Report.TraversalDiagnostics;

type
  [TestFixture]
  TAggregatesCurrencyTests = class
  private
    { BCD dataset with an 'Amt' column (NUMERIC(APrecision, AScale)) and an
      'F' float column; AValues are appended to Amt (Null entries allowed),
      F mirrors Amt as a plain float when non-null. }
    function BuildBcdTable(APrecision, AScale: Integer;
      const AValues: TArray<Variant>; ARepeat: Integer = 1): TClientDataSet;
    { Builds the engine + expression context over ADataSet (no evaluation,
      so aggregate-cache tests start from a cold cache). }
    procedure BuildContextOver(ADataSet: TClientDataSet;
      out AContext: TExpressionContext; out AEngine: TReportEngine;
      out AModel: TReportModel);
    procedure CheckComputedSingleRow(AQty: Integer; ARate: Currency;
      const AExpected: string);
  public
    [Test] procedure Test_Sum_10000_Rows_Of_0_10_Is_Exactly_1000;
    [Test] procedure Test_Sum_Mixed_Nulls_SkipsNulls_Exact;
    [Test] procedure Test_Sum_Numeric_18_4_Exact;
    [Test] procedure Test_MinMax_Avg_On_Currency_Column;
    [Test] procedure Test_MinMax_Sum_Empty_Group_Keeps_Zero;
    [Test] procedure Test_AggregateCache_Still_WorksWith_CurrencyResult;
    [Test] procedure Test_Float_Column_Keeps_Double_Behavior;
    [Test] procedure Test_Sum_QtyTimesRate_10000_Exact;
    [Test] procedure Test_Sum_3x19999_10000_Exact;
    [Test] procedure Test_Sum_Computed_NullOperand_SkipsRow;
    [Test] procedure Test_Sum_Computed_FloatColumn_KeepsDouble;
    [Test] procedure Test_Sum_Computed_GroupFooter_AndReportSummary_Exact;
    [Test] procedure Test_Sum_Scale6_Column_Exact_At_Field_Scale;
    [Test] procedure Test_Sum_Computed_LargeProduct_UsesCorrectScale;
    [Test] procedure Test_Sum_Computed_Scale6_PreservesFieldScale;
    [Test] procedure Test_Bcd_Accumulator_HandlesTenMaximumValues;
    [Test] procedure Test_Bcd_Average_DoesNotOverflowIntermediateSum;
    [Test] procedure Test_Computed_HighScale_Bcd_RejectsUnsupportedGrammar;
    [Test] procedure Test_Computed_MultipleTerms_NegativeAndTinyScales;
    [Test] procedure Test_Computed_ProductBeyondCapacity_Raises;
    [Test] procedure Test_Computed_PositiveRow_Individually;
    [Test] procedure Test_Computed_NegativeRow_Individually;
    [Test] procedure Test_Computed_ThirdPositiveRow_Individually;
    [Test] procedure Test_Computed_SignedOperandMatrix;
    [Test] procedure Test_Computed_SignedAccumulationOrder;
    [Test] procedure Test_Sum_BareNegativeSubunit_Exact;
  end;

implementation

function TAggregatesCurrencyTests.BuildBcdTable(APrecision, AScale: Integer;
  const AValues: TArray<Variant>; ARepeat: Integer): TClientDataSet;
var
  Def: TFieldDef;
  V: Variant;
  R, I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Def := Result.FieldDefs.AddFieldDef;
  Def.Name := 'Amt';
  Def.DataType := ftBCD;
  Def.Precision := APrecision;
  Def.Size := AScale;
  Result.FieldDefs.Add('F', ftFloat);
  Result.CreateDataSet;

  R := 0;
  for I := 0 to ARepeat - 1 do
    for V in AValues do
    begin
      Inc(R);
      Result.AppendRecord([R, V, V]);
    end;
  Result.First;
end;

procedure TAggregatesCurrencyTests.BuildContextOver(ADataSet: TClientDataSet;
  out AContext: TExpressionContext; out AEngine: TReportEngine;
  out AModel: TReportModel);
var
  Model: TReportModel;
  Band: TReportBand;
  Engine: TReportEngine;
  Context: TExpressionContext;
begin
  Model := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Model.Objects.Add(Band);

  Engine := TReportEngine.Create(Model, ADataSet, nil);
  Context := Default(TExpressionContext);
  Context.DataSet := ADataSet;
  Context.Hooks := Engine;
  Context.Parameters := Engine.Parameters;
  Context.Variables := Model.Variables;

  AContext := Context;
  AEngine := Engine;
  AModel := Model;
end;

procedure TAggregatesCurrencyTests.Test_Sum_10000_Rows_Of_0_10_Is_Exactly_1000;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 1);
  Values[0] := 0.10;

  DS := BuildBcdTable(18, 2, Values, 10000);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      // Exact pin: the old Double accumulator drifted (~1e-11 on this data).
      Assert.IsTrue(Double(V) = 1000.0,
        Format('SUM must be exactly 1000, got %.15f', [Double(V)]));
      Assert.IsTrue(Currency(V) = 1000.0,
        'Currency result must carry no rounding residue');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Mixed_Nulls_SkipsNulls_Exact;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 5);
  Values[0] := 0.10;
  Values[1] := Null;
  Values[2] := 0.20;
  Values[3] := Null;
  Values[4] := 0.70;

  DS := BuildBcdTable(18, 2, Values);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      Assert.IsTrue(Double(V) = 1.0,
        Format('SUM must skip NULLs and be exactly 1.0, got %.15f', [Double(V)]));

      V := TReportExpression.Evaluate('COUNT([Amt])', Ctx);
      Assert.AreEqual(3, Integer(V), 'COUNT must count non-null rows only');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Numeric_18_4_Exact;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 3);
  Values[0] := 12345.6789;
  Values[1] := 0.0001;
  Values[2] := 999.9999;

  DS := BuildBcdTable(18, 4, Values);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      // Exact pin at Currency scale (Double(V) is ulp-fragile for
      // non-binary-exact decimals, so compare in the Currency domain).
      Assert.IsTrue(Currency(V) = 13345.6789,
        Format('SUM must be exactly 13345.6789, got %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_MinMax_Avg_On_Currency_Column;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 3);
  Values[0] := 0.10;
  Values[1] := 2.50;
  Values[2] := 1.20;

  DS := BuildBcdTable(18, 2, Values);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('MIN([Amt])', Ctx);
      Assert.IsTrue(Currency(V) = 0.10, 'MIN must be exactly 0.10');
      V := TReportExpression.Evaluate('MAX([Amt])', Ctx);
      Assert.IsTrue(Currency(V) = 2.50, 'MAX must be exactly 2.50');
      V := TReportExpression.Evaluate('AVG([Amt])', Ctx);
      // 3.80 / 3 stays a Double division (SQL AVG keeps more scale than the
      // column); 1.2666...6 within Double precision.
      Assert.IsTrue(Abs(Double(V) - 1.2666666666666666) < 1e-12,
        Format('AVG got %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_MinMax_Sum_Empty_Group_Keeps_Zero;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 0);
  DS := BuildBcdTable(18, 2, Values);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      // Unchanged legacy behavior: an empty group yields 0, not NULL.
      V := TReportExpression.Evaluate('MIN([Amt])', Ctx);
      Assert.IsTrue(Double(V) = 0.0, 'empty-group MIN must stay 0');
      V := TReportExpression.Evaluate('MAX([Amt])', Ctx);
      Assert.IsTrue(Double(V) = 0.0, 'empty-group MAX must stay 0');
      V := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      Assert.IsTrue(Double(V) = 0.0, 'empty-group SUM must stay 0');
      V := TReportExpression.Evaluate('AVG([Amt])', Ctx);
      Assert.IsTrue(Double(V) = 0.0, 'empty-group AVG must stay 0');
      V := TReportExpression.Evaluate('COUNT([Amt])', Ctx);
      Assert.AreEqual(0, Integer(V), 'empty-group COUNT must stay 0');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_AggregateCache_Still_WorksWith_CurrencyResult;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  Snapshot: TReportTraversalSnapshot;
  FirstValue, SecondValue: Variant;
begin
  SetLength(Values, 1);
  Values[0] := 0.10;
  DS := BuildBcdTable(18, 2, Values, 500);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      TReportTraversalDiagnostics.Reset;
      FirstValue := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      SecondValue := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      Snapshot := TReportTraversalDiagnostics.Snapshot;

      Assert.IsTrue(Double(FirstValue) = 50.0,
        Format('cached SUM must stay exact 50, got %.15f', [Double(FirstValue)]));
      Assert.IsTrue(Double(SecondValue) = 50.0, 'cache hit must return the same value');
      Assert.AreEqual(2, Snapshot.AggregateEvaluations, 'two evaluations');
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses, 'first call misses');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits, 'second call hits');
      Assert.AreEqual(1, Snapshot.AggregateTraversals, 'dataset traversed once');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Float_Column_Keeps_Double_Behavior;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Values, 1);
  Values[0] := 0.10;
  DS := BuildBcdTable(18, 2, Values, 10000);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      // The float column keeps the historical Double path: same tolerance
      // class as before the change (0.1 is not binary-representable).
      V := TReportExpression.Evaluate('SUM([F])', Ctx);
      Assert.IsTrue(VarType(V) = varDouble, 'float SUM stays a Double');
      Assert.IsTrue(Abs(Double(V) - 1000.0) < 0.001,
        Format('float SUM drifted too far: %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

{ Qty INTEGER + Rate NUMERIC(18,3) table for computed-aggregate tests.
  ARows entries: Variant arrays [Grp, Qty, Rate]; Null allowed in Qty/Rate. }
function BuildQtyRateTable(const ARows: TArray<Variant>): TClientDataSet;
var
  Def: TFieldDef;
  V: Variant;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Grp', ftString, 4);
  Result.FieldDefs.Add('Qty', ftInteger);
  Def := Result.FieldDefs.AddFieldDef;
  Def.Name := 'Rate';
  Def.DataType := ftBCD;
  Def.Precision := 18;
  Def.Size := 3;
  Result.FieldDefs.Add('F', ftFloat);
  Result.CreateDataSet;
  for V in ARows do
  begin
    Result.Append;
    Result.FieldByName('Grp').AsString := V[0];
    if not VarIsNull(V[1]) then
      Result.FieldByName('Qty').AsInteger := V[1];
    if not VarIsNull(V[2]) then
    begin
      Result.Edit;
      Result.FieldByName('Rate').AsCurrency := V[2];
    end;
    Result.FieldByName('F').AsFloat := 0.1;
    Result.Post;
  end;
  Result.First;
end;

procedure TAggregatesCurrencyTests.CheckComputedSingleRow(AQty: Integer;
  ARate: Currency; const AExpected: string);
var
  Rows: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 1);
  Rows[0] := VarArrayOf(['A', AQty, ARate]);
  DS := BuildQtyRateTable(Rows);
  try
    Assert.AreEqual(AQty, DS.FieldByName('Qty').AsInteger,
      'dataset must expose the signed integer operand unchanged');
    Assert.AreEqual(ARate, DS.FieldByName('Rate').AsCurrency,
      'dataset must expose the decimal operand unchanged');
    Assert.AreEqual(Integer(ftInteger), Integer(DS.FieldByName('Qty').DataType));
    Assert.AreEqual(Integer(ftBCD), Integer(DS.FieldByName('Rate').DataType));
    Assert.AreEqual(18, DS.FieldDefs.Find('Rate').Precision);
    Assert.AreEqual(3, DS.FieldByName('Rate').Size);

    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd(AExpected)),
        Format('single row %d x %s: expected %s, got %s',
          [AQty, CurrToStr(ARate, TFormatSettings.Invariant), AExpected,
           BcdToStr(VarToBcd(V))]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Computed_PositiveRow_Individually;
begin
  CheckComputedSingleRow(1, 0.125, '0.125');
end;

procedure TAggregatesCurrencyTests.Test_Computed_NegativeRow_Individually;
begin
  CheckComputedSingleRow(-2, 0.125, '-0.25');
end;

procedure TAggregatesCurrencyTests.Test_Computed_ThirdPositiveRow_Individually;
begin
  CheckComputedSingleRow(3, 0.25, '0.75');
end;

procedure TAggregatesCurrencyTests.Test_Computed_SignedOperandMatrix;
begin
  CheckComputedSingleRow(-1, 1, '-1');
  CheckComputedSingleRow(-2, 1, '-2');
  CheckComputedSingleRow(-10, 1, '-10');
  CheckComputedSingleRow(-11, 1, '-11');
  CheckComputedSingleRow(-1, 0.1, '-0.1');
  CheckComputedSingleRow(-2, 0.125, '-0.25');
  CheckComputedSingleRow(2, -0.125, '-0.25');
  CheckComputedSingleRow(-2, -0.125, '0.25');
  CheckComputedSingleRow(0, -0.125, '0');
end;

procedure TAggregatesCurrencyTests.Test_Computed_SignedAccumulationOrder;
var
  Rows: TArray<Variant>;
  procedure CheckRows(const ARows: TArray<Variant>; const AExpected: string);
  var
    DS: TClientDataSet;
    Model: TReportModel;
    Engine: TReportEngine;
    Ctx: TExpressionContext;
    V: Variant;
  begin
    DS := BuildQtyRateTable(ARows);
    try
      BuildContextOver(DS, Ctx, Engine, Model);
      try
        V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
        Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd(AExpected)),
          'ordered exact sum expected ' + AExpected + ', got ' +
          BcdToStr(VarToBcd(V)));
      finally
        Engine.Free;
        Model.Free;
      end;
    finally
      DS.Free;
    end;
  end;
begin
  SetLength(Rows, 2);
  Rows[0] := VarArrayOf(['A', 1, 0.125]);
  Rows[1] := VarArrayOf(['A', -2, 0.125]);
  CheckRows(Rows, '-0.125');

  Rows[0] := VarArrayOf(['A', -2, 0.125]);
  Rows[1] := VarArrayOf(['A', 1, 0.125]);
  CheckRows(Rows, '-0.125');

  Rows[0] := VarArrayOf(['A', 1, 0.125]);
  Rows[1] := VarArrayOf(['A', -1, 0.125]);
  CheckRows(Rows, '0');

  Rows[0] := VarArrayOf(['A', -2, 0.125]);
  Rows[1] := VarArrayOf(['A', -1, 0.125]);
  CheckRows(Rows, '-0.375');
end;

procedure TAggregatesCurrencyTests.Test_Sum_BareNegativeSubunit_Exact;
var
  Values: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // This exercises the same signed accumulator through the bare-field path:
  // -.1 - .2 + .15 = -.15, independently of computed-expression parsing.
  SetLength(Values, 3);
  Values[0] := -0.1;
  Values[1] := -0.2;
  Values[2] := 0.15;
  DS := BuildBcdTable(18, 2, Values);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amt])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('-0.15')),
        'bare BCD SUM must preserve a negative subunit total; got ' +
        BcdToStr(VarToBcd(V)));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_QtyTimesRate_10000_Exact;
var
  Rows: TArray<Variant>;
  I: Integer;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // The invoice case: 10,000 x (1 * 0.10).  Each per-row product is exact
  // at Currency scale, so the sum is exactly 1000.00 (the Double path
  // drifts and fails this pin).
  SetLength(Rows, 10000);
  for I := 0 to High(Rows) do
    Rows[I] := VarArrayOf(['G', 1, 0.10]);

  DS := BuildQtyRateTable(Rows);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.IsTrue(Currency(V) = 1000.0,
        Format('SUM([Qty]*[Rate]) must be exactly 1000, got %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_3x19999_10000_Exact;
var
  Rows: TArray<Variant>;
  I: Integer;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // 10,000 x (3 * 19.99) = 599,700.00 exactly (3*19.99 is NOT binary
  // representable, so the Double path accumulates visible drift here).
  SetLength(Rows, 10000);
  for I := 0 to High(Rows) do
    Rows[I] := VarArrayOf(['G', 3, 19.99]);

  DS := BuildQtyRateTable(Rows);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.IsTrue(Currency(V) = 599700.0,
        Format('SUM must be exactly 599700, got %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Computed_NullOperand_SkipsRow;
var
  Rows: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 4);
  Rows[0] := VarArrayOf(['G', 1, 0.10]);
  Rows[1] := VarArrayOf(['G', Null, 0.10]); // NULL Qty: row skipped
  Rows[2] := VarArrayOf(['G', 1, Null]);    // NULL Rate: row skipped
  Rows[3] := VarArrayOf(['G', 2, 0.50]);

  DS := BuildQtyRateTable(Rows);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.IsTrue(Currency(V) = 1.1,
        Format('NULL operands must skip rows: expected 1.1, got %.15f', [Double(V)]));
      V := TReportExpression.Evaluate('COUNT([Qty]*[Rate])', Ctx);
      Assert.AreEqual(2, Integer(V), 'COUNT counts only fully non-null rows');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Computed_FloatColumn_KeepsDouble;
var
  Rows: TArray<Variant>;
  I: Integer;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  SetLength(Rows, 3);
  for I := 0 to High(Rows) do
    Rows[I] := VarArrayOf(['G', 1, 0.10]);

  DS := BuildQtyRateTable(Rows);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      // F is ftFloat, so [F]*2 must stay on the Double path - the result
      // type and tolerance class are unchanged by the Currency work.
      V := TReportExpression.Evaluate('SUM([F]*2)', Ctx);
      Assert.IsTrue(VarType(V) = varDouble, 'float product stays a Double');
      Assert.IsTrue(Abs(Double(V) - 0.6) < 0.001,
        Format('float product sum drifted: %.15f', [Double(V)]));
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Computed_GroupFooter_AndReportSummary_Exact;
var
  Rows: TArray<Variant>;
  I: Integer;
  DS: TClientDataSet;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Engine: TReportEngine;
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Texts: TStringList;
begin
  // Engine-level: 30 rows of (3 * 19.99 = 59.97) split into 3 groups of
  // 10.  Group footers must show 599.70 each (10 rows), the report
  // summary 1799.10 (30 rows) - both exact (Currency), formatted by
  // VarToStr without trailing zeros.
  SetLength(Rows, 30);
  for I := 0 to High(Rows) do
    Rows[I] := VarArrayOf(['G' + IntToStr(1 + (I div 10)), 3, 19.99]);

  DS := BuildQtyRateTable(Rows);
  try
    Model := TReportModel.Create;
    Band := TReportBand.Create;
    Band.BandType := btGroupHeader;
    Band.GroupField := 'Grp';
    Band.Height := 20;
    Model.Objects.Add(Band);

    Band := TReportBand.Create;
    Band.BandType := btGroupFooter;
    Band.Height := 20;
    Txt := TReportTextObject.Create;
    Txt.Expression := 'SUM([Qty]*[Rate])';
    Txt.Bounds := Rect(2, 2, 200, 18);
    Band.Children.Add(Txt);
    Model.Objects.Add(Band);

    Band := TReportBand.Create;
    Band.BandType := btReportSummary;
    Band.Height := 20;
    Txt := TReportTextObject.Create;
    Txt.Expression := 'SUM([Qty]*[Rate])';
    Txt.Bounds := Rect(2, 2, 200, 18);
    Band.Children.Add(Txt);
    Model.Objects.Add(Band);

    Doc := TReportExportDocument.Create;
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.TwoPassRendering := False;
      Engine.Prepare;

      Texts := TStringList.Create;
      try
        for Page in Doc.Pages do
          for Cmd in Page.Commands do
            if (Cmd is TReportExportTextCommand) and
               (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
              Texts.Add(Trim(TReportExportTextCommand(Cmd).Text));

        // VarToStr of a Currency 599.7 / 5997 renders without trailing
        // zeros; the DECIMAL DIGITS are the exactness pin (the old Double
        // path produced 599.7000000000001-class garbage).
        Assert.AreEqual(4, Texts.Count, '3 group footers + 1 summary');
        Assert.IsTrue((Texts[0] = '599.7') and (Texts[1] = '599.7') and
          (Texts[2] = '599.7'),
          'group footers must be exactly 599.7 each, got ' + Texts.Text);
        Assert.AreEqual('1799.1', Texts[3],
          'report summary must be exactly 1799.1 (30 x 59.97)');
      finally
        Texts.Free;
      end;
    finally
      Engine.Free;
      Doc.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Scale6_Column_Exact_At_Field_Scale;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
  I: Integer;
begin
  // NUMERIC(18,6) values with REAL 6-decimal digits: 10,000 x 1.000001.
  // The result is exact even though 1.000001 is not binary-representable.
  DS := TClientDataSet.Create(nil);
  try
    DS.FieldDefs.Add('ID', ftInteger);
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'R6';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 6;
    DS.CreateDataSet;
    for I := 1 to 10000 do
      DS.AppendRecord([I]);
    DS.First;

    // fill via AsString to keep the exact 6-decimal representation
    DS.First;
    while not DS.Eof do
    begin
      DS.Edit;
      DS.FieldByName('R6').AsString := '1.000001';
      DS.Post;
      DS.Next;
    end;
    DS.First;

    BuildContextOver(DS, Ctx, Engine, Model);
    try
      // The exact comparison pins the mathematical sum while allowing a
      // Currency result when the reduced scale and value fit exactly.
      V := TReportExpression.Evaluate('SUM([R6])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('10000.01')),
        'SUM of 6-decimal values must be exact at the input scale');

      V := TReportExpression.Evaluate('MIN([R6])', Ctx);
      Assert.IsTrue(Abs(Double(V) - 1.000001) < 1e-12, 'MIN at field scale');
      V := TReportExpression.Evaluate('MAX([R6])', Ctx);
      Assert.IsTrue(Abs(Double(V) - 1.000001) < 1e-12, 'MAX at field scale');
      V := TReportExpression.Evaluate('AVG([R6])', Ctx);
      Assert.IsTrue(Abs(Double(V) - 1.000001) < 1e-12, 'AVG at field scale');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Computed_LargeProduct_UsesCorrectScale;
var
  Rows: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // A large operand and a fractional product used to enter a magnitude
  // fallback with a mismatched scale. Pin scale, sign, and exact output.
  SetLength(Rows, 3);
  Rows[0] := VarArrayOf(['G', 400000, 1.0]);
  Rows[1] := VarArrayOf(['G', -200000, 0.5]);
  Rows[2] := VarArrayOf(['G', 1, 0.125]);
  DS := BuildQtyRateTable(Rows);
  try
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.AreEqual(300000.125, Double(V), 0.0000001,
        'large positive/negative products and a fraction retain their scale');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Sum_Computed_Scale6_PreservesFieldScale;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  DS := TClientDataSet.Create(nil);
  try
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'Amount';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 6;
    DS.CreateDataSet;
    DS.Append;
    DS.FieldByName('Amount').AsString := '1.234567';
    DS.Post;
    DS.Append;
    DS.FieldByName('Amount').AsString := '2.000001';
    DS.Post;
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amount]*1)', Ctx);
      Assert.IsTrue(VarIsFMTBcd(V),
        'computed FMTBCD aggregate returns a decimal-preserving result');
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('3.234568')),
        'computed SUM retains all six input decimal places');
      V := TReportExpression.Evaluate('SUM([Amount]*0.000001)', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('0.000003234568')),
        'a high-scale product retains all twelve mathematically significant places');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Bcd_Accumulator_HandlesTenMaximumValues;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
  I: Integer;
begin
  DS := TClientDataSet.Create(nil);
  try
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'Amount';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 4;
    DS.CreateDataSet;
    for I := 1 to 10 do
    begin
      DS.Append;
      DS.FieldByName('Amount').AsString := '99999999999999.9999';
      DS.Post;
    end;
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('999999999999999.9990')),
        'SUM of ten maximum NUMERIC(18,4) values is exact');
      V := TReportExpression.Evaluate('AVG([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('99999999999999.9999')),
        'AVG keeps the legal input maximum despite an out-of-Currency sum');
      DS.First;
      while not DS.Eof do
      begin
        DS.Edit;
        DS.FieldByName('Amount').AsString := '-99999999999999.9999';
        DS.Post;
        DS.Next;
      end;
      Engine.Prepare; // clear the engine's aggregate result cache after data changes
      DS.First;
      V := TReportExpression.Evaluate('SUM([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('-999999999999999.9990')),
        'negative SUM of ten maximum NUMERIC(18,4) values is exact');
      V := TReportExpression.Evaluate('AVG([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('-99999999999999.9999')),
        'negative AVG keeps its input value despite an out-of-Currency sum');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Bcd_Average_DoesNotOverflowIntermediateSum;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
  I: Integer;
begin
  DS := TClientDataSet.Create(nil);
  try
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'Amount';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 6;
    DS.CreateDataSet;
    for I := 1 to 10 do
    begin
      DS.Append;
      DS.FieldByName('Amount').AsString := '999999999999.999999';
      DS.Post;
    end;
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('9999999999999.999990')),
        'SUM of ten maximum NUMERIC(18,6) values is exact');
      V := TReportExpression.Evaluate('AVG([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('999999999999.999999')),
        'AVG preserves all six places without an overflowing scaled sum; got ' +
        BcdToStr(VarToBcd(V)));
      DS.First;
      while not DS.Eof do
      begin
        DS.Edit;
        DS.FieldByName('Amount').AsString := '-999999999999.999999';
        DS.Post;
        DS.Next;
      end;
      Engine.Prepare; // clear the engine's aggregate result cache after data changes
      DS.First;
      V := TReportExpression.Evaluate('SUM([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('-9999999999999.999990')),
        'negative SUM of ten maximum NUMERIC(18,6) values is exact');
      V := TReportExpression.Evaluate('AVG([Amount])', Ctx);
      Assert.AreEqual(0,
        BcdCompare(VarToBcd(V), StrToBcd('-999999999999.999999')),
        'negative AVG preserves all six places without an overflowing sum');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Computed_HighScale_Bcd_RejectsUnsupportedGrammar;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  Raised: Boolean;
begin
  DS := TClientDataSet.Create(nil);
  try
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'Amount';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 6;
    DS.CreateDataSet;
    DS.Append;
    DS.FieldByName('Amount').AsString := '1.234567';
    DS.Post;
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      Raised := False;
      try
        TReportExpression.Evaluate('SUM([Amount]/2)', Ctx);
      except
        on E: EConvertError do
          Raised := Pos('supported exact-decimal expression', E.Message) > 0;
      end;
      Assert.IsTrue(Raised,
        'unsupported high-scale BCD grammar fails explicitly instead of using Double');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Computed_MultipleTerms_NegativeAndTinyScales;
var
  Rows: TArray<Variant>;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  V: Variant;
begin
  // Independent arithmetic: (1*.125 + 1*.05) + (-2*.125 + -2*.05)
  // + (3*.25 + 3*.05) = .175 - .35 + .9 = .725.
  SetLength(Rows, 3);
  Rows[0] := VarArrayOf(['A', 1, 0.125]);
  Rows[1] := VarArrayOf(['A', -2, 0.125]);
  Rows[2] := VarArrayOf(['A', 3, 0.25]);
  DS := BuildQtyRateTable(Rows);
  try
    DS.First;
    Assert.AreEqual(1, DS.FieldByName('Qty').AsInteger);
    Assert.AreEqual('0.125', DS.FieldByName('Rate').AsString);
    DS.Next;
    Assert.AreEqual(-2, DS.FieldByName('Qty').AsInteger);
    Assert.AreEqual('0.125', DS.FieldByName('Rate').AsString);
    DS.Next;
    Assert.AreEqual(3, DS.FieldByName('Qty').AsInteger);
    Assert.AreEqual('0.25', DS.FieldByName('Rate').AsString);
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      V := TReportExpression.Evaluate('SUM([Qty]*[Rate])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.625')),
        'independent product total for rows is 0.625; got ' +
        BcdToStr(VarToBcd(V)));
      V := TReportExpression.Evaluate('SUM([Qty]*0.05)', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.1')),
        'independent literal-product total for rows is 0.1');
      V := TReportExpression.Evaluate(
        'SUM([Qty]*[Rate]+[Qty]*0.05)', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.725')),
        'multi-term decimal sum must match independently calculated 0.725; got ' +
        BcdToStr(VarToBcd(V)));
      V := TReportExpression.Evaluate(
        'SUM([Qty]*0.05+[Qty]*[Rate])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.725')),
        'reversing additive term order must preserve exact output');
      V := TReportExpression.Evaluate(
        'SUM([Qty]*[Rate]-[Qty]*0.05)', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.525')),
        'product minus product must preserve signs for negative operands');
      V := TReportExpression.Evaluate(
        'SUM([Qty]*[Rate]+[Qty]*0.05-[Qty]*0.01)', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.705')),
        'three additive product terms must match independent arithmetic');
      V := TReportExpression.Evaluate(
        'SUM([Qty]*[Rate]+[Qty]*[Rate])', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('1.25')),
        'adding product terms must not change sign or scale');
      V := TReportExpression.Evaluate('SUM([Rate]*0.00004)', Ctx);
      Assert.AreEqual(0, BcdCompare(VarToBcd(V), StrToBcd('0.00002')),
        'positive and negative five-place products retain exact scale');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TAggregatesCurrencyTests.Test_Computed_ProductBeyondCapacity_Raises;
var
  Def: TFieldDef;
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Ctx: TExpressionContext;
  Raised: Boolean;
begin
  DS := TClientDataSet.Create(nil);
  try
    Def := DS.FieldDefs.AddFieldDef;
    Def.Name := 'Amount';
    Def.DataType := ftFMTBCD;
    Def.Precision := 18;
    Def.Size := 0;
    DS.CreateDataSet;
    DS.Append;
    DS.FieldByName('Amount').AsString := '999999999999999999';
    DS.Post;
    DS.First;
    BuildContextOver(DS, Ctx, Engine, Model);
    try
      Raised := False;
      try
        TReportExpression.Evaluate(
          'SUM([Amount]*[Amount]*[Amount]*[Amount])', Ctx);
      except
        on E: EConvertError do
          Raised := Pos('64-digit precision or scale', E.Message) > 0;
      end;
      Assert.IsTrue(Raised,
        'an exact product exceeding the documented capacity must raise, not round or fall back');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAggregatesCurrencyTests);

end.
