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
    function BuildShapeEngine(AShape: TReportShapeObject;
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
    [Test] procedure Test_Ellipse_FillAndBorder_Captured;
    [Test] procedure Test_Ellipse_FillOnly_NoBorder;
    [Test] procedure Test_Ellipse_BorderOnly_NoFill;
    [Test] procedure Test_RoundRect_ProducesCommands;
    [Test] procedure Test_Rectangle_Capture_Regression;
    [Test] procedure Test_Line_Capture_Regression;
    [Test] procedure Test_Ellipse_HTMLExport_ContainsVectorEllipse;
    [Test] procedure Test_Ellipse_VectorPDF_ContainsBezierContent;
    [Test] procedure Test_FilePathBMP_VectorPDF_ContainsImage;
    [Test] procedure Test_FilePathGIF_VectorPDF_ContainsImage;
    [Test] procedure Test_FilePathPNG_VectorPDF_Regression;
    [Test] procedure Test_FilePathJPEG_VectorPDF_Regression;
    [Test] procedure Test_FilePathInvalidRaster_GracefulSkip;
  end;

implementation

uses
  System.Types,
  System.StrUtils,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.GIFImg,
  System.IOUtils,
  System.NetEncoding,
  Vittix.Report.Serializer,
  Vittix.Report.Export.HTML,
  Vittix.Report.Export.VectorPDF;

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

{ Builds a one-band engine containing a single shape object.  Uses an
  in-memory dataset so nothing depends on report fixtures. }
function TExportCaptureTests.BuildShapeEngine(AShape: TReportShapeObject;
  out ADoc: TReportExportDocument;
  out AModel: TReportModel;
  out ADS: TClientDataSet): TReportEngine;
var
  Model: TReportModel;
  Band: TReportBand;
  DS: TClientDataSet;
begin
  DS := TClientDataSet.Create(nil);
  DS.FieldDefs.Add('Name', ftString, 20);
  DS.CreateDataSet;
  DS.AppendRecord(['row1']);
  DS.First;

  AShape.Name := 'shape1';
  AShape.Bounds := Rect(30, 40, 230, 140);

  Model := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btPageHeader;
  Band.Height := 400;
  Band.Children.Add(AShape);
  Model.Objects.Add(Band);

  ADoc := TReportExportDocument.Create;
  Result := TReportEngine.Create(Model, DS, nil, nil);
  Result.ExportDocument := ADoc;
  AModel := Model;
  ADS := DS;
end;

{ Collects ellipse commands from all pages. }
function CollectEllipseCommands(ADoc: TReportExportDocument): TArray<TReportExportEllipseCommand>;
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  SetLength(Result, 0);
  for Page in ADoc.Pages do
    for Cmd in Page.Commands do
      if Cmd is TReportExportEllipseCommand then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := TReportExportEllipseCommand(Cmd);
      end;
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

procedure TExportCaptureTests.Test_Ellipse_FillAndBorder_Captured;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Ellipses: TArray<TReportExportEllipseCommand>;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stEllipse;
  Shape.BrushColor := clRed;
  Shape.BrushStyle := bsSolid;
  Shape.PenColor := clBlue;
  Shape.PenWidth := 3;
  Shape.PenStyle := psSolid;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    Ellipses := CollectEllipseCommands(Doc);
    Assert.IsTrue(Length(Ellipses) = 1, Format('ellipse commands=%d', [Length(Ellipses)]));
    // Bounds are page coordinates (object bounds offset by the band
    // position), so assert on the offset-independent size.
    Assert.IsTrue((Ellipses[0].Bounds.Width = 200) and (Ellipses[0].Bounds.Height = 100),
      Format('ellipse bounds=(%d,%d,%d,%d)', [Ellipses[0].Bounds.Left, Ellipses[0].Bounds.Top,
        Ellipses[0].Bounds.Right, Ellipses[0].Bounds.Bottom]));
    Assert.IsTrue(Ellipses[0].HasFill, 'solid fill must be captured');
    Assert.IsTrue(Ellipses[0].FillColor = clRed, 'fill color not preserved');
    Assert.IsTrue(Ellipses[0].HasBorder, 'visible border must be captured');
    Assert.IsTrue(Ellipses[0].BorderColor = clBlue, 'border color not preserved');
    Assert.IsTrue(Ellipses[0].BorderWidth = 3, 'border width not preserved');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_Ellipse_FillOnly_NoBorder;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Ellipses: TArray<TReportExportEllipseCommand>;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stEllipse;
  Shape.BrushColor := clGreen;
  Shape.BrushStyle := bsSolid;
  Shape.PenStyle := psClear;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    Ellipses := CollectEllipseCommands(Doc);
    Assert.IsTrue(Length(Ellipses) = 1, Format('ellipse commands=%d', [Length(Ellipses)]));
    Assert.IsTrue(Ellipses[0].HasFill, 'fill must be captured');
    Assert.IsFalse(Ellipses[0].HasBorder, 'clear pen must not produce a border');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_Ellipse_BorderOnly_NoFill;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Ellipses: TArray<TReportExportEllipseCommand>;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stEllipse;
  Shape.BrushStyle := bsClear;
  Shape.PenColor := clBlack;
  Shape.PenStyle := psSolid;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    Ellipses := CollectEllipseCommands(Doc);
    Assert.IsTrue(Length(Ellipses) = 1, Format('ellipse commands=%d', [Length(Ellipses)]));
    Assert.IsFalse(Ellipses[0].HasFill, 'non-solid brush must not produce a fill');
    Assert.IsTrue(Ellipses[0].HasBorder, 'border must be captured');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;


procedure TExportCaptureTests.Test_RoundRect_ProducesCommands;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  FillCount, BorderCount, OtherCount: Integer;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stRoundRect;
  Shape.BrushColor := clYellow;
  Shape.BrushStyle := bsSolid;
  Shape.PenColor := clNavy;
  Shape.PenWidth := 2;
  Shape.PenStyle := psSolid;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    // Round-rect must survive export capture: same representation as a
    // rectangle (fill-rectangle + rectangle border commands).
    FillCount := 0;
    BorderCount := 0;
    OtherCount := 0;
    for Page in Doc.Pages do
      for Cmd in Page.Commands do
      begin
        if Cmd is TReportExportFillRectangleCommand then
        begin
          Inc(FillCount);
          Assert.IsTrue(TReportExportFillRectangleCommand(Cmd).FillColor = clYellow,
            'round-rect fill color not preserved');
          Assert.IsTrue(TReportExportFillRectangleCommand(Cmd).Bounds.Width = 200,
            'round-rect bounds not preserved');
        end
        else if Cmd is TReportExportRectangleCommand then
        begin
          Inc(BorderCount);
          Assert.IsTrue(TReportExportRectangleCommand(Cmd).BorderColor = clNavy,
            'round-rect border color not preserved');
          Assert.IsTrue(TReportExportRectangleCommand(Cmd).BorderWidth = 2,
            'round-rect border width not preserved');
        end
        else
          Inc(OtherCount);
      end;
    Assert.IsTrue(FillCount = 1, Format('round-rect fill commands=%d', [FillCount]));
    Assert.IsTrue(BorderCount = 1, Format('round-rect border commands=%d', [BorderCount]));
    Assert.IsTrue(OtherCount = 0, 'round-rect must not produce unexpected commands');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_Rectangle_Capture_Regression;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  FillCount, BorderCount, OtherCount: Integer;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stRectangle;
  Shape.BrushColor := clRed;
  Shape.BrushStyle := bsSolid;
  Shape.PenColor := clBlack;
  Shape.PenStyle := psSolid;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    // Existing rectangle structure: exactly one fill-rectangle + one
    // rectangle border command, no ellipse commands.
    FillCount := 0;
    BorderCount := 0;
    OtherCount := 0;
    for Page in Doc.Pages do
      for Cmd in Page.Commands do
      begin
        if Cmd is TReportExportFillRectangleCommand then Inc(FillCount)
        else if Cmd is TReportExportRectangleCommand then Inc(BorderCount)
        else Inc(OtherCount);
      end;
    Assert.IsTrue(FillCount = 1, Format('rectangle fill commands=%d', [FillCount]));
    Assert.IsTrue(BorderCount = 1, Format('rectangle border commands=%d', [BorderCount]));
    Assert.IsTrue(OtherCount = 0, 'rectangle must not acquire new command kinds');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_Line_Capture_Regression;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  Lines: TArray<TReportExportLineCommand>;
  OtherCount: Integer;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stLine;
  Shape.PenColor := clMaroon;
  Shape.PenWidth := 2;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    SetLength(Lines, 0);
    OtherCount := 0;
    for Page in Doc.Pages do
      for Cmd in Page.Commands do
      begin
        if Cmd is TReportExportLineCommand then
        begin
          SetLength(Lines, Length(Lines) + 1);
          Lines[High(Lines)] := TReportExportLineCommand(Cmd);
        end
        else
          Inc(OtherCount);
      end;
    Assert.IsTrue(Length(Lines) = 1, Format('line commands=%d', [Length(Lines)]));
    Assert.IsTrue(OtherCount = 0, 'line shape must not acquire new command kinds');
    // Horizontal line: mid Y of the object bounds, unchanged semantics
    // (both endpoints share the same page Y; absolute value includes the
    // band offset).
    Assert.IsTrue((Lines[0].Color = clMaroon) and (Lines[0].Width = 2));
    Assert.IsTrue((Lines[0].Y1 = Lines[0].Y2) and (Lines[0].X1 < Lines[0].X2),
      Format('line=(%d,%d)-(%d,%d)', [Lines[0].X1, Lines[0].Y1, Lines[0].X2, Lines[0].Y2]));
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;


procedure TExportCaptureTests.Test_Ellipse_HTMLExport_ContainsVectorEllipse;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Ellipses: TArray<TReportExportEllipseCommand>;
  Ms: TStringStream;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stEllipse;
  Shape.BrushColor := clRed;
  Shape.BrushStyle := bsSolid;
  Shape.PenColor := clBlue;
  Shape.PenWidth := 3;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    Ellipses := CollectEllipseCommands(Doc);
    Assert.IsTrue(Length(Ellipses) = 1);

    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      // A real vector ellipse element with the captured geometry.
      Assert.Contains(Ms.DataString, '<ellipse cx="');
      Assert.Contains(Ms.DataString, 'rx="100"');
      Assert.Contains(Ms.DataString, 'ry="50"');
      // Fill and border information is represented.
      Assert.Contains(Ms.DataString, '#ff0000');  // clRed fill
      Assert.Contains(Ms.DataString, '#0000ff');  // clBlue border
      Assert.Contains(Ms.DataString, 'stroke-width="3"');
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_Ellipse_VectorPDF_ContainsBezierContent;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TClientDataSet;
  Shape: TReportShapeObject;
  Ellipses: TArray<TReportExportEllipseCommand>;
  Ms: TStringStream;
  Pdf: string;
begin
  Shape := TReportShapeObject.Create;
  Shape.ShapeType := stEllipse;
  Shape.BrushColor := clRed;
  Shape.BrushStyle := bsSolid;
  Shape.PenColor := clBlue;
  Shape.PenWidth := 3;
  Engine := BuildShapeEngine(Shape, Doc, Model, DS);
  try
    Engine.Prepare;
    Ellipses := CollectEllipseCommands(Doc);
    Assert.IsTrue(Length(Ellipses) = 1);

    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportVectorPDFExporter.ExportDocument(Doc, Ms);
      Pdf := Ms.DataString;
      // Structural content-stream assertions: an ellipse is drawn as a
      // closed path of four cubic Bezier arcs (m/c/h) with fill+stroke
      // (B) — no rasterized image fallback.
      Assert.Contains(Pdf, #10'c ');
      Assert.Contains(Pdf, 'h'#10'B'#10);
      // Border color operator (RG) and fill operator (rg) both present.
      Assert.Contains(Pdf, ' RG'#10);
      Assert.Contains(Pdf, ' rg'#10);
      Assert.IsFalse(ContainsText(Pdf, '/Im'), 'ellipse must not be rasterized');
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;


{ ===== File-path BMP/GIF/PNG/JPEG -> VectorPDF (Phase 4I-9) ===== }

{ Creates a real VCL BMP file with visible content. }
function MakeTempBmpFile: string;
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clRed;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Bmp.Canvas.Brush.Color := clBlue;
    Bmp.Canvas.FillRect(Rect(4, 4, 20, 12));
    Result := TPath.Combine(TPath.GetTempPath,
      'vittix_test_' + TGUID.NewGuid.ToString + '.bmp');
    Bmp.SaveToFile(Result);
  finally
    Bmp.Free;
  end;
end;

{ Creates a real VCL GIF file with visible content (TGIFImage). }
function MakeTempGifFile: string;
var
  Bmp: TBitmap;
  Gif: TGIFImage;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clLime;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Bmp.Canvas.Brush.Color := clBlack;
    Bmp.Canvas.FillRect(Rect(4, 4, 20, 12));
    Gif := TGIFImage.Create;
    try
      Gif.Assign(Bmp);
      Result := TPath.Combine(TPath.GetTempPath,
        'vittix_test_' + TGUID.NewGuid.ToString + '.gif');
      Gif.SaveToFile(Result);
    finally
      Gif.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

{ Creates a real VCL PNG file with visible content. }
function MakeTempPngFile: string;
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clGreen;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Result := TPath.Combine(TPath.GetTempPath,
        'vittix_test_' + TGUID.NewGuid.ToString + '.png');
      Png.SaveToFile(Result);
    finally
      Png.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

{ Creates a real VCL JPEG file with visible content. }
function MakeTempJpegFile: string;
var
  Bmp: TBitmap;
  Jpeg: TJPEGImage;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clYellow;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Jpeg := TJPEGImage.Create;
    try
      Jpeg.Assign(Bmp);
      Result := TPath.Combine(TPath.GetTempPath,
        'vittix_test_' + TGUID.NewGuid.ToString + '.jpg');
      Jpeg.SaveToFile(Result);
    finally
      Jpeg.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

{ Renders an image whose DataField resolves to AFilePath through the real
  engine capture and VectorPDF export and returns the PDF text. }
function ExportImageFileToPDF(const AFilePath: string): string;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
  DS: TClientDataSet;
  Ms: TBytesStream;
  I: Integer;
begin
  // In-memory model identical to the base64 test builder, but the field
  // value is AFilePath: ResolveImageSource returns it and the file-path
  // capture branch runs exactly as in production.
  DS := TClientDataSet.Create(nil);
  DS.FieldDefs.Add('ImgB64', ftString, 2000);
  DS.CreateDataSet;
  DS.AppendRecord([AFilePath]);
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

  Doc := TReportExportDocument.Create;
  Engine := TReportEngine.Create(Model, DS, nil, nil);
  try
    Engine.ExportDocument := Doc;
    Engine.Prepare;
    Ms := TBytesStream.Create;
    try
      TReportVectorPDFExporter.ExportDocument(Doc, Ms);
      // PDF content is binary (compressed streams): convert bytes to
      // characters losslessly instead of strict UTF-8 decoding.
      SetLength(Result, Ms.Size);
      for I := 0 to Ms.Size - 1 do
        Result[I + 1] := Chr(Ms.Bytes[I]);
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TExportCaptureTests.Test_FilePathBMP_VectorPDF_ContainsImage;
var
  BmpPath, Pdf: string;
begin
  BmpPath := MakeTempBmpFile;
  try
    Pdf := ExportImageFileToPDF(BmpPath);
    // Structurally valid PDF with a real embedded image XObject.
    Assert.Contains(Pdf, '%%EOF');
    Assert.Contains(Pdf, '/Subtype /Image');
    Assert.Contains(Pdf, '/FlateDecode');
    Assert.Contains(Pdf, ' Do'#10);
  finally
    TFile.Delete(BmpPath);
  end;
end;

procedure TExportCaptureTests.Test_FilePathGIF_VectorPDF_ContainsImage;
var
  GifPath, Pdf: string;
begin
  GifPath := MakeTempGifFile;
  try
    Pdf := ExportImageFileToPDF(GifPath);
    Assert.Contains(Pdf, '%%EOF');
    Assert.Contains(Pdf, '/Subtype /Image');
    Assert.Contains(Pdf, '/FlateDecode');
    Assert.Contains(Pdf, ' Do'#10);
  finally
    TFile.Delete(GifPath);
  end;
end;

procedure TExportCaptureTests.Test_FilePathPNG_VectorPDF_Regression;
var
  PngPath, Pdf: string;
begin
  PngPath := MakeTempPngFile;
  try
    Pdf := ExportImageFileToPDF(PngPath);
    Assert.Contains(Pdf, '%%EOF');
    Assert.Contains(Pdf, '/Subtype /Image');
    Assert.Contains(Pdf, '/FlateDecode');
    Assert.Contains(Pdf, ' Do'#10);
  finally
    TFile.Delete(PngPath);
  end;
end;

procedure TExportCaptureTests.Test_FilePathJPEG_VectorPDF_Regression;
var
  JpgPath, Pdf: string;
begin
  JpgPath := MakeTempJpegFile;
  try
    Pdf := ExportImageFileToPDF(JpgPath);
    Assert.Contains(Pdf, '%%EOF');
    Assert.Contains(Pdf, '/Subtype /Image');
    Assert.Contains(Pdf, '/DCTDecode');
    Assert.Contains(Pdf, ' Do'#10);
  finally
    TFile.Delete(JpgPath);
  end;
end;

procedure TExportCaptureTests.Test_FilePathInvalidRaster_GracefulSkip;
var
  Pdf: string;
begin
  // Non-existent .bmp path: capture emits no image command and the PDF
  // export must complete without an image object or an exception.
  Pdf := ExportImageFileToPDF(
    TPath.Combine(TPath.GetTempPath, 'vittix_missing_' +
      TGUID.NewGuid.ToString + '.bmp'));
  Assert.Contains(Pdf, '%%EOF');
  Assert.IsFalse(ContainsText(Pdf, '/Im'),
    'missing image must not produce an image XObject');
end;


initialization
  TDUnitX.RegisterTestFixture(TExportCaptureTests);

end.
