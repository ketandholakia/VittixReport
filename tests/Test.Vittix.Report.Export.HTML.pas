unit Test.Vittix.Report.Export.HTML;

{
  Phase 4I-2: HTML export hardening tests.

  Covers the two confirmed defects (font-name HTML attribute escaping and
  file:/// URI percent-encoding) plus pinned image-failure behavior and
  normal-output sanity.  Documents are built in memory and exported to a
  stream — no regression baselines, no runner, no machine-specific paths.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.HTML;

type
  [TestFixture]
  TExportHTMLTests = class
  private
    function TextDoc(const AFontName, AText: string): string;
    function ImageDoc(const ASource: string): string;
  public
    [Test] procedure Test_FontName_Hostile_IsEscaped;
    [Test] procedure Test_FontName_Normal_Unchanged;
    [Test] procedure Test_FileURI_SpecialCharacters_Encoded;
    [Test] procedure Test_UnicodeFileName_PercentEncoded;
    [Test] procedure Test_MissingImage_FallsBackToFileURI;
    [Test] procedure Test_InvalidPNG_DataURIPinned;
    [Test] procedure Test_NormalOutput_StructurallyValid;
    [Test] procedure Test_EllipseCommand_VectorRepresentation;
  end;

implementation

uses
  System.StrUtils,
  System.NetEncoding,
  System.IOUtils;

function TExportHTMLTests.TextDoc(const AFontName, AText: string): string;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportTextCommand;
  Ms: TStringStream;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    Cmd := TReportExportTextCommand.Create;
    Cmd.Bounds := Rect(10, 10, 300, 40);
    Cmd.FontName := AFontName;
    Cmd.Text := AText;
    Page.Commands.Add(Cmd);

    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      Result := Ms.DataString;
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TExportHTMLTests.ImageDoc(const ASource: string): string;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportImageCommand;
  Ms: TStringStream;
begin
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    Cmd := TReportExportImageCommand.Create;
    Cmd.Bounds := Rect(10, 10, 200, 100);
    Cmd.Source := ASource;
    Page.Commands.Add(Cmd);

    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      Result := Ms.DataString;
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TExportHTMLTests.Test_FontName_Hostile_IsEscaped;
var
  HTML, FontName: string;
begin
  FontName := 'Arial "x" & <B>'';q';
  HTML := TextDoc(FontName, 'Hello');

  // The raw font name must not appear anywhere (a raw " would have
  // terminated the style attribute).
  Assert.IsFalse(ContainsText(HTML, FontName),
    'raw hostile font name leaked into the HTML');

  // HTML attribute escaping must be present for every dangerous character.
  Assert.Contains(HTML, '&quot;');
  Assert.Contains(HTML, '&amp;');
  Assert.Contains(HTML, '&lt;');
  Assert.Contains(HTML, '&gt;');
  Assert.Contains(HTML, '&#39;');

  // The CSS font-family declaration stays syntactically contained inside
  // the style attribute (single quotes preserved as entities).

  // Document structure around the attribute remains intact.
  Assert.Contains(HTML, '</div>');
  Assert.Contains(HTML, '</html>');
end;

procedure TExportHTMLTests.Test_FontName_Normal_Unchanged;
var
  HTML: string;
begin
  HTML := TextDoc('Segoe UI', 'Hello');
  // Normal font names (incl. a space) must be functionally unchanged.
  Assert.Contains(HTML, 'font-family:''Segoe UI'',sans-serif');
  Assert.Contains(HTML, 'Hello');
  Assert.Contains(HTML, '<!DOCTYPE html>');
end;

procedure TExportHTMLTests.Test_FileURI_SpecialCharacters_Encoded;
var
  HTML: string;
begin
  // Missing files exercise the file:/// fallback deterministically.
  HTML := ImageDoc('C:\report\My Image.png');
  Assert.Contains(HTML, 'My%20Image.png');
  Assert.Contains(HTML, 'file:///C:/report/');

  HTML := ImageDoc('C:\report\A#B.png');
  Assert.Contains(HTML, 'A%23B.png');
  Assert.IsFalse(ContainsText(HTML, 'A#B.png'), 'raw # truncates the URI');

  HTML := ImageDoc('C:\report\100%.png');
  Assert.Contains(HTML, '100%25.png');

  HTML := ImageDoc('C:\report\A?B.png');
  Assert.Contains(HTML, 'A%3FB.png');
end;

procedure TExportHTMLTests.Test_UnicodeFileName_PercentEncoded;
var
  HTML: string;
begin
  // UTF-8 bytes of the CJK characters must be percent-encoded.
  HTML := ImageDoc('C:\data\' + #$4E2D#$6587 + '.png');
  Assert.Contains(HTML, '%E4%B8%AD%E6%96%87.png');
end;

procedure TExportHTMLTests.Test_MissingImage_FallsBackToFileURI;
var
  HTML: string;
begin
  // Pin current best-effort behavior: a missing image must not raise and
  // must still produce the file:/// fallback reference.
  HTML := ImageDoc('C:\report\does_not_exist.png');
  Assert.Contains(HTML, 'file:///C:/report/does_not_exist.png');
  Assert.Contains(HTML, '<img class="vrt-img"');
end;

procedure TExportHTMLTests.Test_InvalidPNG_DataURIPinned;
var
  TmpDir: string;
  HTML: string;
  Fs: TFileStream;
begin
  // An existing .png file is base64-embedded regardless of pixel validity;
  // pin that behavior (TryGetBase64Image reads bytes, no decoding).
  TmpDir := TPath.Combine(TPath.GetTempPath, 'vittix_4i2_htmltest');
  TDirectory.CreateDirectory(TmpDir);
  try
    Fs := TFileStream.Create(TPath.Combine(TmpDir, 'corrupt.png'), fmCreate);
    try
      Fs.Size := 8; // 8 zero bytes: not a valid PNG, but readable
    finally
      Fs.Free;
    end;

    HTML := ImageDoc(TPath.Combine(TmpDir, 'corrupt.png'));
    Assert.Contains(HTML, 'data:image/png;base64,');
    Assert.IsFalse(ContainsText(HTML, 'file:///'),
      'existing .png must take the base64 path, not the file:/// fallback');
  finally
    TDirectory.Delete(TmpDir, True);
  end;
end;

procedure TExportHTMLTests.Test_NormalOutput_StructurallyValid;
var
  HTML: string;
begin
  HTML := TextDoc('Arial', 'Report output');
  Assert.Contains(HTML, '<!DOCTYPE html>');
  Assert.Contains(HTML, '<html>');
  Assert.Contains(HTML, '</html>');
  Assert.Contains(HTML, '<body>');
  Assert.Contains(HTML, '</body>');
  Assert.Contains(HTML, 'Report output');
  Assert.Contains(HTML, 'width: 793px; height: 1122px;');
end;

procedure TExportHTMLTests.Test_EllipseCommand_VectorRepresentation;
var
  Doc: TReportExportDocument;
  Page: TReportExportPage;
  Cmd: TReportExportEllipseCommand;
  Ms: TStringStream;
  HTML: string;
begin
  // In-memory document with a single ellipse command (fill + border).
  Doc := TReportExportDocument.Create;
  try
    Page := Doc.AddPage(793, 1122);
    Cmd := TReportExportEllipseCommand.Create;
    Cmd.Bounds := Rect(20, 30, 220, 130);
    Cmd.HasFill := True;
    Cmd.FillColor := $000000FF;  // clRed -> #ff0000
    Cmd.HasBorder := True;
    Cmd.BorderColor := $00FF0000; // clBlue -> #0000ff
    Cmd.BorderWidth := 2;
    Page.Commands.Add(Cmd);

    Ms := TStringStream.Create('', TEncoding.UTF8);
    try
      TReportHTMLExporter.ExportDocument(Doc, Ms);
      HTML := Ms.DataString;

      // A real SVG ellipse element must be present (not just a div).
      Assert.Contains(HTML, '<ellipse cx="');
      Assert.Contains(HTML, 'cy="');
      // Geometry: bounds 200x100 -> rx=100, ry=50, offset by border padding.
      Assert.Contains(HTML, 'rx="100"');
      Assert.Contains(HTML, 'ry="50"');
      // Fill/border information is represented.
      Assert.Contains(HTML, 'fill="#ff0000"');
      Assert.Contains(HTML, 'stroke="#0000ff"');
      Assert.Contains(HTML, 'stroke-width="2"');
    finally
      Ms.Free;
    end;
  finally
    Doc.Free;
  end;
end;


initialization
  TDUnitX.RegisterTestFixture(TExportHTMLTests);

end.
