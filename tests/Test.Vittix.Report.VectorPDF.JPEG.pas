unit Test.Vittix.Report.VectorPDF.JPEG;

{
  Vector PDF JPEG color-space handling (v1.0 freeze fix).

  TryLoadJPEGXObject used to emit /DeviceRGB for every embedded JPEG, so
  CMYK scans rendered with wrong colors and progressive files were
  embedded as-is (unreliable across viewers).  Now the JPEG SOF marker is
  parsed: 1 component -> /DeviceGray, 3 -> /DeviceRGB (unchanged baseline
  path), 4 -> /DeviceCMYK with /Decode [1 0 1 0 1 0 1 0] when an Adobe
  APP14 marker marks the inverted-CMYK/YCCK convention.  Progressive
  (SOF2) files decode through the VCL codec onto the shared
  BuildFlateRGBXObject flatten path.

  Fixtures: grayscale/progressive JPEGs are real VCL TJPEGImage encoder
  output; the CMYK fixtures are hand-built marker streams (DQT + APP14 +
  SOF0 with 4 components + SOS + EOI) - sufficient because the baseline
  path embeds the bytes as-is and the assertions are dictionary-level.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TVectorPDFJpegTests = class
  private
    function EncodeJpegFixture(AGrayscale, AProgressive: Boolean): TBytes;
    function BuildCmykJpegFixture(AAdobeApp14: Boolean): TBytes;
    function ExportImageBytesToPdfText(const ABytes: TBytes;
      const AFormat: string): string;
  public
    [Test] procedure Test_BaselineRGB_Jpeg_UsesDeviceRGB_DCTDecode;
    [Test] procedure Test_Grayscale_Jpeg_UsesDeviceGray;
    [Test] procedure Test_CMYK_Jpeg_UsesDeviceCMYK_WithAdobeDecode;
    [Test] procedure Test_CMYK_Jpeg_WithoutAdobe_NoDecode;
    [Test] procedure Test_Progressive_Jpeg_FallsBackToFlateRGB;
  end;

implementation

uses
  System.Types,
  System.StrUtils,
  Vcl.Graphics,
  Vcl.Imaging.jpeg,
  Vittix.Report.Export.VectorPDF;

function TVectorPDFJpegTests.EncodeJpegFixture(AGrayscale, AProgressive: Boolean): TBytes;
var
  Bmp: TBitmap;
  Jpeg: TJPEGImage;
  Ms: TMemoryStream;
begin
  Bmp := TBitmap.Create;
  Jpeg := TJPEGImage.Create;
  Ms := TMemoryStream.Create;
  try
    Bmp.SetSize(24, 16);
    Bmp.Canvas.Brush.Color := clRed;
    Bmp.Canvas.FillRect(Rect(0, 0, 24, 16));
    Jpeg.Grayscale := AGrayscale;
    Jpeg.ProgressiveEncoding := AProgressive;
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

{ Minimal marker-level CMYK JPEG: 1x1, 4 components, SOF0 baseline.
  Only the markers matter - the baseline embed path carries the bytes
  as-is into the PDF stream. }
function TVectorPDFJpegTests.BuildCmykJpegFixture(AAdobeApp14: Boolean): TBytes;
var
  Ms: TMemoryStream;

  procedure W(B: Byte);
  begin
    Ms.WriteBuffer(B, 1);
  end;

  procedure WBytes(const B: TBytes);
  begin
    if Length(B) > 0 then
      Ms.WriteBuffer(B[0], Length(B));
  end;

  procedure WSeg(AMarker: Byte; const APayload: TBytes);
  begin
    W($FF);
    W(AMarker);
    W((Length(APayload) + 2) shr 8);
    W((Length(APayload) + 2) and $FF);
    WBytes(APayload);
  end;

var
  Payload: TBytes;
  I: Integer;
begin
  Ms := TMemoryStream.Create;
  try
    W($FF); W($D8); // SOI

    if AAdobeApp14 then
    begin
      // APP14: 'Adobe' + version 00 64 + flags 0000 0000 + transform 2 (YCCK)
      SetLength(Payload, 12);
      Payload[0] := Ord('A'); Payload[1] := Ord('d'); Payload[2] := Ord('o');
      Payload[3] := Ord('b'); Payload[4] := Ord('e');
      Payload[5] := $00; Payload[6] := $64; // version
      Payload[7] := $00; Payload[8] := $00; // flags0
      Payload[9] := $00; Payload[10] := $00; // flags1
      Payload[11] := $02; // transform = YCCK
      WSeg($EE, Payload);
    end;

    // DQT: table 0, 8-bit, all coefficients 1
    SetLength(Payload, 65);
    Payload[0] := $00;
    for I := 1 to 64 do
      Payload[I] := $01;
    WSeg($DB, Payload);

    // SOF0: precision 8, 1x1, 4 components, all sampling 1x1, table 0
    SetLength(Payload, 15);
    Payload[0] := $08;                       // precision
    Payload[1] := $00; Payload[2] := $01;    // height
    Payload[3] := $00; Payload[4] := $01;    // width
    Payload[5] := $04;                       // 4 components (CMYK)
    for I := 0 to 3 do
    begin
      Payload[6 + I * 3] := I + 1; // component id 1..4
      Payload[7 + I * 3] := $11;   // sampling
      Payload[8 + I * 3] := $00;   // quant table 0
    end;
    WSeg($C0, Payload);

    // SOS over the 4 components
    SetLength(Payload, 12);
    Payload[0] := $04; // component count in scan
    Payload[1] := $01; Payload[2] := $00;
    Payload[3] := $02; Payload[4] := $00;
    Payload[5] := $03; Payload[6] := $00;
    Payload[7] := $04; Payload[8] := $00;
    Payload[9] := $00; // Ss
    Payload[10] := $3F; // Se
    Payload[11] := $00; // Ah/Al
    WSeg($DA, Payload);

    W($00); // minimal entropy data
    W($FF); W($D9); // EOI

    SetLength(Result, Ms.Size);
    if Ms.Size > 0 then
      Move(Ms.Memory^, Result[0], Ms.Size);
  finally
    Ms.Free;
  end;
end;

function TVectorPDFJpegTests.ExportImageBytesToPdfText(const ABytes: TBytes;
  const AFormat: string): string;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportImageCommand;
  Ms: TBytesStream;
  I: Integer;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(200, 100);
    Cmd := TReportExportImageCommand.Create;
    Cmd.Bounds := Rect(0, 0, 24, 16);
    Cmd.Bytes := ABytes;
    Cmd.SourceFormat := AFormat;
    Page.Commands.Add(Cmd);

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
  end;
end;

procedure TVectorPDFJpegTests.Test_BaselineRGB_Jpeg_UsesDeviceRGB_DCTDecode;
var
  Pdf: string;
begin
  Pdf := ExportImageBytesToPdfText(EncodeJpegFixture(False, False), 'jpeg');
  Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
  Assert.Contains(Pdf, '/ColorSpace /DeviceRGB',
    'baseline 3-component JPEG keeps /DeviceRGB');
  Assert.Contains(Pdf, '/DCTDecode', 'baseline JPEG stays a DCT stream');
  Assert.IsFalse(ContainsText(Pdf, '/Decode [1 0'),
    'RGB JPEG must not carry a /Decode inversion');
end;

procedure TVectorPDFJpegTests.Test_Grayscale_Jpeg_UsesDeviceGray;
var
  Pdf: string;
begin
  Pdf := ExportImageBytesToPdfText(EncodeJpegFixture(True, False), 'jpeg');
  Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
  Assert.Contains(Pdf, '/ColorSpace /DeviceGray',
    '1-component JPEG must be embedded as /DeviceGray');
  Assert.Contains(Pdf, '/DCTDecode', 'grayscale JPEG stays a DCT stream');
end;

procedure TVectorPDFJpegTests.Test_CMYK_Jpeg_UsesDeviceCMYK_WithAdobeDecode;
var
  Pdf: string;
begin
  Pdf := ExportImageBytesToPdfText(BuildCmykJpegFixture(True), 'jpeg');
  Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
  Assert.Contains(Pdf, '/ColorSpace /DeviceCMYK',
    '4-component JPEG must be embedded as /DeviceCMYK');
  Assert.Contains(Pdf, ' /Decode [1 0 1 0 1 0 1 0]',
    'Adobe APP14 inverted CMYK must carry the /Decode inversion');
  Assert.Contains(Pdf, '/DCTDecode', 'CMYK JPEG stays a DCT stream');
  Assert.Contains(Pdf, '/Width 1', 'dimensions must come from the SOF marker');
end;

procedure TVectorPDFJpegTests.Test_CMYK_Jpeg_WithoutAdobe_NoDecode;
var
  Pdf: string;
begin
  Pdf := ExportImageBytesToPdfText(BuildCmykJpegFixture(False), 'jpeg');
  Assert.Contains(Pdf, '/ColorSpace /DeviceCMYK',
    '4-component JPEG is still CMYK without APP14');
  Assert.IsFalse(ContainsText(Pdf, ' /Decode [1 0 1 0 1 0 1 0]'),
    'no APP14 marker means no /Decode inversion');
end;

procedure TVectorPDFJpegTests.Test_Progressive_Jpeg_FallsBackToFlateRGB;
var
  Pdf: string;
begin
  Pdf := ExportImageBytesToPdfText(EncodeJpegFixture(False, True), 'jpeg');
  Assert.Contains(Pdf, '%%EOF', 'vector PDF must be complete');
  Assert.IsFalse(ContainsText(Pdf, '/DCTDecode'),
    'progressive JPEG must not be embedded as-is');
  Assert.Contains(Pdf, '/FlateDecode',
    'progressive JPEG decodes onto the Flate RGB path');
  Assert.Contains(Pdf, '/ColorSpace /DeviceRGB',
    'decoded progressive pixels are RGB');
end;

initialization
  TDUnitX.RegisterTestFixture(TVectorPDFJpegTests);

end.
