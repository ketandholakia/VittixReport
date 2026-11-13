unit Test.Vittix.Report.Pagination.Streaming;

{
  Phase B focused tests - flat subreport row streaming / continuation.

  Scope: planner-owned atomic-row continuation for FLAT subreports only.
  These tests assert the approved contract:

   - rows that fit remaining space stay on the current page,
   - a row that does not fit is deferred atomically (never drawn partially,
     never emitted) and is re-emitted as the first row of the next page,
   - no speculative blank page is created,
   - no row is duplicated, omitted, or painted outside the physical page,
   - multiple consecutive page breaks and stream termination at the final
     row work,
   - oversized rows follow the approved single-forced-break-and-clip policy
     (identical to existing band behavior) with no infinite loop,
   - cancellation stops the stream and keeps the dataset contract,
   - exceptions during a flushed row clean up stream state and restore
     dataset positions,
   - nested subreports reached through a streamed row stay on the legacy
     clipped path (Phase C isolation - no continuation for nested streams).
  Phase C supersedes this paragraph: a nested subreport inside a streamed row
  now continues too (its own stream session on the engine stack), so
  Test_NestedInsideFlatStream_ContinuesAllInnerRows asserts the complete inner
  row set instead of the Phase B clip. The legacy clipped path remains the
  fallback when streaming is refused (nested-depth cap) - see the Phase C
  suite's recursion test.

  Repository discipline: R-1 (Test_SubReport_PageBoundary_TwoPassPageCount
  Stable) and R-2 (nested) in Test.Vittix.Report.Engine are untouched; this
  unit adds new coverage only.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.StrUtils,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Context,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Engine,
  Vittix.Report.Export.Commands,
  Vittix.Report.Serializer,
  Vittix.Report.PageSettings,
  Vittix.Report.Interfaces;

type
  { Progress object for the cancellation test: cancelled from the start, so
    the flush's per-row cancellation check halts the stream at the first
    page break attempt. }
  TCancelAlwaysProgress = class(TInterfacedObject, IReportProgress)
  public
    procedure SetTotal(const Total: Integer);
    procedure Advance(const Current: Integer);
    function IsCancelled: Boolean;
  end;

type
  TStreamingFixture = record
    MasterDS, DetailDS, InnerDS: TClientDataSet;
    NamedDataSets: TDictionary<string, TDataSet>;
    Model, SubModel, InnerModel: TReportModel;
    ExportDoc: TReportExportDocument;
    Engine: TReportEngine;
    MasterRecNo, DetailRecNo, InnerRecNo: Integer;
  end;

  [TestFixture]
  TTestPaginationStreaming = class
  private
    function BuildDetailDS(ARows: Integer; const APrefix: string): TClientDataSet;
    function BuildSubModel(ARowHeight: Integer; ANested: Boolean;
      out ANestedModel: TReportModel): TReportModel;
    function BuildRefs(AOuterRows, ARowHeight, APageWidth, APageHeight,
      ANested: Integer): TStreamingFixture;
    procedure FreeRefs(var A: TStreamingFixture);
    procedure AssertRowsExactlyOnce(const A: TStreamingFixture;
      const APrefix: string; ARowCount: Integer);
    procedure AssertNoBlankPage(const A: TStreamingFixture);
    procedure AssertContentInsidePhysicalPages(const A: TStreamingFixture);
    procedure AssertTwoPassParity(const A: TStreamingFixture);
    procedure AssertDataSetsRestored(const A: TStreamingFixture);
    procedure RaiseOnContinuationPage(Sender: TObject; AEngine: TObject;
      AObject: TReportObject; const Context: TExpressionContext;
      var ACanPrint: Boolean);
  public
    [Test] procedure Test_FlatStreaming_FitsRemainingSpace_SinglePage;
    [Test] procedure Test_FlatStreaming_PageBoundary_ContinuationAtAtomicRow;
    [Test] procedure Test_FlatStreaming_ConsecutivePageBreaks;
    [Test] procedure Test_FlatStreaming_EmptySubreport;
    [Test] procedure Test_FlatStreaming_OversizedRow_SingleForcedBreak_NoLoop;
    [Test] procedure Test_FlatStreaming_Cancellation_RestoresDataSets;
    [Test] procedure Test_FlatStreaming_ExceptionDuringFlush_RestoresDataSets;
    [Test] procedure Test_NestedInsideFlatStream_ContinuesAllInnerRows;
  end;

implementation

{ ==================================================================== }
{ Helpers                                                              }
{ ==================================================================== }

procedure TCancelAlwaysProgress.SetTotal(const Total: Integer);
begin
  // nothing
end;

procedure TCancelAlwaysProgress.Advance(const Current: Integer);
begin
  // nothing
end;

function TCancelAlwaysProgress.IsCancelled: Boolean;
begin
  Result := True;
end;

function TTestPaginationStreaming.BuildDetailDS(ARows: Integer;
  const APrefix: string): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Marker', ftString, 40);
  Result.CreateDataSet;
  for I := 1 to ARows do
    Result.AppendRecord([I, Format('%s%d', [APrefix, I])]);
  Result.First;
end;

function TTestPaginationStreaming.BuildSubModel(ARowHeight: Integer;
  ANested: Boolean; out ANestedModel: TReportModel): TReportModel;
var
  SubBand: TReportBand;
  Marker: TReportTextObject;
begin
  Result := TReportModel.Create;
  ANestedModel := nil;

  SubBand := TReportBand.Create;
  SubBand.BandType := btMasterData;
  SubBand.Height := ARowHeight;

  Marker := TReportTextObject.Create;
  Marker.Text := '[Marker]';
  Marker.DataField := 'Marker';
  Marker.Bounds := Rect(4, 4, 140, ARowHeight - 4);
  SubBand.Children.Add(Marker);

  if ANested then
  begin
    { Inner (nested) subreport placed inside the row band. Its per-row
      context has RowStream = nil, so it must keep the legacy clipped loop
      (Phase C isolation). }
    ANestedModel := TReportModel.Create;
    var InnerBand := TReportBand.Create;
    InnerBand.BandType := btMasterData;
    InnerBand.Height := 24;
    var InnerMarker := TReportTextObject.Create;
    InnerMarker.Text := '[Marker]';
    InnerMarker.DataField := 'Marker';
    InnerMarker.Bounds := Rect(160, 2, 330, 24);
    InnerBand.Children.Add(InnerMarker);
    ANestedModel.Objects.Add(InnerBand);

    var InnerSub := TReportSubReportObject.Create;
    InnerSub.ReportJSON := TReportSerializer.SaveToJSON(ANestedModel);
    InnerSub.DataSetName := 'InnerRows';
    InnerSub.Bounds := Rect(150, 2, 340, ARowHeight);
    SubBand.Children.Add(InnerSub);
  end;

  Result.Objects.Add(SubBand);
end;

function TTestPaginationStreaming.BuildRefs(AOuterRows, ARowHeight,
  APageWidth, APageHeight, ANested: Integer): TStreamingFixture;
var
  MasterBand: TReportBand;
  SubReport: TReportSubReportObject;
begin
  Result.MasterDS := TClientDataSet.Create(nil);
  Result.MasterDS.FieldDefs.Add('ID', ftInteger);
  Result.MasterDS.CreateDataSet;
  Result.MasterDS.AppendRecord([1]);
  Result.MasterDS.First;
  Result.MasterRecNo := Result.MasterDS.RecNo;

  Result.DetailDS := BuildDetailDS(AOuterRows, 'detail-');
  Result.DetailRecNo := Result.DetailDS.RecNo;

  Result.InnerDS := nil;
  Result.InnerRecNo := 0;
  if ANested <> 0 then
  begin
    Result.InnerDS := BuildDetailDS(6, 'inner-');
    Result.InnerRecNo := Result.InnerDS.RecNo;
  end;

  Result.NamedDataSets := TDictionary<string, TDataSet>.Create;
  Result.NamedDataSets.Add('DetailRows', Result.DetailDS);
  if Assigned(Result.InnerDS) then
    Result.NamedDataSets.Add('InnerRows', Result.InnerDS);

  Result.Model := TReportModel.Create;
  Result.SubModel := BuildSubModel(ARowHeight, ANested <> 0, Result.InnerModel);

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Height := 40;
  MasterBand.CanGrow := True;
  Result.Model.Objects.Add(MasterBand);
  Result.Model.PageSettings.PaperSize := psCustom;
  Result.Model.PageSettings.CustomWidth := APageWidth;
  Result.Model.PageSettings.CustomHeight := APageHeight;
  Result.Model.PageSettings.Margins := TReportMargins.Default;

  SubReport := TReportSubReportObject.Create;
  SubReport.ReportJSON := TReportSerializer.SaveToJSON(Result.SubModel);
  SubReport.DataSetName := 'DetailRows';
  SubReport.Bounds := Rect(5, 2, 340, 170);
  MasterBand.Children.Add(SubReport);

  Result.ExportDoc := TReportExportDocument.Create;
  Result.Engine := TReportEngine.Create(Result.Model, Result.MasterDS,
    Result.NamedDataSets, nil);
  Result.Engine.ExportDocument := Result.ExportDoc;
end;

procedure TTestPaginationStreaming.FreeRefs(var A: TStreamingFixture);
begin
  A.Engine.Free;
  A.ExportDoc.Free;
  A.InnerModel.Free;
  A.SubModel.Free;
  A.Model.Free;
  A.NamedDataSets.Free;
  A.InnerDS.Free;
  A.DetailDS.Free;
  A.MasterDS.Free;
end;

procedure TTestPaginationStreaming.AssertRowsExactlyOnce(
  const A: TStreamingFixture; const APrefix: string; ARowCount: Integer);
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Counts: array of Integer;
  LastSeen: Integer;
  I, Idx: Integer;
  Text: string;
begin
  SetLength(Counts, ARowCount + 1);
  LastSeen := 0;
  for Page in A.ExportDoc.Pages do
    for Cmd in Page.Commands do
      if Cmd is TReportExportTextCommand then
      begin
        Text := TReportExportTextCommand(Cmd).Text;
        if Text.StartsWith(APrefix) then
        begin
          Idx := StrToIntDef(Copy(Text, Length(APrefix) + 1, MaxInt), 0);
          if (Idx < 1) or (Idx > ARowCount) then
            Assert.Fail(Format('unexpected row marker "%s"', [Text]));
          if Idx <= LastSeen then
            Assert.Fail(Format('row order broken at "%s%s" (last seen %d)',
              [APrefix, Idx, LastSeen]));
          LastSeen := Idx;
          Inc(Counts[Idx]);
        end
        else if Text.StartsWith('inner-') and (APrefix = 'detail-') then
        begin
          // nested stream markers are validated by the dedicated test
        end;
      end;
  for I := 1 to ARowCount do
    Assert.AreEqual(1, Counts[I], Format('row %s%d must be emitted exactly ' +
      'once', [APrefix, I]));
end;

procedure TTestPaginationStreaming.AssertNoBlankPage(const A: TStreamingFixture);
var
  Page: TReportExportPage;
begin
  for Page in A.ExportDoc.Pages do
    Assert.IsTrue(Page.Commands.Count > 0,
      'flat subreport pagination must not introduce a blank page');
end;

procedure TTestPaginationStreaming.AssertContentInsidePhysicalPages(
  const A: TStreamingFixture);
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  for Page in A.ExportDoc.Pages do
    for Cmd in Page.Commands do
      if Cmd is TReportExportTextCommand then
      begin
        // Oversized content (taller than the page) is painted clipped to
        // page content by the same EnsurePageSpaceForBand policy every band
        // uses; the export capture records the natural (unclipped) bounds
        // for such content - identical to legacy oversized-band behavior.
        // Everything that fits a page must be inside the physical page.
        if TReportExportTextCommand(Cmd).Bounds.Height < Page.Height then
        begin
          Assert.AreEqual(True,
            TReportExportTextCommand(Cmd).Bounds.Bottom <= Page.Height,
            Format('text painted past the physical page bottom (page h=%d, ' +
              'bottom=%d)', [Page.Height,
              TReportExportTextCommand(Cmd).Bounds.Bottom]));
        end;
        Assert.AreEqual(True,
          TReportExportTextCommand(Cmd).Bounds.Top >= 0,
          'text painted above the physical page top');
      end;
end;

procedure TTestPaginationStreaming.AssertTwoPassParity(
  const A: TStreamingFixture);
begin
  Assert.AreEqual(A.Engine.PageCount, A.ExportDoc.Pages.Count,
    'counting and rendering passes must produce the same page count');
end;

procedure TTestPaginationStreaming.AssertDataSetsRestored(
  const A: TStreamingFixture);
begin
  Assert.AreEqual(A.MasterRecNo, A.MasterDS.RecNo,
    'master dataset position must be restored');
  Assert.AreEqual(A.DetailRecNo, A.DetailDS.RecNo,
    'subreport dataset position must be restored');
  if Assigned(A.InnerDS) then
    Assert.AreEqual(A.InnerRecNo, A.InnerDS.RecNo,
      'inner dataset position must be restored');
end;

procedure TTestPaginationStreaming.RaiseOnContinuationPage(Sender: TObject;
  AEngine: TObject; AObject: TReportObject; const Context: TExpressionContext;
  var ACanPrint: Boolean);
begin
  // Simulates a failing object/row transport once streaming crosses onto a
  // continuation page - the flush must unwind through the PrintBand finally.
  if Context.PageNumber > 1 then
    raise Exception.Create('injected failure on continuation page');
end;

{ ==================================================================== }
{ Tests                                                                }
{ ==================================================================== }

procedure TTestPaginationStreaming.Test_FlatStreaming_FitsRemainingSpace_SinglePage;
var
  A: TStreamingFixture;
begin
  A := BuildRefs(5, 30, 400, 500, 0);
  try
    A.Engine.Prepare;

    Assert.IsTrue(A.Engine.PageCount = 1,
      'rows that fit remaining space must not create pages');
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'detail-', 5);
    AssertContentInsidePhysicalPages(A);
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_PageBoundary_ContinuationAtAtomicRow;
var
  A: TStreamingFixture;
  Page0: TReportExportPage;
  Cmd: TReportExportCommand;
  FirstContRow: Integer;
  FirstContText: string;
  Page0Count: Integer;
  FoundCont: Boolean;
begin
  A := BuildRefs(30, 30, 400, 500, 0);
  try
    A.Engine.Prepare;

    Assert.IsTrue(A.Engine.PageCount > 1,
      'a tall flat subreport must continue on the next page');
    AssertTwoPassParity(A);
    AssertNoBlankPage(A);
    AssertRowsExactlyOnce(A, 'detail-', 30);
    AssertContentInsidePhysicalPages(A);
    AssertDataSetsRestored(A);

    // Deferred row re-emitted first on the next page: page 0 carries only
    // detail rows before the deferral, so its command count identifies the
    // deferred row's ordinal.
    Page0 := A.ExportDoc.Pages[0];
    Page0Count := Page0.Commands.Count;
    Assert.IsTrue(Page0Count > 0, 'page 0 must carry rows before the break');
    Assert.IsTrue(Page0Count < 30, 'page 0 must defer at least one row');
    Assert.IsTrue(A.ExportDoc.Pages.Count > 1);
    FoundCont := False;
    for Cmd in A.ExportDoc.Pages[1].Commands do
      if Cmd is TReportExportTextCommand then
      begin
        FirstContText := TReportExportTextCommand(Cmd).Text;
        FoundCont := True;
        Break;
      end;
    Assert.IsTrue(FoundCont, 'continuation page must carry the deferred row');
    FirstContRow := StrToIntDef(Copy(FirstContText, Length('detail-') + 1,
      MaxInt), 0);
    Assert.AreEqual(Page0Count + 1, FirstContRow,
      'the deferred row must be re-emitted on the next page in order');
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_ConsecutivePageBreaks;
var
  A: TStreamingFixture;
begin
  A := BuildRefs(40, 30, 400, 500, 0);
  try
    A.Engine.Prepare;

    Assert.IsTrue(A.Engine.PageCount >= 3,
      'a long flat stream must cross several pages');
    AssertTwoPassParity(A);
    AssertNoBlankPage(A);
    AssertRowsExactlyOnce(A, 'detail-', 40);
    AssertContentInsidePhysicalPages(A);
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_EmptySubreport;
var
  A: TStreamingFixture;
begin
  A := BuildRefs(0, 30, 400, 500, 0);
  try
    A.Engine.Prepare;

    Assert.IsTrue(A.Engine.PageCount = 1,
      'an empty subreport must not create speculative pages');
    AssertTwoPassParity(A);
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_OversizedRow_SingleForcedBreak_NoLoop;
var
  A: TStreamingFixture;
begin
  A := BuildRefs(2, 600, 400, 500, 0);
  try
    A.Engine.Prepare;

    // Approved oversized-row policy: one forced break per row (exact band
    // semantics), painted clipped to page content - structurally bounded,
    // so the page count stays finite: content start page + one page/row.
    Assert.IsTrue(A.Engine.PageCount <= 3,
      'oversized rows must not trigger an unbounded page-break loop');
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'detail-', 2);
    AssertContentInsidePhysicalPages(A);
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_Cancellation_RestoresDataSets;
var
  A: TStreamingFixture;
  Cancelled: IReportProgress;
begin
  A := BuildRefs(30, 30, 400, 500, 0);
  try
    Cancelled := TCancelAlwaysProgress.Create as IReportProgress;
    A.Engine.Free;
    A.Engine := TReportEngine.Create(A.Model, A.MasterDS,
      A.NamedDataSets, Cancelled);
    A.Engine.ExportDocument := A.ExportDoc;

    A.Engine.Prepare;

    AssertTwoPassParity(A);
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_FlatStreaming_ExceptionDuringFlush_RestoresDataSets;
var
  A: TStreamingFixture;
begin
  A := BuildRefs(30, 30, 400, 500, 0);
  try
    A.Engine.OnBeforeObject := RaiseOnContinuationPage;

    Assert.WillRaise(
      procedure begin A.Engine.Prepare; end,
      EReportException,
      'an exception during a flushed continuation row must propagate');

    // The dataset contract survives the exception: positions restored.
    AssertDataSetsRestored(A);
  finally
    FreeRefs(A);
  end;
end;

procedure TTestPaginationStreaming.Test_NestedInsideFlatStream_ContinuesAllInnerRows;
var
  A: TStreamingFixture;
  Page: TReportExportPage;
  InnerRow: Integer;
  Cmd: TReportExportCommand;
  Text: string;
  Counts: array[1..6] of Integer;
  DetailTotal: Integer;
begin
  A := BuildRefs(30, 30, 400, 500, 1);
  try
    A.Engine.Prepare;

    // The outer stream continues across pages exactly once each...
    AssertRowsExactlyOnce(A, 'detail-', 30);
    AssertTwoPassParity(A);
    AssertDataSetsRestored(A);

    // ...and the nested (inner) subreport now continues instead of clipping
    // (Phase C). Every inner row appears exactly once per outer row: the inner
    // subreport is one logical stream per outer row and each of its six rows
    // is emitted (in place and/or on continuation pages).
    for InnerRow := Low(Counts) to High(Counts) do
      Counts[InnerRow] := 0;
    DetailTotal := 0;
    for Page in A.ExportDoc.Pages do
      for Cmd in Page.Commands do
        if Cmd is TReportExportTextCommand then
        begin
          Text := TReportExportTextCommand(Cmd).Text;
          if Text.StartsWith('detail-') then
            Inc(DetailTotal)
          else if Text.StartsWith('inner-') then
          begin
            InnerRow := StrToIntDef(Copy(Text, Length('inner-') + 1,
              MaxInt), 0);
            if (InnerRow >= 1) and (InnerRow <= 6) then
              Inc(Counts[InnerRow])
            else
              Assert.Fail('unexpected nested row marker: ' + Text);
          end;
        end;
    Assert.IsTrue(DetailTotal > 0, 'the outer rows must be captured');
    for InnerRow := 1 to 6 do
      Assert.AreEqual(DetailTotal, Counts[InnerRow],
        Format('Phase C nested continuation must emit inner-%d once per ' +
          'outer row', [InnerRow]));
  finally
    FreeRefs(A);
  end;
end;

end.
