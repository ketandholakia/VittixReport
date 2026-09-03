unit Test.Vittix.Report.ExportCapture;

{
  Phase 4I-1: chart/crosstab export-capture correctness tests.

  Verifies that TReportChartObject and TReportCrossTabObject — which have no
  per-primitive capture — are captured as image export commands with correct
  logical bounds, that hidden objects are not captured, and that the export
  document deletes the temporary image files it registered when freed.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Chart,
  Vittix.Report.Objects.CrossTab,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TExportCaptureTests = class
  private
    function BuildDataSet: TClientDataSet;
    function BuildBase64Engine(const AFieldValue: string;
      out ADoc: TReportExportDocument;
      out AModel: TReportModel;
      out ADS: TClientDataSet): TReportEngine;
    function BuildEngine(AChartVisible, ACrossTabVisible: Boolean;
      out AChart, ACrossTab: TReportObject;
      out ADoc: TReportExportDocument;
      out AModel: TReportModel;
      out ADS: TClientDataSet): TReportEngine;
  public
    [Test] procedure Test_Chart_ProducesImageCommand;
    [Test] procedure Test_CrossTab_ProducesImageCommand;
    [Test] procedure Test_HiddenChart_NoImageCommand;
    [Test] procedure Test_HiddenCrossTab_NoImageCommand;
    [Test] procedure Test_ImageCommands_KeepLogicalBounds;
    [Test] procedure Test_DocumentFree_DeletesTempFiles;
    [Test] procedure Test_EmbeddedPicture_ProducesImageCommand;
    [Test] procedure Test_EmbeddedPicture_TempFileDeletedOnDocumentFree;
    [Test] procedure Test_HiddenEmbeddedPicture_NoCommand;
    [Test] procedure Test_EmbeddedPicture_HTMLExport_ContainsImage;
    [Test] procedure Test_Base64Field_DataURI_RendersAndExports;
    [Test] procedure Test_Base64Field_BareBase64_Renders;
    [Test] procedure Test_Base64Field_Invalid_NoCommandNoException;
  end;

implementation

uses
  System.Types,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  System.IOUtils,
  System.NetEncoding,
  Vittix.Report.Serializer,
  Vittix.Report.Export.HTML;

function TExportCaptureTests.BuildDataSet: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Region', ftString, 20);
  Result.FieldDefs.Add('Year', ftInteger);
  Result.FieldDefs.Add('Amount', ftFloat);
  Result.CreateDataSet;
  Result.AppendRecord(['North', 2023, 100.0]);
  Result.AppendRecord(['North', 2024, 150.0]);
  Result.AppendRecord(['South', 2023, 80.0]);
  Result.AppendRecord(['South', 2024, 120.0]);
  Result.First;
end;

function TExportCaptureTests.BuildEngine(AChartVisible, ACrossTabVisible: Boolean;
  out AChart, ACrossTab: TReportObject;
  out ADoc: TReportExportDocument;
  out AModel: TReportModel;
  out ADS: TClientDataSet): TReportEngine;
var
  Model: TReportModel;
  Band: TReportBand;
  Chart: TReportChartObject;
  CrossTab: TReportCrossTabObject;
  DS: TClientDataSet;
begin
  DS := BuildDataSet;
  Model := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
  Band.Height := 400;

  Chart := TReportChartObject.Create;
  Chart.Name := 'chart1';
  Chart.Bounds := Rect(20, 20, 320, 220);
  Chart.ChartType := ctPie;
  Chart.Title := 'Sales';
  // Unregistered name -> no dataset -> chart draws its built-in demo points.
  Chart.DataSetName := '__demo__';
  Chart.Visible := AChartVisible;
  Band.Children.Add(Chart);
  AChart := Chart;

  CrossTab := TReportCrossTabObject.Create;
  CrossTab.Name := 'crosstab1';
  CrossTab.Bounds := Rect(20, 240, 340, 390);
  CrossTab.RowField := 'Region';
  CrossTab.ColumnField := 'Year';
  CrossTab.CellField := 'Amount';
  CrossTab.Visible := ACrossTabVisible;
  Band.Children.Add(CrossTab);
  ACrossTab := CrossTab;

  Model.Objects.Add(Band);

  ADoc := TReportExportDocument.Create;
  Result := TReportEngine.Create(Model, DS, nil, nil);
  Result.ExportDocument := ADoc;
  AModel := Model;
  ADS := DS;
end;

{ Collect image commands matching the given logical size.  The command
  bounds are page coordinates (object bounds offset by the band position),
  so matching is done on width/height, which are offset-independent. }
function CollectBySize(ADoc: TReportExportDocument;
  AWidth, AHeight: Integer): TArray<TReportExportImageCommand>;
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  SetLength(Result, 0);
  for Page in ADoc.Pages do
    for Cmd in Page.Commands do
      if (Cmd.Kind = eckImage) and
         (TReportExportImageCommand(Cmd).Bounds.Width = AWidth) and
         (TReportExportImageCommand(Cmd).Bounds.Height = AHeight) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := TReportExportImageCommand(Cmd);
      end;
end;

procedure TExportCaptureTests.Test_Chart_ProducesImageCommand;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Img: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    Img := CollectBySize(Doc, 300, 200);
    Assert.IsTrue(Length(Img) = 1, Format('chart image commands=%d', [Length(Img)]));
    Assert.IsTrue(TFile.Exists(Img[0].Source), 'chart temp image file missing');
    Assert.IsTrue(TFile.GetSize(Img[0].Source) > 0, 'chart image data empty');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_CrossTab_ProducesImageCommand;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Img: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    Img := CollectBySize(Doc, 320, 150);
    Assert.IsTrue(Length(Img) = 1, Format('crosstab image commands=%d', [Length(Img)]));
    Assert.IsTrue(TFile.Exists(Img[0].Source), 'crosstab temp image file missing');
    Assert.IsTrue(TFile.GetSize(Img[0].Source) > 0, 'crosstab image data empty');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_HiddenChart_NoImageCommand;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Img: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(False, True, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    Img := CollectBySize(Doc, 300, 200);
    Assert.IsTrue(Length(Img) = 0, 'hidden chart must not be captured');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_HiddenCrossTab_NoImageCommand;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Img: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(True, False, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    Img := CollectBySize(Doc, 320, 150);
    Assert.IsTrue(Length(Img) = 0, 'hidden crosstab must not be captured');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_ImageCommands_KeepLogicalBounds;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  ImgC, ImgX: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    ImgC := CollectBySize(Doc, 300, 200);
    ImgX := CollectBySize(Doc, 320, 150);
    Assert.IsTrue(Length(ImgC) = 1);
    Assert.IsTrue(Length(ImgX) = 1);
    // Commands must carry the objects' logical SIZE (1:1, no scaling);
    // positions are page coordinates (object bounds + band offset).
    Assert.IsTrue((ImgC[0].Bounds.Width = 300) and (ImgC[0].Bounds.Height = 200));
    Assert.IsTrue((ImgX[0].Bounds.Width = 320) and (ImgX[0].Bounds.Height = 150));
    Assert.IsTrue(ImgC[0].Stretch, 'image must stretch into logical bounds');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_DocumentFree_DeletesTempFiles;
var
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  ImgC: TArray<TReportExportImageCommand>;
  TempPath: string;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Engine.Prepare;
    ImgC := CollectBySize(Doc, 300, 200);
    Assert.IsTrue(Length(ImgC) = 1);
    TempPath := ImgC[0].Source;
    Assert.IsTrue(TFile.Exists(TempPath));
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
  Assert.IsFalse(TFile.Exists(TempPath),
    'export document must delete registered temp images on free');
end;

procedure TExportCaptureTests.Test_EmbeddedPicture_ProducesImageCommand;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Band: TReportBand;
  Img: TReportImageObject;
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Commands: TArray<TReportExportImageCommand>;
  PngBytes: TBytes;
begin
  // Embedded design-time picture: DataField empty, graphic set via the
  // public Picture property (as the designer does through PictureData).
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Band := Model.Objects[0] as TReportBand;
    Img := TReportImageObject.Create;
    Img.Name := 'imgEmbedded';
    Img.Bounds := Rect(20, 150, 220, 190);
    Img.DataField := '';
    Img.Stretch := True;
    Img.Center := False;
    Img.Proportional := False;
    var Bmp := TBitmap.Create;
    try
      Bmp.SetSize(24, 16);
      Bmp.Canvas.Brush.Color := clRed;
      Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
      Img.Picture.Assign(Bmp);
    finally
      Bmp.Free;
    end;
    Band.Children.Add(Img);

    Engine.Prepare;

    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 1,
      Format('embedded image commands=%d', [Length(Commands)]));
    Assert.IsTrue(TFile.Exists(Commands[0].Source), 'temp PNG missing');
    PngBytes := TFile.ReadAllBytes(Commands[0].Source);
    Assert.IsTrue(Length(PngBytes) > 8, 'temp PNG is empty');
    Assert.IsTrue((PngBytes[0] = $89) and (PngBytes[1] = Ord('P')),
      'temp file is not a PNG');
    // Presentation flags preserved from the object.
    Assert.IsTrue(Commands[0].Stretch);
    Assert.IsFalse(Commands[0].Center);
    Assert.IsFalse(Commands[0].Proportional);
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_EmbeddedPicture_TempFileDeletedOnDocumentFree;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Band: TReportBand;
  Img: TReportImageObject;
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Commands: TArray<TReportExportImageCommand>;
  TempPath: string;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Band := Model.Objects[0] as TReportBand;
    Img := TReportImageObject.Create;
    Img.Bounds := Rect(20, 150, 220, 190);
    Img.DataField := '';
    var Bmp := TBitmap.Create;
    try
      Bmp.SetSize(16, 16);
      Bmp.Canvas.Brush.Color := clBlue;
      Bmp.Canvas.FillRect(Rect(0, 0, 16, 16));
      Img.Picture.Assign(Bmp);
    finally
      Bmp.Free;
    end;
    Band.Children.Add(Img);

    Engine.Prepare;
    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 1);
    TempPath := Commands[0].Source;
    Assert.IsTrue(TFile.Exists(TempPath));
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
  Assert.IsFalse(TFile.Exists(TempPath),
    'export document must delete the embedded-picture temp PNG on free');
end;

procedure TExportCaptureTests.Test_HiddenEmbeddedPicture_NoCommand;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Band: TReportBand;
  Img: TReportImageObject;
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Commands: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Band := Model.Objects[0] as TReportBand;
    Img := TReportImageObject.Create;
    Img.Bounds := Rect(20, 150, 220, 190);
    Img.DataField := '';
    Img.Visible := False;
    var Bmp := TBitmap.Create;
    try
      Bmp.SetSize(16, 16);
      Bmp.Canvas.Brush.Color := clBlue;
      Bmp.Canvas.FillRect(Rect(0, 0, 16, 16));
      Img.Picture.Assign(Bmp);
    finally
      Bmp.Free;
    end;
    Band.Children.Add(Img);

    Engine.Prepare;
    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 0, 'hidden embedded image must not be captured');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_EmbeddedPicture_HTMLExport_ContainsImage;
var
  Model: TReportModel;
  DS: TClientDataSet;
  Band: TReportBand;
  Img: TReportImageObject;
  Chart, CrossTab: TReportObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Ms: TStringStream;
  HTML: string;
begin
  // Real-pipeline check: embedded picture -> engine capture -> actual HTML
  // exporter output contains the image.
  Engine := BuildEngine(True, True, Chart, CrossTab, Doc, Model, DS);
  try
    Band := Model.Objects[0] as TReportBand;
    Img := TReportImageObject.Create;
    Img.Bounds := Rect(20, 150, 220, 190);
    Img.DataField := '';
    Img.Stretch := True;
    var Bmp := TBitmap.Create;
    try
      Bmp.SetSize(24, 16);
      Bmp.Canvas.Brush.Color := clRed;
      Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
      Img.Picture.Assign(Bmp);
    finally
      Bmp.Free;
    end;
    Band.Children.Add(Img);

    Engine.Prepare;
    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      HTML := Ms.DataString;
    finally
      Ms.Free;
    end;
    Assert.Contains(HTML, '<img class="vrt-img"');
    Assert.Contains(HTML, 'data:image/png;base64,');
    Assert.Contains(HTML, '</html>');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

{ Encodes a small real bitmap as base64 PNG text (optionally wrapped as a
  data-URI).  Real encoder output, not fabricated bytes. }
function RealPngBase64(const AAsDataURI: Boolean): string;
var
  Bmp: TBitmap;
  Png: TPngImage;
  Ms: TMemoryStream;
  Bts: TBytes;
begin
  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clGreen;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Png.Assign(Bmp);
    Png.SaveToStream(Ms);
    SetLength(Bts, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Bts[0], Ms.Size);
    Result := TNetEncoding.Base64.EncodeBytesToString(Bts);
    if AAsDataURI then
      Result := 'data:image/png;base64,' + Result;
  finally
    Ms.Free;
    Png.Free;
    Bmp.Free;
  end;
end;

function TExportCaptureTests.BuildBase64Engine(const AFieldValue: string;
  out ADoc: TReportExportDocument;
  out AModel: TReportModel;
  out ADS: TClientDataSet): TReportEngine;
var
  Model: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
  DS: TClientDataSet;
begin
  DS := TClientDataSet.Create(nil);
  DS.FieldDefs.Add('ImgB64', ftString, 2000);
  DS.CreateDataSet;
  DS.AppendRecord([AFieldValue]);
  DS.First;

  Model := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
  Band.Height := 400;
  Img := TReportImageObject.Create;
  Img.Bounds := Rect(20, 150, 220, 190);
  Img.DataField := 'ImgB64';
  Band.Children.Add(Img);
  Model.Objects.Add(Band);

  ADoc := TReportExportDocument.Create;
  Result := TReportEngine.Create(Model, DS, nil, nil);
  Result.ExportDocument := ADoc;
  AModel := Model;
  ADS := DS;
end;

procedure TExportCaptureTests.Test_Base64Field_DataURI_RendersAndExports;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Commands: TArray<TReportExportImageCommand>;
  Model: TReportModel;
  DS: TClientDataSet;
begin
  Engine := BuildBase64Engine(RealPngBase64(True), Doc, Model, DS);
  try
    Engine.Prepare;
    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 1,
      Format('data-URI image commands=%d', [Length(Commands)]));
    Assert.IsTrue(TFile.Exists(Commands[0].Source), 'export temp PNG missing');
    // The rendered image must reach the real HTML exporter as base64 output.
    var Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      Assert.Contains(Ms.DataString, 'data:image/png;base64,');
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
    Engine.Free;
  end;
end;

procedure TExportCaptureTests.Test_Base64Field_BareBase64_Renders;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Commands: TArray<TReportExportImageCommand>;
begin
  Engine := BuildBase64Engine(RealPngBase64(False), Doc, Model, DS);
  try
    Engine.Prepare;
    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 1,
      Format('bare base64 image commands=%d', [Length(Commands)]));
  finally
    Doc.Free;
    Engine.Free;
  end;
end;

procedure TExportCaptureTests.Test_Base64Field_Invalid_NoCommandNoException;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Commands: TArray<TReportExportImageCommand>;
begin
  // Not a path, not decodable base64: best-effort placeholder, no crash,
  // no image command.
  Engine := BuildBase64Engine('not!!a@@valid^^image', Doc, Model, DS);
  try
    Engine.Prepare;
    Commands := CollectBySize(Doc, 200, 40);
    Assert.IsTrue(Length(Commands) = 0,
      Format('invalid base64 commands=%d', [Length(Commands)]));
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExportCaptureTests);

end.
