unit Test.Vittix.Report.Phase6.OutputCoverage;

{
  Phase 6 — widened regression coverage (test-only).

  The Phase 6 audit surfaced that several output paths are NOT exercised by the
  42-report corpus, so the Phase 5 CI gate cannot protect them. This unit closes
  the most important gaps with DETERMINISTIC STRUCTURAL assertions (counts and
  dimensions), deliberately avoiding pixel comparison so the gate stays
  flake-free.

  Gaps covered here:

    1. The linked-detail USER-DATASET transport. `39_detail_bands.vrt` reaches
       the detail path through `TVittixUserDataSet` (the runner registers named
       datasets as user datasets), and that transport had no direct DUnitX
       coverage.

    2. The renderer page shape in dimensions (bitmap size equals the page size,
       metafile non-empty), not just object presence.

  Coverage NOT achievable here (documented limitation): `TVittixReportPreview`
  is a windowed `TCustomControl`. Instantiating it in a console DUnitX run
  raises "Control ... has no parent window", so preview page-ownership
  independence cannot be asserted without a windowed (VCL Forms) harness. That
  path therefore remains outside the automated gate and must be covered
  manually (see TESTING.md, preview/print checklist) until a form-based
  harness is introduced deliberately.

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
  Vittix.Report.Renderer,
  Vittix.Report.UserDataSet,
  Vittix.Report.TraversalDiagnostics;

type
  [TestFixture]
  TPhase6OutputCoverageTests = class
  private
    function CreateIntTable(const AFieldName: string;
      const AValues: array of Integer): TClientDataSet;
    function BuildLinkedReport: TReportModel;
    function BuildPagedReport: TReportModel;
  public
    { 1. Corpus detail transport (TVittixUserDataSet). }
    [Test] procedure Test_Coverage_DetailTransport_UserDataSet;
    { 2. Renderer page shape in dimensions. }
    [Test] procedure Test_Coverage_RendererPageDimensions;
  end;

implementation

function TPhase6OutputCoverageTests.CreateIntTable(const AFieldName: string;
  const AValues: array of Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add(AFieldName, ftInteger);
  Result.CreateDataSet;
  for I := Low(AValues) to High(AValues) do
    Result.AppendRecord([AValues[I]]);
  Result.First;
end;

function TPhase6OutputCoverageTests.BuildLinkedReport: TReportModel;
var
  MasterBand, DetailBand: TReportBand;
begin
  Result := TReportModel.Create;
  MasterBand := TReportBand.Create;
  MasterBand.BandType := btMasterData;
  MasterBand.Height := 20;
  Result.Objects.Add(MasterBand);

  DetailBand := TReportBand.Create;
  DetailBand.BandType := btDetail;
  DetailBand.Height := 10;
  DetailBand.DataSetName := 'Details';
  DetailBand.MasterField := 'ID';
  DetailBand.DetailField := 'MasterID';
  Result.Objects.Add(DetailBand);
end;

function TPhase6OutputCoverageTests.BuildPagedReport: TReportModel;
var
  Band: TReportBand;
  Text: TReportTextObject;
begin
  Result := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 20;
  Text := TReportTextObject.Create;
  Text.Expression := '[ID]';
  Text.Bounds := Rect(2, 2, 100, 16);
  Band.Children.Add(Text);
  Result.Objects.Add(Band);
end;

procedure TPhase6OutputCoverageTests.Test_Coverage_DetailTransport_UserDataSet;
var
  MasterDS, DetailDS: TClientDataSet;
  MasterUDS, DetailUDS: TVittixUserDataSet;
  Named: TDictionary<string, TVittixUserDataSet>;
  Model: TReportModel;
  Engine: TReportEngine;
  Snapshot: TReportTraversalSnapshot;
begin
  // 3 masters; each master owns 2 contiguous detail rows.
  MasterDS := CreateIntTable('ID', [1, 2, 3]);
  DetailDS := CreateIntTable('MasterID', [1, 1, 2, 2, 3, 3]);
  MasterUDS := TVittixUserDataSet.Create(nil);
  DetailUDS := TVittixUserDataSet.Create(nil);
  Named := TDictionary<string, TVittixUserDataSet>.Create;
  Model := BuildLinkedReport;
  try
    MasterUDS.DataSet := MasterDS;
    DetailUDS.DataSet := DetailDS;
    DetailUDS.Name := 'Details';
    Named.Add('Details', DetailUDS);

    Engine := TReportEngine.Create(Model, MasterUDS, Named, nil);
    try
      Engine.TwoPassRendering := False;
      TReportTraversalDiagnostics.Reset;
      Engine.Prepare;
      Snapshot := TReportTraversalDiagnostics.Snapshot;

      // Two detail scans per master row (height look-ahead + print) — the same
      // contract the TDataSet transport has, now covered for the user-dataset
      // transport the checked-in corpus actually uses.
      Assert.AreEqual(6, Snapshot.DetailTraversals,
        'Two detail scans per master row: 2 x 3 masters.');
      Assert.IsTrue(Snapshot.DetailRowsVisited > 0,
        'The user-dataset detail transport must visit detail rows.');
      Assert.IsTrue(Engine.PageCount >= 1,
        'The user-dataset detail report must render at least one page.');
    finally
      Engine.Free;
    end;
  finally
    Model.Free;
    Named.Free;
    DetailUDS.Free;
    MasterUDS.Free;
    DetailDS.Free;
    MasterDS.Free;
  end;
end;

procedure TPhase6OutputCoverageTests.Test_Coverage_RendererPageDimensions;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Renderer: TReportRenderer;
  Values: TArray<Integer>;
  I: Integer;
  PageW, PageH: Integer;
begin
  SetLength(Values, 120);
  for I := 0 to High(Values) do
    Values[I] := I + 1;
  DataSet := CreateIntTable('ID', Values);
  Model := BuildPagedReport;
  try
    PageW := Model.PageSettings.PageWidth;
    PageH := Model.PageSettings.PageHeight;
    Engine := TReportEngine.Create(Model, DataSet, nil);
    Renderer := TReportRenderer.Create;
    try
      Renderer.Render(Engine, PageW, PageH);

      Assert.IsTrue(Engine.PageCount > 1,
        'The fixture must produce multiple pages.');
      Assert.AreEqual(Engine.PageCount, Renderer.Pages.Count,
        'One renderer page per engine page.');

      for I := 0 to Renderer.Pages.Count - 1 do
      begin
        Assert.AreEqual(PageW, Renderer.Pages[I].Bitmap.Width,
          'Renderer bitmap width must equal the page width.');
        Assert.AreEqual(PageH, Renderer.Pages[I].Bitmap.Height,
          'Renderer bitmap height must equal the page height.');
        Assert.IsTrue(Renderer.Pages[I].Metafile.Width > 0,
          'Renderer metafile must carry a non-zero width.');
        Assert.IsTrue(Renderer.Pages[I].Metafile.Height > 0,
          'Renderer metafile must carry a non-zero height.');
      end;
    finally
      Renderer.Free;
      Engine.Free;
    end;
  finally
    Model.Free;
    DataSet.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase6OutputCoverageTests);

end.
