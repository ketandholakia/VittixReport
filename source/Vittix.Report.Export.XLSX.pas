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
  System.Types;

type
  // Helper to store grouped text objects for grid mapping
  TXLSXCell = record
    Text: string;
    X, Y: Integer;
    FontStyle: TFontStyles;
    FontSize: Integer;
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

class procedure TReportXLSXExporter.ExportToStream(APages: TObjectList<TReportExportPage>;
  AStream: TStream);
var
  Zip: TZipFile;
  ContentTypes, Rels, Workbook, WorkbookRels, Sheet1, Styles: TStringStream;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  TextCmd: TReportExportTextCommand;
  AllCells: TList<TXLSXCell>;
  Cell: TXLSXCell;
  I: Integer;
  RowIdx, ColIdx: Integer;
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
const
  CApos = '&apos;';
begin
  AllCells := TList<TXLSXCell>.Create;
  ColWidths := TDictionary<Integer, Integer>.Create;
  try
    // Collect all text from all pages
    for Page in APages do
    begin
      for Cmd in Page.Commands do
      begin
        if Cmd is TReportExportTextCommand then
        begin
          TextCmd := TReportExportTextCommand(Cmd);
          if Trim(TextCmd.Text) <> '' then
          begin
            Cell.Text := TextCmd.Text;
            Cell.X := TextCmd.Bounds.Left;
            Cell.Y := TextCmd.Bounds.Top + (APages.IndexOf(Page) * 2000); // offset pages vertically
            Cell.FontStyle := TextCmd.FontStyle;
            Cell.FontSize := TextCmd.FontSize;
            AllCells.Add(Cell);
          end;
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

    // Estimate column widths from content
    RowIdx := 0;
    ColIdx := 0;
    LastY := -9999;
    for I := 0 to AllCells.Count - 1 do
    begin
      Cell := AllCells[I];
      if Abs(Cell.Y - LastY) > 5 then
      begin
        Inc(RowIdx);
        ColIdx := 1;
        LastY := Cell.Y;
      end
      else
        Inc(ColIdx);

      // Estimate width: each char ~1.1 units, minimum 8
      ColIdxWidth := Max(8, Ceil(Length(Cell.Text) * 1.1));
      if ColWidths.ContainsKey(ColIdx) then
        ColWidths[ColIdx] := Max(ColWidths[ColIdx], ColIdxWidth)
      else
        ColWidths.Add(ColIdx, ColIdxWidth);
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

    // Build minimal styles.xml with font styles
    Styles := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      '<fonts count="3">' +
      '<font><sz val="11"/><name val="Calibri"/></font>' +                          // style 0: default
      '<font><b/><sz val="11"/><name val="Calibri"/></font>' +                      // style 1: bold
      '<font><b/><i/><sz val="11"/><name val="Calibri"/></font>' +                  // style 2: bold+italic
      '</fonts>' +
      '<fills count="2">' +
      '<fill><patternFill patternType="none"/></fill>' +
      '<fill><patternFill patternType="gray125"/></fill>' +
      '</fills>' +
      '<borders count="1"><border/></borders>' +
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
      '<cellXfs count="3">' +
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +           // xf 0: default
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/>' +           // xf 1: bold
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/>' +           // xf 2: bold+italic
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

    Sheet1 := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      ColsElement +
      '<sheetData>', TEncoding.UTF8);

    try
      // Build rows
      RowIdx := 0;
      ColIdx := 0;
      LastY := -9999;

      for I := 0 to AllCells.Count - 1 do
      begin
        Cell := AllCells[I];

        if Abs(Cell.Y - LastY) > 5 then
        begin
          if RowIdx > 0 then
            Sheet1.WriteString('</row>');
          Inc(RowIdx);
          ColIdx := 1;
          Sheet1.WriteString('<row r="' + IntToStr(RowIdx) + '">');
          LastY := Cell.Y;
        end
        else
          Inc(ColIdx);

        // Escape XML chars
        EscapedText := Cell.Text;
        EscapedText := StringReplace(EscapedText, '&', '&amp;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '<', '&lt;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '>', '&gt;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, '"', '&quot;', [rfReplaceAll]);
        EscapedText := StringReplace(EscapedText, #39, CApos, [rfReplaceAll]);

        // Determine style: 0=normal, 1=bold, 2=bold+italic
        StyleId := 0;
        if fsBold in Cell.FontStyle then
        begin
          if fsItalic in Cell.FontStyle then
            StyleId := 2
          else
            StyleId := 1;
        end;

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
        var CN := ColIdx;
        while CN > 0 do
        begin
          ColLetter := Char(64 + ((CN - 1) mod 26) + 1) + ColLetter;
          CN := (CN - 1) div 26;
        end;

        if IsNumeric then
          Sheet1.WriteString(Format('<c r="%s%d" s="%d"><v>%s</v></c>',
            [ColLetter, RowIdx, StyleId, StringReplace(Cell.Text, ',', '.', [])]))
        else
          Sheet1.WriteString(Format('<c r="%s%d" s="%d" t="inlineStr"><is><t>%s</t></is></c>',
            [ColLetter, RowIdx, StyleId, EscapedText]));
      end;
      if RowIdx > 0 then
        Sheet1.WriteString('</row>');

      Sheet1.WriteString('</sheetData></worksheet>');
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
    ColWidths.Free;
    AllCells.Free;
  end;
end;

end.