unit Vittix.Report.Export.VectorPDF;

interface

uses
  System.Classes,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types,
  System.ZLib,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.GIFImg,
  Vittix.Report.Export.VectorPDF.SVG,
  Vittix.Report.Export.VectorPDF.EMF,
  Vittix.Report.Export.Commands;

type
  TScriptCache = Pointer;

  TScriptAnalysis = packed record
    Flags: Word;
    State: Word;
  end;
  PScriptAnalysis = ^TScriptAnalysis;

  TScriptItem = packed record
    iCharPos: Integer;
    a: TScriptAnalysis;
  end;
  PScriptItem = ^TScriptItem;

  TScriptVisAttr = Word;

  TGOffset = packed record
    du: Integer;
    dv: Integer;
  end;
  PGOffset = ^TGOffset;

  TPdfShapedGlyph = record
    GlyphId: Word;
    AdvancePx: Integer;
    OffsetXPx: Integer;
    OffsetYPx: Integer;
  end;

  TPdfShapedGlyphArray = TArray<TPdfShapedGlyph>;

  TPdfUnicodeFontResource = record
    ResourceName: AnsiString;
    Key: string;
    BaseFontName: AnsiString;
    FontName: string;
    FontStyle: TFontStyles;
    Type0ObjectNo: Integer;
    CIDFontObjectNo: Integer;
    DescriptorObjectNo: Integer;
    FontFileObjectNo: Integer;
    CIDToGIDMapObjectNo: Integer;
    ToUnicodeObjectNo: Integer;
    EmSquare: Integer;
    Ascent: Integer;
    Descent: Integer;
    CapHeight: Integer;
    ItalicAngle: Integer;
    Flags: Integer;
    FontBBoxLeft: Integer;
    FontBBoxBottom: Integer;
    FontBBoxRight: Integer;
    FontBBoxTop: Integer;
    FontFileBytes: TBytes;
    UsedGlyphIds: TArray<Word>;
    Widths1000: TArray<Integer>;
    UnicodeHexValues: TArray<AnsiString>;
  end;

  TPdfUnicodeFontResourceArray = TArray<TPdfUnicodeFontResource>;

  TReportVectorPDFExporter = class
  public
    class procedure ExportDocument(
      ADocument: TReportExportDocument;
      const AFileName: string); overload; static;
    class procedure ExportDocument(
      ADocument: TReportExportDocument;
      AStream: TStream); overload; static;
  end;

implementation

function ScriptItemize(pwcInChars: PWideChar; cInChars: Integer; cMaxItems: Integer;
  const psControl: Pointer; const psState: Pointer; pItems: PScriptItem;
  pcItems: PInteger): HRESULT; stdcall; external 'usp10.dll' name 'ScriptItemize';
function ScriptShape(hdc: HDC; var psc: TScriptCache; pwcChars: PWideChar;
  cChars: Integer; cMaxGlyphs: Integer; psa: PScriptAnalysis; pwOutGlyphs: PWord;
  pwLogClust: PWord; psva: Pointer; pcGlyphs: PInteger): HRESULT; stdcall;
  external 'usp10.dll' name 'ScriptShape';
function ScriptPlace(hdc: HDC; var psc: TScriptCache; pwGlyphs: PWord;
  cGlyphs: Integer; psva: Pointer; psa: PScriptAnalysis; piAdvance: PInteger;
  pGoffset: PGOffset; pABC: PABC): HRESULT; stdcall; external 'usp10.dll' name 'ScriptPlace';
function ScriptFreeCache(var psc: TScriptCache): HRESULT; stdcall;
  external 'usp10.dll' name 'ScriptFreeCache';

const
  PDF_POINTS_PER_PIXEL = 72 / 96;
  PDF_XREF_EOL = #13#10;
  SCRIPT_ANALYSIS_RTL = $0400;

type
  // One embedded raster image, written as a PDF Image XObject (not an
  // inline BI/ID/EI image - see VectorPDF_DevelopmentPlan.md "M5.5").
  // ObjectNo is filled in during the numbering pass, after all pages'
  // content and image lists are known.
  TPdfImageXObject = record
    Name: AnsiString;      // Resource name used inside the page content stream, e.g. 'Im1'.
    ObjectNo: Integer;
    Width: Integer;
    Height: Integer;
    ColorSpace: AnsiString;
    BitsPerComponent: Integer;
    Filter: AnsiString;    // '/DCTDecode' (JPEG) or '/FlateDecode' (PNG, raw RGB).
    Bytes: TBytes;
    SMaskName: AnsiString;
    SMaskObjectNo: Integer;
    SMaskBytes: TBytes;
  end;
  TPdfImageXObjectArray = TArray<TPdfImageXObject>;

class procedure TReportVectorPDFExporter.ExportDocument(
  ADocument: TReportExportDocument;
  const AFileName: string);
var
  Stream: TFileStream;
begin
  if not Assigned(ADocument) then
    raise EArgumentNilException.Create('ADocument');
  if AFileName = '' then
    raise EArgumentException.Create('AFileName is required');

  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    ExportDocument(ADocument, Stream);
  finally
    Stream.Free;
  end;
end;

class procedure TReportVectorPDFExporter.ExportDocument(
  ADocument: TReportExportDocument;
  AStream: TStream);
var
  Offsets: TArray<Int64>;
  ObjectCount: Integer;
  I: Integer;
  PageIndex: Integer;
  NextObjNo: Integer;
  XRefOffset: Int64;
  Content: AnsiString;
  MeasureBmp: TBitmap;
  PageContents: TArray<AnsiString>;
  PageImages: TArray<TPdfImageXObjectArray>;
  PageObjNos: TArray<Integer>;
  PageContentObjNos: TArray<Integer>;
  Img: TPdfImageXObject;
  UnicodeFonts: TPdfUnicodeFontResourceArray;

  procedure WriteAnsi(const S: AnsiString);
  begin
    if S <> '' then
      AStream.WriteBuffer(PAnsiChar(S)^, Length(S));
  end;

  procedure BeginObject(AObjectNo: Integer);
  begin
    Offsets[AObjectNo] := AStream.Position;
    WriteAnsi(AnsiString(IntToStr(AObjectNo) + ' 0 obj' + #10));
  end;

  procedure EndObject;
  begin
    WriteAnsi('endobj' + #10);
  end;

  function PdfNumber(AValue: Double): AnsiString;
  begin
    Result := AnsiString(StringReplace(
      FormatFloat('0.###', AValue * PDF_POINTS_PER_PIXEL),
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

  function SupportsPdfAnsiText(const S: string): Boolean;
  var
    UsedDefaultChar: BOOL;
  begin
    Result := True;
    if S = '' then
      Exit;

    UsedDefaultChar := False;
    Result := WideCharToMultiByte(
      1252,
      WC_NO_BEST_FIT_CHARS,
      PChar(S),
      Length(S),
      nil,
      0,
      nil,
      @UsedDefaultChar) > 0;
    if Result then
      Result := not UsedDefaultChar;
  end;

  procedure LogSkippedTextCommand(AText: TReportExportTextCommand; const AReason: string);
  var
    PreviewText: string;
  begin
    PreviewText := AText.Text.Replace(#13#10, ' ').Replace(#13, ' ').Replace(#10, ' ');
    if Length(PreviewText) > 80 then
      PreviewText := Copy(PreviewText, 1, 80) + '...';

    OutputDebugString(PChar(Format(
      'VectorPDF warning: skipped text command (%s) at [%d,%d,%d,%d]: "%s"',
      [AReason,
       AText.Bounds.Left,
       AText.Bounds.Top,
       AText.Bounds.Right,
       AText.Bounds.Bottom,
       PreviewText])));
  end;

  procedure LogRasterizedTextCommand(AText: TReportExportTextCommand; const AReason: string);
  var
    PreviewText: string;
  begin
    PreviewText := AText.Text.Replace(#13#10, ' ').Replace(#13, ' ').Replace(#10, ' ');
    if Length(PreviewText) > 80 then
      PreviewText := Copy(PreviewText, 1, 80) + '...';

    OutputDebugString(PChar(Format(
      'VectorPDF info: rasterized text command (%s) at [%d,%d,%d,%d]: "%s"',
      [AReason,
       AText.Bounds.Left,
       AText.Bounds.Top,
       AText.Bounds.Right,
       AText.Bounds.Bottom,
       PreviewText])));
  end;

  procedure SetMeasureFont(AText: TReportExportTextCommand);
  begin
    // NOTE: measurement uses the report's requested FontName so wrap
    // points and alignment match the GDI-rendered preview as closely as
    // possible. The PDF itself still draws with a built-in Helvetica
    // variant (see PdfFontName) until font embedding lands - see the
    // "Known limitations" note in VectorPDF_DevelopmentPlan.md.
    MeasureBmp.Canvas.Font.Name := AText.FontName;
    MeasureBmp.Canvas.Font.Size := AText.FontSize;
    MeasureBmp.Canvas.Font.Style := AText.FontStyle;
  end;

  function SanitizePdfFontName(const S: string): AnsiString;
  var
    Ch: Char;
  begin
    Result := '';
    for Ch in S do
      if CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) then
        Result := Result + AnsiChar(Ch)
      else
        Result := Result + '_';
    if Result = '' then
      Result := 'EmbeddedFont';
  end;

  function FindUnicodeFontIndex(const AFonts: TPdfUnicodeFontResourceArray;
    const AKey: string): Integer;
  begin
    for Result := 0 to High(AFonts) do
      if SameText(AFonts[Result].Key, AKey) then
        Exit;
    Result := -1;
  end;

  function UnicodeTextHex(const S: string): AnsiString;
  var
    I: Integer;
    CodeUnit: Word;
  begin
    Result := '';
    for I := 1 to Length(S) do
    begin
      CodeUnit := Ord(S[I]);
      Result := Result + AnsiString(IntToHex(CodeUnit, 4));
    end;
  end;

  procedure RegisterUnicodeGlyphInfo(var AFont: TPdfUnicodeFontResource;
    AGlyphId: Word; AWidth1000: Integer; const AUnicodeHex: AnsiString);
  var
    I: Integer;
  begin
    for I := 0 to High(AFont.UsedGlyphIds) do
      if AFont.UsedGlyphIds[I] = AGlyphId then
      begin
        AFont.Widths1000[I] := AWidth1000;
        if (AUnicodeHex <> '') and (AFont.UnicodeHexValues[I] = '') then
          AFont.UnicodeHexValues[I] := AUnicodeHex;
        Exit;
      end;

    SetLength(AFont.UsedGlyphIds, Length(AFont.UsedGlyphIds) + 1);
    SetLength(AFont.Widths1000, Length(AFont.Widths1000) + 1);
    SetLength(AFont.UnicodeHexValues, Length(AFont.UnicodeHexValues) + 1);
    AFont.UsedGlyphIds[High(AFont.UsedGlyphIds)] := AGlyphId;
    AFont.Widths1000[High(AFont.Widths1000)] := AWidth1000;
    AFont.UnicodeHexValues[High(AFont.UnicodeHexValues)] := AUnicodeHex;
  end;

  function TryGetSelectedTrueTypeFont(out AFontBytes: TBytes;
    out AOutlineMetrics: TOutlineTextmetricW): Boolean;
  var
    MetricsSize: UINT;
    MetricsBuffer: TBytes;
    Metrics: POutlineTextmetricW;
    FontDataSize: DWORD;
  begin
    Result := False;
    SetLength(AFontBytes, 0);
    FillChar(AOutlineMetrics, SizeOf(AOutlineMetrics), 0);

    SelectObject(MeasureBmp.Canvas.Handle, MeasureBmp.Canvas.Font.Handle);
    MetricsSize := GetOutlineTextMetricsW(MeasureBmp.Canvas.Handle, 0, nil);
    if MetricsSize = 0 then
      Exit;

    SetLength(MetricsBuffer, MetricsSize);
    Metrics := POutlineTextmetricW(@MetricsBuffer[0]);
    if GetOutlineTextMetricsW(MeasureBmp.Canvas.Handle, MetricsSize, Metrics) = 0 then
      Exit;
    if (Metrics.otmTextMetrics.tmPitchAndFamily and TMPF_TRUETYPE) = 0 then
      Exit;
    if (Metrics.otmfsType and $0002) <> 0 then
      Exit;

    FontDataSize := GetFontData(MeasureBmp.Canvas.Handle, 0, 0, nil, 0);
    if FontDataSize = GDI_ERROR then
      Exit;

    SetLength(AFontBytes, FontDataSize);
    if (FontDataSize > 0) and
       (GetFontData(MeasureBmp.Canvas.Handle, 0, 0, @AFontBytes[0], FontDataSize) = GDI_ERROR) then
      Exit;

    AOutlineMetrics := Metrics^;
    Result := Length(AFontBytes) > 0;
  end;

  function EnsureUnicodeFontResource(AText: TReportExportTextCommand;
    var AFonts: TPdfUnicodeFontResourceArray; out AFontIndex: Integer): Boolean;
  var
    Key: string;
    FontRes: TPdfUnicodeFontResource;
    Metrics: TOutlineTextmetricW;
    FontBytes: TBytes;
    Flags: Integer;
    FixedPitch: Boolean;
  begin
    Key := LowerCase(AText.FontName) + '|' +
      IntToStr(Ord(fsBold in AText.FontStyle)) + '|' +
      IntToStr(Ord(fsItalic in AText.FontStyle));
    AFontIndex := FindUnicodeFontIndex(AFonts, Key);
    if AFontIndex >= 0 then
      Exit(True);

    SetMeasureFont(AText);
    if not TryGetSelectedTrueTypeFont(FontBytes, Metrics) then
      Exit(False);

    FillChar(FontRes, SizeOf(FontRes), 0);
    FontRes.ResourceName := AnsiString('UF' + IntToStr(Length(AFonts) + 1));
    FontRes.Key := Key;
    FontRes.FontName := AText.FontName;
    FontRes.FontStyle := AText.FontStyle;
    FontRes.BaseFontName := SanitizePdfFontName(AText.FontName);
    if fsBold in AText.FontStyle then
      FontRes.BaseFontName := FontRes.BaseFontName + '-Bold';
    if fsItalic in AText.FontStyle then
      FontRes.BaseFontName := FontRes.BaseFontName + '-Italic';
    FontRes.EmSquare := Max(Integer(Metrics.otmEMSquare), 1);
    FontRes.Ascent := MulDiv(Integer(Metrics.otmAscent), 1000, FontRes.EmSquare);
    FontRes.Descent := -MulDiv(Integer(Metrics.otmDescent), 1000, FontRes.EmSquare);
    FontRes.CapHeight := MulDiv(Integer(Metrics.otmsCapEmHeight), 1000, FontRes.EmSquare);
    if FontRes.CapHeight = 0 then
      FontRes.CapHeight := FontRes.Ascent;
    FontRes.FontBBoxLeft := MulDiv(Metrics.otmrcFontBox.Left, 1000, FontRes.EmSquare);
    FontRes.FontBBoxBottom := MulDiv(Metrics.otmrcFontBox.Top, -1000, FontRes.EmSquare);
    FontRes.FontBBoxRight := MulDiv(Metrics.otmrcFontBox.Right, 1000, FontRes.EmSquare);
    FontRes.FontBBoxTop := MulDiv(Metrics.otmrcFontBox.Bottom, -1000, FontRes.EmSquare);
    FontRes.ItalicAngle := 0;
    if fsItalic in AText.FontStyle then
      FontRes.ItalicAngle := -12;
    FixedPitch := (Metrics.otmTextMetrics.tmPitchAndFamily and TMPF_FIXED_PITCH) = 0;
    Flags := 32;
    if FixedPitch then
      Flags := Flags or 1;
    if fsItalic in AText.FontStyle then
      Flags := Flags or 64;
    FontRes.Flags := Flags;
    FontRes.FontFileBytes := FontBytes;

    SetLength(AFonts, Length(AFonts) + 1);
    AFonts[High(AFonts)] := FontRes;
    AFontIndex := High(AFonts);
    Result := True;
  end;

  function TryShapeUnicodeTextLine(AText: TReportExportTextCommand;
    const ALineText: string; var AFonts: TPdfUnicodeFontResourceArray;
    out AFontResourceName: AnsiString; out AGlyphs: TPdfShapedGlyphArray;
    out ALineWidthPx: Integer): Boolean;
  const
    E_OUTOFMEMORY_HRESULT = HRESULT($8007000E);
  var
    FontIndex: Integer;
    ItemCount: Integer;
    Items: TArray<TScriptItem>;
    ItemIndex: Integer;
    RunStart: Integer;
    RunLength: Integer;
    ScriptCache: TScriptCache;
    GlyphCapacity: Integer;
    GlyphCount: Integer;
    GlyphIds: TArray<Word>;
    LogClusters: TArray<Word>;
    VisAttrs: TArray<TScriptVisAttr>;
    Advances: TArray<Integer>;
    Offsets: TArray<TGOffset>;
    RunGlyphsStart: Integer;
    GlyphIndex: Integer;
    CharIndex: Integer;
    ClusterStartGlyph: Integer;
    ClusterEndGlyph: Integer;
    ClusterCharCount: Integer;
    ABC: TABC;
    HR: HRESULT;
    Width1000: Integer;
  begin
    Result := False;
    AFontResourceName := '';
    SetLength(AGlyphs, 0);
    ALineWidthPx := 0;
    if ALineText = '' then
      Exit;
    if not EnsureUnicodeFontResource(AText, AFonts, FontIndex) then
      Exit;

    SetMeasureFont(AText);
    SelectObject(MeasureBmp.Canvas.Handle, MeasureBmp.Canvas.Font.Handle);

    SetLength(Items, Length(ALineText) + 1);
    ItemCount := 0;
    HR := ScriptItemize(PWideChar(ALineText), Length(ALineText), Length(Items),
      nil, nil, @Items[0], @ItemCount);
    if HR <> S_OK then
      Exit;

    ScriptCache := nil;
    try
      for ItemIndex := 0 to ItemCount - 1 do
      begin
        if (Items[ItemIndex].a.Flags and SCRIPT_ANALYSIS_RTL) <> 0 then
          Exit(False);

        RunStart := Items[ItemIndex].iCharPos;
        RunLength := Items[ItemIndex + 1].iCharPos - RunStart;
        if RunLength <= 0 then
          Continue;

        GlyphCapacity := Max(16, RunLength * 3 + 16);
        repeat
          SetLength(GlyphIds, GlyphCapacity);
          SetLength(LogClusters, RunLength);
          SetLength(VisAttrs, GlyphCapacity);
          GlyphCount := 0;
          HR := ScriptShape(
            MeasureBmp.Canvas.Handle,
            ScriptCache,
            PWideChar(ALineText) + RunStart,
            RunLength,
            GlyphCapacity,
            @Items[ItemIndex].a,
            @GlyphIds[0],
            @LogClusters[0],
            @VisAttrs[0],
            @GlyphCount);
          if HR = E_OUTOFMEMORY_HRESULT then
            GlyphCapacity := GlyphCapacity * 2;
        until HR <> E_OUTOFMEMORY_HRESULT;

        if (HR <> S_OK) or (GlyphCount <= 0) then
          Exit;

        SetLength(Advances, GlyphCount);
        SetLength(Offsets, GlyphCount);
        HR := ScriptPlace(
          MeasureBmp.Canvas.Handle,
          ScriptCache,
          @GlyphIds[0],
          GlyphCount,
          @VisAttrs[0],
          @Items[ItemIndex].a,
          @Advances[0],
          @Offsets[0],
          @ABC);
        if HR <> S_OK then
          Exit;

        RunGlyphsStart := Length(AGlyphs);
        SetLength(AGlyphs, RunGlyphsStart + GlyphCount);
        for GlyphIndex := 0 to GlyphCount - 1 do
        begin
          if GlyphIds[GlyphIndex] = 0 then
            Exit(False);

          Width1000 := MulDiv(Advances[GlyphIndex], 1000, Max(AText.FontSize, 1));
          RegisterUnicodeGlyphInfo(AFonts[FontIndex], GlyphIds[GlyphIndex], Width1000, '');

          AGlyphs[RunGlyphsStart + GlyphIndex].GlyphId := GlyphIds[GlyphIndex];
          AGlyphs[RunGlyphsStart + GlyphIndex].AdvancePx := Advances[GlyphIndex];
          AGlyphs[RunGlyphsStart + GlyphIndex].OffsetXPx := Offsets[GlyphIndex].du;
          AGlyphs[RunGlyphsStart + GlyphIndex].OffsetYPx := Offsets[GlyphIndex].dv;
          Inc(ALineWidthPx, Advances[GlyphIndex]);
        end;

        CharIndex := 0;
        while CharIndex < RunLength do
        begin
          ClusterStartGlyph := LogClusters[CharIndex];
          ClusterCharCount := 1;
          while (CharIndex + ClusterCharCount < RunLength) and
                (LogClusters[CharIndex + ClusterCharCount] = ClusterStartGlyph) do
            Inc(ClusterCharCount);

          ClusterEndGlyph := GlyphCount;
          for GlyphIndex := CharIndex + ClusterCharCount to RunLength - 1 do
            if LogClusters[GlyphIndex] <> ClusterStartGlyph then
            begin
              ClusterEndGlyph := LogClusters[GlyphIndex];
              Break;
            end;

          if (ClusterCharCount = 1) and ((ClusterEndGlyph - ClusterStartGlyph) = 1) then
            RegisterUnicodeGlyphInfo(
              AFonts[FontIndex],
              GlyphIds[ClusterStartGlyph],
              MulDiv(Advances[ClusterStartGlyph], 1000, Max(AText.FontSize, 1)),
              UnicodeTextHex(Copy(ALineText, RunStart + CharIndex + 1, 1)));

          Inc(CharIndex, ClusterCharCount);
        end;
      end;
    finally
      ScriptFreeCache(ScriptCache);
    end;

    AFontResourceName := AFonts[FontIndex].ResourceName;
    Result := Length(AGlyphs) > 0;
  end;

  // Greedy word-wrap using real font metrics. Hard line breaks in the
  // source text are preserved; a single word wider than AText.Bounds.Width
  // is not mid-word split (documented limitation, same as most simple
  // word-wrap implementations).
  function WrapTextLines(AText: TReportExportTextCommand): TArray<string>;
  var
    Paragraphs: TArray<string>;
    Para: string;
    Words: TArray<string>;
    Line, TestLine, W: string;
    MaxWidth: Integer;
    Lines: TStringList;
    LineIdx: Integer;
  begin
    if (not AText.WordWrap) or (AText.Bounds.Width <= 0) then
    begin
      SetLength(Result, 1);
      Result[0] := AText.Text;
      Exit;
    end;

    SetMeasureFont(AText);
    MaxWidth := AText.Bounds.Width;

    Lines := TStringList.Create;
    try
      Paragraphs := AText.Text.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
      for Para in Paragraphs do
      begin
        Words := Para.Split([' ']);
        Line := '';
        for W in Words do
        begin
          if Line = '' then
            TestLine := W
          else
            TestLine := Line + ' ' + W;

          if (MeasureBmp.Canvas.TextWidth(TestLine) > MaxWidth) and (Line <> '') then
          begin
            Lines.Add(Line);
            Line := W;
          end
          else
            Line := TestLine;
        end;
        Lines.Add(Line);
      end;

      SetLength(Result, Lines.Count);
      for LineIdx := 0 to Lines.Count - 1 do
        Result[LineIdx] := Lines[LineIdx];
    finally
      Lines.Free;
    end;
  end;

  function PdfTextX(AText: TReportExportTextCommand; const ALineText: string): Double;
  var
    LineWidth: Integer;
  begin
    Result := AText.Bounds.Left;
    if AText.HAlign = taLeftJustify then
      Exit;

    SetMeasureFont(AText);
    LineWidth := MeasureBmp.Canvas.TextWidth(ALineText);

    case AText.HAlign of
      taRightJustify:
        Result := AText.Bounds.Right - LineWidth;
      taCenter:
        Result := AText.Bounds.Left + ((AText.Bounds.Width - LineWidth) / 2);
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

  // Loads a JPEG file as a to-be-embedded Image XObject. Baseline JPEG
  // bytes can be embedded as-is under /DCTDecode; progressive or CMYK
  // JPEGs are a known pre-existing limitation, unchanged by this pass.
  function TryLoadJPEGXObject(AImage: TReportExportImageCommand;
    const AName: AnsiString; out AXObject: TPdfImageXObject): Boolean;
  var
    JPEG: TJPEGImage;
  begin
    Result := False;
    if (AImage.Source = '') or not FileExists(AImage.Source) or
       not IsJPEGFile(AImage.Source) then
      Exit;

    JPEG := TJPEGImage.Create;
    try
      JPEG.LoadFromFile(AImage.Source);
      if (JPEG.Width <= 0) or (JPEG.Height <= 0) then
        Exit;

       AXObject.Name := AName;
       AXObject.Width := JPEG.Width;
       AXObject.Height := JPEG.Height;
       AXObject.ColorSpace := '/DeviceRGB';
       AXObject.BitsPerComponent := 8;
       AXObject.Filter := '/DCTDecode';
       AXObject.Bytes := TFile.ReadAllBytes(AImage.Source);
       AXObject.SMaskName := '';
       AXObject.SMaskObjectNo := 0;
       SetLength(AXObject.SMaskBytes, 0);
       Result := Length(AXObject.Bytes) > 0;
    finally
      JPEG.Free;
    end;
  end;

  // Builds a white-flattened raw-RGB FlateDecode Image XObject from any
  // VCL graphic, using the shared pf24bit ScanLine pixel extraction also
  // used by the PNG loader (no alpha/SMask support, consistent with it).
  function BuildFlateRGBXObject(const AGraphic: TGraphic;
    const AName: AnsiString; out AXObject: TPdfImageXObject): Boolean;
  var
    Bitmap: TBitmap;
    RawBytes: TBytes;
    Row: PByteArray;
    X, Y, Offset, W, H: Integer;
  begin
    Result := False;
    if not Assigned(AGraphic) or (AGraphic.Width <= 0) or
       (AGraphic.Height <= 0) then
      Exit;

    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf24bit;
      Bitmap.SetSize(AGraphic.Width, AGraphic.Height);
      W := Bitmap.Width;
      H := Bitmap.Height;
      Bitmap.Canvas.Brush.Color := clWhite;
      Bitmap.Canvas.FillRect(Rect(0, 0, W, H));
      Bitmap.Canvas.Draw(0, 0, AGraphic);

      SetLength(RawBytes, W * H * 3);
      Offset := 0;
      for Y := 0 to H - 1 do
      begin
        Row := PByteArray(Bitmap.ScanLine[Y]);
        for X := 0 to W - 1 do
        begin
          // pf24bit ScanLine rows are packed BGR; PDF /DeviceRGB wants RGB.
          RawBytes[Offset]     := Row[X * 3 + 2]; // R
          RawBytes[Offset + 1] := Row[X * 3 + 1]; // G
          RawBytes[Offset + 2] := Row[X * 3];     // B
          Inc(Offset, 3);
        end;
      end;
    finally
      Bitmap.Free;
    end;

    AXObject.Name := AName;
    AXObject.Width := W;
    AXObject.Height := H;
    AXObject.ColorSpace := '/DeviceRGB';
    AXObject.BitsPerComponent := 8;
    AXObject.Filter := '/FlateDecode';
    AXObject.Bytes := CompressBytes(RawBytes);
    AXObject.SMaskName := '';
    AXObject.SMaskObjectNo := 0;
    SetLength(AXObject.SMaskBytes, 0);
    Result := Length(AXObject.Bytes) > 0;
  end;

  // Loads a PNG file, flattens it onto white (no alpha channel support
  // yet, unchanged from the previous implementation), and stores it as a
  // FlateDecode raw-RGB Image XObject. Uses ScanLine instead of
  // Canvas.Pixels for the per-pixel copy - the old per-pixel GDI round
  // trip was a real performance problem on large images.
  function TryLoadPNGXObject(AImage: TReportExportImageCommand;
    const AName: AnsiString; out AXObject: TPdfImageXObject): Boolean;
  var
    PNG: TPngImage;
  begin
    Result := False;
    if (AImage.Source = '') or not FileExists(AImage.Source) or
       not IsPNGFile(AImage.Source) then
      Exit;

    PNG := TPngImage.Create;
    try
      PNG.LoadFromFile(AImage.Source);
      Result := BuildFlateRGBXObject(PNG, AName, AXObject);
    finally
      PNG.Free;
    end;
  end;

  // Loads a BMP or GIF file and stores it as the same white-flattened
  // FlateDecode raw-RGB Image XObject used for PNG (first GIF frame for
  // animated files).  These formats render in preview/print/HTML but had
  // no VectorPDF representation and were silently skipped; this keeps the
  // fix VectorPDF-local and leaves the command model format-neutral.
  // Any decode failure returns False so the caller's graceful-skip
  // behavior is preserved.
  function TryLoadRasterFileXObject(AImage: TReportExportImageCommand;
    const AName: AnsiString; out AXObject: TPdfImageXObject): Boolean;
  var
    Ext: string;
    G: TGraphic;
  begin
    Result := False;
    if (AImage.Source = '') or not FileExists(AImage.Source) then
      Exit;
    Ext := LowerCase(ExtractFileExt(AImage.Source));
    if (Ext <> '.bmp') and (Ext <> '.gif') then
      Exit;

    if Ext = '.bmp' then
      G := TBitmap.Create
    else
      G := TGIFImage.Create;
    try
      try
        G.LoadFromFile(AImage.Source);
      except
        Exit; // malformed/unreadable image: graceful skip
      end;
      Result := BuildFlateRGBXObject(G, AName, AXObject);
    finally
      G.Free;
    end;
  end;

  function TryBuildRasterTextXObject(
    AText: TReportExportTextCommand;
    const ALineText: string;
    const AName: AnsiString;
    out AXObject: TPdfImageXObject;
    out AWidthPx: Integer;
    out AHeightPx: Integer): Boolean;
  var
    Bitmap: TBitmap;
    ColorBytes: TBytes;
    AlphaBytes: TBytes;
    Row: PByteArray;
    X, Y, ColorOffset, AlphaOffset: Integer;
    TextHeightPx: Integer;
    FontRGB: LongInt;
    AlphaValue: Byte;
  begin
    Result := False;
    AWidthPx := 0;
    AHeightPx := 0;
    if ALineText = '' then
      Exit;

    SetMeasureFont(AText);
    AWidthPx := MeasureBmp.Canvas.TextWidth(ALineText);
    TextHeightPx := MeasureBmp.Canvas.TextHeight('Ag');
    if AWidthPx <= 0 then
      Exit;
    if TextHeightPx <= 0 then
      TextHeightPx := System.Math.Max(AText.FontSize + 2, 1);
    AHeightPx := TextHeightPx;

    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf24bit;
      Bitmap.SetSize(AWidthPx, AHeightPx);
      Bitmap.Canvas.Brush.Color := clBlack;
      Bitmap.Canvas.FillRect(Rect(0, 0, AWidthPx, AHeightPx));
      Bitmap.Canvas.Font.Assign(MeasureBmp.Canvas.Font);
      Bitmap.Canvas.Font.Color := clWhite;
      Bitmap.Canvas.TextOut(0, 0, ALineText);

      FontRGB := ColorToRGB(AText.FontColor);
      SetLength(ColorBytes, AWidthPx * AHeightPx * 3);
      SetLength(AlphaBytes, AWidthPx * AHeightPx);
      ColorOffset := 0;
      AlphaOffset := 0;
      for Y := 0 to AHeightPx - 1 do
      begin
        Row := PByteArray(Bitmap.ScanLine[Y]);
        for X := 0 to AWidthPx - 1 do
        begin
          AlphaValue := Max(Row[X * 3], Max(Row[X * 3 + 1], Row[X * 3 + 2]));
          ColorBytes[ColorOffset] := GetRValue(FontRGB);
          ColorBytes[ColorOffset + 1] := GetGValue(FontRGB);
          ColorBytes[ColorOffset + 2] := GetBValue(FontRGB);
          AlphaBytes[AlphaOffset] := AlphaValue;
          Inc(ColorOffset, 3);
          Inc(AlphaOffset);
        end;
      end;
    finally
      Bitmap.Free;
    end;

    AXObject.Name := AName;
    AXObject.Width := AWidthPx;
    AXObject.Height := AHeightPx;
    AXObject.ColorSpace := '/DeviceRGB';
    AXObject.BitsPerComponent := 8;
    AXObject.Filter := '/FlateDecode';
    AXObject.Bytes := CompressBytes(ColorBytes);
    AXObject.SMaskName := AName + 'Mask';
    AXObject.SMaskObjectNo := 0;
    AXObject.SMaskBytes := CompressBytes(AlphaBytes);
    Result := (Length(AXObject.Bytes) > 0) and (Length(AXObject.SMaskBytes) > 0);
  end;

  // Builds the page content stream text and, as a side effect, appends any
  // successfully-loaded images to AImages (object numbers are assigned
  // later, once every page's image list is known).
  function BuildPageContent(APage: TReportExportPage;
    var AImages: TPdfImageXObjectArray;
    var AUnicodeFonts: TPdfUnicodeFontResourceArray): AnsiString;
  var
    Command: TReportExportCommand;
    TextCmd: TReportExportTextCommand;
    ImageCmd: TReportExportImageCommand;
    LineCmd: TReportExportLineCommand;
    RectCmd: TReportExportRectangleCommand;
    FillCmd: TReportExportFillRectangleCommand;
    EllipseCmd: TReportExportEllipseCommand;
    R: TRect;
    Lines: TArray<string>;
    LineIndex: Integer;
    LineHeightPx: Integer;
    LineY: Integer;
    LineX: Double;
    ImageName: AnsiString;
    XObject: TPdfImageXObject;
    RasterWidthPx: Integer;
    RasterHeightPx: Integer;
    ShapedGlyphs: TPdfShapedGlyphArray;
    UnicodeFontName: AnsiString;
    ShapedLineWidthPx: Integer;
    Glyph: TPdfShapedGlyph;
    CursorXPx: Integer;
    GlyphX: Double;
    GlyphY: Integer;
    GlyphHex: AnsiString;
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
            Lines := WrapTextLines(TextCmd);
            LineHeightPx := Round(TextCmd.FontSize * 1.2);

            if SupportsPdfAnsiText(TextCmd.Text) then
            begin
              Result := Result +
                'q' + #10 +
                PdfColor(TextCmd.FontColor) + ' rg' + #10 +
                PdfFontName(TextCmd) + ' ' + PdfNumber(TextCmd.FontSize) + ' Tf' + #10;

              for LineIndex := 0 to High(Lines) do
              begin
                LineY := TextCmd.Bounds.Top + TextCmd.FontSize + (LineIndex * LineHeightPx);
                Result := Result +
                  'BT' + #10 +
                  PdfNumber(PdfTextX(TextCmd, Lines[LineIndex])) + ' ' +
                  PdfNumber(PdfY(APage, LineY)) + ' Td' + #10 +
                  '(' + PdfText(Lines[LineIndex]) + ') Tj' + #10 +
                  'ET' + #10;
              end;

              Result := Result + 'Q' + #10;
            end
            else
            begin
              for LineIndex := 0 to High(Lines) do
              begin
                if Lines[LineIndex] = '' then
                  Continue;

                if TryShapeUnicodeTextLine(
                     TextCmd,
                     Lines[LineIndex],
                     AUnicodeFonts,
                     UnicodeFontName,
                     ShapedGlyphs,
                     ShapedLineWidthPx) then
                begin
                  Result := Result +
                    'q' + #10 +
                    PdfColor(TextCmd.FontColor) + ' rg' + #10;

                  LineX := TextCmd.Bounds.Left;
                  if TextCmd.HAlign <> taLeftJustify then
                  begin
                    case TextCmd.HAlign of
                      taRightJustify:
                        LineX := TextCmd.Bounds.Right - ShapedLineWidthPx;
                      taCenter:
                        LineX := TextCmd.Bounds.Left +
                          ((TextCmd.Bounds.Width - ShapedLineWidthPx) / 2);
                    end;
                    if LineX < TextCmd.Bounds.Left then
                      LineX := TextCmd.Bounds.Left;
                  end;

                  LineY := TextCmd.Bounds.Top + TextCmd.FontSize + (LineIndex * LineHeightPx);
                  CursorXPx := 0;
                  for Glyph in ShapedGlyphs do
                  begin
                    GlyphX := LineX + CursorXPx + Glyph.OffsetXPx;
                    GlyphY := LineY + Glyph.OffsetYPx;
                    GlyphHex := AnsiString(IntToHex(Glyph.GlyphId, 4));
                    Result := Result +
                      'BT' + #10 +
                      '/' + UnicodeFontName + ' ' + PdfNumber(TextCmd.FontSize) + ' Tf' + #10 +
                      '1 0 0 1 ' + PdfNumber(GlyphX) + ' ' +
                      PdfNumber(PdfY(APage, GlyphY)) + ' Tm' + #10 +
                      '<' + GlyphHex + '> Tj' + #10 +
                      'ET' + #10;
                    Inc(CursorXPx, Glyph.AdvancePx);
                  end;
                  Result := Result + 'Q' + #10;
                end
                else
                begin
                  // Fallback path for fonts/scripts that cannot be shaped or
                  // embedded safely on the current machine.
                  LogRasterizedTextCommand(TextCmd, 'non-Latin-1 fallback');
                  ImageName := AnsiString('Im' + IntToStr(Length(AImages) + 1));
                  if TryBuildRasterTextXObject(
                       TextCmd,
                       Lines[LineIndex],
                       ImageName,
                       XObject,
                       RasterWidthPx,
                       RasterHeightPx) then
                  begin
                    SetLength(AImages, Length(AImages) + 1);
                    AImages[High(AImages)] := XObject;

                    LineX := PdfTextX(TextCmd, Lines[LineIndex]);
                    LineY := TextCmd.Bounds.Top + (LineIndex * LineHeightPx);
                    Result := Result +
                      'q' + #10 +
                      PdfNumber(RasterWidthPx) + ' 0 0 ' +
                      PdfNumber(RasterHeightPx) + ' ' +
                      PdfNumber(LineX) + ' ' +
                      PdfNumber(PdfY(APage, LineY + RasterHeightPx)) + ' cm' + #10 +
                      '/' + ImageName + ' Do' + #10 +
                      'Q' + #10;
                  end
                  else
                  begin
                    LogSkippedTextCommand(TextCmd, 'failed to rasterize non-Latin-1 text');
                  end;
                end;
              end;
            end;
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

        eckEllipse:
        begin
          EllipseCmd := TReportExportEllipseCommand(Command);
          R := EllipseCmd.Bounds;
          // Approximate the ellipse with four cubic Bezier arcs (kappa =
          // 0.55228475) so the output stays vector content.
          var Kappa: Double := 0.5522847498;
          var ECx := R.Left + R.Width / 2;
          var ECy := PdfY(APage, R.Top + R.Height div 2);
          var ERx := R.Width / 2;
          var ERy := R.Height / 2;
          var Kx := ERx * Kappa;
          var Ky := ERy * Kappa;
          // Ellipse anchor points in PDF coordinates (Y grows upward).
          var EE := PdfNumber(ECx + ERx) + ' ' + PdfNumber(ECy);          // right
          var EN := PdfNumber(ECx) + ' ' + PdfNumber(ECy + ERy);          // top
          var EW := PdfNumber(ECx - ERx) + ' ' + PdfNumber(ECy);          // left
          var ES := PdfNumber(ECx) + ' ' + PdfNumber(ECy - ERy);          // bottom
          Result := Result + 'q' + #10;
          if EllipseCmd.HasBorder then
            Result := Result +
              PdfColor(EllipseCmd.BorderColor) + ' RG' + #10 +
              PdfNumber(EllipseCmd.BorderWidth) + ' w' + #10;
          if EllipseCmd.HasFill then
            Result := Result + PdfColor(EllipseCmd.FillColor) + ' rg' + #10;
          Result := Result +
            'm ' + EE + #10 +
            'c ' + EE + ' ' + PdfNumber(ECx + ERx) + ' ' + PdfNumber(ECy + Ky) + ' ' + EN + #10 +
            'c ' + PdfNumber(ECx + Kx) + ' ' + PdfNumber(ECy + ERy) + ' ' + EW + ' ' + EN + #10 +
            'c ' + EW + ' ' + PdfNumber(ECx - Kx) + ' ' + PdfNumber(ECy - Ky) + ' ' + ES + #10 +
            'c ' + PdfNumber(ECx - Kx) + ' ' + PdfNumber(ECy - ERy) + ' ' + EE + ' ' + ES + #10 +
            'h' + #10;
          if EllipseCmd.HasFill and EllipseCmd.HasBorder then
            Result := Result + 'B' + #10
          else if EllipseCmd.HasFill then
            Result := Result + 'f' + #10
          else
            Result := Result + 'S' + #10;
          Result := Result + 'Q' + #10;
        end;

        eckImage:
        begin
          ImageCmd := TReportExportImageCommand(Command);
          ImageName := AnsiString('Im' + IntToStr(Length(AImages) + 1));

          if TryLoadJPEGXObject(ImageCmd, ImageName, XObject) or
             TryLoadPNGXObject(ImageCmd, ImageName, XObject) or
             TryLoadRasterFileXObject(ImageCmd, ImageName, XObject) then
          begin
            SetLength(AImages, Length(AImages) + 1);
            AImages[High(AImages)] := XObject;

            Result := Result +
              'q' + #10 +
              PdfNumber(ImageCmd.Bounds.Width) + ' 0 0 ' +
              PdfNumber(ImageCmd.Bounds.Height) + ' ' +
              PdfNumber(ImageCmd.Bounds.Left) + ' ' +
              PdfNumber(PdfY(APage, ImageCmd.Bounds.Bottom)) + ' cm' + #10 +
              '/' + ImageName + ' Do' + #10 +
              'Q' + #10;
          end
          else if LowerCase(ExtractFileExt(ImageCmd.Source)) = '.svg' then
          begin
            var SVGPdfCommands: AnsiString;
            if TryDrawSVGToPDFCommands(ImageCmd, APage.Height, SVGPdfCommands) then
              Result := Result + SVGPdfCommands;
          end
          else if (LowerCase(ExtractFileExt(ImageCmd.Source)) = '.emf') or (LowerCase(ExtractFileExt(ImageCmd.Source)) = '.wmf') then
          begin
            var EMFPdfCommands: AnsiString;
            if TryDrawEMFToPDFCommands(ImageCmd, APage.Height, EMFPdfCommands) then
              Result := Result + EMFPdfCommands;
          end;
          // Unsupported/missing image sources are skipped: text, line,
          // shape, and other image output must not be affected (per
          // VectorPDF_DevelopmentPlan.md M5 "fail gracefully" rule).
        end;
      end;
    end;
  end;

  function BuildUnicodeFontWidths(const AFont: TPdfUnicodeFontResource): AnsiString;
  var
    GlyphIds: TArray<Word>;
    Widths: TArray<Integer>;
    I: Integer;
    J: Integer;
    TempGlyph: Word;
    TempWidth: Integer;
  begin
    Result := '[';
    GlyphIds := Copy(AFont.UsedGlyphIds);
    Widths := Copy(AFont.Widths1000);
    for I := 0 to High(GlyphIds) - 1 do
      for J := I + 1 to High(GlyphIds) do
        if GlyphIds[J] < GlyphIds[I] then
        begin
          TempGlyph := GlyphIds[I];
          GlyphIds[I] := GlyphIds[J];
          GlyphIds[J] := TempGlyph;
          TempWidth := Widths[I];
          Widths[I] := Widths[J];
          Widths[J] := TempWidth;
        end;

    for I := 0 to High(GlyphIds) do
      Result := Result +
        AnsiString(IntToStr(GlyphIds[I]) + ' [' + IntToStr(Widths[I]) + '] ');
    Result := Result + ']';
  end;

  function BuildIdentityCIDToGIDMap(const AFont: TPdfUnicodeFontResource): TBytes;
  var
    MaxGlyphId: Integer;
    I: Integer;
  begin
    MaxGlyphId := 0;
    for I := 0 to High(AFont.UsedGlyphIds) do
      if AFont.UsedGlyphIds[I] > MaxGlyphId then
        MaxGlyphId := AFont.UsedGlyphIds[I];

    SetLength(Result, (MaxGlyphId + 1) * 2);
    for I := 0 to MaxGlyphId do
    begin
      Result[I * 2] := Byte((I shr 8) and $FF);
      Result[I * 2 + 1] := Byte(I and $FF);
    end;
  end;

  function BuildToUnicodeCMap(const AFont: TPdfUnicodeFontResource): AnsiString;
  var
    I: Integer;
    EntryCount: Integer;
  begin
    EntryCount := 0;
    for I := 0 to High(AFont.UsedGlyphIds) do
      if AFont.UnicodeHexValues[I] <> '' then
        Inc(EntryCount);

    Result :=
      '/CIDInit /ProcSet findresource begin' + #10 +
      '12 dict begin' + #10 +
      'begincmap' + #10 +
      '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def' + #10 +
      '/CMapName /' + AFont.BaseFontName + '-ToUnicode def' + #10 +
      '/CMapType 2 def' + #10 +
      '1 begincodespacerange' + #10 +
      '<0000> <FFFF>' + #10 +
      'endcodespacerange' + #10 +
      AnsiString(IntToStr(EntryCount)) + ' beginbfchar' + #10;

    for I := 0 to High(AFont.UsedGlyphIds) do
      if AFont.UnicodeHexValues[I] <> '' then
        Result := Result + '<' + AnsiString(IntToHex(AFont.UsedGlyphIds[I], 4)) +
          '> <' + AFont.UnicodeHexValues[I] + '>' + #10;

    Result := Result +
      'endbfchar' + #10 +
      'endcmap' + #10 +
      'CMapName currentdict /CMap defineresource pop' + #10 +
      'end' + #10 +
      'end';
  end;

begin
  if not Assigned(ADocument) then
    raise EArgumentNilException.Create('ADocument');
  if not Assigned(AStream) then
    raise EArgumentNilException.Create('AStream');

  MeasureBmp := TBitmap.Create;
  try
    SetLength(PageContents, ADocument.Pages.Count);
    SetLength(PageImages, ADocument.Pages.Count);
    SetLength(PageObjNos, ADocument.Pages.Count);
    SetLength(PageContentObjNos, ADocument.Pages.Count);

    // Pass 1: build each page's content stream and image list. Image
    // object numbers are not yet known here.
    for PageIndex := 0 to ADocument.Pages.Count - 1 do
      PageContents[PageIndex] :=
        BuildPageContent(ADocument.Pages[PageIndex], PageImages[PageIndex], UnicodeFonts);

    // Pass 2: assign object numbers now that every page's image count is
    // known. Object 1 = Catalog, Object 2 = Pages; page/content/image
    // objects follow sequentially, page by page.
    NextObjNo := 3;
    for PageIndex := 0 to ADocument.Pages.Count - 1 do
    begin
      PageObjNos[PageIndex] := NextObjNo;
      Inc(NextObjNo);
      PageContentObjNos[PageIndex] := NextObjNo;
      Inc(NextObjNo);

      for I := 0 to High(PageImages[PageIndex]) do
      begin
        PageImages[PageIndex][I].ObjectNo := NextObjNo;
        Inc(NextObjNo);
        if Length(PageImages[PageIndex][I].SMaskBytes) > 0 then
        begin
          PageImages[PageIndex][I].SMaskObjectNo := NextObjNo;
          Inc(NextObjNo);
        end;
      end;
    end;

    for I := 0 to High(UnicodeFonts) do
    begin
      UnicodeFonts[I].Type0ObjectNo := NextObjNo;
      Inc(NextObjNo);
      UnicodeFonts[I].CIDFontObjectNo := NextObjNo;
      Inc(NextObjNo);
      UnicodeFonts[I].DescriptorObjectNo := NextObjNo;
      Inc(NextObjNo);
      UnicodeFonts[I].FontFileObjectNo := NextObjNo;
      Inc(NextObjNo);
      UnicodeFonts[I].CIDToGIDMapObjectNo := NextObjNo;
      Inc(NextObjNo);
      UnicodeFonts[I].ToUnicodeObjectNo := NextObjNo;
      Inc(NextObjNo);
    end;

    ObjectCount := NextObjNo - 1;
    SetLength(Offsets, ObjectCount + 1);

    // Pass 3: write the file.
    WriteAnsi('%PDF-1.4' + #10);

    BeginObject(1);
    WriteAnsi('<< /Type /Catalog /Pages 2 0 R >>' + #10);
    EndObject;

    BeginObject(2);
    WriteAnsi('<< /Type /Pages /Count ' +
      AnsiString(IntToStr(ADocument.Pages.Count)) + ' /Kids [');
    for PageIndex := 0 to ADocument.Pages.Count - 1 do
      WriteAnsi(AnsiString(IntToStr(PageObjNos[PageIndex]) + ' 0 R '));
    WriteAnsi('] >>' + #10);
    EndObject;

    for PageIndex := 0 to ADocument.Pages.Count - 1 do
    begin
      BeginObject(PageObjNos[PageIndex]);
      WriteAnsi('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' +
        PdfNumber(ADocument.Pages[PageIndex].Width) + ' ' +
        PdfNumber(ADocument.Pages[PageIndex].Height) +
        '] /Resources << /Font << ' +
        '/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> ' +
        '/F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> ' +
        '/F3 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >> ' +
        '/F4 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-BoldOblique >> ' +
        '>>');
      for I := 0 to High(UnicodeFonts) do
        WriteAnsi(' /' + UnicodeFonts[I].ResourceName + ' ' +
          AnsiString(IntToStr(UnicodeFonts[I].Type0ObjectNo)) + ' 0 R');
      WriteAnsi(' >>');

      if Length(PageImages[PageIndex]) > 0 then
      begin
        WriteAnsi(' /XObject <<');
        for I := 0 to High(PageImages[PageIndex]) do
          WriteAnsi(' /' + PageImages[PageIndex][I].Name + ' ' +
            AnsiString(IntToStr(PageImages[PageIndex][I].ObjectNo)) + ' 0 R');
        WriteAnsi(' >>');
      end;

      WriteAnsi(' >> /Contents ' +
        AnsiString(IntToStr(PageContentObjNos[PageIndex])) + ' 0 R >>' + #10);
      EndObject;

      BeginObject(PageContentObjNos[PageIndex]);
      Content := PageContents[PageIndex];
      WriteAnsi(AnsiString('<< /Length ' + IntToStr(Length(Content)) + ' >>' + #10));
      WriteAnsi('stream' + #10);
      WriteAnsi(Content);
      WriteAnsi('endstream' + #10);
      EndObject;

      for I := 0 to High(PageImages[PageIndex]) do
      begin
        Img := PageImages[PageIndex][I];
        BeginObject(Img.ObjectNo);
        WriteAnsi(AnsiString(
          '<< /Type /XObject /Subtype /Image /Width ' + IntToStr(Img.Width) +
          ' /Height ' + IntToStr(Img.Height) +
          ' /ColorSpace ' + string(Img.ColorSpace) +
          ' /BitsPerComponent ' + IntToStr(Img.BitsPerComponent) +
          ' /Filter ') +
          Img.Filter +
          AnsiString(' /Length ' + IntToStr(Length(Img.Bytes))));
        if Img.SMaskObjectNo > 0 then
          WriteAnsi(AnsiString(' /SMask ' + IntToStr(Img.SMaskObjectNo) + ' 0 R'));
        WriteAnsi(' >>' + #10);
        WriteAnsi('stream' + #10);
        WriteAnsi(BytesToAnsiString(Img.Bytes));
        WriteAnsi(#10 + 'endstream' + #10);
        EndObject;

        if Img.SMaskObjectNo > 0 then
        begin
          BeginObject(Img.SMaskObjectNo);
          WriteAnsi(AnsiString(
            '<< /Type /XObject /Subtype /Image /Width ' + IntToStr(Img.Width) +
            ' /Height ' + IntToStr(Img.Height) +
            ' /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter ') +
            Img.Filter +
            AnsiString(' /Length ' + IntToStr(Length(Img.SMaskBytes)) + ' >>' + #10));
          WriteAnsi('stream' + #10);
          WriteAnsi(BytesToAnsiString(Img.SMaskBytes));
          WriteAnsi(#10 + 'endstream' + #10);
          EndObject;
        end;
      end;
    end;

    for I := 0 to High(UnicodeFonts) do
    begin
      BeginObject(UnicodeFonts[I].Type0ObjectNo);
      WriteAnsi('<< /Type /Font /Subtype /Type0 /BaseFont /' +
        UnicodeFonts[I].BaseFontName +
        ' /Encoding /Identity-H /DescendantFonts [' +
        AnsiString(IntToStr(UnicodeFonts[I].CIDFontObjectNo)) + ' 0 R]' +
        ' /ToUnicode ' + AnsiString(IntToStr(UnicodeFonts[I].ToUnicodeObjectNo)) +
        ' 0 R >>' + #10);
      EndObject;

      BeginObject(UnicodeFonts[I].CIDFontObjectNo);
      WriteAnsi('<< /Type /Font /Subtype /CIDFontType2 /BaseFont /' +
        UnicodeFonts[I].BaseFontName +
        ' /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> ' +
        '/FontDescriptor ' + AnsiString(IntToStr(UnicodeFonts[I].DescriptorObjectNo)) + ' 0 R ' +
        '/DW 1000 /W ' + BuildUnicodeFontWidths(UnicodeFonts[I]) + ' ' +
        '/CIDToGIDMap ' + AnsiString(IntToStr(UnicodeFonts[I].CIDToGIDMapObjectNo)) + ' 0 R >>' + #10);
      EndObject;

      BeginObject(UnicodeFonts[I].DescriptorObjectNo);
      WriteAnsi('<< /Type /FontDescriptor /FontName /' + UnicodeFonts[I].BaseFontName +
        ' /Flags ' + AnsiString(IntToStr(UnicodeFonts[I].Flags)) +
        ' /FontBBox [' +
        AnsiString(IntToStr(UnicodeFonts[I].FontBBoxLeft)) + ' ' +
        AnsiString(IntToStr(UnicodeFonts[I].FontBBoxBottom)) + ' ' +
        AnsiString(IntToStr(UnicodeFonts[I].FontBBoxRight)) + ' ' +
        AnsiString(IntToStr(UnicodeFonts[I].FontBBoxTop)) + '] ' +
        '/ItalicAngle ' + AnsiString(IntToStr(UnicodeFonts[I].ItalicAngle)) +
        ' /Ascent ' + AnsiString(IntToStr(UnicodeFonts[I].Ascent)) +
        ' /Descent ' + AnsiString(IntToStr(UnicodeFonts[I].Descent)) +
        ' /CapHeight ' + AnsiString(IntToStr(UnicodeFonts[I].CapHeight)) +
        ' /StemV 80 /FontFile2 ' +
        AnsiString(IntToStr(UnicodeFonts[I].FontFileObjectNo)) + ' 0 R >>' + #10);
      EndObject;

      BeginObject(UnicodeFonts[I].FontFileObjectNo);
      WriteAnsi('<< /Length ' + AnsiString(IntToStr(Length(UnicodeFonts[I].FontFileBytes))) +
        ' /Length1 ' + AnsiString(IntToStr(Length(UnicodeFonts[I].FontFileBytes))) + ' >>' + #10);
      WriteAnsi('stream' + #10);
      WriteAnsi(BytesToAnsiString(UnicodeFonts[I].FontFileBytes));
      WriteAnsi(#10 + 'endstream' + #10);
      EndObject;

      Content := BytesToAnsiString(BuildIdentityCIDToGIDMap(UnicodeFonts[I]));
      BeginObject(UnicodeFonts[I].CIDToGIDMapObjectNo);
      WriteAnsi('<< /Length ' + AnsiString(IntToStr(Length(Content))) + ' >>' + #10);
      WriteAnsi('stream' + #10);
      WriteAnsi(Content);
      WriteAnsi(#10 + 'endstream' + #10);
      EndObject;

      Content := BuildToUnicodeCMap(UnicodeFonts[I]);
      BeginObject(UnicodeFonts[I].ToUnicodeObjectNo);
      WriteAnsi('<< /Length ' + AnsiString(IntToStr(Length(Content))) + ' >>' + #10);
      WriteAnsi('stream' + #10);
      WriteAnsi(Content);
      WriteAnsi(#10 + 'endstream' + #10);
      EndObject;
    end;

    XRefOffset := AStream.Position;
    WriteAnsi('xref' + #10);
    WriteAnsi(AnsiString('0 ' + IntToStr(ObjectCount + 1) + #10));
    WriteAnsi('0000000000 65535 f ' + PDF_XREF_EOL);
    for I := 1 to ObjectCount do
      WriteAnsi(AnsiString(Format('%.10d 00000 n ', [Offsets[I]]) + PDF_XREF_EOL));
    WriteAnsi('trailer' + #10);
    WriteAnsi(AnsiString('<< /Size ' + IntToStr(ObjectCount + 1) +
      ' /Root 1 0 R >>' + #10));
    WriteAnsi('startxref' + #10);
    WriteAnsi(AnsiString(IntToStr(XRefOffset) + #10));
    WriteAnsi('%%EOF' + #10);
  finally
    MeasureBmp.Free;
  end;
end;

end.
