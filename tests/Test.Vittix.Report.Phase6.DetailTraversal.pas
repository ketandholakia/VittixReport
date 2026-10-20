unit Test.Vittix.Report.Phase6.DetailTraversal;

{
  Phase 6 — linked-detail traversal (GAP-004).

  Detail matching uses the historical ordered First..Eof scan for both
  TDataSet and TVittixUserDataSet transports. Each master row observes the
  detail dataset's current visible rows. Matching uses VarSameValue, so NULL
  matches NULL, and output remains in detail-dataset order. Scan-cost tests
  and the large-data benchmark are separate from output-correctness tests.
}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Engine,
  Vittix.Report.UserDataSet,
  Vittix.Report.Context,
  Vittix.Report.TraversalDiagnostics,
  Vittix.Report.Export.Commands,
  Vittix.Report.Interfaces;

type
  [TestFixture]
  TPhase6DetailTraversalTests = class
  private
    FDetailMutationDone: Boolean;
    FDetailToMutate: TClientDataSet;
    function CreateMasterData(ACount: Integer): TClientDataSet;
    function CreateDetailData(const AMasterIDs: array of Integer): TClientDataSet;
    function BuildLinkedReport(const AMasterField: string = 'ID';
      const ADetailField: string = 'MasterID'): TReportModel;
    function BuildLinkedReportWithText(const AFieldName: string = 'MasterID'): TReportModel;
    procedure HandleBeforeBandForMutation(Sender: TObject; AEngine: TObject;
      ABand: TReportBand; const Context: TExpressionContext;
      var ACanPrint: Boolean);
    procedure HandleBeforeBandForFailure(Sender: TObject; AEngine: TObject;
      ABand: TReportBand; const Context: TExpressionContext;
      var ACanPrint: Boolean);
    procedure HandleBeforePrintCancel(Sender: TObject; AEngine: TObject;
      AReport: TReportModel; var ACancel: Boolean);
    procedure RunEngine(AMaster: TClientDataSet; ADetail: TClientDataSet;
      out DetailTraversals, DetailRowsVisited: Integer);
  public
    [Test] procedure Test_DetailScanCost_NoMatch_10x10;
    [Test] procedure Test_DetailScanCost_MatchLast_1x10;
    [Test] procedure Test_DetailScanCost_MatchFirst_1x10;
    [Test] procedure Test_DetailScanCost_NoMatch_200x50;
    [Test] procedure Test_Detail_InvalidDetailField_Raises;
    [Test] procedure Test_Detail_PartialRelationship_Raises;
    [Test] procedure Test_Detail_InvalidDetailField_UserDataSet_Raises;
    [Test] procedure Test_Detail_Unlinked_RemainsSupported;
    [Test] procedure Test_Benchmark_DetailScan_2000x20;
    [Test] procedure Test_Detail_NullKey_MatchesNullRows;
    [Test] procedure Test_Detail_MasterLinked_KeepsHistoricalScan;
    [Test] procedure Test_Detail_MasterLinked_ScanCostCounters;
    [Test] procedure Test_Detail_MasterLinked_CallerDisabledRejectedWithoutBalancing;
    [Test] procedure Test_Detail_MasterLinked_CancellationRestoresState;
    [Test] procedure Test_Detail_NestedMasterLinksChangeVisibleRows;
    [Test] procedure Test_Detail_DataChangesBetweenPasses_SecondPassReflectsNewData;
    [Test] procedure Test_Detail_MidPassInteriorMutation_SameCountAndFirstKey;
    [Test] procedure Test_Detail_RenderFailure_RestoresPositionAndControls;
  end;

  { Collects the detail-band text values in print order through the real
  export capture, so rendered values and row order can be asserted directly. }
function CollectDetailTexts(ADoc: TObject): TStringList;

type
  TCancelAfterFirstProgress = class(TInterfacedObject, IReportProgress)
  public
    procedure SetTotal(const Total: Integer);
    procedure Advance(const Current: Integer);
    function IsCancelled: Boolean;
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

function TPhase6DetailTraversalTests.BuildLinkedReport(
  const AMasterField, ADetailField: string): TReportModel;
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
  DetailBand.MasterField := AMasterField;
  DetailBand.DetailField := ADetailField;
  Result.Objects.Add(DetailBand);
end;

function TPhase6DetailTraversalTests.BuildLinkedReportWithText(const AFieldName: string): TReportModel;
var
  DetailBand: TReportBand;
  Txt: TReportTextObject;
begin
  // Same linked model, but the detail band carries a text child bound to
  // the detail field so the printed OUTPUT can be compared, not just the
  // traversal counters.
  Result := BuildLinkedReport;
  DetailBand := TReportBand(Result.Objects[1]);
  Txt := TReportTextObject.Create;
  Txt.DataField := AFieldName;
  Txt.Bounds := Rect(2, 2, 100, 18);
  DetailBand.Children.Add(Txt);
end;

procedure TPhase6DetailTraversalTests.HandleBeforeBandForMutation(
  Sender: TObject; AEngine: TObject; ABand: TReportBand;
  const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  ACanPrint := True;
  // At the start of master row 2, mutate an INTERIOR detail row. The
  // record count and first detail key stay unchanged; later scans must see
  // the row's new key and omit it from master row 3.
  if FDetailMutationDone or (Context.RowNumber <> 2) then
    Exit;
  FDetailMutationDone := True;
  if FDetailToMutate.Locate('MasterID', 3, []) then
  begin
    FDetailToMutate.Edit;
    FDetailToMutate.FieldByName('MasterID').AsInteger := 99;
    FDetailToMutate.Post;
  end;
end;

procedure TPhase6DetailTraversalTests.HandleBeforeBandForFailure(
  Sender: TObject; AEngine: TObject; ABand: TReportBand;
  const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  ACanPrint := True;
  if ABand.BandType = btDetail then
    raise EInvalidOpException.Create('intentional detail-band failure');
end;

procedure TPhase6DetailTraversalTests.HandleBeforePrintCancel(
  Sender: TObject; AEngine: TObject; AReport: TReportModel;
  var ACancel: Boolean);
begin
  ACancel := True;
end;

procedure TCancelAfterFirstProgress.SetTotal(const Total: Integer);
begin
end;

procedure TCancelAfterFirstProgress.Advance(const Current: Integer);
begin
end;

function TCancelAfterFirstProgress.IsCancelled: Boolean;
begin
  Result := True;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_InvalidDetailField_Raises;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Raised: Boolean;
begin
  Master := CreateMasterData(2);
  Detail := CreateDetailData([1, 2]);
  Model := BuildLinkedReport('ID', 'TypoMasterID');
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    NamedDataSets.Add('Details', Detail);
    Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
    try
      Raised := False;
      try
        Engine.Prepare;
      except
        on E: EReportException do
        begin
          Raised := True;
          Assert.IsTrue(Pos('TypoMasterID', E.Message) > 0,
            'diagnostic must identify the missing detail field');
        end;
      end;
      Assert.IsTrue(Raised,
        'an invalid configured relationship must not print every detail row');
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_PartialRelationship_Raises;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
begin
  Master := CreateMasterData(1);
  Detail := CreateDetailData([1]);
  Model := BuildLinkedReport('ID', '');
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    NamedDataSets.Add('Details', Detail);
    Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
    try
      Assert.WillRaise(
        procedure begin Engine.Prepare; end,
        EReportException,
        'a relationship must define both fields or neither field');
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_InvalidDetailField_UserDataSet_Raises;
var
  Master, Detail: TClientDataSet;
  MasterUDS, DetailUDS: TVittixUserDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedUserDataSets: TDictionary<string, TVittixUserDataSet>;
begin
  Master := CreateMasterData(2);
  Detail := CreateDetailData([1, 2]);
  MasterUDS := TVittixUserDataSet.Create(nil);
  DetailUDS := TVittixUserDataSet.Create(nil);
  Model := BuildLinkedReport('ID', 'TypoMasterID');
  NamedUserDataSets := TDictionary<string, TVittixUserDataSet>.Create;
  try
    MasterUDS.DataSet := Master;
    DetailUDS.DataSet := Detail;
    NamedUserDataSets.Add('Details', DetailUDS);
    Engine := TReportEngine.Create(Model, MasterUDS, NamedUserDataSets, nil);
    try
      Assert.WillRaise(
        procedure begin Engine.Prepare; end,
        EReportException,
        'wrapped datasets must receive the same relationship validation');
    finally
      Engine.Free;
    end;
  finally
    NamedUserDataSets.Free;
    Model.Free;
    DetailUDS.Free;
    MasterUDS.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_Unlinked_RemainsSupported;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Texts: TStringList;
begin
  Master := CreateMasterData(1);
  Detail := CreateDetailData([10, 20, 30]);
  try
    Model := BuildLinkedReportWithText;
    // Empty relationship fields are supported and print every detail row
    // in dataset order.
    TReportBand(Model.Objects[1]).MasterField := '';
    TReportBand(Model.Objects[1]).DetailField := '';
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(3, Texts.Count, 'all unlinked detail rows render');
          Assert.AreEqual('10', Texts[0], 'first detail row stays first');
          Assert.AreEqual('20', Texts[1], 'second detail row stays second');
          Assert.AreEqual('30', Texts[2], 'third detail row stays third');
        finally
          Texts.Free;
        end;
        Assert.IsFalse(Detail.ControlsDisabled);
        Assert.AreEqual(1, Detail.RecNo, 'position is restored after rendering');
      finally
        Engine.Free;
        Doc.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.RunEngine(AMaster: TClientDataSet;
  ADetail: TClientDataSet; out DetailTraversals, DetailRowsVisited: Integer);
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
    finally
      Engine.Free;
    end;
  finally
    NamedDataSets.Free;
    Model.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_DetailScanCost_NoMatch_10x10;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited: Integer;
begin
  // 10 masters x 10 details, no detail row ever matches.  The per-pass
  // key index builds once and no-match lookups visit no detail rows.
  Master := CreateMasterData(10);
  Detail := CreateDetailData([999, 999, 999, 999, 999, 999, 999, 999, 999, 999]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited);

    Assert.AreEqual(20, Traversals,
      'Two detail traversals per master row (height look-ahead + print).');
    Assert.AreEqual(10, RowsVisited,
      'One 10-row index build; no-match master keys visit nothing.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_DetailScanCost_MatchLast_1x10;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited: Integer;
begin
  // One master, and its only matching detail row is the LAST of 10.
  // The index builds once over all 10 rows, then visits only the match.
  Master := CreateMasterData(1);
  Detail := CreateDetailData([999, 999, 999, 999, 999, 999, 999, 999, 999, 1]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited);

    Assert.AreEqual(2, Traversals,
      'Two detail traversals: height look-ahead + print.');
    Assert.AreEqual(12, RowsVisited,
      'One 10-row index build + one matched look-ahead + one matched print visit.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_DetailScanCost_MatchFirst_1x10;
var
  Master, Detail: TClientDataSet;
  Traversals, RowsVisited: Integer;
begin
  // The matching detail row is the first one: the look-ahead stops at once.
  Master := CreateMasterData(1);
  Detail := CreateDetailData([1, 999, 999, 999, 999, 999, 999, 999, 999, 999]);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited);

    Assert.AreEqual(2, Traversals, 'Two detail traversals: look-ahead + print.');
    Assert.AreEqual(12, RowsVisited,
      'One 10-row index build + one matched look-ahead + one matched print ' +
      'visit (build overhead shows on tiny data; the 2000x20 benchmark wins).');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_DetailScanCost_NoMatch_200x50;
var
  Master, Detail: TClientDataSet;
  IDs: TArray<Integer>;
  I: Integer;
  Traversals, RowsVisited: Integer;
begin
  // Deterministic scan-cost characterization: 200 masters x 50 details,
  // no matches, and two full detail scans per master.
  Master := CreateMasterData(200);
  SetLength(IDs, 50);
  for I := 0 to High(IDs) do
    IDs[I] := 999999; // never matches
  Detail := CreateDetailData(IDs);
  try
    RunEngine(Master, Detail, Traversals, RowsVisited);

    Assert.AreEqual(400, Traversals, 'Two traversals per master row: 2 x 200.');
    Assert.AreEqual(50, RowsVisited,
      'One 50-row index build replaces every per-master scan.');
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Benchmark_DetailScan_2000x20;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Snapshot: TReportTraversalSnapshot;
  Started, ElapsedMs: UInt64;
  HeapBefore, HeapAfter: THeapStatus;
  HeapDeltaBytes: Int64;
  BenchmarkLine, BenchmarkOutputPath: string;
begin
  // Reproducible, non-gating scan benchmark: 2,000 master rows and 20
  // detail rows. The first 20 masters match one row each; the remaining
  // 1,980 have no match. Measurements describe this in-memory TClientDataSet
  // workload only, not database I/O or peak process memory.
  Master := CreateMasterData(2000);
  Detail := CreateDetailData([1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
  try
    Model := BuildLinkedReport;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        // Heap delta is GetHeapStatus.TotalAllocated after source datasets
        // are already allocated and while the engine remains alive. It is
        // current Delphi heap allocation, not peak RSS/working set.
        HeapBefore := GetHeapStatus;
        Started := GetTickCount64;
        Engine.Prepare;
        ElapsedMs := GetTickCount64 - Started;
        HeapAfter := GetHeapStatus;
        HeapDeltaBytes := Int64(HeapAfter.TotalAllocated) -
          Int64(HeapBefore.TotalAllocated);
        Snapshot := TReportTraversalDiagnostics.Snapshot;

        Assert.IsTrue(Engine.PageCount >= 1, 'benchmark report renders');
        BenchmarkLine := Format(
          'DETAIL_SCAN_BENCHMARK masters=%d details=%d traversals=%d row_visits=%d elapsed_ms=%d current_heap_delta_bytes=%d measurement=GetTickCount64+GetHeapStatus.TotalAllocated',
          [2000, 20, Snapshot.DetailTraversals, Snapshot.DetailRowsVisited,
           ElapsedMs, HeapDeltaBytes]);
        Writeln(BenchmarkLine);
        // DUnitX suppresses test stdout in its console summary. When this
        // optional path is set, preserve the reproducible measurement outside
        // the source tree for CI/review collection.
        BenchmarkOutputPath := GetEnvironmentVariable(
          'VITTIX_DETAIL_SCAN_BENCHMARK_OUTPUT');
        if BenchmarkOutputPath <> '' then
          TFile.WriteAllText(BenchmarkOutputPath, BenchmarkLine + sLineBreak,
            TEncoding.UTF8);
      finally
        Engine.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_NullKey_MatchesNullRows;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Texts: TStringList;
begin
  Master := TClientDataSet.Create(nil);
  Master.FieldDefs.Add('ID', ftInteger);
  Master.CreateDataSet;
  Master.AppendRecord([Null]);
  Master.AppendRecord([1]);
  Master.AppendRecord([2]);
  Master.First;

  Detail := TClientDataSet.Create(nil);
  Detail.FieldDefs.Add('MasterID', ftInteger);
  Detail.FieldDefs.Add('Label', ftString, 20);
  Detail.CreateDataSet;
  Detail.AppendRecord([Null, 'null-A']);
  Detail.AppendRecord([Null, 'null-B']);
  Detail.AppendRecord([1, 'one']);
  Detail.AppendRecord([2, 'two']);
  Detail.First;
  try
    Model := BuildLinkedReportWithText('Label');
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(4, Texts.Count, 'NULL matches only NULL; numeric keys match their rows');
          Assert.AreEqual('null-A', Texts[0], 'first NULL row remains first');
          Assert.AreEqual('null-B', Texts[1], 'second NULL row remains second');
          Assert.AreEqual('one', Texts[2], 'numeric row 1 follows NULL rows');
          Assert.AreEqual('two', Texts[3], 'numeric row 2 remains last');
        finally
          Texts.Free;
        end;
      finally
        Engine.Free;
        Doc.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    Detail.Free;
    Master.Free;
  end;
end;

function CollectDetailTexts(ADoc: TObject): TStringList;
var
  Doc: TReportExportDocument absolute ADoc;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  Result := TStringList.Create;
  for Page in Doc.Pages do
    for Cmd in Page.Commands do
      if (Cmd is TReportExportTextCommand) and
         (Trim(TReportExportTextCommand(Cmd).Text) <> '') then
        Result.Add(Trim(TReportExportTextCommand(Cmd).Text));
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MasterLinked_KeepsHistoricalScan;
var
  Master, Detail: TClientDataSet;
  MasterSrc: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Texts: TStringList;
begin
  Master := CreateMasterData(3);
  Detail := CreateDetailData([1, 1, 2, 3, 3]);
  MasterSrc := TDataSource.Create(nil);
  try
    MasterSrc.DataSet := Master;
    Detail.IndexFieldNames := 'MasterID';
    Detail.MasterFields := 'ID';
    Detail.MasterSource := MasterSrc;

    // Prove the in-memory master/detail view changes as the master advances.
    Master.First;
    Detail.First;
    Assert.AreEqual(2, Detail.RecordCount, 'master 1 exposes two detail rows');
    Assert.AreEqual(1, Detail.FieldByName('MasterID').AsInteger);
    Master.Next;
    Detail.First;
    Assert.AreEqual(1, Detail.RecordCount, 'master 2 exposes one detail row');
    Assert.AreEqual(2, Detail.FieldByName('MasterID').AsInteger);
    Master.Next;
    Detail.First;
    Assert.AreEqual(2, Detail.RecordCount, 'master 3 exposes two detail rows');
    Assert.AreEqual(3, Detail.FieldByName('MasterID').AsInteger);

    Master.First;
    Detail.First;
    Master.First;
    Model := BuildLinkedReportWithText;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.Prepare;
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(5, Texts.Count, 'all currently visible linked rows render');
          Assert.AreEqual('1', Texts[0], 'master 1 first linked row');
          Assert.AreEqual('1', Texts[1], 'master 1 second linked row');
          Assert.AreEqual('2', Texts[2], 'master 2 linked row');
          Assert.AreEqual('3', Texts[3], 'master 3 first linked row');
          Assert.AreEqual('3', Texts[4], 'master 3 second linked row');
        finally
          Texts.Free;
        end;
        Assert.IsFalse(Detail.ControlsDisabled,
          'master-linked scan leaves controls enabled');
      finally
        Engine.Free;
        Doc.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    MasterSrc.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MasterLinked_ScanCostCounters;
var
  Master, Detail: TClientDataSet;
  MasterSrc: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Snapshot: TReportTraversalSnapshot;
begin
  Master := CreateMasterData(3);
  Detail := CreateDetailData([1, 1, 2, 3, 3]);
  MasterSrc := TDataSource.Create(nil);
  try
    MasterSrc.DataSet := Master;
    Detail.IndexFieldNames := 'MasterID';
    Detail.MasterFields := 'ID';
    Detail.MasterSource := MasterSrc;
    Model := BuildLinkedReport;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.TwoPassRendering := False;
        TReportTraversalDiagnostics.Reset;
        Engine.Prepare;
        Snapshot := TReportTraversalDiagnostics.Snapshot;
        Assert.AreEqual(6, Snapshot.DetailTraversals,
          'three master rows each perform one look-ahead and one print scan');
        Assert.AreEqual(8, Snapshot.DetailRowsVisited,
          'look-ahead visits one row per master; print scans visit 2+1+2 linked rows');
      finally
        Engine.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    MasterSrc.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MasterLinked_CallerDisabledRejectedWithoutBalancing;
var
  Master, Detail: TClientDataSet;
  MasterSrc: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Raised: Boolean;
begin
  Master := CreateMasterData(3);
  Detail := CreateDetailData([1, 1, 2, 3, 3]);
  MasterSrc := TDataSource.Create(nil);
  try
    MasterSrc.DataSet := Master;
    Detail.IndexFieldNames := 'MasterID';
    Detail.MasterFields := 'ID';
    Detail.MasterSource := MasterSrc;
    Model := BuildLinkedReport;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Master.DisableControls;
        Master.DisableControls;
        Raised := False;
        try
          Engine.Prepare;
        except
          on E: EReportException do
            Raised := Pos('requires master controls enabled', E.Message) > 0;
        end;
        Assert.IsTrue(Raised,
          'linked report must reject caller-disabled master notifications');
        Assert.IsTrue(Master.ControlsDisabled,
          'Prepare must not enable controls disabled by its caller');
        Master.EnableControls;
        Assert.IsTrue(Master.ControlsDisabled,
          'one caller disable level remains after one matching enable');
        Master.EnableControls;
        Assert.IsFalse(Master.ControlsDisabled,
          'the caller can balance its own two disable levels');
      finally
        Engine.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    MasterSrc.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MasterLinked_CancellationRestoresState;
var
  Master, Detail: TClientDataSet;
  MasterSrc: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Progress: IReportProgress;
begin
  Master := CreateMasterData(3);
  Detail := CreateDetailData([1, 1, 2, 3, 3]);
  MasterSrc := TDataSource.Create(nil);
  try
    MasterSrc.DataSet := Master;
    Detail.IndexFieldNames := 'MasterID';
    Detail.MasterFields := 'ID';
    Detail.MasterSource := MasterSrc;
    Master.First;
    Master.Next;
    Detail.First;
    Model := BuildLinkedReport;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    Doc := TReportExportDocument.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Progress := TCancelAfterFirstProgress.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, Progress);
      try
        Engine.ExportDocument := Doc;
        Engine.Prepare;
        Assert.AreEqual(1, Engine.PageCount,
          'cancellation after the first row retains the completed partial page');
        Assert.AreEqual(2, Master.RecNo, 'cancel leaves caller master position');
        Assert.AreEqual(1, Detail.RecNo, 'cancel leaves caller detail position');
        Assert.IsFalse(Master.ControlsDisabled, 'master controls remain enabled');
        Assert.IsFalse(Detail.ControlsDisabled, 'detail controls remain enabled');
      finally
        Engine.Free;
      end;
    finally
      Doc.Free;
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    MasterSrc.Free;
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_NestedMasterLinksChangeVisibleRows;
var
  Master, Outer, Inner: TClientDataSet;
  MasterSrc, OuterSrc: TDataSource;
begin
  Master := CreateMasterData(2);
  Outer := TClientDataSet.Create(nil);
  Inner := TClientDataSet.Create(nil);
  MasterSrc := TDataSource.Create(nil);
  OuterSrc := TDataSource.Create(nil);
  try
    Outer.FieldDefs.Add('ID', ftInteger);
    Outer.FieldDefs.Add('MasterID', ftInteger);
    Outer.CreateDataSet;
    Outer.AppendRecord([10, 1]);
    Outer.AppendRecord([11, 1]);
    Outer.AppendRecord([20, 2]);
    Outer.First;
    MasterSrc.DataSet := Master;
    Outer.IndexFieldNames := 'MasterID';
    Outer.MasterFields := 'ID';
    Outer.MasterSource := MasterSrc;

    Inner.FieldDefs.Add('OuterID', ftInteger);
    Inner.FieldDefs.Add('Marker', ftString, 20);
    Inner.CreateDataSet;
    Inner.AppendRecord([10, 'INNER-10']);
    Inner.AppendRecord([11, 'INNER-11']);
    Inner.AppendRecord([20, 'INNER-20']);
    Inner.First;
    OuterSrc.DataSet := Outer;
    Inner.IndexFieldNames := 'OuterID';
    Inner.MasterFields := 'ID';
    Inner.MasterSource := OuterSrc;

    Master.First;
    Outer.First;
    Assert.AreEqual(2, Outer.RecordCount, 'master 1 exposes two outer rows');
    Assert.AreEqual(1, Inner.RecordCount, 'outer 10 exposes one inner row');
    Outer.Next;
    Inner.First;
    Assert.AreEqual(1, Inner.RecordCount, 'outer 11 exposes one inner row');
    Assert.AreEqual('INNER-11', Inner.FieldByName('Marker').AsString);
    Master.Next;
    Outer.First;
    Inner.First;
    Assert.AreEqual(1, Outer.RecordCount, 'master 2 exposes one outer row');
    Assert.AreEqual(1, Inner.RecordCount, 'outer 20 exposes one inner row');
    Assert.AreEqual('INNER-20', Inner.FieldByName('Marker').AsString);
  finally
    OuterSrc.Free;
    MasterSrc.Free;
    Inner.Free;
    Outer.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_DataChangesBetweenPasses_SecondPassReflectsNewData;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Texts: TStringList;
begin
  // Re-Prepare on the same engine after
  // the detail rows changed must print the NEW data.
  Master := CreateMasterData(1);
  Detail := CreateDetailData([1]);
  try
    Model := BuildLinkedReportWithText;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;

        Engine.Prepare;
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(1, Texts.Count, 'first pass prints the one original row');
        finally
          Texts.Free;
        end;

        // Change the detail rows between Prepare calls;
        // the export document accumulates pages, so pass 2 gets a fresh one.
        Doc.Free;
        Doc := TReportExportDocument.Create;
        Engine.ExportDocument := Doc;
        Detail.EmptyDataSet;
        Detail.AppendRecord([1]);
        Detail.AppendRecord([1]);
        Detail.First;

        Engine.Prepare;
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(2, Texts.Count, 'second pass must see BOTH new rows');
        finally
          Texts.Free;
        end;
        Assert.IsFalse(Detail.ControlsDisabled,
          'between-pass render leaves controls enabled');
        Assert.AreEqual(1, Detail.RecNo,
          'between-pass render restores detail position');
      finally
        Engine.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_MidPassInteriorMutation_SameCountAndFirstKey;
var
  Master, Detail: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
  Texts: TStringList;
begin
  // While master row 2 starts, mutate row 3 from key 3 to key 99. The
  // count remains three and the first key remains 1, so this specifically
  // covers the interior-mutation case missed by a first-key guard.
  Master := CreateMasterData(3);
  Detail := CreateDetailData([1, 2, 3]);
  try
    Model := BuildLinkedReportWithText;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        FDetailMutationDone := False;
        FDetailToMutate := Detail;
        Engine.OnBeforeBand := Self.HandleBeforeBandForMutation;
        Engine.Prepare;

        Assert.AreEqual(3, Detail.RecordCount, 'mutation preserves record count');
        Detail.First;
        Assert.AreEqual(1, Detail.FieldByName('MasterID').AsInteger,
          'mutation preserves the first row key');
        Texts := CollectDetailTexts(Doc);
        try
          Assert.AreEqual(2, Texts.Count,
            'later scan observes the changed interior row and omits master 3');
          Assert.AreEqual('1', Texts[0], 'master 1 output remains first');
          Assert.AreEqual('2', Texts[1], 'master 2 output remains second');
        finally
          Texts.Free;
        end;
        Assert.IsFalse(Detail.ControlsDisabled,
          'interior mutation path leaves controls enabled');
        Assert.AreEqual(1, Detail.RecNo,
          'position restores to the original first row');
      finally
        Engine.Free;
        Doc.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    Detail.Free;
    Master.Free;
  end;
end;

procedure TPhase6DetailTraversalTests.Test_Detail_RenderFailure_RestoresPositionAndControls;
var
  Master, Detail: TClientDataSet;
  MasterSrc: TDataSource;
  Model: TReportModel;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  Doc: TReportExportDocument;
begin
  Master := CreateMasterData(2);
  Detail := CreateDetailData([1, 2]);
  MasterSrc := TDataSource.Create(nil);
  try
    MasterSrc.DataSet := Master;
    Detail.IndexFieldNames := 'MasterID';
    Detail.MasterFields := 'ID';
    Detail.MasterSource := MasterSrc;
    Detail.First;
    Model := BuildLinkedReportWithText;
    NamedDataSets := TDictionary<string, TDataSet>.Create;
    try
      NamedDataSets.Add('Details', Detail);
      Doc := TReportExportDocument.Create;
      Engine := TReportEngine.Create(Model, Master, NamedDataSets, nil);
      try
        Engine.ExportDocument := Doc;
        Engine.TwoPassRendering := False;
        Engine.OnBeforeBand := HandleBeforeBandForFailure;

        try
          Engine.Prepare;
          Assert.Fail('a detail-band exception should propagate as a report error');
        except
          on E: EReportException do ;
        end;

        Assert.IsFalse(Detail.ControlsDisabled,
          'detail controls must be re-enabled on the failed render path');
        Assert.IsFalse(Master.ControlsDisabled,
          'master controls must be enabled on the failed linked render path');
        Assert.AreEqual(1, Detail.RecNo,
          'detail position must be restored on the failed render path');
      finally
        Engine.Free;
        Doc.Free;
      end;
    finally
      NamedDataSets.Free;
      Model.Free;
    end;
  finally
    MasterSrc.Free;
    Detail.Free;
    Master.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase6DetailTraversalTests);

end.
