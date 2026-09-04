unit Test.Vittix.Report.Export.XLSX;

{
  Phase 4I-7: XLSX export cell fill/border fidelity tests.

  Documents are built in memory from export commands and exported to a
  stream; the generated package is opened with TZipFile and the worksheet
  and style parts are asserted structurally.  No report files, no runner
  and no machine-specific paths are involved.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TExportXLSXTests = class
  private
    function ExportToBytes(ADoc: TReportExportDocument): TBytes;
    function TextCmd(const AText: string; const ABounds: TRect;
      AStyle: TFontStyles = []): TReportExportTextCommand;
  public
    [Test] procedure Test_TextCell_InlineString_Emitted;
    [Test] procedure Test_NumericCell_Value_Emitted;
    [Test] procedure Test_BoldStyle_Preserved;
    [Test] procedure Test_FillRectangle_BecomesCellFill;
    [Test] procedure Test_BorderRectangle_BecomesCellBorder;
    [Test] procedure Test_AllParts_WellFormedXml;
    [Test] procedure Test_EmptyDocument_ValidPackage;
    [Test] procedure Test_BarcodeBar_NotConvertedToCellFill;
    [Test] procedure Test_UncoveredRectangle_Ignored;
  end;

implementation

uses
  System.IOUtils,
  Vcl.Graphics,
  System.Zip,
  Xml.XMLDoc,
  Xml.XMLIntf,
  Winapi.ActiveX,
  Vittix.Report.Export.XLSX;

function TExportXLSXTests.ExportToBytes(ADoc: TReportExportDocument): TBytes;
var
  TempFile: string;
begin
  // Export through the public file API to a temporary file, then read the
  // package bytes back. Keeps the test independent of stream-zip quirks.
  TempFile := TPath.ChangeExtension(TPath.GetTempFileName, '.xlsx');
  try
    TReportXLSXExporter.ExportToFile(ADoc.Pages, TempFile);
    Result := TFile.ReadAllBytes(TempFile);
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

function TExportXLSXTests.TextCmd(const AText: string; const ABounds: TRect;
  AStyle: TFontStyles): TReportExportTextCommand;
begin
  Result := TReportExportTextCommand.Create;
  Result.Text := AText;
  Result.Bounds := ABounds;
  Result.FontStyle := AStyle;
end;

function ReadZipEntry(const APkg: TBytes; const AName: string): string;
var
  Zip: TZipFile;
  TempFile: string;
  Buffer: TBytes;
begin
  TempFile := TPath.ChangeExtension(TPath.GetTempFileName, '.xlsx');
  try
    TFile.WriteAllBytes(TempFile, APkg);
    Zip := TZipFile.Create;
    try
      Zip.Open(TempFile, zmRead);
      Zip.Read(AName, Buffer);
      Result := TEncoding.UTF8.GetString(Buffer);
    finally
      Zip.Free;
    end;
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

function ZipHasEntry(const APkg: TBytes; const AName: string): Boolean;
var
  Zip: TZipFile;
  TempFile: string;
begin
  TempFile := TPath.ChangeExtension(TPath.GetTempFileName, '.xlsx');
  try
    TFile.WriteAllBytes(TempFile, APkg);
    Zip := TZipFile.Create;
    try
      Zip.Open(TempFile, zmRead);
      Result := Zip.IndexOf(AName) >= 0;
    finally
      Zip.Free;
    end;
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

procedure AssertXmlWellFormed(const AXml: string);
var
  Doc: IXMLDocument;
begin
  // Raises EXMLDocError on malformed XML.
  Doc := NewXMLDocument;
  Doc.XML.Text := AXml;
  Doc.Active := True;
  Assert.IsTrue(Doc.DocumentElement <> nil);
end;

{ TExportXLSXTests }

procedure TExportXLSXTests.Test_TextCell_InlineString_Emitted;
var
  Doc: TReportExportDocument;
  Pkg: TBytes;
  Sheet: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Doc.AddPage(793, 1122).Commands.Add(TextCmd('Hello World', Rect(10, 10, 300, 40)));
    Pkg := ExportToBytes(Doc);
    Assert.IsTrue(ZipHasEntry(Pkg, 'xl/worksheets/sheet1.xml'));
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    Assert.Contains(Sheet, 'r="A1"');
    Assert.Contains(Sheet, 't="inlineStr"');
    Assert.Contains(Sheet, '<t>Hello World</t>');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_NumericCell_Value_Emitted;
var
  Doc: TReportExportDocument;
  Pkg: TBytes;
  Sheet: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Doc.AddPage(793, 1122).Commands.Add(TextCmd('42', Rect(10, 10, 300, 40)));
    Pkg := ExportToBytes(Doc);
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    // Numeric cells are emitted as raw <v> values without t="inlineStr".
    Assert.Contains(Sheet, '<c r="A1" s="0"><v>42</v></c>');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_BoldStyle_Preserved;
var
  Doc: TReportExportDocument;
  Pkg: TBytes;
  Sheet, Styles: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Doc.AddPage(793, 1122).Commands.Add(
      TextCmd('Bold text', Rect(10, 10, 300, 40), [fsBold]));
    Pkg := ExportToBytes(Doc);
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    Styles := ReadZipEntry(Pkg, 'xl/styles.xml');
    // Bold cell uses the historical static xf 1.
    Assert.Contains(Sheet, 's="1"');
    Assert.Contains(Styles, '<font><b/><sz val="11"/><name val="Calibri"/></font>');
    Assert.Contains(Styles, '<cellXfs count="3">');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_FillRectangle_BecomesCellFill;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  FillCmd: TReportExportFillRectangleCommand;
  Pkg: TBytes;
  Sheet, Styles: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    // A background fill fully covering the text cell.
    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := Rect(5, 5, 310, 50);
    FillCmd.FillColor := clYellow;
    Page.Commands.Add(FillCmd);
    Page.Commands.Add(TextCmd('Filled', Rect(10, 10, 300, 40)));
    Pkg := ExportToBytes(Doc);
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    Styles := ReadZipEntry(Pkg, 'xl/styles.xml');
    // A solid yellow fill definition exists (clYellow -> FFFFFF00).
    Assert.Contains(Styles, '<fills count="3">');
    Assert.Contains(Styles, '<fgColor rgb="FFFFFF00"/>');
    // The affected cell keeps its text and references a composed xf
    // (font 0, fill 2, border 0 -> deterministic id 3, fillId="2").
    Assert.Contains(Sheet, 's="3"');
    Assert.Contains(Sheet, '<t>Filled</t>');
    Assert.Contains(Styles, 'fillId="2"');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_BorderRectangle_BecomesCellBorder;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  RectCmd: TReportExportRectangleCommand;
  Pkg: TBytes;
  Sheet, Styles: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    // A border rectangle fully covering the text cell.
    RectCmd := TReportExportRectangleCommand.Create;
    RectCmd.Bounds := Rect(5, 5, 310, 50);
    RectCmd.BorderColor := clBlack;
    Page.Commands.Add(RectCmd);
    Page.Commands.Add(TextCmd('Bordered', Rect(10, 10, 300, 40)));
    Pkg := ExportToBytes(Doc);
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    Styles := ReadZipEntry(Pkg, 'xl/styles.xml');
    // A thin black border definition exists.
    Assert.Contains(Styles, '<borders count="2">');
    Assert.Contains(Styles, '<left style="thin"><color rgb="FF000000"/></left>');
    // The cell keeps its text and references a bordered xf (borderId="1").
    Assert.Contains(Sheet, '<t>Bordered</t>');
    Assert.Contains(Styles, 'borderId="1"');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_AllParts_WellFormedXml;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  FillCmd: TReportExportFillRectangleCommand;
  RectCmd: TReportExportRectangleCommand;
  Pkg: TBytes;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := Rect(5, 5, 310, 50);
    FillCmd.FillColor := clYellow;
    Page.Commands.Add(FillCmd);
    RectCmd := TReportExportRectangleCommand.Create;
    RectCmd.Bounds := Rect(5, 5, 310, 50);
    Page.Commands.Add(RectCmd);
    Page.Commands.Add(TextCmd('A & B <tag>', Rect(10, 10, 300, 40)));
    Page.Commands.Add(TextCmd('Bold & "quoted"', Rect(10, 50, 300, 80), [fsBold]));
    Pkg := ExportToBytes(Doc);
    AssertXmlWellFormed(ReadZipEntry(Pkg, '[Content_Types].xml'));
    AssertXmlWellFormed(ReadZipEntry(Pkg, '_rels/.rels'));
    AssertXmlWellFormed(ReadZipEntry(Pkg, 'xl/workbook.xml'));
    AssertXmlWellFormed(ReadZipEntry(Pkg, 'xl/_rels/workbook.xml.rels'));
    AssertXmlWellFormed(ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml'));
    AssertXmlWellFormed(ReadZipEntry(Pkg, 'xl/styles.xml'));
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_EmptyDocument_ValidPackage;
var
  Doc: TReportExportDocument;
  Pkg: TBytes;
  Sheet: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Doc.AddPage(793, 1122);
    Pkg := ExportToBytes(Doc);
    Assert.IsTrue(ZipHasEntry(Pkg, 'xl/worksheets/sheet1.xml'));
    Assert.IsTrue(ZipHasEntry(Pkg, 'xl/styles.xml'));
    Sheet := ReadZipEntry(Pkg, 'xl/worksheets/sheet1.xml');
    AssertXmlWellFormed(Sheet);
    Assert.Contains(Sheet, '</sheetData>');
    Assert.DoesNotContain(Sheet, '<c r=');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_BarcodeBar_NotConvertedToCellFill;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Bar: TReportExportFillRectangleCommand;
  I: Integer;
  Pkg: TBytes;
  Styles: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    Page.Commands.Add(TextCmd('12345', Rect(10, 10, 200, 40)));
    // Barcode-like narrow bars next to the text: none of them fully covers
    // the text cell, so none may become a cell fill.
    for I := 0 to 4 do
    begin
      Bar := TReportExportFillRectangleCommand.Create;
      Bar.Bounds := Rect(210 + I * 6, 10, 214 + I * 6, 40);
      Bar.FillColor := clBlack;
      Page.Commands.Add(Bar);
    end;
    Pkg := ExportToBytes(Doc);
    Styles := ReadZipEntry(Pkg, 'xl/styles.xml');
    // Only the two static fills exist - no barcode bar became a fill.
    Assert.Contains(Styles, '<fills count="2">');
    Assert.DoesNotContain(Styles, '<fgColor rgb="FF000000"/>');
  finally
    Doc.Free;
  end;
end;

procedure TExportXLSXTests.Test_UncoveredRectangle_Ignored;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  FillCmd: TReportExportFillRectangleCommand;
  Pkg: TBytes;
  Styles: string;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    Page.Commands.Add(TextCmd('Cell', Rect(10, 10, 300, 40)));
    // A fill that does not cover the text cell must be ignored.
    FillCmd := TReportExportFillRectangleCommand.Create;
    FillCmd.Bounds := Rect(400, 100, 500, 200);
    FillCmd.FillColor := clRed;
    Page.Commands.Add(FillCmd);
    Pkg := ExportToBytes(Doc);
    Styles := ReadZipEntry(Pkg, 'xl/styles.xml');
    Assert.Contains(Styles, '<fills count="2">');
    Assert.DoesNotContain(Styles, '<fgColor rgb="FFFF0000"/>');
  finally
    Doc.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExportXLSXTests);

end.
