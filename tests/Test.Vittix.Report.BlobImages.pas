unit Test.Vittix.Report.BlobImages;

{
  BLOB image support for data-bound images (v1.0 freeze fix).

  TReportImageObject.DataField now resolves binary blob columns (TBlobField
  with ftBlob/ftGraphic/ftOraBlob - Firebird BLOB SUB_TYPE 0 through FireDAC)
  in addition to the existing file-path and base64 string sources.  These
  tests pin:

  - per-row correctness through the Draw (preview) path: the right image for
    each row, and a NULL blob row must NOT reuse the previous row's image;
  - the export-capture path: one image command per non-null row, temp files
    keep the original encoded format (PNG stays PNG, JPEG stays JPEG);
  - Vector PDF export agreement (FlateDecode for PNG, DCTDecode for JPEG);
  - HTML export agreement (data:image/png + data:image/jpeg embedded).

  Fixtures are TFDMemTable in-memory tables (same engine as FireDAC
  production use), filled through CreateBlobStream - no external files.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TBlobImageTests = class
  private
    function GreenPngBytes: TBytes;
    function BluePngBytes: TBytes;
    function RedJpegBytes: TBytes;
    function BuildBlobTable: TFDMemTable;
    function BuildEngine(const ADataField: string; AIncludePhoto: Boolean;
      out ADoc: TReportExportDocument;
      out AModel: TReportModel;
      out ADS: TFDMemTable): TReportEngine;
  public
    [Test] procedure Test_BlobPNG_DrawPath_RendersPerRow_NoCrossRowReuse;
    [Test] procedure Test_BlobJPEG_DrawPath_RendersAndNullStaysEmpty;
    [Test] procedure Test_Blob_Capture_CommandsPerRow_InOriginalFormat;
    [Test] procedure Test_Blob_NullRow_ProducesNoCaptureCommand;
    [Test] procedure Test_BlobPNG_VectorPDF_ContainsImageXObject;
    [Test] procedure Test_BlobJPEG_VectorPDF_UsesDCTDecode;
    [Test] procedure Test_Blob_HTMLExport_ContainsBothImages;
  end;

implementation

uses
  Winapi.Windows,
  System.Types,
  System.UITypes,
  System.Math,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg,
  Vittix.Report.Renderer,
  Vittix.Report.Export.HTML,
  Vittix.Report.Export.VectorPDF;

const
  ImgW = 24;
  ImgH = 16;
  BandH = 60;

{ ---------------- fixtures ---------------- }

function EncodeSolidColorPng(AColor: TColor): TBytes;
var
  Bmp: TBitmap;
  Png: TPngImage;
  Ms: TMemoryStream;
begin
  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(ImgW, ImgH);
    Bmp.Canvas.Brush.Color := AColor;
    Bmp.Canvas.FillRect(Rect(0, 0, ImgW, ImgH));
    Png.Assign(Bmp);
    Png.SaveToStream(Ms);
    SetLength(Result, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Result[0], Ms.Size);
  finally
    Ms.Free;
    Png.Free;
    Bmp.Free;
  end;
end;

function EncodeSolidColorJpeg(AColor: TColor): TBytes;
var
  Bmp: TBitmap;
  Jpeg: TJPEGImage;
  Ms: TMemoryStream;
begin
  Bmp := TBitmap.Create;
  Jpeg := TJPEGImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(ImgW, ImgH);
    Bmp.Canvas.Brush.Color := AColor;
    Bmp.Canvas.FillRect(Rect(0, 0, ImgW, ImgH));
    Jpeg.Assign(Bmp);
    Jpeg.SaveToStream(Ms);
    SetLength(Result, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Result[0], Ms.Size);
  finally
    Ms.Free;
    Jpeg.Free;
    Bmp.Free;
  end;
end;

function TBlobImageTests.GreenPngBytes: TBytes;
begin
  Result := EncodeSolidColorPng(clLime);
end;

function TBlobImageTests.BluePngBytes: TBytes;
begin
  Result := EncodeSolidColorPng(clBlue);
end;

function TBlobImageTests.RedJpegBytes: TBytes;
begin
  Result := EncodeSolidColorJpeg(clRed);
end;

procedure AppendBlobRow(DS: TFDMemTable; const ALabel: string;
  ALogo, APhoto: TBytes);

  procedure FillBlob(const AFieldName: string; const ABytes: TBytes);
  var
    Stream: TStream;
  begin
    if Length(ABytes) = 0 then
      Exit;
    Stream := DS.CreateBlobStream(DS.FieldByName(AFieldName), bmWrite);
    try
      Stream.WriteBuffer(ABytes[0], Length(ABytes));
    finally
      Stream.Free;
    end;
  end;

begin
  DS.Append;
  try
    DS.FieldByName('RowLabel').AsString := ALabel;
    FillBlob('Logo', ALogo);
    FillBlob('Photo', APhoto);
  except
    DS.Cancel;
    raise;
  end;
  DS.Post;
end;

function TBlobImageTests.BuildBlobTable: TFDMemTable;
begin
  Result := TFDMemTable.Create(nil);
  Result.FieldDefs.Add('RowLabel', ftString, 20);
  Result.FieldDefs.Add('Logo', ftBlob);
  Result.FieldDefs.Add('Photo', ftGraphic);
  Result.CreateDataSet;
  // Row 1: both images.  Row 2: PNG logo only.  Row 3: both NULL.
  AppendBlobRow(Result, 'row1', GreenPngBytes, RedJpegBytes);
  AppendBlobRow(Result, 'row2', BluePngBytes, nil);
  AppendBlobRow(Result, 'row3', nil, nil);
  Result.First;
end;

function TBlobImageTests.BuildEngine(const ADataField: string;
  AIncludePhoto: Boolean;
  out ADoc: TReportExportDocument;
  out AModel: TReportModel;
  out ADS: TFDMemTable): TReportEngine;
var
  Model: TReportModel;
  Band: TReportBand;
  Img: TReportImageObject;
begin
  ADS := BuildBlobTable;
  Model := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := BandH;

  Img := TReportImageObject.Create;
  Img.Name := 'imgBlob';
  Img.Bounds := Rect(10, 5, 10 + ImgW + 106, 5 + ImgH + 34);
  Img.DataField := ADataField;
  // 1:1 draw: the bitmap pixels map straight to the fixture image.
  Img.Stretch := False;
  Img.Center := False;
  Img.Proportional := False;
  Band.Children.Add(Img);

  if AIncludePhoto then
  begin
    Img := TReportImageObject.Create;
    Img.Name := 'imgBlobPhoto';
    Img.Bounds := Rect(150, 5, 150 + ImgW + 106, 5 + ImgH + 34);
    Img.DataField := 'Photo';
    Img.Stretch := False;
    Img.Center := False;
    Img.Proportional := False;
    Band.Children.Add(Img);
  end;

  Model.Objects.Add(Band);
  AModel := Model;

  ADoc := TReportExportDocument.Create;
  Result := TReportEngine.Create(Model, ADS, nil, nil);
  Result.ExportDocument := ADoc;
end;

{ ---------------- scan helpers ---------------- }

{ Bounding box of pixels matching AColor exactly. }
procedure FindExactColorBox(Bmp: TBitmap; AColor: TColor;
  out AFound: Boolean; out ABox: TRect);
var
  X, Y: Integer;
begin
  AFound := False;
  ABox := Rect(MaxInt, MaxInt, -1, -1);
  for Y := 0 to Bmp.Height - 1 do
    for X := 0 to Bmp.Width - 1 do
      if Bmp.Canvas.Pixels[X, Y] = AColor then
      begin
        AFound := True;
        if X < ABox.Left then ABox.Left := X;
        if X > ABox.Right then ABox.Right := X;
        if Y < ABox.Top then ABox.Top := Y;
        if Y > ABox.Bottom then ABox.Bottom := Y;
      end;
end;

{ True when any pixel inside ARect matches AColor exactly. }
function WindowHasExactColor(Bmp: TBitmap; const ARect: TRect;
  AColor: TColor): Boolean;
var
  X, Y: Integer;
begin
  Result := False;
  for Y := Max(0, ARect.Top) to Min(Bmp.Height - 1, ARect.Bottom) do
    for X := Max(0, ARect.Left) to Min(Bmp.Width - 1, ARect.Right) do
      if Bmp.Canvas.Pixels[X, Y] = AColor then
        Exit(True);
end;

{ Bounding box of JPEG-decoded near-red pixels (lossy codec: exact match is
  not stable across machines, a generous tolerance is). }
procedure FindReddishBox(Bmp: TBitmap; out AFound: Boolean; out ABox: TRect;
  out ACount: Integer);
var
  X, Y: Integer;
  C: TColor;
begin
  AFound := False;
  ACount := 0;
  ABox := Rect(MaxInt, MaxInt, -1, -1);
  for Y := 0 to Bmp.Height - 1 do
    for X := 0 to Bmp.Width - 1 do
    begin
      C := Bmp.Canvas.Pixels[X, Y];
      if (GetRValue(C) > 180) and (GetGValue(C) < 80) and (GetBValue(C) < 80) then
      begin
        Inc(ACount);
        AFound := True;
        if X < ABox.Left then ABox.Left := X;
        if X > ABox.Right then ABox.Right := X;
        if Y < ABox.Top then ABox.Top := Y;
        if Y > ABox.Bottom then ABox.Bottom := Y;
      end;
    end;
end;

function WindowHasReddish(Bmp: TBitmap; const ARect: TRect): Boolean;
var
  X, Y: Integer;
  C: TColor;
begin
  Result := False;
  for Y := Max(0, ARect.Top) to Min(Bmp.Height - 1, ARect.Bottom) do
    for X := Max(0, ARect.Left) to Min(Bmp.Width - 1, ARect.Right) do
    begin
      C := Bmp.Canvas.Pixels[X, Y];
      if (GetRValue(C) > 180) and (GetGValue(C) < 80) and (GetBValue(C) < 80) then
        Exit(True);
    end;
end;

function CollectImageCommands(ADoc: TReportExportDocument): TArray<TReportExportImageCommand>;
var
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
begin
  SetLength(Result, 0);
  for Page in ADoc.Pages do
    for Cmd in Page.Commands do
      if Cmd.Kind = eckImage then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := TReportExportImageCommand(Cmd);
      end;
end;

function ExportDocToPdfText(ADoc: TReportExportDocument): string;
var
  Ms: TBytesStream;
  I: Integer;
begin
  Ms := TBytesStream.Create;
  try
    TReportVectorPDFExporter.ExportDocument(ADoc, Ms);
    // PDF content is binary (compressed streams): convert bytes to
    // characters losslessly instead of strict UTF-8 decoding.
    SetLength(Result, Ms.Size);
    for I := 0 to Ms.Size - 1 do
      Result[I + 1] := Chr(Ms.Bytes[I]);
  finally
    Ms.Free;
  end;
end;

{ ---------------- tests ---------------- }

procedure TBlobImageTests.Test_BlobPNG_DrawPath_RendersPerRow_NoCrossRowReuse;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Renderer: TReportRenderer;
  Bmp: TBitmap;
  GreenFound, BlueFound: Boolean;
  GreenBox, BlueBox: TRect;
  Stride, Row3Top: Integer;
begin
  // Three master rows: green PNG / blue PNG / NULL logo.  The NULL row must
  // render empty - in particular it must NOT repeat row 2's image.
  Engine := BuildEngine('Logo', False, Doc, Model, DS);
  Renderer := TReportRenderer.Create;
  try
    Renderer.Render(Engine, Model.PageSettings.PageWidth,
      Model.PageSettings.PageHeight);
    Assert.IsTrue(Renderer.Pages.Count >= 1, 'preview must render one page');
    Bmp := Renderer.Pages[0].Bitmap;
    Assert.IsNotNull(Bmp, 'preview bitmap must materialise');

    FindExactColorBox(Bmp, clLime, GreenFound, GreenBox);
    FindExactColorBox(Bmp, clBlue, BlueFound, BlueBox);

    Assert.IsTrue(GreenFound, 'row 1 must draw the green PNG');
    Assert.IsTrue(BlueFound, 'row 2 must draw the blue PNG');
    Assert.AreEqual(ImgW, GreenBox.Right - GreenBox.Left + 1, 'green 1:1 width');
    Assert.AreEqual(ImgH, GreenBox.Bottom - GreenBox.Top + 1, 'green 1:1 height');
    Assert.AreEqual(ImgW, BlueBox.Right - BlueBox.Left + 1, 'blue 1:1 width');
    Assert.AreEqual(ImgH, BlueBox.Bottom - BlueBox.Top + 1, 'blue 1:1 height');
    Assert.AreEqual(GreenBox.Left, BlueBox.Left, 'rows share the band X offset');

    // Row order: band instances stack top-down, so blue (row 2) sits exactly
    // one band stride below green (row 1).
    Stride := BlueBox.Top - GreenBox.Top;
    Assert.IsTrue(Stride > 0, 'row 2 must print below row 1');

    // The NULL row's image window must be blank (no green, no blue).
    Row3Top := GreenBox.Top + 2 * Stride;
    Assert.IsFalse(WindowHasExactColor(Bmp,
      Rect(GreenBox.Left, Row3Top, GreenBox.Right, Row3Top + ImgH - 1), clLime),
      'NULL row must not reuse a previous row''s image (green)');
    Assert.IsFalse(WindowHasExactColor(Bmp,
      Rect(GreenBox.Left, Row3Top, GreenBox.Right, Row3Top + ImgH - 1), clBlue),
      'NULL row must not reuse a previous row''s image (blue)');
  finally
    Renderer.Free;
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TBlobImageTests.Test_BlobJPEG_DrawPath_RendersAndNullStaysEmpty;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Renderer: TReportRenderer;
  Bmp: TBitmap;
  Found: Boolean;
  Box: TRect;
  Count, Stride, Row2Top: Integer;
begin
  // ftGraphic column with a JPEG payload: row 1 renders, rows 2-3 are NULL.
  Engine := BuildEngine('Photo', False, Doc, Model, DS);
  Renderer := TReportRenderer.Create;
  try
    Renderer.Render(Engine, Model.PageSettings.PageWidth,
      Model.PageSettings.PageHeight);
    Bmp := Renderer.Pages[0].Bitmap;
    Assert.IsNotNull(Bmp, 'preview bitmap must materialise');

    FindReddishBox(Bmp, Found, Box, Count);
    Assert.IsTrue(Found, 'row 1 must draw the JPEG photo');
    Assert.IsTrue(Count > 200, Format('JPEG red pixels=%d', [Count]));
    Assert.AreEqual(ImgH, Box.Bottom - Box.Top + 1, 'JPEG drawn 1:1 height');

    // Rows 2 and 3 (NULL) must be blank: no reddish pixels at the next band
    // strides below the drawn image.
    Stride := BandH;
    Row2Top := Box.Top + Stride;
    Assert.IsFalse(WindowHasReddish(Bmp,
      Rect(Box.Left, Row2Top, Box.Right, Row2Top + ImgH - 1)),
      'NULL row must not reuse the JPEG image');
    Row2Top := Box.Top + 2 * Stride;
    Assert.IsFalse(WindowHasReddish(Bmp,
      Rect(Box.Left, Row2Top, Box.Right, Row2Top + ImgH - 1)),
      'second NULL row must not reuse the JPEG image');
  finally
    Renderer.Free;
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TBlobImageTests.Test_Blob_Capture_CommandsPerRow_InOriginalFormat;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Commands: TArray<TReportExportImageCommand>;
  I: Integer;
  FileBytes: TBytes;
  DeletedPaths: array[0..2] of string;
begin
  // Logo (PNG) + Photo (JPEG) objects across 3 rows: row 1 has both images,
  // row 2 only the logo, row 3 both NULL.  Each non-null cell captures one
  // command whose temp file keeps the ORIGINAL encoded format (not a
  // re-encoded PNG): [Logo PNG, Photo JPEG, Logo PNG].
  Engine := BuildEngine('Logo', True, Doc, Model, DS);
  try
    Engine.Prepare;
    Commands := CollectImageCommands(Doc);
    Assert.AreEqual(3, Length(Commands),
      'row1 logo + row1 photo + row2 logo = three image commands');
    Assert.IsTrue(Length(Commands[0].Source) > 0, 'command must carry a source');

    for I := 0 to 2 do
    begin
      Assert.IsTrue(TFile.Exists(Commands[I].Source),
        Format('command %d temp file missing', [I]));
      FileBytes := TFile.ReadAllBytes(Commands[I].Source);
      DeletedPaths[I] := Commands[I].Source;
      if I = 1 then
      begin
        // Photo object, row 1: JPEG bytes preserved
        Assert.IsTrue((Length(FileBytes) > 3) and (FileBytes[0] = $FF) and
          (FileBytes[1] = $D8) and (FileBytes[2] = $FF),
          'command 1 must stay original JPEG');
      end
      else
      begin
        // Logo object, rows 1-2: PNG bytes preserved
        Assert.IsTrue((Length(FileBytes) > 4) and (FileBytes[0] = $89) and
          (FileBytes[1] = $50) and (FileBytes[2] = $4E) and (FileBytes[3] = $47),
          Format('command %d must stay original PNG', [I]));
      end;
    end;
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;

  for I := 0 to 2 do
    Assert.IsFalse(TFile.Exists(DeletedPaths[I]),
      'export document must delete the registered blob temp file on free');
end;

procedure TBlobImageTests.Test_Blob_NullRow_ProducesNoCaptureCommand;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Commands: TArray<TReportExportImageCommand>;
begin
  Engine := BuildEngine('Logo', False, Doc, Model, DS);
  try
    Engine.Prepare;
    Commands := CollectImageCommands(Doc);
    Assert.AreEqual(2, Length(Commands),
      'rows 1-2 capture, the NULL row 3 must not');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TBlobImageTests.Test_BlobPNG_VectorPDF_ContainsImageXObject;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Pdf: string;
begin
  Engine := BuildEngine('Logo', False, Doc, Model, DS);
  try
    Engine.Prepare;
    Pdf := ExportDocToPdfText(Doc);
    Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
    Assert.Contains(Pdf, '/Subtype /Image',
      'blob PNG must export as an image XObject');
    Assert.Contains(Pdf, '/FlateDecode', 'blob PNG keeps the Flate path');
    Assert.Contains(Pdf, ' Do'#10, 'image XObject must be drawn');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TBlobImageTests.Test_BlobJPEG_VectorPDF_UsesDCTDecode;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Pdf: string;
begin
  Engine := BuildEngine('Photo', False, Doc, Model, DS);
  try
    Engine.Prepare;
    Pdf := ExportDocToPdfText(Doc);
    Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
    Assert.Contains(Pdf, '/Subtype /Image',
      'blob JPEG must export as an image XObject');
    Assert.Contains(Pdf, '/DCTDecode',
      'blob JPEG must pass through as a JPEG XObject, not be re-encoded');
    Assert.Contains(Pdf, ' Do'#10, 'image XObject must be drawn');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TBlobImageTests.Test_Blob_HTMLExport_ContainsBothImages;
var
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Model: TReportModel;
  DS: TFDMemTable;
  Ms: TStringStream;
  HTML: string;
begin
  Engine := BuildEngine('Logo', True, Doc, Model, DS);
  try
    Engine.Prepare;
    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      HTML := Ms.DataString;
    finally
      Ms.Free;
    end;
    Assert.Contains(HTML, 'data:image/png;base64,', 'PNG logo must embed');
    Assert.Contains(HTML, 'data:image/jpeg;base64,', 'JPEG photo must embed');
    Assert.Contains(HTML, '</html>');
  finally
    Doc.Free;
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBlobImageTests);

end.
