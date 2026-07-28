unit Vittix.Report.Export.XLSX;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Zip,
  Vittix.Report.Export.Commands;

type
  TReportXLSXExporter = class
  public
    class procedure ExportToStream(APages: TObjectList<TReportExportPage>; AStream: TStream);
    class procedure ExportToFile(APages: TObjectList<TReportExportPage>; const AFileName: string);
  end;

implementation

uses
  System.Types;

type
  // Helper to store grouped text objects for grid mapping
  TXLSXCell = record
    Text: string;
    X, Y: Integer;
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
  ContentTypes, Rels, Workbook, WorkbookRels, Sheet1: TStringStream;
  Page: TReportExportPage;
  Cmd: TReportExportCommand;
  TextCmd: TReportExportTextCommand;
  AllCells: TList<TXLSXCell>;
  Cell: TXLSXCell;
  I: Integer;
  RowIdx, ColIdx: Integer;
  LastY: Integer;
  EscapedText: string;
begin
  AllCells := TList<TXLSXCell>.Create;
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

    // Generate XML streams
    ContentTypes := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
      '<Default Extension="xml" ContentType="application/xml"/>' +
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
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
      '</Relationships>', TEncoding.UTF8);

    Sheet1 := TStringStream.Create('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
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
        EscapedText := StringReplace(EscapedText, '''', '&apos;', [rfReplaceAll]);

        Sheet1.WriteString('<c r="' + string(Char(64 + ColIdx)) + IntToStr(RowIdx) + '" t="inlineStr"><is><t>' + EscapedText + '</t></is></c>');
      end;
      if RowIdx > 0 then
        Sheet1.WriteString('</row>');

      Sheet1.WriteString('</sheetData></worksheet>');
      Sheet1.Position := 0;
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
        Zip.Close;
      finally
        Zip.Free;
      end;
    finally
      ContentTypes.Free;
      Rels.Free;
      Workbook.Free;
      WorkbookRels.Free;
      Sheet1.Free;
    end;
  finally
    AllCells.Free;
  end;
end;

end.
