unit Vittix.Report.Export.XLSX;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Zip,
  Vcl.Graphics,
  Vittix.Report.Export.Commands;

type
  TReportXLSXExporter = class
  public
    class procedure ExportToStream(APages: TObjectList<TReportExportPage>; AStream: TStream);
    class procedure ExportToFile(APages: TObjectList<TReportExportPage>; const AFileName: string);
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  System.Types,
  Winapi.Windows;

type
  // Helper to store grouped text objects for grid mapping
  TXLSXCell = record
    Text: string;
    X, Y: Integer;            // X = bounds left; Y = bounds top + page offset (row grouping key)
    Bounds: TRect;            // page-local command bounds (used by fill/border mapping)
    PageIndex: Integer;
    Row, Col: Integer;        // assigned grid position (1-based)
    FontStyle: TFontStyles;
    FontSize: Integer;
    StyleId: Integer;         // resolved cellXf index
    FillColor: TColor;        // clNone = no fill
    BorderColor: TColor;      // clNone = no border
  end;

  // A rectangle/fill command captured for conservative geometry mapping.
  TXLSXShape = record
    Bounds: TRect;
    PageIndex: Integer;
    Color: TColor;
  end;

class procedure TReportXLSXExporter.ExportToFile(APages: TObjectList<TReportExportPage>;
  const AFileName: string);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(AFileName, fmCreate);
  try
    ExportToStream(APages, FS);
  finally
    FS.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Fill/border mapping heuristic (Phase 4I-7)
//
// The XLSX exporter previously consumed only TReportExportTextCommand; the
// fill and rectangle commands emitted for field backgrounds, field borders,
// shape fills and table grids were silently discarded.
//
// Mapping rule (conservative, deterministic):
//   A fill/rectangle command is applied ONLY to text cells whose full
//   generated bounds lie completely inside the command's geometry on the
//   same page. Commands that do not fully cover at least one text cell are
//   ignored - the exporter never guesses and never emits partial geometry.
//
//   This deliberately excludes barcode bars: each bar is a thin rectangle
//   that can never fully contain a text cell, so bars never become cell
//   styling. Pure white fills (the default page/cell background) are also
//   skipped so table/field backgrounds do not add redundant style entries.
//
// Supported command kinds:
//   TReportExportFillRectangleCommand - text/shape/table/barcode background
//     fills -> XLSX cell fill (when the coverage rule holds).
//   TReportExportRectangleCommand     - text/image/shape/table borders
//     -> XLSX cell border (when the coverage rule holds).
//
// TReportExportLineCommand and TReportExportImageCommand are NOT mapped.
// ---------------------------------------------------------------------------

function RectFullyCovers(const AOuter, AInner: TRect): Boolean;
begin
  Result := (AOuter.Left <= AInner.Left) and (AOuter.Top <= AInner.Top) and
    (AInner.Right <= AOuter.Right) and (AInner.Bottom <= AOuter.Bottom);
end;

function ColorToARGB(AColor: TColor): string;
begin
  // TColor is $00BBGGRR; OOXML wants FFRRGGBB.
  Result := Format('FF%.2X%.2X%.2X',
    [GetRValue(AColor), GetGValue(AColor), GetBValue(AColor)]);
end;

class procedure TReportXLSXExporter.ExportToStream(APages: TObjectList<TReportExportPage>;
  AStream: TStream);
var
  Zip: TZipFile;
  ContentTypes, Rels, Workbook, WorkbookRels, Sheet1, Styles: TStringStream;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  TextCmd: TReportExportTextCommand;
  FillCmd: TReportExportFillRectangleCommand;
  RectCmd: TReportExportRectangleCommand;
  AllCells: TList<TXLSXCell>;
  Cell: TXLSXCell;
  Shape: TXLSXShape;
  I: Integer;
  PageIdx: Integer;
  LastY: Integer;
  EscapedText: string;
  ColWidths: TDictionary<Integer, Integer>; // col index -> max text length
  ColIdxWidth: Integer;
  ColsElement: string;
  IsNumeric: Boolean;
  IsDate: Boolean;
  Dummy: Double;
  StyleId: Integer;
  ColLetter: string;
  // Fill/border capture and style-table bookkeeping
  Fills: TList<TXLSXShape>;
  Borders: TList<TXLSXShape>;
  FillIds: TDictionary<Integer, Integer>;   // TColor -> fill id (>= 2)
  BorderIds: TDictionary<Integer, Integer>; // TColor -> border id (>= 1)
  XfIds: TDictionary<string, Integer>;      // 'font:fill:border' -> cellXf id
  NextFillId, NextBorderId, NextXfId: Integer;
  FontId, FillId, BorderId, Key: Integer;
  XfKey: string;
  BorderColorText: string;
  FillsXml, BordersXml, CellXfsXml: string;
  SheetXml: string;
  CurrentRow: Integer;
  RowCounter, ColCounter: Integer;
  FillOrder, BorderOrder: TList<Integer>;  // deterministic creation order
  XfOrder: TList<string>;
const
  CApos = '&apos;';
begin
  AllCells := TList<TXLSXCell>.Create;
  ColWidths := TDictionary<Integer, Integer>.Create;
  Fills := TList<TXLSXShape>.Create;
  Borders := TList<TXLSXShape>.Create;
  FillIds := TDictionary<Integer, Integer>.Create;
  BorderIds := TDictionary<Integer, Integer>.Create;
  XfIds := TDictionary<string, Integer>.Create;
  FillOrder := TList<Integer>.Create;
  BorderOrder := TList<Integer>.Create;
  XfOrder := TList<string>.Create;
  try
    // Collect all text from all pages
    for PageIdx := 0 to APages.Count - 1 do
    begin
      Page := APages[PageIdx];
      for Cmd in Page.Commands do
      begin
        if Cmd is TReportExportTextCommand then
        begin
          TextCmd := TReportExportTextCommand(Cmd);
          if Trim(TextCmd.Text) <> '' then
          begin
            Cell.Text := TextCmd.Text;
            Cell.X := TextCmd.Bounds.Left;
            Cell.Y := TextCmd.Bounds.Top + (PageIdx * 2000); // offset pages vertically
            Cell.Bounds := TextCmd.Bounds;
            Cell.PageIndex := PageIdx;
            Cell.Row := 0;
            Cell.Col := 0;
            Cell.FontStyle := TextCmd.FontStyle;
            Cell.FontSize := TextCmd.FontSize;
            Cell.FillColor := clNone;
            Cell.BorderColor := clNone;
            AllCells.Add(Cell);
          end;
        end
        else if Cmd is TReportExportFillRectangleCommand then
        begin
          // Pure-white fills are the default background; skip them so
          // table/field backgrounds do not create redundant style entries.
          FillCmd := TReportExportFillRectangleCommand(Cmd);
          if FillCmd.FillColor <> clWhite then
          begin
            Shape.Bounds := FillCmd.Bounds;
            Shape.PageIndex := PageIdx;
            Shape.Color := FillCmd.FillColor;
            Fills.Add(Shape);
          end;
        end
        else if Cmd is TReportExportRectangleCommand then
        begin
          RectCmd := TReportExportRectangleCommand(Cmd);
          Shape.Bounds := RectCmd.Bounds;
          Shape.PageIndex := PageIdx;
          Shape.Color := RectCmd.BorderColor;
          Borders.Add(Shape);
        end;
      end;
    end;

    // Sort by Y, then by X
    AllCells.Sort(TComparer<TXLSXCell>.Construct(
      function(const Left, Right: TXLSXCell): Integer
      begin
        // Group by roughly 5 pixels
        if Abs(Left.Y - Right.Y) > 5 then
          Result := Left.Y - Right.Y
        else
          Result := Left.X - Right.X;
      end));

    // Assign grid row/column per cell and estimate column widths from content.
    // The row grouping logic (roughly 5 pixels) must stay identical to the
    // row emission pass below.
    LastY := -9999;
    RowCounter := 0;
    ColCounter := 0;
    for I := 0 to AllCells.Count - 1 do
    begin
      Cell := AllCells[I];
      if Abs(Cell.Y - LastY) > 5 then
      begin
        Inc(RowCounter);
        ColCounter := 1;
        LastY := Cell.Y;
      end
      else
        Inc(ColCounter);
      Cell.Row := RowCounter;
      Cell.Col := ColCounter;

      // Estimate width: each char ~1.1 units, minimum 8
      ColIdxWidth := Max(8, Ceil(Length(Cell.Text) * 1.1));
      if ColWidths.ContainsKey(Cell.Col) then
        ColWidths[Cell.Col] := Max(ColWidths[Cell.Col], ColIdxWidth)
      else
        ColWidths.Add(Cell.Col, ColIdxWidth);
      AllCells[I] := Cell;
    end;

    // Conservative fill/border mapping: a shape applies to a cell only when
    // the cell's full bounds are covered by the shape geometry on the same
    // page (see the heuristic notes at the top of this unit).
    for I := 0 to AllCells.Count - 1 do
    begin
      Cell := AllCells[I];
      for Key := 0 to Fills.Count - 1 do
      begin
        Shape := Fills[Key];
        if (Shape.PageIndex = Cell.PageIndex) and
           RectFullyCovers(Shape.Bounds, Cell.Bounds) then
        begin
          // First matching fill wins; keeps the result deterministic.
          Cell.FillColor := Shape.Color;
          Break;
        end;
      end;
      for Key := 0 to Borders.Count - 1 do
      begin
        Shape := Borders[Key];
        if (Shape.PageIndex = Cell.PageIndex) and
           RectFullyCovers(Shape.Bounds, Cell.Bounds) then
        begin
          Cell.BorderColor := Shape.Color;
          Break;
        end;
      end;
      AllCells[I] := Cell;
    end;

    // Build <cols> element for column widths
    ColsElement := '<cols>';
    for var ColPair in ColWidths do
    begin
      ColLetter := '';
      var CN := ColPair.Key;
      while CN > 0 do
      begin
        ColLetter := Char(64 + ((CN - 1) mod 26) + 1) + ColLetter;
        CN := (CN - 1) div 26;
      end;
      ColsElement := ColsElement + Format('<col min="%d" max="%d" width="%d" customWidth="1"/>',
        [ColPair.Key, ColPair.Key, ColPair.Value]);
    end;
    ColsElement := ColsElement + '</cols>';

    // Resolve a cellXf id for every cell. The first three xfs keep their
    // pre-existing font-only meaning (0=normal, 1=bold, 2=bold+italic);
    // fill/border variants are appended deterministically on first use.
    NextFillId := 2;   // fills 0 (none) and 1 (gray125) are the static entries
    NextBorderId := 1; // border 0 is the static empty border
    NextXfId := 3;     // xfs 0..2 are the static font-only entries
    XfIds.Add('0:0:0', 0);
    XfIds.Add('1:0:0', 1);
    XfIds.Add('2:0:0', 2);
    for I := 0 to AllCells.Count - 1 do
    begin
      Cell := AllCells[I];

      // Font id: identical to the pre-existing static mapping.
      if fsBold in Cell.FontStyle then
      begin
        if fsItalic in Cell.FontStyle then
          FontId := 2
        else
          FontId := 1;
      end
      else
        FontId := 0;

      if Cell.FillColor = clNone then
        FillId := 0
      else if not FillIds.TryGetValue(Cell.FillColor, FillId) then
      begin
        FillId := NextFillId;
        Inc(NextFillId);
        FillIds.Add(Cell.FillColor, FillId);
        FillOrder.Add(Cell.FillColor);
      end;

      if Cell.BorderColor = clNone then
        BorderId := 0
      else if not BorderIds.TryGetValue(Cell.BorderColor, BorderId) then
      begin
        BorderId := NextBorderId;
        Inc(NextBorderId);
        BorderIds.Add(Cell.BorderColor, BorderId);
        BorderOrder.Add(Cell.BorderColor);
      end;

      XfKey := Format('%d:%d:%d', [FontId, FillId, BorderId]);
      if not XfIds.TryGetValue(XfKey, Cell.StyleId) then
      begin
        Cell.StyleId := NextXfId;
        Inc(NextXfId);
        XfIds.Add(XfKey, Cell.StyleId);
        XfOrder.Add(XfKey);
      end;

      AllCells[I] := Cell;
    end;

    // Build styles.xml: the three static fonts are preserved unchanged;
    // fills, borders and cellXfs are extended dynamically with correct
    // OOXML count attributes.
    FillsXml := '';
    for Key := 0 to FillOrder.Count - 1 do
      FillsXml := FillsXml + Format('<fill><patternFill patternType="solid">' +
        '<fgColor rgb="%s"/><bgColor indexed="64"/></patternFill></fill>',
        [ColorToARGB(FillOrder[Key])]);

    BordersXml := '';
    for Key := 0 to BorderOrder.Count - 1 do
    begin
      BorderColorText := ColorToARGB(BorderOrder[Key]);
      BordersXml := BordersXml +
        '<border>' +
        '<left style="thin"><color rgb="' + BorderColorText + '"/></left>' +
        '<right style="thin"><color rgb="' + BorderColorText + '"/></right>' +
        '<top style="thin"><color rgb="' + BorderColorText + '"/></top>' +
        '<bottom style="thin"><color rgb="' + BorderColorText + '"/></bottom>' +
        '<diagonal/></border>';
    end;

    CellXfsXml :=
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +           // xf 0: default
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/>' +           // xf 1: bold
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/>';            // xf 2: bold+italic
    for Key := 0 to XfOrder.Count - 1 do
    begin
      var Parts := XfOrder[Key].Split([':']);
      CellXfsXml := CellXfsXml + Format(
        '<xf numFmtId="0" fontId="%s" fillId="%s" borderId="%s" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>',
        [Parts[0], Parts[1], Parts[2]]);
    end;

    Styles := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      '<fonts count="3">' +
      '<font><sz val="11"/><name val="Calibri"/></font>' +                          // style 0: default
      '<font><b/><sz val="11"/><name val="Calibri"/></font>' +                      // style 1: bold
      '<font><b/><i/><sz val="11"/><name val="Calibri"/></font>' +                  // style 2: bold+italic
      '</fonts>' +
      '<fills count="' + IntToStr(2 + FillOrder.Count) + '">' +
      '<fill><patternFill patternType="none"/></fill>' +
      '<fill><patternFill patternType="gray125"/></fill>' +
      FillsXml +
      '</fills>' +
      '<borders count="' + IntToStr(1 + BorderOrder.Count) + '"><border/>' +
      BordersXml +
      '</borders>' +
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
      '<cellXfs count="' + IntToStr(3 + XfOrder.Count) + '">' +
      CellXfsXml +
      '</cellXfs>' +
      '</styleSheet>', TEncoding.UTF8);

    // Generate XML streams
    ContentTypes := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
      '</Types>', TEncoding.UTF8);

    Rels := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
      '</Relationships>', TEncoding.UTF8);

    Workbook := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>' +
      '</workbook>', TEncoding.UTF8);

    WorkbookRels := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
      '</Relationships>', TEncoding.UTF8);

    // The worksheet XML is assembled as a plain string and wrapped in a
    // TStringStream afterwards. (Appending to an already-constructed UTF-8
    // TStringStream produced corrupted entry data in TZipFile.Add.)
    SheetXml := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      ColsElement +
      '<sheetData>';

    try
      // Build rows using the grid positions assigned in the pre-pass above
      // (identical row grouping: rows change when Y moves more than 5 px).
      CurrentRow := 0;

      for I := 0 to AllCells.Count - 1 do
      begin
        Cell := AllCells[I];

        if Cell.Row <> CurrentRow then
        begin
          if CurrentRow > 0 then
            SheetXml := SheetXml + '</row>';
          CurrentRow := Cell.Row;
          SheetXml := SheetXml + '<row r="' + IntToStr(CurrentRow) + '">';
        end;

        // Escape XML chars
        EscapedText := Cell.Text;
        EscapedText := StringReplace(EscapedText, '&', '&amp;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '<', '&lt;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '>', '&gt;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '"', '&quot;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, #39, CApos, [rfReplaceAll]);

        // Resolved cellXf: font-only ids 0..2 match the historical mapping;
        // fill/border variants were appended in the style resolution pass.
        StyleId := Cell.StyleId;

        // Detect numeric/date content for number format
        IsNumeric := TryStrToFloat(Cell.Text, Dummy);
        IsDate := False;
        if not IsNumeric then
        begin
          // Simple date detection: matches common date patterns
          var Trimmed := Trim(Cell.Text);
          if (Length(Trimmed) >= 8) and (Length(Trimmed) <= 10) then
            IsDate := (Pos('/', Trimmed) > 0) or (Pos('-', Trimmed) > 0) or (Pos('.', Trimmed) > 0);
        end;

        // Build cell reference (supports A-ZZ columns)
        ColLetter := '';
        var CN := Cell.Col;
        while CN > 0 do
        begin
          ColLetter := Char(64 + ((CN - 1) mod 26) + 1) + ColLetter;
          CN := (CN - 1) div 26;
        end;

        if IsNumeric then
          SheetXml := SheetXml + Format('<c r="%s%d" s="%d"><v>%s</v></c>',
            [ColLetter, Cell.Row, StyleId, StringReplace(Cell.Text, ',', '.', [])])
        else
          SheetXml := SheetXml + Format('<c r="%s%d" s="%d" t="inlineStr"><is><t>%s</t></is></c>',
            [ColLetter, Cell.Row, StyleId, EscapedText]);
      end;
      if CurrentRow > 0 then
        SheetXml := SheetXml + '</row>';

      SheetXml := SheetXml + '</sheetData></worksheet>';
      Sheet1 := TStringStream.Create(SheetXml, TEncoding.UTF8);
      Sheet1.Position := 0;
      Styles.Position := 0;
      ContentTypes.Position := 0;
      Rels.Position := 0;
      Workbook.Position := 0;
      WorkbookRels.Position := 0;

      Zip := TZipFile.Create;
      try
        Zip.Open(AStream, zmWrite);
        Zip.Add(ContentTypes, '[Content_Types].xml');
        Zip.Add(Rels, '_rels/.rels');
        Zip.Add(Workbook, 'xl/workbook.xml');
        Zip.Add(WorkbookRels, 'xl/_rels/workbook.xml.rels');
        Zip.Add(Sheet1, 'xl/worksheets/sheet1.xml');
        Zip.Add(Styles, 'xl/styles.xml');
        Zip.Close;
      finally
        Zip.Free;
      end;
    finally
      Styles.Free;
      ContentTypes.Free;
      Rels.Free;
      Workbook.Free;
      WorkbookRels.Free;
      Sheet1.Free;
    end;
  finally
    XfOrder.Free;
    BorderOrder.Free;
    FillOrder.Free;
    XfIds.Free;
    BorderIds.Free;
    FillIds.Free;
    Borders.Free;
    Fills.Free;
    ColWidths.Free;
    AllCells.Free;
  end;
end;

end.