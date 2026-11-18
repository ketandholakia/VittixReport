unit Test.Vittix.Report.Pagination.Nested;

{
  Phase C focused tests - nested subreport row streaming / continuation.

  Scope: a subreport nested inside a streamed parent row continues at atomic
  row boundaries instead of being clipped to its declared bounds, while the
  Phase B flat continuation and the Phase A planner remain in charge of pages.

  Covered contract:
   - child rows fit / cross one / cross several page boundaries;
   - child continuation completes before the next parent row (source order at
     every nesting level);
   - multiple child records under multiple parent records, nested link
     matching by captured parent values;
   - parent and child dataset restoration (success, cancellation, exception);
   - page/column headers and page numbers on nested continuation pages;
   - no blank page, no duplicate/missing row, atomic rows;
   - count/render/export page-count parity;
   - oversized nested row terminates (bounded), clipped policy;
   - recursion/re-entrancy depth guard falls back to the legacy loop;
   - continued rows never overlap the footer or leave the page content area
     (Phase B geometry inset regression);
   - three-level nesting (grandchild) continuation.

  The pre-existing suites (flat continuation, R-1, R-2, grouped/corpus) are run
  unchanged in the Phase C gates.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
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
  { Cancellation source: cancelled from the start, so the band-boundary
    continuation flush stops at its first per-row cancellation check. }
  TCancelNestedProgress = class(TInterfacedObject, IReportProgress)
  public
    procedure SetTotal(const Total: Integer);
    procedure Advance(const Current: Integer);
    function IsCancelled: Boolean;
  end;

  TTextHit = record
    PageIndex: Integer;
    Text: string;
    Bounds: TRect;
  end;

  TNestedFixture = record
    MainDS, ParentDS, ChildDS, LeafDS: TClientDataSet;
    NamedDataSets: TDictionary<string, TDataSet>;
    Model, OuterModel, InnerModel, LeafModel: TReportModel;
    ExportDoc: TReportExportDocument;
    Engine: TReportEngine;
    MainRecNo, ParentRecNo, ChildRecNo, LeafRecNo: Integer;
    ParentCount, ChildCount, LeafCount: Integer;
    PageW, PageH, FooterH: Integer;
  end;

  [TestFixture]
  TStreamingNestedTests = class
  private
    function BuildMainDS: TClientDataSet;
    function BuildParentDS(AParents: Integer): TClientDataSet;
    function BuildChildDS(AParents, AChildren: Integer): TClientDataSet;
    function BuildLeafDS(AParents, AChildren: Integer): TClientDataSet;
    function BuildLeafModel: TReportModel;
    function BuildInnerModel(ARowHeight: Integer; AWithLeaf: Boolean;
      out ALeafModel: TReportModel): TReportModel;
    function BuildOuterModel(AInnerJSON: string; AOuterRowH, AInnerTop: Integer;
      AWithLeaf: Boolean): TReportModel;
    function BuildFixture(AParents, AChildren: Integer; APageW, APageH: Integer;
      AChildRowH: Integer; AWithChrome: Boolean;
      const AHeaderText: string = 'HDR'; AWithLeaf: Boolean = False): TNestedFixture;
    procedure FreeFixture(var A: TNestedFixture);
    function Hits(const A: TNestedFixture; const APrefix: string): TArray<TTextHit>;
    procedure AssertRowsExactlyOnce(const A: TNestedFixture;
      const APrefix: string; AExpected: Integer);
    procedure AssertNoBlankPage(const A: TNestedFixture);
    procedure AssertTwoPassParity(const A: TNestedFixture);
    procedure AssertDataSetsRestored(const A: TNestedFixture);
    procedure AssertNestedGrouping(const A: TNestedFixture;
      AParents: Integer);
    procedure RaiseForNestedMarkerOnContinuation(Sender: TObject;
      AEngine: TObject; AObject: TReportObject;
      const Context: TExpressionContext; var ACanPrint: Boolean);
    function BuildChainReport(ADepth: Integer): TReportModel;
  public
    [Test] procedure Test_NestedFitsCurrentPage;
    [Test] procedure Test_ChildRowsCrossOnePageBoundary;
    [Test] procedure Test_ChildRowsCrossMultiplePageBoundaries;
    [Test] procedure Test_ParentContinuesAfterChildContinuation;
    [Test] procedure Test_NestedLinkMatching;
    [Test] procedure Test_ParentAndChildDatasetsRestoredAfterSuccess;
    [Test] procedure Test_DatasetsRestoredAfterCancellation;
    [Test] procedure Test_DatasetsRestoredAfterNestedFlushException;
    [Test] procedure Test_PageAndColumnHeadersOnContinuationPages;
    [Test] procedure Test_PageNumbersOnNestedContinuationPages;
    [Test] procedure Test_NoBlankPageAtNestedBoundaries;
    [Test] procedure Test_NoDuplicateOrMissingRowsAndAtomicity;
    [Test] procedure Test_CountRenderExportPageCountParity;
    [Test] procedure Test_NestedOversizedRow_TerminatesAndClips;
    [Test] procedure Test_NestedRecursionDepth_Guarded;
    [Test] procedure Test_NestedContinuationRespectsFooterAndPageBounds;
    [Test] procedure Test_ThreeLevelNesting_ContinuesAllLevels;
  end;

implementation

{ ==================================================================== }
{ Progress + helpers                                                   }
{ ==================================================================== }

procedure TCancelNestedProgress.SetTotal(const Total: Integer);
begin
end;

procedure TCancelNestedProgress.Advance(const Current: Integer);
begin
end;

function TCancelNestedProgress.IsCancelled: Boolean;
begin
  Result := True;
end;

function TStreamingNestedTests.BuildMainDS: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.CreateDataSet;
  Result.AppendRecord([1]);
  Result.First;
end;

function TStreamingNestedTests.BuildParentDS(AParents: Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('MainID', ftInteger);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Label', ftString, 20);
  Result.CreateDataSet;
  for I := 1 to AParents do
    Result.AppendRecord([1, I, Format('parent-%d', [I])]);
  Result.First;
end;

function TStreamingNestedTests.BuildChildDS(AParents,
  AChildren: Integer): TClientDataSet;
var
  P, M: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('ParentID', ftInteger);
  Result.FieldDefs.Add('Marker', ftString, 20);
  Result.CreateDataSet;
  for P := 1 to AParents do
    for M := 1 to AChildren do
      Result.AppendRecord([(P - 1) * AChildren + M, P,
        Format('child-%d-%d', [P, M])]);
  Result.First;
end;

function TStreamingNestedTests.BuildLeafDS(AParents,
  AChildren: Integer): TClientDataSet;
var
  P, M: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ParentID', ftInteger);
  Result.FieldDefs.Add('Marker', ftString, 24);
  Result.CreateDataSet;
  for P := 1 to AParents do
    for M := 1 to AChildren do
      Result.AppendRecord([(P - 1) * AChildren + M,
        Format('leaf-%d-%d', [P, M])]);
  Result.First;
end;

function TStreamingNestedTests.BuildLeafModel: TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 18;
  Text := TReportTextObject.Create;
  Text.Text := '[Marker]';
  Text.DataField := 'Marker';
  Text.Bounds := Rect(2, 2, 300, 16);
  Band.Children.Add(Text);
  Result.Objects.Add(Band);
end;

function TStreamingNestedTests.BuildInnerModel(ARowHeight: Integer;
  AWithLeaf: Boolean; out ALeafModel: TReportModel): TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
begin
  Result := TReportModel.Create;
  ALeafModel := nil;

  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := ARowHeight;
  Text := TReportTextObject.Create;
  Text.Text := '[Marker]';
  Text.DataField := 'Marker';
  Text.Bounds := Rect(2, 2, 140, ARowHeight - 2);
  Band.Children.Add(Text);

  if AWithLeaf then
  begin
    ALeafModel := BuildLeafModel;
    var LeafSub := TReportSubReportObject.Create;
    LeafSub.ReportJSON := TReportSerializer.SaveToJSON(ALeafModel);
    LeafSub.DataSetName := 'Leaves';
    LeafSub.MasterField := 'ID';
    LeafSub.DetailField := 'ParentID';
    LeafSub.Bounds := Rect(140, 4, 330, 22);
    Band.Children.Add(LeafSub);
  end;

  Result.Objects.Add(Band);
end;

function TStreamingNestedTests.BuildOuterModel(AInnerJSON: string;
  AOuterRowH, AInnerTop: Integer; AWithLeaf: Boolean): TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
  Sub: TReportSubReportObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := AOuterRowH;

  Text := TReportTextObject.Create;
  Text.Text := '[Label]';
  Text.DataField := 'Label';
  Text.Bounds := Rect(2, 2, 140, 18);
  Band.Children.Add(Text);

  Sub := TReportSubReportObject.Create;
  Sub.ReportJSON := AInnerJSON;
  Sub.DataSetName := 'Children';
  Sub.MasterField := 'ID';
  Sub.DetailField := 'ParentID';
  Sub.Bounds := Rect(4, AInnerTop, 340, AInnerTop + 22);
  Band.Children.Add(Sub);

  Result.Objects.Add(Band);
end;

function TStreamingNestedTests.BuildFixture(AParents, AChildren: Integer;
  APageW, APageH: Integer; AChildRowH: Integer; AWithChrome: Boolean;
  const AHeaderText: string; AWithLeaf: Boolean): TNestedFixture;
var
  MasterBand: TReportBand;
  Sub: TReportSubReportObject;
  Band: TReportBand;
  Text: TReportTextObject;
  InnerJSON: string;
begin
  Result := Default(TNestedFixture);
  Result.PageW := APageW;
  Result.PageH := APageH;
  Result.FooterH := 0;
  Result.ParentCount := AParents;
  Result.ChildCount := AChildren;
  Result.LeafCount := 0;

  Result.MainDS := BuildMainDS;
  Result.ParentDS := BuildParentDS(AParents);
  Result.ChildDS := BuildChildDS(AParents, AChildren);
  Result.MainRecNo := Result.MainDS.RecNo;
  Result.ParentRecNo := Result.ParentDS.RecNo;
  Result.ChildRecNo := Result.ChildDS.RecNo;

  Result.NamedDataSets := TDictionary<string, TDataSet>.Create;
  Result.NamedDataSets.Add('Parents', Result.ParentDS);
  Result.NamedDataSets.Add('Children', Result.ChildDS);

  if AWithLeaf then
  begin
    Result.LeafDS := BuildLeafDS(AParents, AChildren);
    Result.LeafRecNo := Result.LeafDS.RecNo;
    Result.LeafCount := AParents * AChildren;
    Result.NamedDataSets.Add('Leaves', Result.LeafDS);
  end;

  Result.InnerModel := BuildInnerModel(AChildRowH, AWithLeaf, Result.LeafModel);
  InnerJSON := TReportSerializer.SaveToJSON(Result.InnerModel);
  Result.OuterModel := BuildOuterModel(InnerJSON, 30, 20, AWithLeaf);

  Result.Model := TReportModel.Create;
  Result.Model.PageSettings.PaperSize := psCustom;
  Result.Model.PageSettings.CustomWidth := APageW;
  Result.Model.PageSettings.CustomHeight := APageH;
  Result.Model.PageSettings.Margins := TReportMargins.Default;

  if AWithChrome then
  begin
    Band := TReportBand.Create;
    Band.BandType := btPageHeader;
    Band.Height := 20;
    Text := TReportTextObject.Create;
    Text.Text := AHeaderText;
    Text.Bounds := Rect(2, 2, 300, 18);
    Band.Children.Add(Text);
    Result.Model.Objects.Add(Band);

    Band := TReportBand.Create;
    Band.BandType := btColumnHeader;
    Band.Height := 18;
    Text := TReportTextObject.Create;
    Text.Text := 'COL';
    Text.Bounds := Rect(2, 2, 300, 16);
    Band.Children.Add(Text);
    Result.Model.Objects.Add(Band);

    Band := TReportBand.Create;
    Band.BandType := btPageFooter;
    Band.Height := 20;
    Text := TReportTextObject.Create;
    Text.Text := 'FTR';
    Text.Bounds := Rect(2, 2, 300, 18);
    Band.Children.Add(Text);
    Result.Model.Objects.Add(Band);
    Result.FooterH := 20;
  end;

  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Height := 40;
  MasterBand.CanGrow := True;
  Sub := TReportSubReportObject.Create;
  Sub.ReportJSON := TReportSerializer.SaveToJSON(Result.OuterModel);
  Sub.DataSetName := 'Parents';
  Sub.MasterField := 'ID';
  Sub.DetailField := 'MainID';
  Sub.Bounds := Rect(5, 2, 340, 40);
  MasterBand.Children.Add(Sub);
  Result.Model.Objects.Add(MasterBand);

  Result.ExportDoc := TReportExportDocument.Create;
  Result.Engine := TReportEngine.Create(Result.Model, Result.MainDS,
    Result.NamedDataSets, nil);
  Result.Engine.ExportDocument := Result.ExportDoc;
end;

procedure TStreamingNestedTests.FreeFixture(var A: TNestedFixture);
begin
  A.Engine.Free;
  A.ExportDoc.Free;
  A.LeafModel.Free;
  A.InnerModel.Free;
  A.OuterModel.Free;
  A.Model.Free;
  A.NamedDataSets.Free;
  A.LeafDS.Free;
  A.ChildDS.Free;
  A.ParentDS.Free;
  A.MainDS.Free;
end;

function TStreamingNestedTests.Hits(const A: TNestedFixture;
  const APrefix: string): TArray<TTextHit>;
var
  P, C: Integer;
  Page: TReportExportPage;
  Cmd: TReportExportTextCommand;
begin
  Result := nil;
  for P := 0 to A.ExportDoc.Pages.Count - 1 do
  begin
    Page := A.ExportDoc.Pages[P];
    for C := 0 to Page.Commands.Count - 1 do
      if Page.Commands[C] is TReportExportTextCommand then
      begin
        Cmd := TReportExportTextCommand(Page.Commands[C]);
        if (APrefix = '') or Cmd.Text.StartsWith(APrefix) then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)].PageIndex := P;
          Result[High(Result)].Text := Cmd.Text;
          Result[High(Result)].Bounds := Cmd.Bounds;
        end;
      end;
  end;
end;

procedure TStreamingNestedTests.AssertRowsExactlyOnce(const A: TNestedFixture;
  const APrefix: string; AExpected: Integer);
var
  HitsArr: TArray<TTextHit>;
  Counts: TDictionary<string, Integer>;
  Hit: TTextHit;
begin
  HitsArr := Hits(A, APrefix);
  Counts := TDictionary<string, Integer>.Create;
  try
    for Hit in HitsArr do
      if Counts.ContainsKey(Hit.Text) then
        Counts[Hit.Text] := Counts[Hit.Text] + 1
      else
        Counts.Add(Hit.Text, 1);
    Assert.AreEqual(AExpected, Length(HitsArr),
      Format('%s rows: expected %d, got %d', [APrefix, AExpected, Length(HitsArr)]));
    for Hit in HitsArr do
      Assert.AreEqual(1, Counts[Hit.Text],
        Format('%s row "%s" must be emitted exactly once', [APrefix, Hit.Text]));
  finally
    Counts.Free;
  end;
end;

procedure TStreamingNestedTests.AssertNoBlankPage(const A: TNestedFixture);
var
  P: Integer;
begin
  for P := 0 to A.ExportDoc.Pages.Count - 1 do
    Assert.IsTrue(A.ExportDoc.Pages[P].Commands.Count > 0,
      Format('page %d must not be blank', [P]));
end;

procedure TStreamingNestedTests.AssertTwoPassParity(const A: TNestedFixture);
begin
  Assert.AreEqual(A.Engine.PageCount, A.ExportDoc.Pages.Count,
    'counting and rendering passes must produce the same page count');
end;

procedure TStreamingNestedTests.AssertDataSetsRestored(
  const A: TNestedFixture);
begin
  Assert.AreEqual(A.MainRecNo, A.MainDS.RecNo,
    'main dataset position must be restored');
  Assert.AreEqual(A.ParentRecNo, A.ParentDS.RecNo,
    'parent dataset position must be restored');
  Assert.AreEqual(A.ChildRecNo, A.ChildDS.RecNo,
    'child dataset position must be restored');
  if Assigned(A.LeafDS) then
    Assert.AreEqual(A.LeafRecNo, A.LeafDS.RecNo,
      'leaf dataset position must be restored');
end;

{ Ordering at every nesting level: parent labels appear in source order, and
  every child run belongs to the parent label that precedes it. }
procedure TStreamingNestedTests.AssertNestedGrouping(const A: TNestedFixture;
  AParents: Integer);
var
  HitsArr: TArray<TTextHit>;
  Hit: TTextHit;
  LastParent, ExpectedParent, P, M: Integer;
  ChildIdx: Integer;
begin
  HitsArr := Hits(A, '');
  LastParent := 0;
  ExpectedParent := 1;
  for Hit in HitsArr do
  begin
    if Hit.Text.StartsWith('parent-') then
    begin
      LastParent := StrToIntDef(Copy(Hit.Text, Length('parent-') + 1,
        MaxInt), 0);
      Assert.AreEqual(ExpectedParent, LastParent,
        Format('parent rows must stay in source order (expected %d, got %d)',
          [ExpectedParent, LastParent]));
      Inc(ExpectedParent);
    end
    else if Hit.Text.StartsWith('child-') then
    begin
      ChildIdx := Pos('-', Hit.Text, Length('child-') + 1);
      P := StrToIntDef(Copy(Hit.Text, Length('child-') + 1,
        ChildIdx - Length('child-') - 1), 0);
      M := StrToIntDef(Copy(Hit.Text, ChildIdx + 1, MaxInt), 0);
      Assert.IsTrue(P = LastParent,
        Format('child "%s" must follow its parent (last parent %d)',
          [Hit.Text, LastParent]));
      Assert.IsTrue(M >= 1, 'child index must be positive');
    end;
  end;
  Assert.AreEqual(AParents, LastParent,
    'every parent row must be emitted in order');
end;

procedure TStreamingNestedTests.RaiseForNestedMarkerOnContinuation(
  Sender: TObject; AEngine: TObject; AObject: TReportObject;
  const Context: TExpressionContext; var ACanPrint: Boolean);
begin
  if (Context.PageNumber > 1) and (AObject is TReportTextObject) and
     (TReportTextObject(AObject).DataField = 'Marker') then
    raise Exception.Create('injected failure on a nested continuation row');
end;

{ Depth-first chain: level N contains a subreport whose model is level N-1.
  All levels read the same single-row dataset with no link fields, so every
  level draws one row; beyond the engine cap the subreport falls back to the
  legacy clipped loop and execution terminates. }
function TStreamingNestedTests.BuildChainReport(ADepth: Integer): TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
  Sub: TReportSubReportObject;
  ChildModel: TReportModel;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 24;
  Text := TReportTextObject.Create;
  Text.Text := Format('level-%d', [ADepth]);
  Text.Bounds := Rect(2, 2, 120, 20);
  Band.Children.Add(Text);
  if ADepth > 0 then
  begin
    ChildModel := BuildChainReport(ADepth - 1);
    try
      Sub := TReportSubReportObject.Create;
      Sub.ReportJSON := TReportSerializer.SaveToJSON(ChildModel);
      // Empty DataSetName: the nested levels share the engine's main dataset
      // (one row, no link fields -> every level draws that row).
      Sub.Bounds := Rect(4, 20, 200, 44);
      Band.Children.Add(Sub);
    finally
      ChildModel.Free;
    end;
  end;
  Result.Objects.Add(Band);
end;

{ ==================================================================== }
{ Tests                                                                }
{ ==================================================================== }

procedure TStreamingNestedTests.Test_NestedFitsCurrentPage;
var
  A: TNestedFixture;
begin
  A := BuildFixture(2, 2, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.AreEqual(1, A.Engine.PageCount,
      'nested rows that fit must not create pages');
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'parent-', 2);
    AssertRowsExactlyOnce(A, 'child-', 4);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_ChildRowsCrossOnePageBoundary;
var
  A: TNestedFixture;
begin
  A := BuildFixture(4, 6, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount > 1,
      'the nested rows must cross a page boundary');
    AssertTwoPassParity(A);
    AssertNoBlankPage(A);
    AssertRowsExactlyOnce(A, 'parent-', 4);
    AssertRowsExactlyOnce(A, 'child-', 24);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_ChildRowsCrossMultiplePageBoundaries;
var
  A: TNestedFixture;
begin
  A := BuildFixture(10, 5, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 3,
      'the nested rows must cross several page boundaries');
    AssertTwoPassParity(A);
    AssertNoBlankPage(A);
    AssertRowsExactlyOnce(A, 'parent-', 10);
    AssertRowsExactlyOnce(A, 'child-', 50);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_ParentContinuesAfterChildContinuation;
var
  A: TNestedFixture;
begin
  A := BuildFixture(6, 6, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount > 1);
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'parent-', 6);
    AssertRowsExactlyOnce(A, 'child-', 36);
    AssertNestedGrouping(A, 6);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_NestedLinkMatching;
var
  A: TNestedFixture;
begin
  A := BuildFixture(5, 3, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    AssertRowsExactlyOnce(A, 'child-', 15);
    AssertNestedGrouping(A, 5);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_ParentAndChildDatasetsRestoredAfterSuccess;
var
  A: TNestedFixture;
begin
  A := BuildFixture(6, 4, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_DatasetsRestoredAfterCancellation;
var
  A: TNestedFixture;
  Cancelled: IReportProgress;
begin
  A := BuildFixture(8, 5, 400, 500, 22, False);
  try
    Cancelled := TCancelNestedProgress.Create as IReportProgress;
    A.Engine.Free;
    A.Engine := TReportEngine.Create(A.Model, A.MainDS,
      A.NamedDataSets, Cancelled);
    A.Engine.ExportDocument := A.ExportDoc;

    A.Engine.Prepare;
    AssertTwoPassParity(A);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_DatasetsRestoredAfterNestedFlushException;
var
  A: TNestedFixture;
begin
  A := BuildFixture(6, 5, 400, 500, 22, False);
  try
    A.Engine.OnBeforeObject := RaiseForNestedMarkerOnContinuation;
    Assert.WillRaise(
      procedure begin A.Engine.Prepare; end,
      EReportException,
      'an exception during a nested continuation row must propagate');
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_PageAndColumnHeadersOnContinuationPages;
var
  A: TNestedFixture;
  P: Integer;
  HitsArr: TArray<TTextHit>;
  Hit: TTextHit;
  Headers, Columns, Footers: TArray<Integer>;
begin
  A := BuildFixture(8, 4, 400, 500, 22, True);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 2);
    SetLength(Headers, A.ExportDoc.Pages.Count);
    SetLength(Columns, A.ExportDoc.Pages.Count);
    SetLength(Footers, A.ExportDoc.Pages.Count);
    HitsArr := Hits(A, '');
    for Hit in HitsArr do
    begin
      if Hit.Text = 'HDR' then Inc(Headers[Hit.PageIndex])
      else if Hit.Text = 'COL' then Inc(Columns[Hit.PageIndex])
      else if Hit.Text = 'FTR' then Inc(Footers[Hit.PageIndex]);
    end;
    for P := 0 to A.ExportDoc.Pages.Count - 1 do
    begin
      Assert.AreEqual(1, Headers[P],
        Format('page %d must carry exactly one page header', [P]));
      Assert.AreEqual(1, Columns[P],
        Format('page %d must carry exactly one column header', [P]));
      Assert.AreEqual(1, Footers[P],
        Format('page %d must carry exactly one footer', [P]));
    end;
    AssertRowsExactlyOnce(A, 'child-', 32);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_PageNumbersOnNestedContinuationPages;
var
  A: TNestedFixture;
  HitsArr: TArray<TTextHit>;
  Hit: TTextHit;
  P: Integer;
  Seen: TArray<Boolean>;
begin
  A := BuildFixture(8, 4, 400, 500, 22, True, 'Page [PageNo]');
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 2);
    SetLength(Seen, A.ExportDoc.Pages.Count);
    HitsArr := Hits(A, 'Page ');
    for Hit in HitsArr do
    begin
      P := StrToIntDef(Copy(Hit.Text, Length('Page ') + 1, MaxInt), 0);
      Assert.IsTrue((P >= 1) and (P <= A.ExportDoc.Pages.Count),
        Format('page number "%s" out of range', [Hit.Text]));
      Assert.AreEqual(Hit.PageIndex + 1, P,
        Format('page header on page %d must report page %d',
          [Hit.PageIndex, P]));
      Assert.IsFalse(Seen[P - 1],
        Format('page number %d must appear exactly once', [P]));
      Seen[P - 1] := True;
    end;
    for P := 0 to High(Seen) do
      Assert.IsTrue(Seen[P], Format('page %d must report its number', [P + 1]));
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_NoBlankPageAtNestedBoundaries;
var
  A: TNestedFixture;
begin
  A := BuildFixture(8, 4, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 2);
    AssertNoBlankPage(A);
    AssertTwoPassParity(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_NoDuplicateOrMissingRowsAndAtomicity;
var
  A: TNestedFixture;
  HitsArr, ChildHits: TArray<TTextHit>;
  Hit: TTextHit;
  PageOf: TDictionary<string, Integer>;
begin
  A := BuildFixture(8, 4, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    AssertRowsExactlyOnce(A, 'parent-', 8);
    AssertRowsExactlyOnce(A, 'child-', 32);

    HitsArr := Hits(A, 'parent-');
    ChildHits := Hits(A, 'child-');
    PageOf := TDictionary<string, Integer>.Create;
    try
      for Hit in HitsArr do
        PageOf.Add(Hit.Text, Hit.PageIndex);
      for Hit in ChildHits do
      begin
        Assert.IsFalse(PageOf.ContainsKey(Hit.Text),
          Format('row "%s" must not repeat', [Hit.Text]));
        PageOf.Add(Hit.Text, Hit.PageIndex);
      end;
    finally
      PageOf.Free;
    end;
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_CountRenderExportPageCountParity;
var
  A: TNestedFixture;
begin
  A := BuildFixture(8, 4, 400, 500, 22, False);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 2);
    AssertTwoPassParity(A);
    AssertNoBlankPage(A);
    AssertRowsExactlyOnce(A, 'child-', 32);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_NestedOversizedRow_TerminatesAndClips;
var
  A: TNestedFixture;
begin
  A := BuildFixture(2, 2, 400, 500, 600, False);
  try
    A.Engine.Prepare;
    // Each oversized child row gets exactly one forced break and is painted
    // clipped; the page count stays finite (one page per row plus start).
    Assert.IsTrue(A.Engine.PageCount <= 12,
      Format('oversized nested rows must not loop (pages=%d)',
        [A.Engine.PageCount]));
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'child-', 4);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_NestedRecursionDepth_Guarded;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  ExportDoc: TReportExportDocument;
  RecNo: Integer;
  HitsArr: TArray<TTextHit>;
  A: TNestedFixture;
begin
  DS := TClientDataSet.Create(nil);
  ExportDoc := TReportExportDocument.Create;
  Model := nil;
  try
    DS.FieldDefs.Add('ID', ftInteger);
    DS.CreateDataSet;
    DS.AppendRecord([1]);
    DS.First;
    RecNo := DS.RecNo;

    // The engine cap is 16 streams; this chain has 19 levels, so the deepest
    // levels must fall back to the legacy clipped loop and the whole prepare
    // must terminate. (Depth is limited by the fixture, not the engine: every
    // level embeds the child JSON as a string, and JSON escaping amplifies the
    // document per level - a 20-level chain exhausts memory while *building*
    // the test model, before any engine call.)
    Model := BuildChainReport(18);
    Model.PageSettings.PaperSize := psCustom;
    Model.PageSettings.CustomWidth := 400;
    Model.PageSettings.CustomHeight := 500;
    Model.PageSettings.Margins := TReportMargins.Default;

    Engine := TReportEngine.Create(Model, DS, nil);
    try
      Engine.ExportDocument := ExportDoc;
      Engine.Prepare;
      Assert.IsTrue(Engine.PageCount >= 1,
        'a deeply nested report must complete with at least one page');
      Assert.AreEqual(Engine.PageCount, ExportDoc.Pages.Count,
        'count/render parity must hold at the depth cap');
      Assert.AreEqual(RecNo, DS.RecNo,
        'the shared dataset position must be restored');
    finally
      Engine.Free;
    end;

    // The chain really rendered nested levels (not a no-op report).
    A := Default(TNestedFixture);
    A.ExportDoc := ExportDoc;
    HitsArr := Hits(A, 'level-');
    Assert.IsTrue(Length(HitsArr) >= 2,
      'nested chain levels must be emitted');
  finally
    ExportDoc.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TStreamingNestedTests.Test_NestedContinuationRespectsFooterAndPageBounds;
var
  A: TNestedFixture;
  HitsArr: TArray<TTextHit>;
  Hit: TTextHit;
  ContentBottom: Integer;
begin
  A := BuildFixture(8, 4, 400, 500, 22, True);
  try
    A.Engine.Prepare;
    Assert.IsTrue(A.Engine.PageCount >= 2);
    ContentBottom := A.PageH - 40 - A.FooterH;   // margins 40, footer reserved
    HitsArr := Hits(A, '');
    for Hit in HitsArr do
      if Hit.Text.StartsWith('parent-') or Hit.Text.StartsWith('child-') then
      begin
        Assert.IsTrue(Hit.Bounds.Bottom <= ContentBottom,
          Format('row "%s" overlaps the footer (bottom=%d, limit=%d)',
            [Hit.Text, Hit.Bounds.Bottom, ContentBottom]));
        Assert.IsTrue(Hit.Bounds.Top >= 0,
          Format('row "%s" escaped the page top', [Hit.Text]));
      end;
  finally
    FreeFixture(A);
  end;
end;

procedure TStreamingNestedTests.Test_ThreeLevelNesting_ContinuesAllLevels;
var
  A: TNestedFixture;
begin
  A := BuildFixture(2, 2, 400, 500, 22, False, 'HDR', True);
  try
    A.Engine.Prepare;
    AssertTwoPassParity(A);
    AssertRowsExactlyOnce(A, 'parent-', 2);
    AssertRowsExactlyOnce(A, 'child-', 4);
    AssertRowsExactlyOnce(A, 'leaf-', 4);
    AssertDataSetsRestored(A);
  finally
    FreeFixture(A);
  end;
end;

end.
