unit Test.Vittix.Report.Phase6.DetailTraversal;

{
  Phase 6 — linked-detail traversal characterization (GAP-004).

  STATUS: the planned detail-match INDEX is DEFERRED (not implemented). Evidence
  gathered while implementing it showed the optimization can only help the
  bookmark-capable TDataSet transport, while the checked-in corpus reaches the
  detail path through TVittixUserDataSet, which has no bookmarks. The index
  would therefore speed up a path no corpus report uses and could not be
  validated by the CI gate. See docs/Phase6-Output-Coverage.md.

  These tests are kept as evidence: they lock the CURRENT, pre-optimization
  behavior of the GAP-004 hot path — for every master row the engine rescans the
  whole detail dataset (cost O(masters x details)). The scaling test records the
  baseline any future index would have to improve without changing output.

  The tests assert STRUCTURAL counters only (TReportTraversalDiagnostics), so
  they are deterministic and CI-safe.

  No production file is modified by this unit.
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
  Vittix.Report.Engine,
  Vittix.Report.TraversalDiagnostics;

type
  [TestFixture]
  TPhase6DetailTraversalTests = class
  private
    function CreateMasterData(ACount: Integer): TClientDataSet;
    function CreateDetailData(const AMasterIDs: array of Integer): TClientDataSet;
    function BuildLinkedReport: TReportModel;
    function RunEngine(AMaster: TClientDataSet; ADetail: TClientDataSet;
      out DetailTraversals, DetailRowsVisited, PageCount: Integer): Integer;
  public
    [Test] procedure Test_Detail_NoMatch_CurrentBehavior;
    [Test] procedure Test_Detail_MatchLastRow_CurrentBehavior;
    [Test] procedure Test_Detail_MatchFirstRow_CurrentBehavior;
    [Test] procedure Test_Detail_ScalingBaseline_200x50;
  end;

implementation

const
  MasterBandHeight = 20;
  DetailBandHeight = 10;

function TPhase6DetailTraversalTests.CreateMasterData(
  ACount: Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.CreateDataSet;
  for I := 1 to ACount do
    Result.AppendRecord([I]);
  Result.First;
end;

function TPhase6DetailTraversalTests.CreateDetailData(
  const AMasterIDs: array of Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('MasterID', ftInteger);
  Result.CreateDataSet;
  for I := Low(AMasterIDs) to High(AMasterIDs) do
    Result.AppendRecord([AMasterIDs[I]]);
  Result.First;
end;

function TPhase6DetailTraversalTests.BuildLinkedReport: TReportModel;
var
  MasterBand, DetailBand: TReportBand;
begin
  Result := TReportModel.Create;
  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Height := MasterBandHeight;
  Result.Objects.Add(MasterBand);

  DetailBand := TReportBand.Create;
  DetailBand.BandType := btDetail;
  DetailBand.Height := DetailBandHeight;
  DetailBand.DataSetName := 'Details';
  DetailBand.MasterField := 'ID';
  DetailBand.DetailField := 'MasterID';
  Result.Objects.Add(DetailBand);
end;

function TPhase6DetailTraversalTests.RunEngine(AMaster: TClientDataSet;
  ADetail: TClientDataSet;
  out DetailTraversals, DetailRowsVisited, PageCount: Integer): Integer;
var
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Snapshot: TReportTraversalSnapshot;
begin
  Model := BuildLinkedReport;
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    // The detail source is reached through the named-dataset registry
    // (Band.DataSetName = 'Details'), exactly as production reports do.
    NamedDataSets.Add('Details', ADetail);
    Engine := TReportEngine.Create(Model, AMaster, NamedDataSets, nil);
    try
      Engine.TwoPassRendering := False;
      TReportTraversalDiagnostics.Reset;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;
      DetailTraversals := Snapshot.DetailTraversals;
      DetailRowsVisited := Snapshot.DetailRowsVisited;
      PageCount := Engine.Pages.Count;
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
  end;
  Result := PageCount;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_NoMatch_CurrentBehavior;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited, Pages: Integer;
begin
  // 10 masters x 10 details, no detail row ever matches.
  // Current behavior: every master performs TWO full detail scans
  // (one look-ahead for the first detail row's height, one to print).
  Master := CreateMasterData(10);
  Detail := CreateDetailData([999, 999, 999, 999, 999, 999, 999, 999, 999, 999]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited, Pages);

    Assert.AreEqual(20, Traversals,
      'Two detail scans per master row (height look-ahead + print).');
    Assert.AreEqual(200, RowsVisited,
      'No match means each scan visits all 10 detail rows: 10 masters x 2 x 10.');
    Assert.IsTrue(Pages >= 1, 'The report must still render at least one page.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MatchLastRow_CurrentBehavior;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited, Pages: Integer;
begin
  // One master, and its only matching detail row is the LAST of 10.
  // Current behavior: the look-ahead scan visits all 10 rows to find it.
  Master := CreateMasterData(1);
  Detail := CreateDetailData([999, 999, 999, 999, 999, 999, 999, 999, 999, 1]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited, Pages);

    Assert.AreEqual(2, Traversals,
      'Two detail scans per master row: height look-ahead + print.');
    Assert.AreEqual(20, RowsVisited,
      'Look-ahead walks all 10 rows to reach the last match; the print scan ' +
      'always visits all 10 rows.');
    Assert.IsTrue(Pages >= 1, 'The report must render.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MatchFirstRow_CurrentBehavior;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited, Pages: Integer;
begin
  // The matching detail row is the first one: the look-ahead stops at once.
  Master := CreateMasterData(1);
  Detail := CreateDetailData([1, 999, 999, 999, 999, 999, 999, 999, 999, 999]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited, Pages);

    Assert.AreEqual(2, Traversals, 'Two detail scans per master row.');
    Assert.AreEqual(11, RowsVisited,
      'Look-ahead stops after 1 row, but the print scan always visits all 10.');
    Assert.IsTrue(Pages >= 1, 'The report must render.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_ScalingBaseline_200x50;
var
  Master, Detail: TClientDataSet;
  IDs: TArray<Integer>;
  I: Integer;
  Traversals, RowsVisited, Pages: Integer;
begin
  // GAP-004 baseline at scale: 200 masters x 50 detail rows, and no detail row
  // matches any master. Every master performs two full 50-row scans, giving
  // 2 x 200 x 50 = 20 000 visited rows. This is the number the Phase 6 index
  // must collapse toward a single detail pass, WITHOUT changing output.
  Master := CreateMasterData(200);
  SetLength(IDs, 50);
  for I := 0 to High(IDs) do
    IDs[I] := 999999; // never matches
  Detail := CreateDetailData(IDs);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited, Pages);

    Assert.AreEqual(400, Traversals, 'Two scans per master row: 2 x 200.');
    Assert.AreEqual(20000, RowsVisited,
      'Baseline: O(masters x details) = 200 x 2 x 50.');
    Assert.IsTrue(Pages >= 1, 'The report must render at least one page.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase6DetailTraversalTests);

end.
