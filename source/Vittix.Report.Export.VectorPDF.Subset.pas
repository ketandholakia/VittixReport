unit Vittix.Report.Export.VectorPDF.Subset;

{
  Vittix.Report.Export.VectorPDF.Subset
  =====================================

  TrueType glyph subsetting for the Vector PDF writer.

  The Vector PDF writer emits text as glyph IDs under an /Identity-H Type0
  font and an identity CIDToGIDMap (see Vittix.Report.Export.VectorPDF).
  Because glyph IDs are therefore load-bearing, the subset MUST PRESERVE
  GLYPH IDS - we cannot renumber glyphs without rewriting every content
  stream and the CIDToGIDMap.

  Strategy ("retain GIDs"):
    * keep glyf entries only for the used glyphs (plus composite components),
      packed in glyph-id order with empty entries for unused glyphs;
    * rebuild loca in long format with numGlyphs + 1 entries so every original
      glyph id keeps its meaning;
    * set head.indexToLocFormat = 1;
    * keep only the tables a PDF viewer needs to decode the outlines
      (head, hhea, maxp, hmtx, cmap, OS/2, loca, glyf) - dropping name/post/
      GSUB/GPOS/GDEF etc., which is where most of an Indic font's bytes live;
    * recompute the table directory, per-table checksums and
      head.checkSumAdjustment.

  Any parse failure returns the input unchanged, so this can never make
  output worse than the status quo.
}

interface

uses
  System.SysUtils;

{ Returns a subset of AFontBytes containing only AGlyphIds (plus any
  composite-component glyphs they reference).  Returns AFontBytes unchanged
  when the font cannot be parsed, when no glyphs are requested, or when the
  subset would not be smaller. }
function SubsetTrueTypeFont(const AFontBytes: TBytes;
  const AGlyphIds: TArray<Word>): TBytes;

implementation

const
  TAG_head = $68656164; // 'head'
  TAG_hhea = $68686561; // 'hhea'
  TAG_maxp = $6D617870; // 'maxp'
  TAG_hmtx = $686D7478; // 'hmtx'
  TAG_cmap = $636D6170; // 'cmap'
  TAG_OS2  = $4F532F32; // 'OS/2'
  TAG_loca = $6C6F6361; // 'loca'
  TAG_glyf = $676C7966; // 'glyf'

  COMPOSITE_ARG_1_AND_2_ARE_WORDS = $0001;
  COMPOSITE_WE_HAVE_A_SCALE       = $0008;
  COMPOSITE_MORE_COMPONENTS       = $0020;
  COMPOSITE_WE_HAVE_X_AND_Y_SCALE = $0040;
  COMPOSITE_WE_HAVE_TWO_BY_TWO    = $0080;

type
  TTableEntry = record
    Tag: Cardinal;
    Offset: Integer;
    Length: Integer;
  end;

function ReadU16(const B: TBytes; AOffset: Integer): Cardinal;
begin
  if (AOffset < 0) or (AOffset + 1 >= Length(B)) then
    Exit(0);
  Result := (Cardinal(B[AOffset]) shl 8) or Cardinal(B[AOffset + 1]);
end;

function ReadI16(const B: TBytes; AOffset: Integer): Integer;
begin
  Result := SmallInt(Word(ReadU16(B, AOffset)));
end;

function ReadU32(const B: TBytes; AOffset: Integer): Cardinal;
begin
  if (AOffset < 0) or (AOffset + 3 >= Length(B)) then
    Exit(0);
  Result := (Cardinal(B[AOffset]) shl 24) or (Cardinal(B[AOffset + 1]) shl 16) or
            (Cardinal(B[AOffset + 2]) shl 8) or Cardinal(B[AOffset + 3]);
end;

procedure PutU16(var B: TBytes; AOffset: Integer; AValue: Cardinal);
begin
  B[AOffset]     := Byte((AValue shr 8) and $FF);
  B[AOffset + 1] := Byte(AValue and $FF);
end;

procedure PutU32(var B: TBytes; AOffset: Integer; AValue: Cardinal);
begin
  B[AOffset]     := Byte((AValue shr 24) and $FF);
  B[AOffset + 1] := Byte((AValue shr 16) and $FF);
  B[AOffset + 2] := Byte((AValue shr 8) and $FF);
  B[AOffset + 3] := Byte(AValue and $FF);
end;

{ Sum of the table's bytes interpreted as big-endian uint32s, zero-padded
  to a multiple of 4 (this is the TrueType table checksum). }
function TableChecksum(const B: TBytes; AOffset, ALength: Integer): Cardinal;
var
  I: Integer;
  V: Cardinal;
begin
  Result := 0;
  I := 0;
  while I < ALength do
  begin
    V := 0;
    if I + 3 < ALength then
      V := (Cardinal(B[AOffset + I]) shl 24) or
           (Cardinal(B[AOffset + I + 1]) shl 16) or
           (Cardinal(B[AOffset + I + 2]) shl 8) or
           Cardinal(B[AOffset + I + 3])
    else if I + 2 < ALength then
      V := (Cardinal(B[AOffset + I]) shl 24) or
           (Cardinal(B[AOffset + I + 1]) shl 16) or
           (Cardinal(B[AOffset + I + 2]) shl 8)
    else if I + 1 < ALength then
      V := (Cardinal(B[AOffset + I]) shl 24) or
           (Cardinal(B[AOffset + I + 1]) shl 16)
    else
      V := Cardinal(B[AOffset + I]) shl 24;

    Result := Cardinal(Int64(Result) + Int64(V));   // wrap is intended
    Inc(I, 4);
  end;
end;

function FindTable(const Tables: TArray<TTableEntry>; ATag: Cardinal): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Tables) do
    if Tables[I].Tag = ATag then
      Exit(I);
  Result := -1;
end;

{ Adds the composite-component closure of AGlyphId into AUsed. }
procedure AddCompositeComponents(const B: TBytes; AGlyphStart, AGlyphLength: Integer;
  var AUsed: TArray<Boolean>; var AQueue: TArray<Integer>);

  procedure QueueGlyph(AId: Integer);
  begin
    if (AId >= 0) and (AId < Length(AUsed)) and not AUsed[AId] then
    begin
      AUsed[AId] := True;
      SetLength(AQueue, Length(AQueue) + 1);
      AQueue[High(AQueue)] := AId;
    end;
  end;

var
  NumberOfContours: Integer;
  P, Flags, CompGlyph: Integer;
begin
  NumberOfContours := ReadI16(B, AGlyphStart);
  if NumberOfContours >= 0 then
    Exit;                                  // simple glyph: no components

  P := AGlyphStart + 10;                   // skip the 5 header shorts
  while P + 3 < AGlyphStart + AGlyphLength do
  begin
    Flags := Integer(ReadU16(B, P));
    CompGlyph := Integer(ReadU16(B, P + 2));
    Inc(P, 4);

    if (Flags and COMPOSITE_ARG_1_AND_2_ARE_WORDS) <> 0 then
      Inc(P, 4)
    else
      Inc(P, 2);

    if (Flags and COMPOSITE_WE_HAVE_A_SCALE) <> 0 then
      Inc(P, 2)
    else if (Flags and COMPOSITE_WE_HAVE_X_AND_Y_SCALE) <> 0 then
      Inc(P, 4)
    else if (Flags and COMPOSITE_WE_HAVE_TWO_BY_TWO) <> 0 then
      Inc(P, 8);

    QueueGlyph(CompGlyph);

    if (Flags and COMPOSITE_MORE_COMPONENTS) = 0 then
      Break;
  end;
end;

function SubsetTrueTypeFont(const AFontBytes: TBytes;
  const AGlyphIds: TArray<Word>): TBytes;
var
  Tables: TArray<TTableEntry>;
  NumTables: Integer;
  I, J: Integer;
  Idx: Integer;
  SfntVersion: Cardinal;
  MaxpIdx, HeadIdx, LocaIdx, GlyfIdx: Integer;
  NumGlyphs: Integer;
  IndexToLocFormat: Integer;
  LocaOffsets: TArray<Integer>;
  Used: TArray<Boolean>;
  Queue: TArray<Integer>;
  Head: TBytes;
  GlyfOut: TBytes;
  GlyfLen: Integer;
  LocaOut: TBytes;
  GlyphStart, GlyphLength, Pad: Integer;
  Out: TBytes;
  NumOut: Integer;
  HeaderSize, DirSize, DataOffset: Integer;
  SfntSearchRange, SfntEntrySelector, SfntRangeShift: Cardinal;
  TotalChecksum: Cardinal;
  Adjustment: Cardinal;
  TableTags: array[0..7] of Cardinal;
  TableOutIdx: array[0..7] of Integer;
  TableOffsets: array[0..7] of Integer;
  TableLengths: array[0..7] of Integer;
  TableChecksums: array[0..7] of Cardinal;
  OutCount: Integer;
  Found: Boolean;
  FullLength: Integer;
begin
  Result := AFontBytes;
  FullLength := Length(AFontBytes);
  if (FullLength < 12) or (Length(AGlyphIds) = 0) then
    Exit;

  SfntVersion := ReadU32(AFontBytes, 0);
  if (SfntVersion <> $00010000) and (SfntVersion <> $74727565) then
    Exit;                                  // not a TrueType outline font

  NumTables := Integer(ReadU16(AFontBytes, 4));
  if (NumTables <= 0) or (12 + NumTables * 16 > FullLength) then
    Exit;

  SetLength(Tables, NumTables);
  for I := 0 to NumTables - 1 do
  begin
    Tables[I].Tag := ReadU32(AFontBytes, 12 + I * 16);
    Tables[I].Offset := Integer(ReadU32(AFontBytes, 12 + I * 16 + 8));
    Tables[I].Length := Integer(ReadU32(AFontBytes, 12 + I * 16 + 12));
    if (Tables[I].Offset < 0) or (Tables[I].Length < 0) or
       (Tables[I].Offset + Tables[I].Length > FullLength) then
      Exit;
  end;

  MaxpIdx := FindTable(Tables, TAG_maxp);
  HeadIdx := FindTable(Tables, TAG_head);
  LocaIdx := FindTable(Tables, TAG_loca);
  GlyfIdx := FindTable(Tables, TAG_glyf);
  if (MaxpIdx < 0) or (HeadIdx < 0) or (LocaIdx < 0) or (GlyfIdx < 0) then
    Exit;

  NumGlyphs := Integer(ReadU16(AFontBytes, Tables[MaxpIdx].Offset + 4));
  if (NumGlyphs <= 0) or (NumGlyphs > 65535) then
    Exit;

  IndexToLocFormat := ReadI16(AFontBytes, Tables[HeadIdx].Offset + 50);
  if (IndexToLocFormat <> 0) and (IndexToLocFormat <> 1) then
    Exit;

  SetLength(LocaOffsets, NumGlyphs + 1);
  if IndexToLocFormat = 1 then
  begin
    if Tables[LocaIdx].Length < (NumGlyphs + 1) * 4 then
      Exit;
    for I := 0 to NumGlyphs do
      LocaOffsets[I] := Integer(ReadU32(AFontBytes, Tables[LocaIdx].Offset + I * 4));
  end
  else
  begin
    if Tables[LocaIdx].Length < (NumGlyphs + 1) * 2 then
      Exit;
    for I := 0 to NumGlyphs do
      LocaOffsets[I] := Integer(ReadU16(AFontBytes, Tables[LocaIdx].Offset + I * 2)) * 2;
  end;

  // Validate the loca ramp.
  for I := 0 to NumGlyphs - 1 do
    if (LocaOffsets[I] > LocaOffsets[I + 1]) or
       (LocaOffsets[I + 1] > Tables[GlyfIdx].Length) then
      Exit;

  // Seed the used set with the requested glyphs (plus .notdef) and expand
  // composite components transitively.
  SetLength(Used, NumGlyphs);
  SetLength(Queue, 0);
  Used[0] := True;
  SetLength(Queue, 1);
  Queue[0] := 0;

  for I := 0 to High(AGlyphIds) do
    if (AGlyphIds[I] < NumGlyphs) and not Used[AGlyphIds[I]] then
    begin
      Used[AGlyphIds[I]] := True;
      SetLength(Queue, Length(Queue) + 1);
      Queue[High(Queue)] := AGlyphIds[I];
    end;

  I := 0;
  while I < Length(Queue) do
  begin
    GlyphStart := Tables[GlyfIdx].Offset + LocaOffsets[Queue[I]];
    GlyphLength := LocaOffsets[Queue[I] + 1] - LocaOffsets[Queue[I]];
    if GlyphLength > 0 then
      AddCompositeComponents(AFontBytes, GlyphStart, GlyphLength, Used, Queue);
    Inc(I);
  end;

  // Build the new glyf and long loca (glyph ids preserved).
  SetLength(GlyfOut, 0);
  GlyfLen := 0;
  SetLength(LocaOut, (NumGlyphs + 1) * 4);
  for I := 0 to NumGlyphs - 1 do
  begin
    PutU32(LocaOut, I * 4, Cardinal(GlyfLen));
    if not Used[I] then
      Continue;
    GlyphStart := Tables[GlyfIdx].Offset + LocaOffsets[I];
    GlyphLength := LocaOffsets[I + 1] - LocaOffsets[I];
    if GlyphLength <= 0 then
      Continue;
    SetLength(GlyfOut, GlyfLen + GlyphLength);
    Move(AFontBytes[GlyphStart], GlyfOut[GlyfLen], GlyphLength);
    Inc(GlyfLen, GlyphLength);
    Pad := (4 - (GlyphLength mod 4)) mod 4;
    if Pad > 0 then
    begin
      SetLength(GlyfOut, GlyfLen + Pad);
      for J := 0 to Pad - 1 do
        GlyfOut[GlyfLen + J] := 0;
      Inc(GlyfLen, Pad);
    end;
  end;
  PutU32(LocaOut, NumGlyphs * 4, Cardinal(GlyfLen));

  // New head: same as the original, but long loca.
  Head := Copy(AFontBytes, Tables[HeadIdx].Offset, 54);
  if Length(Head) <> 54 then
    Exit;
  PutU32(Head, 8, 0);                      // checkSumAdjustment fixed up later
  PutU16(Head, 50, 1);                     // indexToLocFormat = long

  // Emit a whitelist of tables, in a deterministic order.
  NumOut := 0;
  TableTags[0] := TAG_head; TableTags[1] := TAG_hhea; TableTags[2] := TAG_maxp;
  TableTags[3] := TAG_hmtx; TableTags[4] := TAG_cmap; TableTags[5] := TAG_OS2;
  TableTags[6] := TAG_loca; TableTags[7] := TAG_glyf;

  for I := 0 to High(TableTags) do
  begin
    if (TableTags[I] = TAG_head) or (TableTags[I] = TAG_loca) or
       (TableTags[I] = TAG_glyf) then
    begin
      TableOutIdx[NumOut] := I;
      Inc(NumOut);
    end
    else if FindTable(Tables, TableTags[I]) >= 0 then
    begin
      TableOutIdx[NumOut] := I;
      Inc(NumOut);
    end;
  end;

  HeaderSize := 12 + NumOut * 16;
  // Table order in the directory must be sorted by tag; sort the output list.
  for I := 0 to NumOut - 2 do
    for J := I + 1 to NumOut - 1 do
      if TableTags[TableOutIdx[J]] < TableTags[TableOutIdx[I]] then
      begin
        Idx := TableOutIdx[I];
        TableOutIdx[I] := TableOutIdx[J];
        TableOutIdx[J] := Idx;
      end;

  // Lay out the table data (4-byte aligned).
  DataOffset := HeaderSize;
  for I := 0 to NumOut - 1 do
  begin
    Idx := TableOutIdx[I];
    TableOffsets[I] := DataOffset;
    if TableTags[Idx] = TAG_head then
      TableLengths[I] := 54
    else if TableTags[Idx] = TAG_loca then
      TableLengths[I] := Length(LocaOut)
    else if TableTags[Idx] = TAG_glyf then
      TableLengths[I] := GlyfLen
    else
    begin
      Found := False;
      for J := 0 to High(Tables) do
        if Tables[J].Tag = TableTags[Idx] then
        begin
          TableLengths[I] := Tables[J].Length;
          Found := True;
          Break;
        end;
      if not Found then
        TableLengths[I] := 0;
    end;
    Inc(DataOffset, TableLengths[I]);
    Inc(DataOffset, (4 - (TableLengths[I] mod 4)) mod 4);
  end;

  if DataOffset >= FullLength then
    Exit;                                  // subset would not be smaller

  SetLength(Out, DataOffset);
  for I := 0 to DataOffset - 1 do
    Out[I] := 0;

  // sfnt header
  PutU32(Out, 0, $00010000);
  PutU16(Out, 4, Cardinal(NumOut));
  SfntEntrySelector := 0;
  while (Cardinal(1) shl (SfntEntrySelector + 1)) <= Cardinal(NumOut) do
    Inc(SfntEntrySelector);
  SfntSearchRange := (Cardinal(1) shl SfntEntrySelector) * 16;
  SfntRangeShift := Cardinal(NumOut) * 16 - SfntSearchRange;
  PutU16(Out, 6, SfntSearchRange);
  PutU16(Out, 8, SfntEntrySelector);
  PutU16(Out, 10, SfntRangeShift);

  for I := 0 to NumOut - 1 do
  begin
    Idx := TableOutIdx[I];
    PutU32(Out, 12 + I * 16, TableTags[Idx]);
    PutU32(Out, 12 + I * 16 + 8, Cardinal(TableOffsets[I]));
    PutU32(Out, 12 + I * 16 + 12, Cardinal(TableLengths[I]));

    if TableTags[Idx] = TAG_head then
      Move(Head[0], Out[TableOffsets[I]], 54)
    else if TableTags[Idx] = TAG_loca then
      Move(LocaOut[0], Out[TableOffsets[I]], Length(LocaOut))
    else if TableTags[Idx] = TAG_glyf then
    begin
      if GlyfLen > 0 then
        Move(GlyfOut[0], Out[TableOffsets[I]], GlyfLen);
    end
    else
    begin
      for J := 0 to High(Tables) do
        if Tables[J].Tag = TableTags[Idx] then
        begin
          Move(AFontBytes[Tables[J].Offset], Out[TableOffsets[I]], Tables[J].Length);
          Break;
        end;
    end;

    // Checksum with the head checkSumAdjustment field zeroed (it already is).
    TableChecksums[I] := TableChecksum(Out, TableOffsets[I], TableLengths[I]);
    PutU32(Out, 12 + I * 16 + 4, TableChecksums[I]);
  end;

  // head.checkSumAdjustment = 0xB1B0AFBA - total file checksum.
  TotalChecksum := 0;
  for I := 0 to NumOut - 1 do
    TotalChecksum := Cardinal(Int64(TotalChecksum) + Int64(TableChecksums[I]));
  TotalChecksum := Cardinal(Int64(TotalChecksum) +
    Int64(TableChecksum(Out, 0, HeaderSize)));
  Adjustment := Cardinal($B1B0AFBA) - TotalChecksum;

  for I := 0 to NumOut - 1 do
    if TableTags[TableOutIdx[I]] = TAG_head then
    begin
      PutU32(Out, TableOffsets[I] + 8, Adjustment);
      Break;
    end;

  Result := Out;
end;

end.
