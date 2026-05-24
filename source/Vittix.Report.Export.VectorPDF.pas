unit Vittix.Report.Export.VectorPDF;

interface

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  System.ZLib,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  Vittix.Report.Export.Commands;

type
  TReportVectorPDFExporter = class
  public
    class procedure ExportDocument(
      ADocument: TReportExportDocument;
      const AFileName: string); static;
  end;

implementation

class procedure TReportVectorPDFExporter.ExportDocument(
  ADocument: TReportExportDocument;
  const AFileName: string);
var
  Stream: TFileStream;
  Offsets: TArray<Int64>;
  ObjectCount: Integer;
  I: Integer;
  PageIndex: Integer;
  ObjNo: Integer;
  ContentObjNo: Integer;
  XRefOffset: Int64;
  Content: AnsiString;

  procedure WriteAnsi(const S: AnsiString);
  begin
    if S <> '' then
      Stream.WriteBuffer(PAnsiChar(S)^, Length(S));
  end;

  procedure BeginObject(AObjectNo: Integer);
  begin
    Offsets[AObjectNo] := Stream.Position;
    WriteAnsi(AnsiString(IntToStr(AObjectNo) + ' 0 obj' + #10));
  end;

  procedure EndObject;
  begin
    WriteAnsi('endobj' + #10);
  end;

  function PageObjectNo(APageIndex: Integer): Integer;
  begin
    Result := 3 + (APageIndex * 2);
  end;

  function PageContentObjectNo(APageIndex: Integer): Integer;
  begin
    Result := PageObjectNo(APageIndex) + 1;
  end;

  function PdfNumber(AValue: Double): AnsiString;
  begin
    Result := AnsiString(StringReplace(
      FormatFloat('0.###', AValue),
      FormatSettings.DecimalSeparator,
      '.',
      []));
  end;

  function PdfColor(AColor: TColor): AnsiString;
  var
    RGBColor: LongInt;
  begin
    RGBColor := ColorToRGB(AColor);
    Result :=
      PdfNumber(GetRValue(RGBColor) / 255) + ' ' +
      PdfNumber(GetGValue(RGBColor) / 255) + ' ' +
      PdfNumber(GetBValue(RGBColor) / 255);
  end;

  function PdfY(APage: TReportExportPage; AY: Integer): Double;
  begin
    Result := APage.Height - AY;
  end;

  function PdfText(const S: string): AnsiString;
  var
    Ch: AnsiChar;
  begin
    Result := '';
    for Ch in AnsiString(S) do
    begin
      case Ch of
        '(', ')', '\': Result := Result + '\' + Ch;
        #13, #10: Result := Result + ' ';
      else
        Result := Result + Ch;
      end;
    end;
  end;

  function PdfTextX(AText: TReportExportTextCommand): Double;
  var
    EstimatedWidth: Double;
  begin
    Result := AText.Bounds.Left;
    if AText.HAlign = taLeftJustify then
      Exit;

    EstimatedWidth := Length(AText.Text) * AText.FontSize * 0.5;
    case AText.HAlign of
      taRightJustify:
        Result := AText.Bounds.Right - EstimatedWidth;
      taCenter:
        Result := AText.Bounds.Left + ((AText.Bounds.Width - EstimatedWidth) / 2);
    end;

    if Result < AText.Bounds.Left then
      Result := AText.Bounds.Left;
  end;

  function PdfFontName(AText: TReportExportTextCommand): AnsiString;
  begin
    if (fsBold in AText.FontStyle) and (fsItalic in AText.FontStyle) then
      Result := '/F4'
    else if fsItalic in AText.FontStyle then
      Result := '/F3'
    else if fsBold in AText.FontStyle then
      Result := '/F2'
    else
      Result := '/F1';
  end;

  function BytesToAnsiString(const ABytes: TBytes): AnsiString;
  begin
    SetLength(Result, Length(ABytes));
    if Length(ABytes) > 0 then
      Move(ABytes[0], PAnsiChar(Result)^, Length(ABytes));
  end;

  function IsJPEGFile(const AFileName: string): Boolean;
  var
    Ext: string;
  begin
    Ext := LowerCase(ExtractFileExt(AFileName));
    Result := (Ext = '.jpg') or (Ext = '.jpeg');
  end;

  function IsPNGFile(const AFileName: string): Boolean;
  begin
    Result := SameText(ExtractFileExt(AFileName), '.png');
  end;

  function CompressBytes(const ABytes: TBytes): TBytes;
  var
    Input: TMemoryStream;
    Output: TMemoryStream;
    Compressor: TCompressionStream;
  begin
    Input := TMemoryStream.Create;
    try
      if Length(ABytes) > 0 then
        Input.WriteBuffer(ABytes[0], Length(ABytes));
      Input.Position := 0;
      Output := TMemoryStream.Create;
      try
        Compressor := TCompressionStream.Create(System.ZLib.clDefault, Output);
        try
          Compressor.CopyFrom(Input, 0);
        finally
          Compressor.Free;
        end;
        SetLength(Result, Output.Size);
        if Output.Size > 0 then
        begin
          Output.Position := 0;
          Output.ReadBuffer(Result[0], Output.Size);
        end;
      finally
        Output.Free;
      end;
    finally
      Input.Free;
    end;
  end;

  function BuildJPEGImageContent(
    APage: TReportExportPage;
    AImage: TReportExportImageCommand): AnsiString;
  var
    JPEG: TJPEGImage;
    ImageBytes: TBytes;
    W: Integer;
    H: Integer;
  begin
    Result := '';
    if (AImage.Source = '') or not FileExists(AImage.Source) or
       not IsJPEGFile(AImage.Source) then
      Exit;

    JPEG := TJPEGImage.Create;
    try
      JPEG.LoadFromFile(AImage.Source);
      W := JPEG.Width;
      H := JPEG.Height;
    finally
      JPEG.Free;
    end;

    if (W <= 0) or (H <= 0) or (AImage.Bounds.Width <= 0) or
       (AImage.Bounds.Height <= 0) then
      Exit;

    ImageBytes := TFile.ReadAllBytes(AImage.Source);
    if Length(ImageBytes) = 0 then
      Exit;

    Result :=
      'q' + #10 +
      PdfNumber(AImage.Bounds.Width) + ' 0 0 ' +
      PdfNumber(AImage.Bounds.Height) + ' ' +
      PdfNumber(AImage.Bounds.Left) + ' ' +
      PdfNumber(PdfY(APage, AImage.Bounds.Bottom)) + ' cm' + #10 +
      'BI' + #10 +
      '/W ' + AnsiString(IntToStr(W)) + #10 +
      '/H ' + AnsiString(IntToStr(H)) + #10 +
      '/CS /RGB' + #10 +
      '/BPC 8' + #10 +
      '/F /DCTDecode' + #10 +
      'ID' + #10 +
      BytesToAnsiString(ImageBytes) + #10 +
      'EI' + #10 +
      'Q' + #10;
  end;

  function BuildPNGImageContent(
    APage: TReportExportPage;
    AImage: TReportExportImageCommand): AnsiString;
  var
    PNG: TPngImage;
    Bitmap: TBitmap;
    RawBytes: TBytes;
    CompressedBytes: TBytes;
    X: Integer;
    Y: Integer;
    Offset: Integer;
    PixelColor: TColor;
    RGBColor: LongInt;
    W: Integer;
    H: Integer;
  begin
    Result := '';
    if (AImage.Source = '') or not FileExists(AImage.Source) or
       not IsPNGFile(AImage.Source) then
      Exit;

    PNG := TPngImage.Create;
    try
      PNG.LoadFromFile(AImage.Source);
      if (PNG.Width <= 0) or (PNG.Height <= 0) or
         (AImage.Bounds.Width <= 0) or (AImage.Bounds.Height <= 0) then
        Exit;

      Bitmap := TBitmap.Create;
      try
        Bitmap.PixelFormat := pf24bit;
        Bitmap.SetSize(PNG.Width, PNG.Height);
        W := Bitmap.Width;
        H := Bitmap.Height;
        Bitmap.Canvas.Brush.Color := clWhite;
        Bitmap.Canvas.FillRect(Rect(0, 0, W, H));
        Bitmap.Canvas.Draw(0, 0, PNG);

        SetLength(RawBytes, W * H * 3);
        Offset := 0;
        for Y := 0 to H - 1 do
          for X := 0 to W - 1 do
          begin
            PixelColor := Bitmap.Canvas.Pixels[X, Y];
            RGBColor := ColorToRGB(PixelColor);
            RawBytes[Offset] := GetRValue(RGBColor);
            RawBytes[Offset + 1] := GetGValue(RGBColor);
            RawBytes[Offset + 2] := GetBValue(RGBColor);
            Inc(Offset, 3);
          end;
      finally
        Bitmap.Free;
      end;

      CompressedBytes := CompressBytes(RawBytes);
      if Length(CompressedBytes) = 0 then
        Exit;

      Result :=
        'q' + #10 +
        PdfNumber(AImage.Bounds.Width) + ' 0 0 ' +
        PdfNumber(AImage.Bounds.Height) + ' ' +
        PdfNumber(AImage.Bounds.Left) + ' ' +
        PdfNumber(PdfY(APage, AImage.Bounds.Bottom)) + ' cm' + #10 +
        'BI' + #10 +
        '/W ' + AnsiString(IntToStr(W)) + #10 +
        '/H ' + AnsiString(IntToStr(H)) + #10 +
        '/CS /RGB' + #10 +
        '/BPC 8' + #10 +
        '/F /FlateDecode' + #10 +
        'ID' + #10 +
        BytesToAnsiString(CompressedBytes) + #10 +
        'EI' + #10 +
        'Q' + #10;
    finally
      PNG.Free;
    end;
  end;

  function BuildPageContent(APage: TReportExportPage): AnsiString;
  var
    Command: TReportExportCommand;
    TextCmd: TReportExportTextCommand;
    ImageCmd: TReportExportImageCommand;
    LineCmd: TReportExportLineCommand;
    RectCmd: TReportExportRectangleCommand;
    FillCmd: TReportExportFillRectangleCommand;
    R: TRect;
  begin
    Result := '';
    for Command in APage.Commands do
    begin
      case Command.Kind of
        eckText:
        begin
          TextCmd := TReportExportTextCommand(Command);
          if TextCmd.Text <> '' then
          begin
            Result := Result +
              'q' + #10 +
              'BT' + #10 +
              PdfColor(TextCmd.FontColor) + ' rg' + #10 +
              PdfFontName(TextCmd) + ' ' + PdfNumber(TextCmd.FontSize) + ' Tf' + #10 +
              PdfNumber(PdfTextX(TextCmd)) + ' ' +
              PdfNumber(PdfY(APage, TextCmd.Bounds.Top + TextCmd.FontSize)) +
              ' Td' + #10 +
              '(' + PdfText(TextCmd.Text) + ') Tj' + #10 +
              'ET' + #10 +
              'Q' + #10;
          end;
        end;

        eckLine:
        begin
          LineCmd := TReportExportLineCommand(Command);
          Result := Result +
            'q' + #10 +
            PdfColor(LineCmd.Color) + ' RG' + #10 +
            PdfNumber(LineCmd.Width) + ' w' + #10 +
            PdfNumber(LineCmd.X1) + ' ' + PdfNumber(PdfY(APage, LineCmd.Y1)) + ' m' + #10 +
            PdfNumber(LineCmd.X2) + ' ' + PdfNumber(PdfY(APage, LineCmd.Y2)) + ' l' + #10 +
            'S' + #10 +
            'Q' + #10;
        end;

        eckRectangle:
        begin
          RectCmd := TReportExportRectangleCommand(Command);
          R := RectCmd.Bounds;
          Result := Result +
            'q' + #10 +
            PdfColor(RectCmd.BorderColor) + ' RG' + #10 +
            PdfNumber(RectCmd.BorderWidth) + ' w' + #10 +
            PdfNumber(R.Left) + ' ' + PdfNumber(PdfY(APage, R.Bottom)) + ' ' +
            PdfNumber(R.Width) + ' ' + PdfNumber(R.Height) + ' re' + #10 +
            'S' + #10 +
            'Q' + #10;
        end;

        eckFillRectangle:
        begin
          FillCmd := TReportExportFillRectangleCommand(Command);
          R := FillCmd.Bounds;
          Result := Result +
            'q' + #10 +
            PdfColor(FillCmd.FillColor) + ' rg' + #10 +
            PdfNumber(R.Left) + ' ' + PdfNumber(PdfY(APage, R.Bottom)) + ' ' +
            PdfNumber(R.Width) + ' ' + PdfNumber(R.Height) + ' re' + #10 +
            'f' + #10 +
            'Q' + #10;
        end;

        eckImage:
        begin
          ImageCmd := TReportExportImageCommand(Command);
          Result := Result + BuildJPEGImageContent(APage, ImageCmd);
          Result := Result + BuildPNGImageContent(APage, ImageCmd);
        end;
      end;
    end;
  end;

begin
  if not Assigned(ADocument) then
    raise EArgumentNilException.Create('ADocument');
  if AFileName = '' then
    raise EArgumentException.Create('AFileName is required');

  ObjectCount := 2 + (ADocument.Pages.Count * 2);
  SetLength(Offsets, ObjectCount + 1);

  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    WriteAnsi('%PDF-1.4' + #10);

    BeginObject(1);
    WriteAnsi('<< /Type /Catalog /Pages 2 0 R >>' + #10);
    EndObject;

    BeginObject(2);
    WriteAnsi('<< /Type /Pages /Count ' +
      AnsiString(IntToStr(ADocument.Pages.Count)) + ' /Kids [');
    for PageIndex := 0 to ADocument.Pages.Count - 1 do
      WriteAnsi(AnsiString(IntToStr(PageObjectNo(PageIndex)) + ' 0 R '));
    WriteAnsi('] >>' + #10);
    EndObject;

    for PageIndex := 0 to ADocument.Pages.Count - 1 do
    begin
      ObjNo := PageObjectNo(PageIndex);
      ContentObjNo := PageContentObjectNo(PageIndex);

      BeginObject(ObjNo);
      WriteAnsi('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' +
        AnsiString(IntToStr(ADocument.Pages[PageIndex].Width)) + ' ' +
        AnsiString(IntToStr(ADocument.Pages[PageIndex].Height)) +
        '] /Resources << /Font << ' +
        '/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> ' +
        '/F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> ' +
        '/F3 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >> ' +
        '/F4 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-BoldOblique >> ' +
        '>> >>' +
        ' /Contents ' + AnsiString(IntToStr(ContentObjNo)) + ' 0 R >>' + #10);
      EndObject;

      BeginObject(ContentObjNo);
      Content := BuildPageContent(ADocument.Pages[PageIndex]);
      WriteAnsi(AnsiString('<< /Length ' + IntToStr(Length(Content)) + ' >>' + #10));
      WriteAnsi('stream' + #10);
      WriteAnsi(Content);
      WriteAnsi('endstream' + #10);
      EndObject;
    end;

    XRefOffset := Stream.Position;
    WriteAnsi('xref' + #10);
    WriteAnsi(AnsiString('0 ' + IntToStr(ObjectCount + 1) + #10));
    WriteAnsi('0000000000 65535 f ' + #10);
    for I := 1 to ObjectCount do
      WriteAnsi(AnsiString(Format('%.10d 00000 n ', [Offsets[I]]) + #10));
    WriteAnsi('trailer' + #10);
    WriteAnsi(AnsiString('<< /Size ' + IntToStr(ObjectCount + 1) +
      ' /Root 1 0 R >>' + #10));
    WriteAnsi('startxref' + #10);
    WriteAnsi(AnsiString(IntToStr(XRefOffset) + #10));
    WriteAnsi('%%EOF' + #10);
  finally
    Stream.Free;
  end;
end;

end.
