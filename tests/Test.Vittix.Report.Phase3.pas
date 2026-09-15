unit Test.Vittix.Report.Phase3;

interface

uses
  System.Types,
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
  TPhase3PerformanceTests = class
  private
    function CreateDataSet(ACount: Integer): TClientDataSet;
    function CreateMasterReport: TReportModel;
  public
    [Test]
    procedure Test_AggregateCache_ReducesRepeatedTraversal_AndPreservesCursor;
    [Test]
    procedure Test_AggregateCache_IsClearedForEachReportExecution;
    [Test]
    procedure Test_SubReportModelCache_ReducesParseCount_WithoutReducingScans;
  end;

implementation

function TPhase3PerformanceTests.CreateDataSet(ACount: Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  for I := 1 to ACount do
    Result.AppendRecord([I, I * 10.0]);
  Result.First;
end;

function TPhase3PerformanceTests.CreateMasterReport: TReportModel;
var
  Band: TReportBand;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Result.Objects.Add(Band);
end;

procedure TPhase3PerformanceTests.Test_AggregateCache_ReducesRepeatedTraversal_AndPreservesCursor;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Context: TExpressionContext;
  Snapshot: TReportTraversalSnapshot;
  FirstValue, SecondValue: Variant;
begin
  DataSet := CreateDataSet(20);
  Model := TReportModel.Create;
  try
    DataSet.Next;
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Context := Default(TExpressionContext);
      Context.DataSet := DataSet;
      Context.Hooks := Engine;
      Context.Parameters := Engine.Parameters;
      Context.Variables := Model.Variables;
      TReportTraversalDiagnostics.Reset;

      FirstValue := TReportExpression.Evaluate('SUM([Amount])', Context);
      SecondValue := TReportExpression.Evaluate('SUM([Amount])', Context);
      Snapshot := TReportTraversalDiagnostics.Snapshot;

      Assert.AreEqual(Double(FirstValue), Double(SecondValue), 0.001);
      Assert.AreEqual(2100.0, Double(FirstValue), 0.001);
      Assert.AreEqual(2, Snapshot.AggregateEvaluations);
      Assert.AreEqual(1, Snapshot.AggregateCacheMisses);
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
      Assert.AreEqual(1, Snapshot.AggregateTraversals);
      Assert.AreEqual(20, Snapshot.AggregateRowsVisited);
      Assert.AreEqual(2, DataSet.FieldByName('ID').AsInteger,
        'A cache hit must preserve the same caller cursor behavior as the initial evaluation.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase3PerformanceTests.Test_AggregateCache_IsClearedForEachReportExecution;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Summary: TReportBand;
  Text1, Text2: TReportTextObject;
  Snapshot: TReportTraversalSnapshot;
begin
  DataSet := CreateDataSet(5);
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
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.AggregateTraversals);
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);

      TReportTraversalDiagnostics.Reset;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.AggregateTraversals,
        'A new Prepare execution must not reuse a previous execution cache.');
      Assert.AreEqual(1, Snapshot.AggregateCacheHits);
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase3PerformanceTests.Test_SubReportModelCache_ReducesParseCount_WithoutReducingScans;
var
  DataSet: TClientDataSet;
  Model, SubModel: TReportModel;
  Engine: TReportEngine;
  MasterBand, SubBand: TReportBand;
  SubReport: TReportSubReportObject;
  Snapshot: TReportTraversalSnapshot;
begin
  DataSet := CreateDataSet(2);
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
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(1, Snapshot.SubReportParseAttempts);
      Assert.AreEqual(1, Snapshot.SubReportCacheMisses);
      Assert.AreEqual(1, Snapshot.SubReportCacheHits);
      Assert.AreEqual(2, Snapshot.SubReportTraversals,
        'Phase 3 intentionally caches parsed models only, not linked dataset scans.');
      Assert.AreEqual(4, Snapshot.SubReportRowsVisited);
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
  TDUnitX.RegisterTestFixture(TPhase3PerformanceTests);

end.
