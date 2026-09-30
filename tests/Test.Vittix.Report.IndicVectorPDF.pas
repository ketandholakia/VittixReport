unit Test.Vittix.Report.IndicVectorPDF;

{
  M5.6 regression coverage: TrueType glyph subsetting and Indic-script
  (Devanagari/Gujarati) Vector PDF font embedding.

  The Vector PDF writer emits text as glyph IDs under an /Identity-H Type0
  font, so subsets must preserve glyph IDs.  These tests pin:
    * the subsetter's structural contract (glyph count preserved, long loca,
      smaller output, graceful fallback on non-font input);
    * end-to-end writer behaviour for non-Latin text (embedded Type0 font,
      FontFile2, ToUnicode, and a subset smaller than the whole font file);
    * that Latin text is embedded through the same shaped-glyph pipeline
      (DP-30 / M-14) so the PDF draws with the font the layout measured
      with; the built-in Helvetica resources remain as a fallback only.
}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTrueTypeSubsetTests = class
  public
    [Test] procedure Subset_PreservesGlyphCount_AndShrinks;
    [Test] procedure Subset_UsesLongLoca;
    [Test] procedure Subset_NonFontInput_ReturnsInputUnchanged;
    [Test] procedure Subset_EmptyGlyphList_ReturnsInputUnchanged;
    [Test] procedure Subset_NotdefOnly_StillValidAndSmaller;
  end;

  [TestFixture]
  TIndicVectorPdfTests = class
  private
    function ExportTextPdf(const AText, AFontName: string; AFontSize: Integer): AnsiString;
    function ExportReportPdf(const AReportPath: string): AnsiString;
  public
    [Test] procedure Indic_EmbedsType0FontWithSubset;
    [Test] procedure Indic_SubsetIsSmallerThanWholeFontFile;
    [Test] procedure Indic_ToUnicodeMapPresent;
    [Test] procedure LatinText_EmbedsReportFont;
    [Test] procedure HindiReportFixture_ExportsType0Font;
    [Test] procedure GujaratiReportFixture_ExportsType0Font;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.StrUtils,
  System.IOUtils,
  Data.DB,
  Datasnap.DBClient,
  Vcl.Graphics,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.Serializer,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.VectorPDF,
  Vittix.Report.Export.VectorPDF.Subset;

const
  NIRMALA_TTC = 'C:\Windows\Fonts\Nirmala.ttc';
  ARIAL_TTF   = 'C:\Windows\Fonts\arial.ttf';

{ ============================== helpers ================================== }

function BytesOfFile(const APath: string): TBytes;
begin
  Result := TFile.ReadAllBytes(APath);
end;

function BytesToAnsi(const B: TBytes): AnsiString;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

{ Offset of a table's data inside an sfnt, or -1. }
function TableOffset(const ABytes: TBytes; ATag: Cardinal): Integer;
var
  NumTables, I: Integer;
  Tag: Cardinal;
begin
  Result := -1;
  if Length(ABytes) < 12 then
    Exit;
  NumTables := (Integer(ABytes[4]) shl 8) or Integer(ABytes[5]);
  for I := 0 to NumTables - 1 do
  begin
    if 12 + I * 16 + 16 > Length(ABytes) then
      Exit;
    Tag := (Cardinal(ABytes[12 + I * 16]) shl 24) or
           (Cardinal(ABytes[12 + I * 16 + 1]) shl 16) or
           (Cardinal(ABytes[12 + I * 16 + 2]) shl 8) or
           Cardinal(ABytes[12 + I * 16 + 3]);
    if Tag = ATag then
      Exit((Integer(ABytes[12 + I * 16 + 8]) shl 24) or
           (Integer(ABytes[12 + I * 16 + 9]) shl 16) or
           (Integer(ABytes[12 + I * 16 + 10]) shl 8) or
           Integer(ABytes[12 + I * 16 + 11]));
  end;
end;

function NumGlyphsOf(const ABytes: TBytes): Integer;
var
  Off: Integer;
begin
  Off := TableOffset(ABytes, $6D617870);   // maxp
  if (Off < 0) or (Off + 6 > Length(ABytes)) then
    Exit(-1);
  Result := (Integer(ABytes[Off + 4]) shl 8) or Integer(ABytes[Off + 5]);
end;

function PdfContains(const APdf: AnsiString; const ANeedle: string): Boolean;
begin
  Result := Pos(ANeedle, string(APdf)) > 0;
end;

{ Value of the first "/Length1 N" in the PDF, or -1. }
function PdfFontFileLength1(const APdf: AnsiString): Integer;
var
  P, I: Integer;
  S, Digits: string;
begin
  Result := -1;
  S := string(APdf);
  P := Pos('/Length1 ', S);
  if P = 0 then
    Exit;
  Digits := '';
  I := P + Length('/Length1 ');
  while (I <= Length(S)) and (S[I] >= '0') and (S[I] <= '9') do
  begin
    Digits := Digits + S[I];
    Inc(I);
  end;
  if Digits <> '' then
    Result := StrToIntDef(Digits, -1);
end;

function MakeDummyDataSet: TClientDataSet;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('Name', ftString, 20);
  Result.CreateDataSet;
  Result.AppendRecord(['row1']);
  Result.First;
end;

{ ============================ subsetter tests ============================ }

procedure TTrueTypeSubsetTests.Subset_PreservesGlyphCount_AndShrinks;
var
  Full, Sub: TBytes;
begin
  Assert.IsTrue(FileExists(ARIAL_TTF), 'arial.ttf missing');
  Full := BytesOfFile(ARIAL_TTF);

  Sub := SubsetTrueTypeFont(Full, [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70]);

  Assert.IsTrue(Length(Sub) < Length(Full),
    Format('subset (%d) must be smaller than the whole font (%d)',
      [Length(Sub), Length(Full)]));
  Assert.IsTrue(Length(Sub) > 1000, 'subset is implausibly small');
  Assert.AreEqual(NumGlyphsOf(Full), NumGlyphsOf(Sub),
    'glyph count (and therefore glyph ids) must be preserved');
end;

procedure TTrueTypeSubsetTests.Subset_UsesLongLoca;
var
  Sub: TBytes;
  HeadOff: Integer;
begin
  Sub := SubsetTrueTypeFont(BytesOfFile(ARIAL_TTF), [0, 5, 10, 20]);
  HeadOff := TableOffset(Sub, $68656164);   // head
  Assert.IsTrue(HeadOff >= 0, 'subset must keep the head table');
  Assert.AreEqual(1, (Integer(Sub[HeadOff + 50]) shl 8) or Integer(Sub[HeadOff + 51]),
    'subset must declare long loca offsets');
  Assert.IsTrue(TableOffset(Sub, $6C6F6361) >= 0, 'subset must keep loca');
end;

procedure TTrueTypeSubsetTests.Subset_NonFontInput_ReturnsInputUnchanged;
var
  Junk, Sub: TBytes;
  I: Integer;
begin
  SetLength(Junk, 64);
  for I := 0 to High(Junk) do
    Junk[I] := Byte(I);
  Sub := SubsetTrueTypeFont(Junk, [0, 1, 2]);
  Assert.AreEqual(Length(Junk), Length(Sub), 'non-font input must pass through');
end;

procedure TTrueTypeSubsetTests.Subset_EmptyGlyphList_ReturnsInputUnchanged;
var
  Full, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  Sub := SubsetTrueTypeFont(Full, []);
  Assert.AreEqual(Length(Full), Length(Sub), 'no glyphs requested -> unchanged');
end;

procedure TTrueTypeSubsetTests.Subset_NotdefOnly_StillValidAndSmaller;
var
  Full, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  Sub := SubsetTrueTypeFont(Full, [0]);
  Assert.IsTrue(Length(Sub) < Length(Full), 'notdef-only subset must still shrink');
  Assert.AreEqual(NumGlyphsOf(Full), NumGlyphsOf(Sub));
end;

{ ================================ Indic e2e ============================== }

function TIndicVectorPdfTests.ExportTextPdf(const AText, AFontName: string;
  AFontSize: Integer): AnsiString;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Band: TReportBand;
  Txt: TReportTextObject;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Ms: TBytesStream;
begin
  DS := MakeDummyDataSet;
  Model := TReportModel.Create;
  try
    Txt := TReportTextObject.Create;
    Txt.Name := 'txtIndic';
    Txt.Text := AText;
    Txt.Bounds := Rect(30, 40, 740, 100);
    Txt.Font.Name := AFontName;
    Txt.Font.Size := AFontSize;

    Band := TReportBand.Create;
    Band.BandType := btPageHeader;
    Band.Height := 200;
    Band.Children.Add(Txt);
    Model.Objects.Add(Band);

    Doc := TReportExportDocument.Create;
    Engine := TReportEngine.Create(Model, DS, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Ms := TBytesStream.Create;
      try
        TReportVectorPDFExporter.ExportDocument(Doc, Ms);
        Result := BytesToAnsi(Copy(Ms.Bytes, 0, Ms.Size));
      finally
        Ms.Free;
      end;
    finally
      Engine.Free;
      Doc.Free;
    end;
  finally
    Model.Free;
    DS.Free;
  end;
end;

function TIndicVectorPdfTests.ExportReportPdf(const AReportPath: string): AnsiString;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Doc: TReportExportDocument;
  Engine: TReportEngine;
  Ms: TBytesStream;
begin
  Assert.IsTrue(FileExists(AReportPath), 'report fixture missing: ' + AReportPath);
  DS := MakeDummyDataSet;
  Model := TReportSerializer.LoadFromFile(AReportPath);
  try
    Doc := TReportExportDocument.Create;
    Engine := TReportEngine.Create(Model, DS, nil, nil);
    try
      Engine.ExportDocument := Doc;
      Engine.Prepare;
      Ms := TBytesStream.Create;
      try
        TReportVectorPDFExporter.ExportDocument(Doc, Ms);
        Result := BytesToAnsi(Copy(Ms.Bytes, 0, Ms.Size));
      finally
        Ms.Free;
      end;
    finally
      Engine.Free;
      Doc.Free;
    end;
  finally
    Model.Free;
    DS.Free;
  end;
end;

procedure TIndicVectorPdfTests.Indic_EmbedsType0FontWithSubset;
var
  Pdf: AnsiString;
begin
  // Devanagari: na ma s te  (U+0928 U+092E U+0938 U+094D U+0924 U+0947)
  Pdf := ExportTextPdf(#$0928 + #$092E + #$0938 + #$094D + #$0924 + #$0947,
    'Nirmala UI', 14);
  Assert.IsTrue(PdfContains(Pdf, '/Type0'), 'expected an embedded Type0 font');
  Assert.IsTrue(PdfContains(Pdf, '/CIDFontType2'), 'expected CIDFontType2');
  Assert.IsTrue(PdfContains(Pdf, '/FontFile2'), 'expected /FontFile2');
  Assert.IsTrue(PdfContains(Pdf, '/Identity-H'), 'expected Identity-H encoding');
end;

procedure TIndicVectorPdfTests.Indic_SubsetIsSmallerThanWholeFontFile;
var
  Pdf: AnsiString;
  L1, Whole: Integer;
begin
  Pdf := ExportTextPdf(#$0928 + #$092E + #$0938 + #$094D + #$0924 + #$0947,
    'Nirmala UI', 14);
  L1 := PdfFontFileLength1(Pdf);
  Assert.IsTrue(L1 > 0, 'expected /Length1 for the embedded font');
  Whole := Length(BytesOfFile(NIRMALA_TTC));
  Assert.IsTrue(L1 < Whole,
    Format('embedded font (%d) must be a subset of the font file (%d)', [L1, Whole]));
  Assert.IsTrue(L1 < 500000,
    Format('embedded subset should be far smaller than the whole font (%d)', [L1]));
end;

procedure TIndicVectorPdfTests.Indic_ToUnicodeMapPresent;
begin
  Assert.IsTrue(PdfContains(
    ExportTextPdf(#$0928 + #$092E + #$0938 + #$094D + #$0924 + #$0947, 'Nirmala UI', 14),
    '/ToUnicode'), 'expected a /ToUnicode CMap for text extraction');
end;

procedure TIndicVectorPdfTests.LatinText_EmbedsReportFont;
var
  Pdf: AnsiString;
begin
  // DP-30 / M-14: Latin text must be embedded through the same shaped-glyph
  // pipeline as the Indic scripts so the PDF renders with (and measures
  // identically to) the report font.  Until DP-30 Latin always drew with
  // built-in Helvetica while the layout measured with the report font.
  Pdf := ExportTextPdf('Plain latin invoice line 123.45', 'Tahoma', 12);
  Assert.IsTrue(PdfContains(Pdf, '/Type0'), 'Latin text must use an embedded Type0 font');
  Assert.IsTrue(PdfContains(Pdf, '/CIDFontType2'), 'expected CIDFontType2');
  Assert.IsTrue(PdfContains(Pdf, '/FontFile2'), 'expected an embedded font file');
  Assert.IsTrue(PdfContains(Pdf, '/ToUnicode'), 'expected a ToUnicode map for extraction');
  Assert.IsTrue(PdfContains(Pdf, '/BaseFont /Tahoma'),
    'the embedded font must be the report font (Tahoma), not Helvetica');
  Assert.IsFalse(PdfContains(Pdf, '(Plain latin invoice line 123.45) Tj'),
    'Latin text must not be drawn as a Helvetica literal any more');
end;

procedure TIndicVectorPdfTests.HindiReportFixture_ExportsType0Font;
begin
  Assert.IsTrue(PdfContains(
    ExportReportPdf(TPath.Combine(GetCurrentDir, 'tests\indic_hindi.vrt')),
    '/Type0'), 'Hindi fixture must export an embedded Type0 font');
end;

procedure TIndicVectorPdfTests.GujaratiReportFixture_ExportsType0Font;
begin
  Assert.IsTrue(PdfContains(
    ExportReportPdf(TPath.Combine(GetCurrentDir, 'tests\indic_gujarati.vrt')),
    '/Type0'), 'Gujarati fixture must export an embedded Type0 font');
end;

initialization
  TDUnitX.RegisterTestFixture(TTrueTypeSubsetTests);
  TDUnitX.RegisterTestFixture(TIndicVectorPdfTests);

end.
