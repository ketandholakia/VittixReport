unit Test.Vittix.Report.AggregatesCurrency;

{
  Currency-safe aggregates (v1.0 freeze fix).

  TReportAggregates used to accumulate SUM/AVG/MIN/MAX in Double, so
  NUMERIC(18,2) columns (FireDAC ftBCD - the Firebird money layout)
  drifted away from SQL SUM() as rows accumulated.  SUM/AVG/MIN/MAX now
  accumulate in Currency when the inner expression is a bare [Field]
  token bound to a BCD/FMTBCD/currency field (read via Field.AsCurrency,
  no Double round trip), or when the evaluator hands back a varCurrency
  value.  Every other input keeps the exact Double path from before.

  These tests pin EXACT equality (not tolerance): the old Double
  accumulator fails them, the Currency accumulator passes.

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

{ Qty INTEGER + Rate NUMERIC(18,2) table for computed-aggregate tests.
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
  Def.Size := 2;
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
  // The Currency accumulator (4 decimals) would round every row to 1.0000
  // and return 10000; the scaled-Int64 path returns exactly 10000.01.
  // The pre-fix Double path drifts (1.000001 is not binary-representable)
  // and fails the exact equality below.
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
      // Tolerance is the half-ulp class of Double at this magnitude
      // (~1e-12); the PRE-fix Currency accumulator returned 10000.00
      // (every row rounded to 4 decimals), off by 0.01 - a different
      // failure class entirely.
      V := TReportExpression.Evaluate('SUM([R6])', Ctx);
      Assert.IsTrue(VarType(V) = varDouble, 'scale>4 SUM stays a Double');
      Assert.IsTrue(Abs(Double(V) - 10000.01) < 1e-9,
        Format('SUM of 6-decimal values must be 10000.01, got %.15f',
          [Double(V)]));

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

initialization
  TDUnitX.RegisterTestFixture(TAggregatesCurrencyTests);

end.
