unit Test.Vittix.Report.Phase2;

{
  Phase 2 -- data capability and traversal diagnostics.

  The no-bookmark dataset deliberately removes only bookmark acquisition. It
  remains an in-memory TClientDataSet so each test is deterministic and uses
  the same field/navigation behavior as the normal test fixtures.
}

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
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
  Vittix.Report.TraversalDiagnostics,
  Vittix.Report.Utils;

type
  TNoBookmarkClientDataSet = class(TClientDataSet)
  public
    function GetBookmark: TBookmark; override;
  end;

  [TestFixture]
  TPhase2DataCapabilityTests = class
  private
    function CreateDataSet(const ACount: Integer; ANoBookmarks: Boolean = False): TClientDataSet;
    function CreateMasterReport: TReportModel;
    function CreateMasterDetailReport: TReportModel;
  public
    [Test]
    procedure Test_NonBookmarkSource_IsDetectedWithoutProviderDependency;
    [Test]
    procedure Test_NonBookmark_MasterTraversal_LeavesCursorAtEOF_CurrentBehavior;
    [Test]
    procedure Test_NonBookmark_Aggregate_LeavesCursorAtEOF_CurrentBehavior;
    [Test]
    procedure Test_NonBookmark_Grouping_Completes_CurrentBehavior;
    [Test]
    procedure Test_NonBookmark_MasterDetail_Completes_CurrentBehavior;
    [Test]
    procedure Test_NonBookmark_SubReport_Completes_CurrentBehavior;
    [Test]
    procedure Test_DetailTraversalDiagnostics_CountExistingScans;
    [Test]
    procedure Test_SubReportTraversalDiagnostics_ObserveExistingWork;
  end;

implementation

function TNoBookmarkClientDataSet.GetBookmark: TBookmark;
begin
  Result := nil;
end;

function TPhase2DataCapabilityTests.CreateDataSet(const ACount: Integer;
  ANoBookmarks: Boolean): TClientDataSet;
var
  I: Integer;
  GroupCode: string;
begin
  if ANoBookmarks then
    Result := TNoBookmarkClientDataSet.Create(nil)
  else
    Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('MasterID', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.FieldDefs.Add('GroupCode', ftString, 8);
  Result.CreateDataSet;
  for I := 1 to ACount do
  begin
    if Odd(I) then
      GroupCode := 'A'
    else
      GroupCode := 'B';
    Result.AppendRecord([I, I, I * 10.0, GroupCode]);
  end;
  Result.First;
end;

function TPhase2DataCapabilityTests.CreateMasterReport: TReportModel;
var
  Band: TReportBand;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Result.Objects.Add(Band);
end;

function TPhase2DataCapabilityTests.CreateMasterDetailReport: TReportModel;
var
  MasterBand, DetailBand: TReportBand;
begin
  Result := CreateMasterReport;
  MasterBand := TReportBand(Result.Objects[0]);
  MasterBand.Name := 'Master';
  DetailBand := TReportBand.Create;
  DetailBand.Name := 'Details';
  DetailBand.BandType := btDetail;
  DetailBand.Height := 10;
  DetailBand.DataSetName := 'Details';
  DetailBand.MasterField := 'ID';
  DetailBand.DetailField := 'MasterID';
  Result.Objects.Add(DetailBand);
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmarkSource_IsDetectedWithoutProviderDependency;
var
  DataSet: TClientDataSet;
begin
  DataSet := CreateDataSet(2, True);
  try
    Assert.IsFalse(DataSetSupportsBookmarks(DataSet),
      'The deterministic test source must report no bookmark capability.');
    Assert.IsTrue(DataSet.Active);
  finally
    DataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmark_MasterTraversal_LeavesCursorAtEOF_CurrentBehavior;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
begin
  DataSet := CreateDataSet(3, True);
  Model := CreateMasterReport;
  try
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Assert.AreEqual(1, Engine.PageCount);
      Assert.IsTrue(DataSet.Eof,
        'Without a bookmark, current engine traversal cannot restore caller position.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmark_Aggregate_LeavesCursorAtEOF_CurrentBehavior;
var
  DataSet: TClientDataSet;
  Context: TExpressionContext;
begin
  DataSet := CreateDataSet(3, True);
  try
    Context := Default(TExpressionContext);
    Context.DataSet := DataSet;
    Assert.AreEqual(60.0, Double(TReportExpression.Evaluate('SUM([Amount])', Context)), 0.001);
    Assert.IsTrue(DataSet.Eof,
      'Aggregate evaluation directly uses bookmark APIs and does not restore this source.');
  finally
    DataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmark_Grouping_Completes_CurrentBehavior;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  GroupBand: TReportBand;
begin
  DataSet := CreateDataSet(4, True);
  Model := CreateMasterReport;
  try
    GroupBand := TReportBand.Create;
    GroupBand.BandType := btGroupHeader;
    GroupBand.GroupField := 'GroupCode';
    GroupBand.Height := 10;
    Model.Objects.Insert(0, GroupBand);
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Assert.IsTrue(Engine.PageCount > 0);
      Assert.IsTrue(DataSet.Eof,
        'Grouping completes, but does not restore a no-bookmark primary source.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmark_MasterDetail_Completes_CurrentBehavior;
var
  MasterDataSet, DetailDataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
begin
  MasterDataSet := CreateDataSet(2, True);
  DetailDataSet := CreateDataSet(3, True);
  Model := CreateMasterDetailReport;
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    NamedDataSets.Add('Details', DetailDataSet);
    Engine := TReportEngine.Create(Model, MasterDataSet, NamedDataSets, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Assert.IsTrue(MasterDataSet.Eof);
      Assert.IsTrue(DetailDataSet.Eof,
        'Detail traversal completes but cannot restore a no-bookmark source.');
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
    DetailDataSet.Free;
    MasterDataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_NonBookmark_SubReport_Completes_CurrentBehavior;
var
  DataSet: TClientDataSet;
  Model, SubModel: TReportModel;
  Engine: TReportEngine;
  MasterBand: TReportBand;
  SubReport: TReportSubReportObject;
begin
  DataSet := CreateDataSet(2, True);
  Model := CreateMasterReport;
  SubModel := CreateMasterReport;
  try
    MasterBand := TReportBand(Model.Objects[0]);
    SubReport := TReportSubReportObject.Create;
    SubReport.ReportJSON := TReportSerializer.SaveToJSON(SubModel);
    SubReport.Bounds := Rect(5, 2, 200, 80);
    MasterBand.Children.Add(SubReport);
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Assert.IsTrue(Engine.PageCount > 0);
      Assert.IsTrue(DataSet.Eof,
        'Subreport traversal completes but cannot restore a no-bookmark source.');
    finally
      Engine.Free;
    end;
  finally
    SubModel.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_DetailTraversalDiagnostics_CountExistingScans;
var
  MasterDataSet, DetailDataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Snapshot: TReportTraversalSnapshot;
begin
  MasterDataSet := CreateDataSet(2);
  DetailDataSet := CreateDataSet(3);
  Model := CreateMasterDetailReport;
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    NamedDataSets.Add('Details', DetailDataSet);
    TReportTraversalDiagnostics.Reset;
    Engine := TReportEngine.Create(Model, MasterDataSet, NamedDataSets, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.AreEqual(4, Snapshot.DetailTraversals,
        'Two master rows currently cause a look-ahead and print scan each.');
      Assert.AreEqual(9, Snapshot.DetailRowsVisited,
        'Diagnostic row count must expose the existing repeated scan pattern.');
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
    DetailDataSet.Free;
    MasterDataSet.Free;
  end;
end;

procedure TPhase2DataCapabilityTests.Test_SubReportTraversalDiagnostics_ObserveExistingWork;
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

    TReportTraversalDiagnostics.Reset;
    Engine := TReportEngine.Create(Model, DataSet, nil);
    try
      Engine.TwoPassRendering := False;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      Assert.IsTrue(Snapshot.SubReportParseAttempts > 0);
      Assert.IsTrue(Snapshot.SubReportTraversals > 0);
      Assert.IsTrue(Snapshot.SubReportRowsVisited > 0);
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
  TDUnitX.RegisterTestFixture(TPhase2DataCapabilityTests);

end.
