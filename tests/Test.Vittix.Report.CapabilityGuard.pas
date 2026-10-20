unit Test.Vittix.Report.CapabilityGuard;

{
  Dataset capability guard (v1.0 freeze fix).

  Groups, aggregates, cross-tab and chart all evaluate through dataset
  bookmarks.  A TFDQuery with FetchOptions.Unidirectional := True (or any
  bookmark-incapable cursor) used to fail mid-render with confusing
  errors (CrossTab's unguarded GetBookmark, group bookmark restore
  failures).  Prepare now fails up front with a clear message naming the
  fix, and progress totals can be vetoed host-side through the
  ProgressTotalHook so a FireDAC on-demand cursor's fetched-so-far count
  is never published as a total.

  The fake dataset is a TClientDataSet descendant whose GetBookmark
  raises - exactly the observable behavior of a unidirectional cursor.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.Types,
  System.SysUtils,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.Interfaces;

type
  { Behaves like a bookmark-incapable cursor: every GetBookmark raises,
    which makes DataSetSupportsBookmarks return False. }
  TNoBookmarkDataSet = class(TClientDataSet)
  public
    function GetBookmark: TBookmark; override;
  end;

  { Records the progress calls the engine makes. }
  TProgressRecorder = class(TInterfacedObject, IReportProgress)
  public
    TotalSet: Integer;
    TotalCalls: Integer;
    AdvanceCalls: Integer;
    procedure SetTotal(const Total: Integer);
    procedure Advance(const Current: Integer);
    function IsCancelled: Boolean;
  end;

  [TestFixture]
  TCapabilityGuardTests = class
  private
    function BuildRowTable: TClientDataSet;
    function BuildGroupModel: TReportModel;
    function BuildPlainModel: TReportModel;
    function BuildAggregateModel: TReportModel;
    function BuildCrossTabModel: TReportModel;
  public
    [Test] procedure Test_CrossTab_On_BookmarklessData_Raises_ClearError;
    [Test] procedure Test_AggregateExpression_On_BookmarklessData_Raises_ClearError;
    [Test] procedure Test_GroupBands_On_BookmarklessData_StillPrepares;
    [Test] procedure Test_PlainReport_On_BookmarklessData_StillPrepares;
    [Test] procedure Test_NormalDataset_With_Groups_StillPrepares;
    [Test] procedure Test_ProgressHook_Unknown_Total_Publishes_Zero;
    [Test] procedure Test_ProgressHook_Known_Total_Is_Used;
    [Test] procedure Test_NoHook_Keeps_RecordCount_Total;
  end;

{ Test hooks matching TReportProgressTotalHook (Vittix.Report.Interfaces). }
function ProgressTotalUnknownHook(ADataSet: TDataSet;
  out ATotal: Integer): Boolean;
function ProgressTotalKnownHook(ADataSet: TDataSet;
  out ATotal: Integer): Boolean;

implementation

function TNoBookmarkDataSet.GetBookmark: TBookmark;
begin
  raise EDatabaseError.Create('Dataset is unidirectional (no bookmarks)');
end;

procedure TProgressRecorder.SetTotal(const Total: Integer);
begin
  TotalSet := Total;
  Inc(TotalCalls);
end;

procedure TProgressRecorder.Advance(const Current: Integer);
begin
  Inc(AdvanceCalls);
end;

function TProgressRecorder.IsCancelled: Boolean;
begin
  Result := False;
end;

function ProgressTotalUnknownHook(ADataSet: TDataSet;
  out ATotal: Integer): Boolean;
begin
  ATotal := 0;
  Result := False; // FireDAC on-demand: fetched-so-far is not a total
end;

function ProgressTotalKnownHook(ADataSet: TDataSet;
  out ATotal: Integer): Boolean;
begin
  ATotal := 42;
  Result := True;
end;

{ ---------------- fixtures ---------------- }

function TCapabilityGuardTests.BuildRowTable: TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  for I := 1 to 5 do
    Result.AppendRecord(['North', I * 10.0]);
  Result.First;
end;

function TCapabilityGuardTests.BuildGroupModel: TReportModel;
var
  Band: TReportBand;
  Txt: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btGroupHeader;
  Band.GroupField := 'Region';
  Band.Height := 20;
  Txt := TReportTextObject.Create;
  Txt.Text := 'Group';
  Band.Children.Add(Txt);
  Result.Objects.Add(Band);
end;

function TCapabilityGuardTests.BuildPlainModel: TReportModel;
var
  Band: TReportBand;
  Txt: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Txt := TReportTextObject.Create;
  Txt.Text := 'Row';
  Band.Children.Add(Txt);
  Result.Objects.Add(Band);
end;

function TCapabilityGuardTests.BuildAggregateModel: TReportModel;
var
  Band: TReportBand;
  Txt: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btReportSummary;
  Band.Height := 20;
  Txt := TReportTextObject.Create;
  Txt.Expression := 'SUM([Amount])';
  Band.Children.Add(Txt);
  Result.Objects.Add(Band);
end;

function TCapabilityGuardTests.BuildCrossTabModel: TReportModel;
var
  Band: TReportBand;
  CrossTab: TReportCrossTabObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btReportSummary;
  Band.Height := 40;
  CrossTab := TReportCrossTabObject.Create;
  CrossTab.Name := 'cross1';
  CrossTab.Bounds := Rect(10, 10, 310, 110);
  CrossTab.RowField := 'Region';
  CrossTab.ColumnField := 'Region';
  CrossTab.CellField := 'Amount';
  Band.Children.Add(CrossTab);
  Result.Objects.Add(Band);
end;

{ ---------------- tests ---------------- }

procedure TCapabilityGuardTests.Test_CrossTab_On_BookmarklessData_Raises_ClearError;
var
  DS: TNoBookmarkDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  RaisedMsg: string;
begin
  DS := TNoBookmarkDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['North', 10.0]);
    DS.First;

    Model := BuildCrossTabModel;
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      RaisedMsg := '';
      try
        Engine.Prepare;
      except
        on E: EReportException do
          RaisedMsg := E.Message;
      end;
      Assert.Contains(RaisedMsg,
        'FetchOptions.Unidirectional := False',
        'cross-tab needs bookmarks and must get the clear fix message');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_GroupBands_On_BookmarklessData_StillPrepares;
var
  DS: TNoBookmarkDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
begin
  // Backward compatibility (pinned by Phase2): group bands degrade
  // gracefully without bookmarks and must NOT trip the guard.
  DS := TNoBookmarkDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['North', 10.0]);
    DS.AppendRecord(['South', 20.0]);
    DS.First;

    Model := BuildGroupModel;
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Engine.Prepare;
      Assert.IsTrue(Engine.PageCount >= 1, 'grouped report must still render');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_AggregateExpression_On_BookmarklessData_Raises_ClearError;
var
  DS: TNoBookmarkDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  RaisedMsg: string;
begin
    DS := TNoBookmarkDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['North', 10.0]);
    DS.First;

    Model := BuildAggregateModel;
    Engine := TReportEngine.Create(Model, DS, nil);
    try
      RaisedMsg := '';
      try
        Engine.Prepare;
      except
        on E: EReportException do
          RaisedMsg := E.Message;
      end;
      Assert.Contains(RaisedMsg,
        'FetchOptions.Unidirectional := False',
        'aggregate expressions need bookmarks');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_PlainReport_On_BookmarklessData_StillPrepares;
var
  DS: TNoBookmarkDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
begin
  // Backward compatibility: a plain row report never touches bookmarks,
  // so it must keep rendering even on a bookmark-incapable dataset.
  DS := TNoBookmarkDataSet.Create(nil);
  try
    DS.FieldDefs.Add('Region', ftString, 20);
    DS.FieldDefs.Add('Amount', ftFloat);
    DS.CreateDataSet;
    DS.AppendRecord(['North', 10.0]);
    DS.First;

    Model := BuildPlainModel;
    Engine := TReportEngine.Create(Model, TClientDataSet(DS), nil);
    try
      Engine.Prepare;
      Assert.IsTrue(Engine.PageCount >= 1, 'plain report must render');
    finally
      Engine.Free;
      Model.Free;
    end;
  finally
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_NormalDataset_With_Groups_StillPrepares;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
begin
  // Normal (bookmark-capable) datasets must be unaffected by the guard.
  DS := BuildRowTable;
  Model := BuildGroupModel;
  Engine := TReportEngine.Create(Model, DS, nil);
  try
    Engine.Prepare;
    Assert.IsTrue(Engine.PageCount >= 1, 'grouped report must render');
  finally
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_ProgressHook_Unknown_Total_Publishes_Zero;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Recorder: TProgressRecorder;
  SavedHook: TReportProgressTotalHook;
begin
  DS := BuildRowTable;
  Model := BuildPlainModel;
  Recorder := TProgressRecorder.Create;
  SavedHook := ProgressTotalHook;
  ProgressTotalHook := ProgressTotalUnknownHook;
  try
    Engine := TReportEngine.Create(Model, DS, Recorder);
    try
      Engine.Prepare;
      Assert.AreEqual(1, Recorder.TotalCalls, 'SetTotal called once per pass');
      Assert.AreEqual(0, Recorder.TotalSet,
        'unknown total must publish 0, not a fetched-so-far count');
    finally
      Engine.Free;
    end;
  finally
    ProgressTotalHook := SavedHook;
    Model.Free;
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_ProgressHook_Known_Total_Is_Used;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Recorder: TProgressRecorder;
  SavedHook: TReportProgressTotalHook;
begin
  DS := BuildRowTable;
  Model := BuildPlainModel;
  Recorder := TProgressRecorder.Create;
  SavedHook := ProgressTotalHook;
  ProgressTotalHook := ProgressTotalKnownHook;
  try
    Engine := TReportEngine.Create(Model, DS, Recorder);
    try
      Engine.Prepare;
      Assert.IsTrue(Recorder.TotalCalls >= 1, 'SetTotal called');
      Assert.AreEqual(42, Recorder.TotalSet, 'hook total wins');
    finally
      Engine.Free;
    end;
  finally
    ProgressTotalHook := SavedHook;
    Model.Free;
    DS.Free;
  end;
end;

procedure TCapabilityGuardTests.Test_NoHook_Keeps_RecordCount_Total;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Recorder: TProgressRecorder;
begin
  DS := BuildRowTable; // 5 rows
  Model := BuildPlainModel;
  Recorder := TProgressRecorder.Create;
  try
    Assert.IsTrue(not Assigned(ProgressTotalHook), 'test assumes default hook');
    Engine := TReportEngine.Create(Model, DS, Recorder);
    try
      Engine.Prepare;
      Assert.IsTrue(Recorder.TotalCalls >= 1, 'SetTotal called');
      Assert.AreEqual(5, Recorder.TotalSet,
        'without a hook the historical RecordCount total is kept');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCapabilityGuardTests);

end.
