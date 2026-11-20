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
    [Test] procedure TTC_Container_SubsetsFaceByFamilyName;
    [Test] procedure TTC_SecondFace_SelectedWhenFirstInvalid;
    [Test] procedure TTC_StrippedHeaderBlob_IsSubsets;
    [Test] procedure TTC_UnknownFamily_ReturnsInputUnchanged;
    [Test] procedure TTC_MalformedContainer_ReturnsInputUnchanged;
    [Test] procedure TTC_OutOfRangeFaceOffset_ReturnsInputUnchanged;
    [Test] procedure TTC_FamilyMatch_IsExact_NotSubstring;
    [Test] procedure TTC_StyleSelection_RegularPrefersRegular;
    [Test] procedure TTC_StyleSelection_BoldAndItalicExact;
    [Test] procedure TTC_StyleFallback_WhenExactStyleUnavailable;
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
  [Test] procedure LatinAccented_ToUnicodeMappingsPresent;
  [Test] procedure IndicSimple_ToUnicodeMappingsPresent;
  [Test] procedure ShapedFonts_EmitCidWidths;
    [Test] procedure LatinText_EmbedsReportFont;
    [Test] procedure HindiReportFixture_ExportsType0Font;
    [Test] procedure GujaratiReportFixture_ExportsType0Font;
    [Test] procedure TextRendering_FontSizeAndAdvanceSpacing_NotContracted;
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

{ head.macStyle of a standalone sfnt: head table + 44 (2 bytes, big endian). }
function MacStyleOf(const ABytes: TBytes): Integer;
var
  Off: Integer;
begin
  Off := TableOffset(ABytes, $68656164);   // 'head'
  if (Off < 0) or (Off + 46 > Length(ABytes)) then
    Exit(-1);
  Result := (Integer(ABytes[Off + 44]) shl 8) or Integer(ABytes[Off + 45]);
end;

function PatchMacStyle(const AFace: TBytes; AValue: Word): TBytes;
var
  Off: Integer;
begin
  Result := Copy(AFace);
  Off := TableOffset(Result, $68656164);   // 'head'
  Assert.IsTrue((Off >= 0) and (Off + 46 <= Length(Result)), 'head table required');
  Result[Off + 44] := Byte((AValue shr 8) and $FF);
  Result[Off + 45] := Byte(AValue and $FF);
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Exit(False);
end;

{ Builds a synthetic TrueType Collection: TTC v1 header (12 + 4*N bytes) plus
  the faces concatenated 4-byte aligned.  Each face's table directory is
  REBASED to container-absolute offsets, exactly like real collections
  (Nirmala.ttc et al.) lay their faces out. }
function MakeTtc(const AFaces: TArray<TBytes>): TBytes;
var
  N, I, J, HeaderSize, Cursor, Pad, NumTables, Off: Integer;
  Offs: TArray<Integer>;
begin
  N := Length(AFaces);
  if N = 0 then
    Exit;
  HeaderSize := 12 + N * 4;
  Cursor := HeaderSize;
  SetLength(Offs, N);
  for I := 0 to N - 1 do
  begin
    Offs[I] := Cursor;
    Inc(Cursor, Length(AFaces[I]));
    Pad := (4 - (Cursor mod 4)) mod 4;
    Inc(Cursor, Pad);
  end;
  SetLength(Result, Cursor);               // dynamic arrays zero-init
  Result[0] := Ord('t'); Result[1] := Ord('t');
  Result[2] := Ord('c'); Result[3] := Ord('f');
  Result[4] := 0; Result[5] := 0; Result[6] := 1; Result[7] := 0;  // version 1.0
  Result[8] := 0; Result[9] := 0; Result[10] := 0; Result[11] := Byte(N);
  for I := 0 to N - 1 do
  begin
    Result[12 + I * 4]     := Byte((Cardinal(Offs[I]) shr 24) and $FF);
    Result[12 + I * 4 + 1] := Byte((Cardinal(Offs[I]) shr 16) and $FF);
    Result[12 + I * 4 + 2] := Byte((Cardinal(Offs[I]) shr 8) and $FF);
    Result[12 + I * 4 + 3] := Byte(Cardinal(Offs[I]) and $FF);
  end;
  for I := 0 to N - 1 do
  begin
    Move(AFaces[I][0], Result[Offs[I]], Length(AFaces[I]));
    // Rebase the face's table offsets to container-absolute positions.
    NumTables := (Integer(Result[Offs[I] + 4]) shl 8) or Integer(Result[Offs[I] + 5]);
    for J := 0 to NumTables - 1 do
    begin
      Off := Offs[I] + 12 + J * 16 + 8;
      Cursor := (Integer(Result[Off]) shl 24) or (Integer(Result[Off + 1]) shl 16) or
        (Integer(Result[Off + 2]) shl 8) or Integer(Result[Off + 3]);
      Inc(Cursor, Offs[I]);
      Result[Off]     := Byte((Cardinal(Cursor) shr 24) and $FF);
      Result[Off + 1] := Byte((Cardinal(Cursor) shr 16) and $FF);
      Result[Off + 2] := Byte((Cardinal(Cursor) shr 8) and $FF);
      Result[Off + 3] := Byte(Cardinal(Cursor) and $FF);
    end;
  end;
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

{ ============================== TTC tests ================================ }

procedure TTrueTypeSubsetTests.TTC_Container_SubsetsFaceByFamilyName;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  Ttc := MakeTtc(TArray<TBytes>.Create(Full));

  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, False);

  Assert.IsTrue((Length(Sub) > 1000) and (Length(Sub) < Length(Ttc)),
    Format('TTC face subset (%d) must be a real subset of the container (%d)',
      [Length(Sub), Length(Ttc)]));
  Assert.AreEqual(NumGlyphsOf(Full), NumGlyphsOf(Sub),
    'selected-face subset must preserve glyph count');
end;

procedure TTrueTypeSubsetTests.TTC_SecondFace_SelectedWhenFirstInvalid;
var
  Full, Junk, Ttc, Sub: TBytes;
  I: Integer;
begin
  Full := BytesOfFile(ARIAL_TTF);
  SetLength(Junk, 400);
  for I := 0 to High(Junk) do
    Junk[I] := Byte((I * 7) and $FF);
  Junk[0] := 0; Junk[1] := 0; Junk[2] := 0; Junk[3] := 0;   // invalid sfnt version
  Ttc := MakeTtc(TArray<TBytes>.Create(Junk, Full));

  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, False);

  Assert.IsTrue((Length(Sub) > 1000) and (Length(Sub) < Length(Ttc)),
    Format('selection must skip the invalid face 0 and subset face 1 (%d of %d)',
      [Length(Sub), Length(Ttc)]));
  Assert.AreEqual(NumGlyphsOf(Full), NumGlyphsOf(Sub),
    'face 1 subset must preserve glyph count');
end;

procedure TTrueTypeSubsetTests.TTC_StrippedHeaderBlob_IsSubsets;
var
  Full, Ttc, Blob, Sub: TBytes;
begin
  // Reproduces the GDI GetFontData shape for collection faces: the 'ttcf'
  // header is gone, the first face directory sits at offset 0, and the table
  // offsets inside are still collection-absolute.  The old parser declined
  // this input and embedded the whole blob (5.3 MB for Nirmala.ttc).
  Full := BytesOfFile(ARIAL_TTF);
  Ttc := MakeTtc(TArray<TBytes>.Create(Full));
  Blob := Copy(Ttc, 12 + 4, Length(Ttc) - (12 + 4));

  Sub := SubsetTrueTypeFontForFamily(Blob,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, False);

  Assert.IsTrue((Length(Sub) > 1000) and (Length(Sub) < Length(Blob)),
    Format('repaired blob must subset (%d of %d)', [Length(Sub), Length(Blob)]));
  Assert.AreEqual(NumGlyphsOf(Full), NumGlyphsOf(Sub),
    'repaired-blob subset must preserve glyph count');
end;

procedure TTrueTypeSubsetTests.TTC_UnknownFamily_ReturnsInputUnchanged;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  Ttc := MakeTtc(TArray<TBytes>.Create(Full));

  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70],
    'NoSuchFamily', False, False);

  Assert.AreEqual(Length(Ttc), Length(Sub),
    'no family match -> whole-input fallback, never a guessed face');
end;

procedure TTrueTypeSubsetTests.TTC_MalformedContainer_ReturnsInputUnchanged;
var
  Bad, Sub: TBytes;
begin
  // 'ttcf' + version 1.0 + numFonts = 0
  SetLength(Bad, 16);
  Bad[0] := Ord('t'); Bad[1] := Ord('t'); Bad[2] := Ord('c'); Bad[3] := Ord('f');
  Bad[4] := 0; Bad[5] := 0; Bad[6] := 1; Bad[7] := 0;
  Bad[8] := 0; Bad[9] := 0; Bad[10] := 0; Bad[11] := 0;

  Sub := SubsetTrueTypeFontForFamily(Bad, [0, 1, 2], 'Arial', False, False);
  Assert.AreEqual(Length(Bad), Length(Sub),
    'malformed container must pass through unchanged');
end;

procedure TTrueTypeSubsetTests.TTC_OutOfRangeFaceOffset_ReturnsInputUnchanged;
var
  Bad, Sub: TBytes;
begin
  // 'ttcf' + version 1.0 + numFonts = 1 + face offset 4096 (beyond the buffer)
  SetLength(Bad, 16);
  Bad[0] := Ord('t'); Bad[1] := Ord('t'); Bad[2] := Ord('c'); Bad[3] := Ord('f');
  Bad[4] := 0; Bad[5] := 0; Bad[6] := 1; Bad[7] := 0;
  Bad[8] := 0; Bad[9] := 0; Bad[10] := 0; Bad[11] := 1;
  Bad[12] := $00; Bad[13] := $00; Bad[14] := $10; Bad[15] := $00;

  Sub := SubsetTrueTypeFontForFamily(Bad, [0, 1, 2], 'Arial', False, False);
  Assert.AreEqual(Length(Bad), Length(Sub),
    'out-of-range face offset must pass through unchanged');
end;

procedure TTrueTypeSubsetTests.TTC_FamilyMatch_IsExact_NotSubstring;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  Ttc := MakeTtc(TArray<TBytes>.Create(Full));

  // 'Aria' is a strict substring of the face family 'Arial': with the
  // historical substring comparison this face would have been selected.
  // Exact-equality matching must refuse it and keep the whole-font fallback
  // (the result must be the input, unchanged).
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Aria', False, False);
  Assert.IsTrue(SameBytes(Sub, Ttc),
    'substring family requests must not select a face (exact equality only)');

  // Control: the exact family name still selects and subsets the face.
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, False);
  Assert.IsTrue((Length(Sub) > 1000) and (Length(Sub) < Length(Ttc)),
    'exact family name must still select the face');
end;

procedure TTrueTypeSubsetTests.TTC_StyleSelection_RegularPrefersRegular;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  // Face 0 flagged bold, face 1 regular - regular listed second.
  Ttc := MakeTtc(TArray<TBytes>.Create(PatchMacStyle(Full, $0001),
                                       PatchMacStyle(Full, $0000)));

  // A regular request must prefer the regular face (mask 0 = neither bit),
  // not accept the first family match (the bold face, historical behavior).
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, False);
  Assert.AreEqual(0, MacStyleOf(Sub),
    'regular request must select the regular face');

  // A bold request must prefer the bold face.
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', True, False);
  Assert.AreEqual(1, MacStyleOf(Sub),
    'bold request must select the bold face');
end;

procedure TTrueTypeSubsetTests.TTC_StyleSelection_BoldAndItalicExact;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  // Italic available: an italic request must prefer the italic face.
  Ttc := MakeTtc(TArray<TBytes>.Create(PatchMacStyle(Full, $0002),
                                       PatchMacStyle(Full, $0000)));
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', False, True);
  Assert.AreEqual(2, MacStyleOf(Sub),
    'italic request must select the italic face');

  // Bold-italic face available: a bold-italic request must prefer it.
  Ttc := MakeTtc(TArray<TBytes>.Create(PatchMacStyle(Full, $0003),
                                       PatchMacStyle(Full, $0001)));
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', True, True);
  Assert.AreEqual(3, MacStyleOf(Sub),
    'bold-italic request must select the bold-italic face');
end;

procedure TTrueTypeSubsetTests.TTC_StyleFallback_WhenExactStyleUnavailable;
var
  Full, Ttc, Sub: TBytes;
begin
  Full := BytesOfFile(ARIAL_TTF);
  // Only a bold-italic face exists: a bold request has no exact style match
  // and must fall back to the family match (documented behavior), still
  // subsetting instead of using the whole-font fallback.
  Ttc := MakeTtc(TArray<TBytes>.Create(PatchMacStyle(Full, $0003)));
  Sub := SubsetTrueTypeFontForFamily(Ttc,
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 36, 37, 68, 69, 70], 'Arial', True, False);
  // The selected face IS the bold-italic face: its own macStyle (3) is kept
  // in the subset's head table. The fallback contract is that the family
  // face is still chosen and subsetted - not that its style bits change.
  Assert.AreEqual(3, MacStyleOf(Sub),
    'no exact style: fall back to the first (bold-italic) family match');
  Assert.IsTrue((Length(Sub) > 1000) and (Length(Sub) < Length(Ttc)),
    'style fallback must still subset the family face');
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

procedure TIndicVectorPdfTests.LatinAccented_ToUnicodeMappingsPresent;
var
  Pdf: AnsiString;
begin
  Pdf := ExportTextPdf('Cafe ' + #$00E9 + ' ' + #$20AC, 'Tahoma', 12);

  // This checks the character-to-Unicode mapping independently of visual
  // placement: the generated CMap must contain the accented Latin and Euro
  // code points, not merely a /ToUnicode dictionary.
  Assert.IsTrue(PdfContains(Pdf, ' <00E9>'),
    'accented Latin character must have a direct ToUnicode mapping');
  Assert.IsTrue(PdfContains(Pdf, ' <20AC>'),
    'Euro character must have a direct ToUnicode mapping');
end;

procedure TIndicVectorPdfTests.IndicSimple_ToUnicodeMappingsPresent;
var
  DevanagariPdf, GujaratiPdf: AnsiString;
begin
  // Use one simple character per run. Complex Indic clusters may map several
  // Unicode code points to one glyph sequence; those require an external text
  // extractor to validate and are intentionally not conflated with this
  // one-to-one mapping check.
  DevanagariPdf := ExportTextPdf(#$0928, 'Nirmala UI', 14);
  GujaratiPdf := ExportTextPdf(#$0A95, 'Nirmala UI', 14);

  Assert.IsTrue(PdfContains(DevanagariPdf, ' <0928>'),
    'Devanagari character must have a direct ToUnicode mapping');
  Assert.IsTrue(PdfContains(GujaratiPdf, ' <0A95>'),
    'Gujarati character must have a direct ToUnicode mapping');
end;

procedure TIndicVectorPdfTests.ShapedFonts_EmitCidWidths;
var
  LatinPdf, DevanagariPdf, GujaratiPdf: AnsiString;
begin
  LatinPdf := ExportTextPdf('Width probe', 'Tahoma', 12);
  DevanagariPdf := ExportTextPdf(#$0928 + #$092E, 'Nirmala UI', 14);
  GujaratiPdf := ExportTextPdf(#$0A95 + #$0A95, 'Nirmala UI', 14);

  // /W is the CIDFont glyph-width table. Presence of positive width entries
  // is a structural check that ScriptPlace advances reached the PDF font;
  // it does not by itself prove visual placement or extraction correctness.
  Assert.IsTrue(PdfContains(LatinPdf, '/W ['),
    'Latin shaped font must emit a CID width table');
  Assert.IsTrue(PdfContains(DevanagariPdf, '/W ['),
    'Devanagari shaped font must emit a CID width table');
  Assert.IsTrue(PdfContains(GujaratiPdf, '/W ['),
    'Gujarati shaped font must emit a CID width table');
  Assert.IsFalse(PdfContains(LatinPdf, '[0]'),
    'Latin CID width table must not contain a zero-width glyph entry');
  Assert.IsFalse(PdfContains(DevanagariPdf, '[0]'),
    'Devanagari CID width table must not contain a zero-width glyph entry');
  Assert.IsFalse(PdfContains(GujaratiPdf, '[0]'),
    'Gujarati CID width table must not contain a zero-width glyph entry');
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

procedure TIndicVectorPdfTests.TextRendering_FontSizeAndAdvanceSpacing_NotContracted;
var
  Pdf: AnsiString;
begin
  // Regression test for character spacing defect:
  // When rendering text at 12 pt, the PDF Tf operator must specify the full 12 pt
  // font size (not 12 * 72/96 = 9 pt). Sizing the font outline at 9 pt while spacing
  // glyph advances at 12 pt caused a 1.33x-1.40x excessive character spacing gap.
  Pdf := ExportTextPdf('ABC', 'Arial', 12);

  // Must contain '12 Tf' for the font size operator, and must NOT contain '9 Tf'
  Assert.IsTrue(PdfContains(Pdf, ' 12 Tf'), 'PDF must set Tf operator with unscaled point size (12 Tf)');
  Assert.IsFalse(PdfContains(Pdf, ' 9 Tf'), 'PDF must not scale font size by 72/96 (9 Tf)');

  // CIDFont glyph widths in /W must also reflect the 1000-unit design scale
  Assert.IsTrue(PdfContains(Pdf, '/W ['), 'PDF must emit CIDFont /W table');
  Assert.IsFalse(PdfContains(Pdf, ' 889 ]'), 'Arial A advance must not be inflated to 889 (should be ~667)');
end;

initialization
  TDUnitX.RegisterTestFixture(TTrueTypeSubsetTests);
  TDUnitX.RegisterTestFixture(TIndicVectorPdfTests);

end.
