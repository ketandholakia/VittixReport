unit Test.Vittix.Report.Export.Email;

{
  Email export temp-file safety (v1.0 freeze fix).

  TReportEmailExporter used to write the PDF to %TEMP%\<Title>.pdf under the
  RAW report title, so a second export with the same title overwrote the
  first, and the post-send cleanup DELETED whatever file occupied that name -
  including a file the user happened to have there.  Non-ASCII titles
  (Gujarati/Hindi) were also destroyed on the way into AnsiString MAPI
  fields and file names.

  The fix writes each export into a NEW GUID-named folder under %TEMP%,
  names the file from the ASCII-sanitized title (fallback 'Report'), builds
  the MAPI subject from the same sanitized title, and deletes only its own
  GUID folder afterwards.  These tests pin the sanitizing and path
  behavior; the MAPI call itself is deliberately not tested.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Vittix.Report.Export.Email;

type
  [TestFixture]
  TExportEmailTests = class
  private
    procedure CleanupFolderOf(const APath: string);
  public
    [Test] procedure Test_Sanitize_GujaratiTitle_FallsBackToReport;
    [Test] procedure Test_Sanitize_MixedTitle_KeepsAsciiOnly;
    [Test] procedure Test_Sanitize_EmptyTitle_FallsBackToReport;
    [Test] procedure Test_TempPdfPath_TwoCalls_NeverSamePath;
    [Test] procedure Test_TempPdfPath_LivesInNewGuidFolder_WithAsciiName;
    [Test] procedure Test_TempPdfPath_NeverTouchesExistingTempTitleFile;
  end;

implementation

procedure TExportEmailTests.CleanupFolderOf(const APath: string);
begin
  try
    if TDirectory.Exists(ExtractFilePath(APath)) then
      TDirectory.Delete(ExtractFilePath(APath), True);
  except
    // best-effort test cleanup
  end;
end;

procedure TExportEmailTests.Test_Sanitize_GujaratiTitle_FallsBackToReport;
var
  S: string;
begin
  // Pure Gujarati title - no ASCII survives, so the fallback applies.
  S := TReportEmailExporter.SanitizeTitleToAscii(#$0AB5#$0ACB#$0A9C#$0AB0#$0ABE#$0AA4#$0AB0#$0ABF#$0AAA#$0ACB#$0AB0#$0ACD#$0A9F);
  Assert.AreEqual('Report', S, 'pure non-ASCII title must fall back to Report');
end;

procedure TExportEmailTests.Test_Sanitize_MixedTitle_KeepsAsciiOnly;
var
  S: string;
  C: Char;
begin
  // Gujarati words around an ASCII core.
  S := TReportEmailExporter.SanitizeTitleToAscii(
    #$0AB5#$0ACB#$0A9C#$0AB0#$0ABE#$0AA4' Invoice 2026-Q3');
  Assert.AreEqual('Invoice 2026-Q3', S,
    'the ASCII core must survive and non-ASCII words must be dropped');
  for C in S do
    Assert.IsTrue(Ord(C) < 128, 'sanitized title must be ASCII-only');
end;

procedure TExportEmailTests.Test_Sanitize_EmptyTitle_FallsBackToReport;
begin
  Assert.AreEqual('Report', TReportEmailExporter.SanitizeTitleToAscii(''),
    'empty title must fall back to Report');
  Assert.AreEqual('Report', TReportEmailExporter.SanitizeTitleToAscii('   '),
    'whitespace-only title must fall back to Report');
end;

procedure TExportEmailTests.Test_TempPdfPath_TwoCalls_NeverSamePath;
var
  P1, P2: string;
begin
  P1 := TReportEmailExporter.TempPdfPath('Sales Report');
  P2 := TReportEmailExporter.TempPdfPath('Sales Report');
  try
    Assert.AreNotEqual(P1, P2, 'two exports must never share a temp path');
  finally
    CleanupFolderOf(P1);
    CleanupFolderOf(P2);
  end;
end;

procedure TExportEmailTests.Test_TempPdfPath_LivesInNewGuidFolder_WithAsciiName;
var
  P: string;
  Folder: string;
begin
  P := TReportEmailExporter.TempPdfPath(#$0AB5#$0ACB#$0A9C#$0AB0#$0ABE#$0AA4' Sales');
  try
    Folder := ExtractFilePath(P);
    Assert.IsTrue(TDirectory.Exists(Folder),
      'TempPdfPath must create its own folder under %TEMP%');
    Assert.IsTrue(Pos(LowerCase(TPath.GetTempPath), LowerCase(Folder)) = 1,
      'the new folder must live under %TEMP%');
    // The Gujarati words drop out and the ASCII core 'Sales' names the file;
    // a title with NO ASCII at all falls back to 'Report' (pinned above).
    Assert.AreEqual('Sales.pdf', ExtractFileName(P).ToLower,
      'the file name must come from the sanitized ASCII title');
    Assert.IsFalse(TFile.Exists(P), 'TempPdfPath must not create the PDF itself');
  finally
    CleanupFolderOf(P);
  end;
end;

procedure TExportEmailTests.Test_TempPdfPath_NeverTouchesExistingTempTitleFile;
var
  Sentinel, P: string;
begin
  // A user file squatting on the OLD naming scheme (%TEMP%\<Title>.pdf)
  // must never be overwritten or deleted by the exporter's temp handling.
  Sentinel := TPath.Combine(TPath.GetTempPath, 'Sales Report.pdf');
  TFile.WriteAllText(Sentinel, 'user data');
  try
    P := TReportEmailExporter.TempPdfPath('Sales Report');
    try
      Assert.AreNotEqual(Sentinel, P,
        'the export path must not be the legacy %TEMP%\<Title>.pdf path');
      Assert.IsTrue(TFile.Exists(Sentinel),
        'the pre-existing file at the legacy path must still be there');
    finally
      CleanupFolderOf(P);
    end;
  finally
    TFile.Delete(Sentinel);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExportEmailTests);

end.
