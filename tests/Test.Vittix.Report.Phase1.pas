unit Test.Vittix.Report.Phase1;

{
  Phase 1 -- Characterization & Safety

  These tests intentionally describe the current runtime contract.  They do
  not change expression semantics, pagination rules, or serializer behavior.
  All data is in-memory and the fixture test is read-only.
}

interface

uses
  System.SysUtils,
  System.Types,
  System.IOUtils,
  System.Generics.Collections,
  Data.DB,
  Datasnap.DBClient,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Serializer,
  Vittix.Report.Expressions,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TPhase1CharacterizationTests = class
  private
    function CreateRows(const ACount: Integer): TClientDataSet;
    function CreatePagedReport: TReportModel;
    function FindReportsDirectory: string;
    procedure AssertObjectShape(const AExpected, AActual: TReportObject;
      const AFixtureName, APath: string);
  public
    [Test]
    procedure Test_GAP001_BookmarkAggregate_RestoresCursor;
    [Test]
    procedure Test_GAP002_MasterAndDetailCursors_AreRestored;
    [Test]
    procedure Test_GAP005_RendererRetainsOneBitmapAndMetafilePerEnginePage;
    [Test]
    procedure Test_GAP006_OneAndTwoPass_KeepPaginationAndExportPageCountsAligned;
    [Test]
    procedure Test_VRT_AllBundledFixtures_LoadSaveReload_PreserveModelShape;
  end;

implementation

function TPhase1CharacterizationTests.CreateRows(
  const ACount: Integer): TClientDataSet;
var
  I: Integer;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.FieldDefs.Add('MasterID', ftInteger);
  Result.CreateDataSet;
  for I := 1 to ACount do
    Result.AppendRecord([I, I * 10.0, I]);
  Result.First;
end;

function TPhase1CharacterizationTests.CreatePagedReport: TReportModel;
var
  Header, Master: TReportBand;
  Text: TReportTextObject;
begin
  Result := TReportModel.Create;

  Header := TReportBand.Create;
  Header.BandType := btPageHeader;
  Header.Height := 20;
  Text := TReportTextObject.Create;
  Text.Bounds := Rect(0, 0, 180, 18);
  Text.Expression := '[PageNo]/[TotalPages]';
  Header.Children.Add(Text);
  Result.Objects.Add(Header);

  Master := TReportBand.Create;
  Master.BandType := btMasterData;
  Master.Height := 60;
  Result.Objects.Add(Master);
end;

function TPhase1CharacterizationTests.FindReportsDirectory: string;
var
  Candidate: string;
begin
  Candidate := TPath.Combine(GetCurrentDir, 'reports');
  if TDirectory.Exists(Candidate) then
    Exit(Candidate);

  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\\..\\reports');
  Candidate := TPath.GetFullPath(Candidate);
  if TDirectory.Exists(Candidate) then
    Exit(Candidate);

  raise Exception.Create('Could not locate the repository reports directory.');
end;

procedure TPhase1CharacterizationTests.AssertObjectShape(
  const AExpected, AActual: TReportObject; const AFixtureName, APath: string);
var
  ExpectedBand, ActualBand: TReportBand;
  I: Integer;
begin
  Assert.AreEqual(AExpected.ClassName, AActual.ClassName,
    AFixtureName + ': object class changed at ' + APath);
  Assert.AreEqual(AExpected.Name, AActual.Name,
    AFixtureName + ': object name changed at ' + APath);

  if AExpected is TReportBand then
  begin
    Assert.IsTrue(AActual is TReportBand,
      AFixtureName + ': band became a non-band at ' + APath);
    ExpectedBand := TReportBand(AExpected);
    ActualBand := TReportBand(AActual);
    Assert.AreEqual(Ord(ExpectedBand.BandType), Ord(ActualBand.BandType),
      AFixtureName + ': band type changed at ' + APath);
    Assert.AreEqual(ExpectedBand.Children.Count, ActualBand.Children.Count,
      AFixtureName + ': child count changed at ' + APath);
    for I := 0 to ExpectedBand.Children.Count - 1 do
      AssertObjectShape(ExpectedBand.Children[I], ActualBand.Children[I],
        AFixtureName, APath + '/' + IntToStr(I));
  end;
end;

procedure TPhase1CharacterizationTests.Test_GAP001_BookmarkAggregate_RestoresCursor;
var
  DataSet: TClientDataSet;
  Context: TExpressionContext;
  ExpectedID: Integer;
begin
  DataSet := CreateRows(3);
  try
    DataSet.Next;
    ExpectedID := DataSet.FieldByName('ID').AsInteger;
    Context := Default(TExpressionContext);
    Context.DataSet := DataSet;

    Assert.AreEqual(60.0, Double(TReportExpression.Evaluate('SUM([Amount])', Context)),
      0.001, 'Control aggregate result changed.');
    Assert.AreEqual(ExpectedID, DataSet.FieldByName('ID').AsInteger,
      'Aggregate evaluation must restore a bookmark-capable dataset cursor.');
    Assert.IsFalse(DataSet.Eof, 'Aggregate evaluation must not leave the dataset at EOF.');
  finally
    DataSet.Free;
  end;
end;

procedure TPhase1CharacterizationTests.Test_GAP002_MasterAndDetailCursors_AreRestored;
var
  Model: TReportModel;
  MasterDataSet, DetailDataSet: TClientDataSet;
  Engine: TReportEngine;
  NamedDataSets: TDictionary<string, TDataSet>;
  MasterBand, DetailBand: TReportBand;
  ExpectedMasterID, ExpectedDetailMasterID: Integer;
begin
  MasterDataSet := CreateRows(3);
  DetailDataSet := CreateRows(4);
  Model := TReportModel.Create;
  NamedDataSets := TDictionary<string, TDataSet>.Create;
  try
    DetailDataSet.Edit;
    DetailDataSet.FieldByName('MasterID').AsInteger := 1;
    DetailDataSet.Post;
    DetailDataSet.Next;
    DetailDataSet.Edit;
    DetailDataSet.FieldByName('MasterID').AsInteger := 2;
    DetailDataSet.Post;
    DetailDataSet.Next;
    DetailDataSet.Edit;
    DetailDataSet.FieldByName('MasterID').AsInteger := 2;
    DetailDataSet.Post;
    DetailDataSet.First;

    MasterBand := TReportBand.Create;
    MasterBand.BandType := btMasterData;
    MasterBand.Height := 20;
    Model.Objects.Add(MasterBand);
    DetailBand := TReportBand.Create;
    DetailBand.BandType := btDetail;
    DetailBand.Height := 10;
    DetailBand.DataSetName := 'Details';
    DetailBand.MasterField := 'ID';
    DetailBand.DetailField := 'MasterID';
    Model.Objects.Add(DetailBand);

    MasterDataSet.Next;
    DetailDataSet.Next;
    ExpectedMasterID := MasterDataSet.FieldByName('ID').AsInteger;
    ExpectedDetailMasterID := DetailDataSet.FieldByName('MasterID').AsInteger;
    NamedDataSets.Add('Details', DetailDataSet);
    Engine := TReportEngine.Create(Model, MasterDataSet, NamedDataSets, nil);
    try
      Engine.Prepare;
      Assert.AreEqual(ExpectedMasterID, MasterDataSet.FieldByName('ID').AsInteger,
        'Master cursor changed after report preparation.');
      Assert.AreEqual(ExpectedDetailMasterID, DetailDataSet.FieldByName('MasterID').AsInteger,
        'Detail cursor changed after report preparation.');
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

procedure TPhase1CharacterizationTests.Test_GAP005_RendererRetainsOneBitmapAndMetafilePerEnginePage;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Renderer: TReportRenderer;
  I: Integer;
begin
  DataSet := CreateRows(40);
  Model := CreatePagedReport;
  try
    Engine := TReportEngine.Create(Model, DataSet, nil);
    Renderer := TReportRenderer.Create;
    try
      Renderer.Render(Engine, Model.PageSettings.PageWidth, Model.PageSettings.PageHeight);
      Assert.IsTrue(Engine.PageCount > 1, 'The fixture must exercise multiple pages.');
      Assert.AreEqual(Engine.PageCount, Renderer.Pages.Count,
        'Renderer page retention differs from the engine page count.');
      for I := 0 to Renderer.Pages.Count - 1 do
      begin
        Assert.IsNotNull(Renderer.Pages[I].Bitmap, 'Renderer bitmap is missing.');
        Assert.IsNotNull(Renderer.Pages[I].Metafile, 'Renderer metafile is missing.');
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

procedure TPhase1CharacterizationTests.Test_GAP006_OneAndTwoPass_KeepPaginationAndExportPageCountsAligned;
var
  DataSet: TClientDataSet;
  Model: TReportModel;
  OnePassEngine, TwoPassEngine: TReportEngine;
  OnePassDoc, TwoPassDoc: TReportExportDocument;
  OnePassPages, TwoPassPages: Integer;
begin
  DataSet := CreateRows(40);
  Model := CreatePagedReport;
  OnePassDoc := TReportExportDocument.Create;
  TwoPassDoc := TReportExportDocument.Create;
  try
    OnePassEngine := TReportEngine.Create(Model, DataSet, nil);
    try
      OnePassEngine.TwoPassRendering := False;
      OnePassEngine.ExportDocument := OnePassDoc;
      OnePassEngine.Prepare;
      OnePassPages := OnePassEngine.PageCount;
      Assert.AreEqual(OnePassPages, OnePassDoc.Pages.Count,
        'One-pass export page count differs from rendered pages.');
    finally
      OnePassEngine.Free;
    end;

    TwoPassEngine := TReportEngine.Create(Model, DataSet, nil);
    try
      TwoPassEngine.TwoPassRendering := True;
      TwoPassEngine.ExportDocument := TwoPassDoc;
      TwoPassEngine.Prepare;
      TwoPassPages := TwoPassEngine.PageCount;
      Assert.AreEqual(TwoPassPages, TwoPassDoc.Pages.Count,
        'Two-pass export page count differs from rendered pages.');
      Assert.AreEqual(OnePassPages, TwoPassPages,
        'Changing pass mode changed pagination for the deterministic fixture.');
      Assert.IsTrue(TwoPassDoc.Pages[0].Commands.Count > 0,
        'The output-fidelity baseline must contain captured draw commands.');
    finally
      TwoPassEngine.Free;
    end;
  finally
    TwoPassDoc.Free;
    OnePassDoc.Free;
    Model.Free;
    DataSet.Free;
  end;
end;

procedure TPhase1CharacterizationTests.Test_VRT_AllBundledFixtures_LoadSaveReload_PreserveModelShape;
var
  Files: TArray<string>;
  FileName, FixtureName, JSON: string;
  Original, Reloaded: TReportModel;
  I: Integer;
begin
  Files := TDirectory.GetFiles(FindReportsDirectory, '*.vrt');
  // The Phase 1 brief referred to 45 fixtures; the checked-in reports folder
  // currently contains 42. Keep this explicit so a fixture is not silently
  // removed or added without updating the compatibility baseline.
  Assert.AreEqual(42, Length(Files), 'The checked-in .vrt fixture baseline changed.');
  for FileName in Files do
  begin
    FixtureName := ExtractFileName(FileName);
    Original := TReportSerializer.LoadFromFile(FileName);
    try
      JSON := TReportSerializer.SaveToJSON(Original);
      Reloaded := TReportSerializer.LoadFromJSON(JSON);
      try
        Assert.AreEqual(Original.Title, Reloaded.Title, FixtureName + ': title changed.');
        Assert.AreEqual(Original.DataSetNames.Text, Reloaded.DataSetNames.Text,
          FixtureName + ': dataset names changed.');
        Assert.AreEqual(Original.Variables.Text, Reloaded.Variables.Text,
          FixtureName + ': report variables changed.');
        Assert.AreEqual(Original.PageSettings.PageWidth, Reloaded.PageSettings.PageWidth,
          FixtureName + ': page width changed.');
        Assert.AreEqual(Original.PageSettings.PageHeight, Reloaded.PageSettings.PageHeight,
          FixtureName + ': page height changed.');
        Assert.AreEqual(Original.Objects.Count, Reloaded.Objects.Count,
          FixtureName + ': top-level object count changed.');
        for I := 0 to Original.Objects.Count - 1 do
          AssertObjectShape(Original.Objects[I], Reloaded.Objects[I], FixtureName, IntToStr(I));
      finally
        Reloaded.Free;
      end;
    finally
      Original.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhase1CharacterizationTests);

end.
