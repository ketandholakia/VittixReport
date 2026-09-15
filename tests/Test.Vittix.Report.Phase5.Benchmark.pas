unit Test.Vittix.Report.Phase5.Benchmark;

{
  Phase 5 — Benchmark harness.

  Deterministic, gate-safe performance characterization. These tests assert
  STRUCTURAL counters only (TReportTraversalDiagnostics), never wall-clock
  time. Elapsed time and process resources are recorded informationally so a
  human can see the trend, but no assertion depends on them.

  This mirrors the Phase 3 pattern (Test.Vittix.Report.Phase3.pas) and simply
  scales it: the Phase 3 fixtures use 20/5/2 rows; this unit adds the 100-row
  and 10,000-row cases the Phase 5 plan calls for.

  No production unit is modified or required by this harness.
}

interface

uses
  System.SysUtils,
  System.Types,
  System.Variants,
  System.Diagnostics,
  System.IOUtils,
  Data.DB,
  Datasnap.DBClient,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Engine,
  Vittix.Report.Expressions,
  Vittix.Report.Serializer,
  Vittix.Report.TraversalDiagnostics;

type
  [TestFixture]
  TPhase5BenchmarkTests = class
  private
    function CreateDataSet(ACount: Integer): TClientDataSet;
    function CreateMasterReport: TReportModel;
    function BuildContext(ADataSet: TClientDataSet; AModel: TReportModel;
      AEngine: TReportEngine): TExpressionContext;
    procedure RecordTiming(const ALabel: string; AStopwatch: TStopwatch;
      ARows: Integer);
  public
    { Aggregate cache scaling. }
    [Test] procedure Test_Benchmark_AggregateCache_100Rows;
    [Test] procedure Test_Benchmark_AggregateCache_10000Rows;
    { A real engine render pass must still reuse one cached aggregate scan. }
    [Test] procedure Test_Benchmark_RenderPass_AggregateReuse_1000Rows;
    { Subreport parsed-model cache must not scale with row count. }
    [Test] procedure Test_Benchmark_SubReportModelCache_100Rows;
  end;

implementation

const
  { ID = 1..N, Amount = ID * 10. }
  AmountFactor = 10.0;

function SumAmount(ACount: Integer): Double;
begin
  // sum(i * 10) for i = 1..N  =  10 * N * (N + 1) / 2
  Result := AmountFactor * (ACount * (ACount + 1)) / 2.0;
end;

function TPhase5BenchmarkTests.CreateDataSet(ACount: Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  for I := 1 to ACount do
    Result.AppendRecord([I, I * AmountFactor]);
  Result.First;
end;

function TPhase5BenchmarkTests.CreateMasterReport: TReportModel;
var
  Band: TReportBand;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Result.Objects.Add(Band);
end;

function TPhase5BenchmarkTests.BuildContext(ADataSet: TClientDataSet;
  AModel: TReportModel; AEngine: TReportEngine): TExpressionContext;
begin
  Result := Default(TExpressionContext);
  Result.DataSet := ADataSet;
  Result.Hooks := AEngine;
  Result.Parameters := AEngine.Parameters;
  Result.Variables := AModel.Variables;
end;

procedure TPhase5BenchmarkTests.RecordTiming(const ALabel: string;
  AStopwatch: TStopwatch; ARows: Integer);
var
  Line: string;
  Dir: string;
begin
  // Informational only — never asserted. DUnitX captures console output, so
  // the trend is appended to a run log under build\ (gitignored) where a human
  // and the CI artifact upload can see it. The structural counters in the
  // assertions are what the gate enforces.
  Line := Format('[benchmark] %s: %d rows in %d ms (%s)',
    [ALabel, ARows, AStopwatch.ElapsedMilliseconds,
     FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]);
  Writeln(Line);
  try
    Dir := TPath.Combine(TPath.GetFullPath('.'), 'build');
    TDirectory.CreateDirectory(Dir);
    TFile.AppendAllText(TPath.Combine(Dir, 'phase5-benchmark-timings.txt'),
      Line + sLineBreak, TEncoding.UTF8);
  except
    // Never let informational logging affect a test result.
  end;
end;

procedure TPhase5BenchmarkTests.Test_Benchmark_AggregateCache_100Rows;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  Snapshot: TReportTraversalSnapshot;
  First, Second: Variant;
  Watch: TStopwatch;
begin
  DataSet := CreateDataSet(100);
  Model := TReportModel.Create;
  try
    DataSet.Next;
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Context := BuildContext(DataSet, Model, Engine);
      TReportTraversalDiagnostics.Reset;
      Watch := TStopwatch.StartNew;

      First := TReportExpression.Evaluate('SUM([Amount])', Context);
      Second := TReportExpression.Evaluate('SUM([Amount])', Context);

      Watch.Stop;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      RecordTiming('aggregate 2x SUM, 100 rows', Watch, 100);

      Assert.AreEqual(SumAmount(100), Double(First), 0.001, 'SUM over 100 rows');
      Assert.AreEqual(Double(First), Double(Second), 0.001,
        'The cached value must equal the initial value.');
      Assert.AreEqual(2, Snapshot.AggregateEvaluations);
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses,
        'Only the first evaluation scans.');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits,
        'The second evaluation must hit the cache.');
      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'One dataset traversal for two identical aggregates.');
      Assert.AreEqual(100, Snapshot.AggregateRowsVisited,
        'The traversal must visit every row exactly once.');
      Assert.AreEqual(2, DataSet.FieldByName('ID').AsInteger,
        'Cache hit must preserve the caller cursor (started at row 2).');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase5BenchmarkTests.Test_Benchmark_AggregateCache_10000Rows;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  Snapshot: TReportTraversalSnapshot;
  First, Second: Variant;
  Watch: TStopwatch;
begin
  DataSet := CreateDataSet(10000);
  Model := TReportModel.Create;
  try
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Context := BuildContext(DataSet, Model, Engine);
      TReportTraversalDiagnostics.Reset;
      Watch := TStopwatch.StartNew;

      First := TReportExpression.Evaluate('SUM([Amount])', Context);
      Second := TReportExpression.Evaluate('SUM([Amount])', Context);

      Watch.Stop;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      RecordTiming('aggregate 2x SUM, 10000 rows', Watch, 10000);

      Assert.AreEqual(SumAmount(10000), Double(First), 1.0,
        'SUM over 10000 rows');
      Assert.AreEqual(Double(First), Double(Second), 1.0,
        'The cached value must equal the initial value at scale.');
      Assert.AreEqual(2, Snapshot.AggregateEvaluations);
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses,
        'Cache behavior must not degrade with row count.');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'Exactly one traversal regardless of 10000 rows.');
      Assert.AreEqual(10000, Snapshot.AggregateRowsVisited,
        'Every row visited exactly once.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase5BenchmarkTests.Test_Benchmark_RenderPass_AggregateReuse_1000Rows;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Summary: TReportBand;
  Text1, Text2: TReportTextObject;
  Engine: TReportEngine;
  Snapshot: TReportTraversalSnapshot;
  Watch: TStopwatch;
begin
  DataSet := CreateDataSet(1000);
  Model := CreateMasterReport;
  try
    Summary := TReportBand.Create;
    Summary.BandType := btReportSummary;
    Summary.Height := 30;
    Text1 := TReportTextObject.Create;
    Text1.Expression := 'SUM([Amount])';
    Text1.Bounds := Rect(0, 0, 100, 14);
    Summary.Children.Add(Text1);
    Text2 := TReportTextObject.Create;
    Text2.Expression := 'SUM([Amount])';
    Text2.Bounds := Rect(0, 15, 100, 29);
    Summary.Children.Add(Text2);
    Model.Objects.Add(Summary);

    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      TReportTraversalDiagnostics.Reset;
      Watch := TStopwatch.StartNew;

      Engine.Prepare;

      Watch.Stop;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      RecordTiming('render pass, 1000 rows, 2 summary aggregates', Watch, 1000);

      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'Two identical summary aggregates must share one traversal in a real render.');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits,
        'The second summary aggregate must be served from the cache.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase5BenchmarkTests.Test_Benchmark_SubReportModelCache_100Rows;
var
  DataSet: TClientDataSet;
  Model, SubModel: TReportModel;
  Engine: TReportEngine;
  MasterBand, SubBand: TReportBand;
  SubReport: TReportSubReportObject;
  Snapshot: TReportTraversalSnapshot;
  Watch: TStopwatch;
begin
  DataSet := CreateDataSet(100);
  Model := CreateMasterReport;
  SubModel := CreateMasterReport;
  try
    MasterBand := TReportBand(Model.Objects[0]);
    SubBand := TReportBand(SubModel.Objects[0]);
    SubBand.Height := 10;
    SubReport := TReportSubReportObject.Create;
    SubReport.ReportJSON := TReportSerializer.SaveToJSON(SubModel);
    SubReport.Bounds := Rect(5, 2, 200, 80);
    MasterBand.Children.Add(SubReport);

    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      TReportTraversalDiagnostics.Reset;
      Watch := TStopwatch.StartNew;

      Engine.Prepare;

      Watch.Stop;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      RecordTiming('render pass, 100 rows, 1 subreport', Watch, 100);

      // The invariant that matters: parsing is cached, so it does NOT scale
      // with the number of master rows.
      Assert.AreEqual(1, Snapshot.SubReportParseAttempts,
        'The subreport JSON must be parsed once regardless of row count.');
      Assert.AreEqual(1, Snapshot.SubReportCacheMisses,
        'Exactly one parse miss for the whole render.');
      Assert.IsTrue(Snapshot.SubReportTraversals >= 100,
        'Linked subreport traversal is intentionally not cached in Phase 5 ' +
        '(GAP-004 partial); it still scans per master row.');
    finally
      Engine.Free;
    end;
  finally
    SubModel.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase5BenchmarkTests);

end.
