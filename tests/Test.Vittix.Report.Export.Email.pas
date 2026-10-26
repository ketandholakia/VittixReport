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
  System.Generics.Collections,
  System.SysUtils,
  System.IOUtils,
  Vcl.Graphics,
  Vittix.Report.Export.Email,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TExportEmailTests = class
  private
    FTempRoot: string;
    FExportFailureMode: Integer;
    FMapiResult: Cardinal;
    FMapiCalled: Boolean;
    FFailDelete: Boolean;
    FLastPdfPath: string;
    procedure StartTestHooks;
    procedure FinishTestHooks;
    procedure StubPrinterExport(const APdfFile: string);
    procedure StubVectorExport(const APdfFile: string);
    function StubMapiSend(const APdfFile, AReportTitle: string): Cardinal;
    procedure StubDeleteFolder(const AFolder: string);
    function CreateTestDocument: TReportExportDocument;
    procedure CleanupFolderOf(const APath: string);
  public
    [Test] procedure Test_Sanitize_GujaratiTitle_FallsBackToReport;
    [Test] procedure Test_Sanitize_MixedTitle_KeepsAsciiOnly;
    [Test] procedure Test_Sanitize_EmptyTitle_FallsBackToReport;
    [Test] procedure Test_TempPdfPath_TwoCalls_NeverSamePath;
    [Test] procedure Test_TempPdfPath_LivesInNewGuidFolder_WithAsciiName;
    [Test] procedure Test_TempPdfPath_DoesNotUseLegacyTitlePath;
    [Test] procedure Test_ExportFailureBeforeOutput_CleansOwnedFolder;
    [Test] procedure Test_PrinterExportFailure_CleansOwnedFolder;
    [Test] procedure Test_ExportFailureAfterPartialOutput_CleansOnlyOwnedFolder;
    [Test] procedure Test_MapiError_CleansOwnedFolder;
    [Test] procedure Test_MapiCancel_CleansOwnedFolder;
    [Test] procedure Test_CleanupFailure_ReportsBothFailuresAndPreservesUnrelatedFile;
    [Test] procedure Test_CleanupRefusesOutsideAndInvalidGuidFolders;
  end;

implementation

uses
  Winapi.Mapi;

procedure TExportEmailTests.StartTestHooks;
begin
  FTempRoot := TPath.Combine(TPath.GetTempPath,
    'VittixEmailTest-' + StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]));
  TDirectory.CreateDirectory(FTempRoot);
  FExportFailureMode := 0;
  FMapiResult := SUCCESS_SUCCESS;
  FMapiCalled := False;
  FFailDelete := False;
  FLastPdfPath := '';
  TReportEmailExporter.SetTestHooks(FTempRoot, nil, StubVectorExport,
    StubMapiSend, StubDeleteFolder);
end;

procedure TExportEmailTests.StubPrinterExport(const APdfFile: string);
begin
  StubVectorExport(APdfFile);
end;

procedure TExportEmailTests.FinishTestHooks;
begin
  TReportEmailExporter.ResetTestHooks;
  if (FTempRoot <> '') and TDirectory.Exists(FTempRoot) then
    TDirectory.Delete(FTempRoot, True);
  FTempRoot := '';
end;

procedure TExportEmailTests.StubVectorExport(const APdfFile: string);
begin
  FLastPdfPath := APdfFile;
  if FExportFailureMode = 1 then
    raise Exception.Create('simulated export failure before output');
  if FExportFailureMode = 2 then
  begin
    TFile.WriteAllText(APdfFile, 'partial PDF');
    raise Exception.Create('simulated export failure after partial output');
  end;
end;

function TExportEmailTests.StubMapiSend(const APdfFile,
  AReportTitle: string): Cardinal;
begin
  FMapiCalled := True;
  Assert.AreEqual(FLastPdfPath, APdfFile);
  Assert.AreEqual('Failure-path report', AReportTitle);
  Result := FMapiResult;
end;

procedure TExportEmailTests.StubDeleteFolder(const AFolder: string);
begin
  if FFailDelete then
    raise Exception.Create('simulated cleanup failure');
  if TDirectory.Exists(AFolder) then
    TDirectory.Delete(AFolder, True);
end;

function TExportEmailTests.CreateTestDocument: TReportExportDocument;
begin
  Result := TReportExportDocument.Create;
  Result.AddPage(100, 100);
end;

function IsValidGuidText(const AValue: string): Boolean;
begin
  try
    Result := GUIDToString(StringToGUID('{' + AValue + '}')) <> '';
  except
    Result := False;
  end;
end;

procedure TExportEmailTests.CleanupFolderOf(const APath: string);
var
  TempPath, FolderPath, FolderName, GuidText: string;
begin
  try
    if APath = '' then
      Exit;

    if FTempRoot <> '' then
      TempPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(FTempRoot))
    else
      TempPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(TPath.GetTempPath));
    FolderPath := ExcludeTrailingPathDelimiter(
      TPath.GetFullPath(ExtractFilePath(APath)));
    FolderName := ExtractFileName(FolderPath);
    if not SameText(ExtractFileDir(FolderPath), TempPath) or
       (Copy(FolderName, 1, Length('VittixMail-')) <> 'VittixMail-') then
      Exit;

    GuidText := Copy(FolderName, Length('VittixMail-') + 1, MaxInt);
    if not IsValidGuidText(GuidText) then
      Exit;

    if TDirectory.Exists(FolderPath) then
      TDirectory.Delete(FolderPath, True);
  except
    // Best effort; if validation or deletion fails, leave the directory alone.
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

procedure TExportEmailTests.Test_TempPdfPath_DoesNotUseLegacyTitlePath;
var
  P, LegacyPath, FolderPath, FolderName: string;
begin
  P := '';
  LegacyPath := TPath.GetFullPath(
    TPath.Combine(TPath.GetTempPath, 'Sales Report.pdf'));
  try
    P := TReportEmailExporter.TempPdfPath('Sales Report');
    FolderPath := ExcludeTrailingPathDelimiter(
      TPath.GetFullPath(ExtractFilePath(P)));
    FolderName := ExtractFileName(FolderPath);

    Assert.AreNotEqual(LegacyPath, TPath.GetFullPath(P),
      'the export path must not use the legacy title-based path');
    Assert.IsTrue(SameText(ExtractFileDir(FolderPath),
      ExcludeTrailingPathDelimiter(TPath.GetFullPath(TPath.GetTempPath))),
      'the export folder must be directly under the system temp directory');
    Assert.AreEqual('VittixMail-', Copy(FolderName, 1, Length('VittixMail-')),
      'the export folder must use the dedicated VittixMail- prefix');
    Assert.IsTrue(IsValidGuidText(Copy(FolderName,
      Length('VittixMail-') + 1, MaxInt)),
      'the export folder suffix must be a GUID');
    Assert.IsTrue(not TFile.Exists(P),
      'TempPdfPath should return a path without creating the PDF itself');
  finally
    if P <> '' then
      CleanupFolderOf(P);
  end;
end;

procedure TExportEmailTests.Test_ExportFailureBeforeOutput_CleansOwnedFolder;
var
  Doc: TReportExportDocument;
begin
  StartTestHooks;
  Doc := CreateTestDocument;
  try
    FExportFailureMode := 1;
    try
      TReportEmailExporter.SendEmailWithReport(Doc, 'Failure-path report');
      Assert.Fail('expected export failure');
    except
      on E: Exception do
        Assert.AreEqual('simulated export failure before output', E.Message);
    end;
    Assert.IsFalse(FMapiCalled, 'MAPI must not run when PDF export fails');
    Assert.IsFalse(TDirectory.Exists(ExtractFilePath(FLastPdfPath)));
  finally
    Doc.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_PrinterExportFailure_CleansOwnedFolder;
var
  Pages: TObjectList<TMetafile>;
begin
  StartTestHooks;
  TReportEmailExporter.SetTestHooks(FTempRoot, StubPrinterExport,
    StubVectorExport, StubMapiSend, StubDeleteFolder);
  Pages := TObjectList<TMetafile>.Create(True);
  Pages.Add(TMetafile.Create);
  try
    FExportFailureMode := 1;
    try
      TReportEmailExporter.SendEmailWithReport(Pages, 'Failure-path report');
      Assert.Fail('expected printer-path export failure');
    except
      on E: Exception do
        Assert.AreEqual('simulated export failure before output', E.Message);
    end;
    Assert.IsFalse(FMapiCalled, 'MAPI must not run when PDF export fails');
    Assert.IsFalse(TDirectory.Exists(ExtractFilePath(FLastPdfPath)));
  finally
    Pages.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_ExportFailureAfterPartialOutput_CleansOnlyOwnedFolder;
var
  Doc: TReportExportDocument;
  Sentinel: string;
begin
  StartTestHooks;
  Doc := CreateTestDocument;
  Sentinel := TPath.Combine(FTempRoot, 'unrelated-sentinel.txt');
  TFile.WriteAllText(Sentinel, 'preserve');
  try
    FExportFailureMode := 2;
    try
      TReportEmailExporter.SendEmailWithReport(Doc, 'Failure-path report');
      Assert.Fail('expected export failure');
    except
      on E: Exception do
        Assert.AreEqual('simulated export failure after partial output', E.Message);
    end;
    Assert.IsFalse(TDirectory.Exists(ExtractFilePath(FLastPdfPath)));
    Assert.IsTrue(TFile.Exists(Sentinel), 'cleanup must not remove sibling files');
  finally
    Doc.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_MapiError_CleansOwnedFolder;
var
  Doc: TReportExportDocument;
begin
  StartTestHooks;
  Doc := CreateTestDocument;
  try
    FMapiResult := 77;
    try
      TReportEmailExporter.SendEmailWithReport(Doc, 'Failure-path report');
      Assert.Fail('expected MAPI error');
    except
      on E: Exception do
        Assert.IsTrue(Pos('MAPI error code: 77', E.Message) > 0, E.Message);
    end;
    Assert.IsTrue(FMapiCalled);
    Assert.IsFalse(TDirectory.Exists(ExtractFilePath(FLastPdfPath)));
  finally
    Doc.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_MapiCancel_CleansOwnedFolder;
var
  Doc: TReportExportDocument;
begin
  StartTestHooks;
  Doc := CreateTestDocument;
  try
    FMapiResult := MAPI_USER_ABORT;
    TReportEmailExporter.SendEmailWithReport(Doc, 'Failure-path report');
    Assert.IsTrue(FMapiCalled);
    Assert.IsFalse(TDirectory.Exists(ExtractFilePath(FLastPdfPath)));
  finally
    Doc.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_CleanupFailure_ReportsBothFailuresAndPreservesUnrelatedFile;
var
  Doc: TReportExportDocument;
  Sentinel: string;
begin
  StartTestHooks;
  Doc := CreateTestDocument;
  Sentinel := TPath.Combine(FTempRoot, 'unrelated-sentinel.txt');
  TFile.WriteAllText(Sentinel, 'preserve');
  try
    FExportFailureMode := 1;
    FFailDelete := True;
    try
      TReportEmailExporter.SendEmailWithReport(Doc, 'Failure-path report');
      Assert.Fail('expected combined export and cleanup failure');
    except
      on E: Exception do
      begin
        Assert.IsTrue(Pos('simulated export failure before output', E.Message) > 0, E.Message);
        Assert.IsTrue(Pos('simulated cleanup failure', E.Message) > 0, E.Message);
      end;
    end;
    Assert.IsTrue(TDirectory.Exists(ExtractFilePath(FLastPdfPath)),
      'failed cleanup must leave the owned folder for diagnosis/recovery');
    Assert.IsTrue(TFile.Exists(Sentinel), 'cleanup must not touch sibling files');
  finally
    Doc.Free;
    FinishTestHooks;
  end;
end;

procedure TExportEmailTests.Test_CleanupRefusesOutsideAndInvalidGuidFolders;
var
  OutsideFolder, InvalidFolder: string;
begin
  StartTestHooks;
  try
    OutsideFolder := TPath.Combine(TPath.Combine(FTempRoot, 'nested'),
      'VittixMail-' + StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]));
    TDirectory.CreateDirectory(OutsideFolder);
    try
      try
        TReportEmailExporter.TestCleanupTempPdf(TPath.Combine(OutsideFolder, 'x.pdf'));
        Assert.Fail('expected refusal of a nested/outside path');
      except
        on E: Exception do
          Assert.IsTrue(Pos('Refusing to clean', E.Message) > 0, E.Message);
      end;
      Assert.IsTrue(TDirectory.Exists(OutsideFolder));
    finally
      TDirectory.Delete(TPath.Combine(FTempRoot, 'nested'), True);
    end;

    InvalidFolder := TPath.Combine(FTempRoot, 'VittixMail-not-a-guid');
    TDirectory.CreateDirectory(InvalidFolder);
    try
      try
        TReportEmailExporter.TestCleanupTempPdf(TPath.Combine(InvalidFolder, 'x.pdf'));
        Assert.Fail('expected refusal of an invalid GUID folder');
      except
        on E: Exception do
          Assert.IsTrue(Pos('invalid exporter temp folder', E.Message) > 0, E.Message);
      end;
      Assert.IsTrue(TDirectory.Exists(InvalidFolder));
    finally
      TDirectory.Delete(InvalidFolder, True);
    end;
  finally
    FinishTestHooks;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExportEmailTests);

end.
