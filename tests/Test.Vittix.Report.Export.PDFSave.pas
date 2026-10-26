unit Test.Vittix.Report.Export.PDFSave;

{
  Atomic PDF save tests.

  The user-facing "Save PDF..." actions export the captured Vector PDF document
  to a temporary file in the destination directory and only replace the chosen
  destination after the export succeeds.  These tests pin the file-safety
  contract: valid PDF output, explicit overwrite, preservation of an existing
  destination on failure, and rejection of a missing destination directory.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.Types,
  Winapi.Windows,
  Winapi.AclAPI,
  Winapi.AccCtrl,
  Vcl.Graphics,
  Vittix.Report.Export.Commands,
  Vittix.Report.Export.VectorPDF;

type
  [TestFixture]
  TReportPdfSaveTests = class
  private
    FTempDir: string;
    function CreateDocument: TReportExportDocument;
    function NewTempDir: string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Test_AtomicSave_WritesValidPdf;
    [Test] procedure Test_AtomicSave_OverwritesExistingAfterSuccess;
    [Test] procedure Test_AtomicSave_EmptyDocumentPreservesExisting;
    [Test] procedure Test_AtomicSave_MissingDirectoryRaises;
    [Test] procedure Test_AtomicSave_PartialWriteFailurePreservesExisting;
    [Test] procedure Test_AtomicSave_ReplacementFailurePreservesExisting;
    [Test] procedure Test_AtomicSave_RepeatedExportCleansTemporaryFiles;
    [Test] procedure Test_AtomicSave_PreservesRestrictiveDacl;
    [Test] procedure Test_AtomicSave_DoesNotOverwriteConcurrentNewFile;
  end;

implementation

const
  TEST_PROTECTED_DACL_SECURITY_INFORMATION = $80000000;
  TEST_SDDL_REVISION_1 = 1;

var
  ExpectedTempDacl, ObservedTempDacl: string;

function ConvertStringSecurityDescriptorToSecurityDescriptorW(
  StringSecurityDescriptor: PWideChar; StringSDRevision: DWORD;
  var SecurityDescriptor: PSECURITY_DESCRIPTOR;
  var SecurityDescriptorSize: DWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'ConvertStringSecurityDescriptorToSecurityDescriptorW';

function ConvertSecurityDescriptorToStringSecurityDescriptorW(
  SecurityDescriptor: PSECURITY_DESCRIPTOR; StringSDRevision: DWORD;
  SecurityInformation: DWORD; var StringSecurityDescriptor: PWideChar;
  var StringSecurityDescriptorLen: DWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'ConvertSecurityDescriptorToStringSecurityDescriptorW';

procedure SetAdminOnlyDacl(const AFileName: string);
var
  SD: PSECURITY_DESCRIPTOR;
  Dacl: PACL;
  Present, Defaulted: BOOL;
  Size: DWORD;
  ErrorCode: DWORD;
begin
  SD := nil;
  Size := 0;
  if not ConvertStringSecurityDescriptorToSecurityDescriptorW(
    'D:P(A;;FA;;;BA)', TEST_SDDL_REVISION_1, SD, Size) then
    RaiseLastOSError;
  try
    if not GetSecurityDescriptorDacl(SD, Present, Dacl, Defaulted) then
      RaiseLastOSError;
    if not Present then
      raise Exception.Create('Test DACL was not present');
    ErrorCode := SetNamedSecurityInfo(PChar(AFileName), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION or TEST_PROTECTED_DACL_SECURITY_INFORMATION,
      nil, nil, Dacl, nil);
    if ErrorCode <> ERROR_SUCCESS then
      RaiseLastOSError(ErrorCode);
  finally
    LocalFree(HLOCAL(SD));
  end;
end;

function GetDaclSddl(const AFileName: string): string;
var
  SD: PSECURITY_DESCRIPTOR;
  Dacl, Sacl: PACL;
  Owner, Group: PSID;
  Sddl: PWideChar;
  SddlLength: DWORD;
  ErrorCode: DWORD;
begin
  SD := nil;
  Dacl := nil;
  Sacl := nil;
  Owner := nil;
  Group := nil;
  Sddl := nil;
  SddlLength := 0;
  ErrorCode := GetNamedSecurityInfo(PChar(AFileName), SE_FILE_OBJECT,
    DACL_SECURITY_INFORMATION, @Owner, @Group, @Dacl, @Sacl, @SD);
  if ErrorCode <> ERROR_SUCCESS then
    RaiseLastOSError(ErrorCode);
  try
    if not ConvertSecurityDescriptorToStringSecurityDescriptorW(
      SD, TEST_SDDL_REVISION_1, DACL_SECURITY_INFORMATION, Sddl, SddlLength) then
      RaiseLastOSError;
    Result := string(Sddl);
  finally
    if Sddl <> nil then LocalFree(HLOCAL(Sddl));
    if SD <> nil then LocalFree(HLOCAL(SD));
  end;
end;

procedure InjectPartialPdfWrite(AStream: TStream);
const
  Partial = '%PDF-1.4 partial';
begin
  AStream.WriteBuffer(Partial[1], Length(Partial));
  raise Exception.Create('Injected partial PDF write failure');
end;

procedure InjectPdfReplacementFailure(const ATarget, ATemp: string;
  AReplaceExisting: Boolean);
begin
  raise Exception.Create('Injected PDF replacement failure');
end;

procedure CreateConcurrentPdfDestination(const ATarget, ATemp: string;
  AReplaceExisting: Boolean);
begin
  Assert.IsFalse(AReplaceExisting,
    'destination was absent when the save began');
  TFile.WriteAllText(ATarget, 'concurrent-writer');
end;

function TReportPdfSaveTests.NewTempDir: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := TPath.Combine(TPath.GetTempPath,
    'VittixPdfSaveTest-' + GUIDToString(Guid));
  TDirectory.CreateDirectory(Result);
end;

procedure TReportPdfSaveTests.Setup;
begin
  SetReportVectorPdfTestHooks(nil, nil, nil);
  FTempDir := NewTempDir;
end;

procedure TReportPdfSaveTests.TearDown;
begin
  SetReportVectorPdfTestHooks(nil, nil, nil);
  if TDirectory.Exists(FTempDir) then
    try
      TDirectory.Delete(FTempDir, True);
    except
      // Best effort: a failed test should not mask its own assertion.
    end;
end;

function TReportPdfSaveTests.CreateDocument: TReportExportDocument;
var
  Page: TReportExportPage;
  Cmd: TReportExportTextCommand;
begin
  Result := TReportExportDocument.Create;
  Page := Result.AddPage(600, 800);
  Cmd := TReportExportTextCommand.Create;
  Cmd.Bounds := Rect(20, 20, 400, 60);
  Cmd.Text := 'Atomic PDF save test';
  Cmd.FontName := 'Arial';
  Cmd.FontSize := 12;
  Cmd.FontColor := clBlack;
  Page.Commands.Add(Cmd);
end;

procedure TReportPdfSaveTests.Test_AtomicSave_WritesValidPdf;
var
  Doc: TReportExportDocument;
  Dest: string;
  Bytes: TBytes;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  Doc := CreateDocument;
  try
    TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
  finally
    Doc.Free;
  end;

  Assert.IsTrue(TFile.Exists(Dest), 'atomic save must create the destination');
  Bytes := TFile.ReadAllBytes(Dest);
  Assert.IsTrue(Length(Bytes) > 200, 'saved PDF should be non-trivial');
  Assert.AreEqual('%PDF-', TEncoding.ASCII.GetString(Bytes, 0, 5),
    'saved file must be a PDF');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_OverwritesExistingAfterSuccess;
var
  Doc: TReportExportDocument;
  Dest: string;
  Bytes: TBytes;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  TFile.WriteAllText(Dest, 'sentinel');

  Doc := CreateDocument;
  try
    TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
  finally
    Doc.Free;
  end;

  Bytes := TFile.ReadAllBytes(Dest);
  Assert.AreEqual('%PDF-', TEncoding.ASCII.GetString(Bytes, 0, 5),
    'successful save must replace the existing destination');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_EmptyDocumentPreservesExisting;
var
  Doc: TReportExportDocument;
  Dest: string;
  Raised: Boolean;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  TFile.WriteAllText(Dest, 'sentinel');

  Doc := TReportExportDocument.Create;
  try
    Raised := False;
    try
      TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    except
      on E: Exception do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'an empty document must be rejected');
  finally
    Doc.Free;
  end;

  Assert.AreEqual('sentinel', TFile.ReadAllText(Dest),
    'failed save must preserve the existing destination');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')),
    'failed save must not leave a temporary file');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_MissingDirectoryRaises;
var
  Doc: TReportExportDocument;
  Dest: string;
  Raised: Boolean;
begin
  Dest := TPath.Combine(FTempDir, 'missing', 'report.pdf');
  Doc := CreateDocument;
  try
    Raised := False;
    try
      TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    except
      on E: Exception do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'a missing destination directory must be rejected');
  finally
    Doc.Free;
  end;

  Assert.IsFalse(TFile.Exists(Dest),
    'a rejected save must not create the destination');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_PartialWriteFailurePreservesExisting;
var
  Doc: TReportExportDocument;
  Dest, DaclBefore: string;
  Raised: Boolean;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  TFile.WriteAllText(Dest, 'sentinel');
  SetAdminOnlyDacl(Dest);
  DaclBefore := GetDaclSddl(Dest);
  Doc := CreateDocument;
  try
    SetReportVectorPdfTestHooks(InjectPartialPdfWrite, nil, nil);
    Raised := False;
    try
      TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    except
      on E: Exception do
        Raised := True;
    end;
  finally
    Doc.Free;
    SetReportVectorPdfTestHooks(nil, nil, nil)
  end;
  Assert.IsTrue(Raised, 'injected partial export must fail');
  Assert.AreEqual('sentinel', TFile.ReadAllText(Dest),
    'partial output must not replace the existing destination');
  Assert.AreEqual(DaclBefore, GetDaclSddl(Dest),
    'partial output failure must preserve the destination DACL');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')),
    'partial output temp must be removed');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_ReplacementFailurePreservesExisting;
var
  Doc: TReportExportDocument;
  Dest, DaclBefore: string;
  Raised: Boolean;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  TFile.WriteAllText(Dest, 'sentinel');
  SetAdminOnlyDacl(Dest);
  DaclBefore := GetDaclSddl(Dest);
  Doc := CreateDocument;
  try
    SetReportVectorPdfTestHooks(nil, InjectPdfReplacementFailure, nil);
    Raised := False;
    try
      TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    except
      on E: Exception do
        Raised := True;
    end;
  finally
    Doc.Free;
    SetReportVectorPdfTestHooks(nil, nil, nil)
  end;
  Assert.IsTrue(Raised, 'injected replacement failure must be reported');
  Assert.AreEqual('sentinel', TFile.ReadAllText(Dest),
    'replacement failure must preserve existing bytes');
  Assert.AreEqual(DaclBefore, GetDaclSddl(Dest),
    'replacement failure must preserve the destination DACL');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')),
    'replacement failure temp must be removed');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.bak')),
    'replacement failure backup must be removed');
end;

procedure TReportPdfSaveTests.Test_AtomicSave_RepeatedExportCleansTemporaryFiles;
var
  Doc: TReportExportDocument;
  Dest: string;
  Bytes: TBytes;
begin
  Dest := TPath.Combine(FTempDir, 'report.pdf');
  Doc := CreateDocument;
  try
    TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
  finally
    Doc.Free;
  end;
  Bytes := TFile.ReadAllBytes(Dest);
  Assert.AreEqual('%PDF-', TEncoding.ASCII.GetString(Bytes, 0, 5));
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')));
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.bak')));
end;

procedure ObserveTempDacl(const ATemp: string);
begin
  ObservedTempDacl := GetDaclSddl(ATemp);
  Assert.AreEqual(ExpectedTempDacl, ObservedTempDacl);
end;

procedure TReportPdfSaveTests.Test_AtomicSave_PreservesRestrictiveDacl;
var
  Doc: TReportExportDocument;
  Dest, DaclBefore, DaclAfter: string;
  HashBefore, HashAfter: string;
begin
  Dest := TPath.Combine(FTempDir, 'restricted.pdf');
  TFile.WriteAllText(Dest, 'restricted-sentinel');
  SetAdminOnlyDacl(Dest);
  DaclBefore := GetDaclSddl(Dest);
  HashBefore := THashSHA2.GetHashStringFromFile(Dest);
  ExpectedTempDacl := DaclBefore;
  ObservedTempDacl := '';
  SetReportVectorPdfTestHooks(nil, nil, ObserveTempDacl);
  Doc := CreateDocument;
  try
    TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
  finally
    Doc.Free;
    SetReportVectorPdfTestHooks(nil, nil, nil);
  end;
  DaclAfter := GetDaclSddl(Dest);
  HashAfter := THashSHA2.GetHashStringFromFile(Dest);
  TFile.WriteAllText(TPath.Combine(TPath.GetDirectoryName(ParamStr(0)),
    'pdf-acl-evidence.txt'),
    'DACL before=' + DaclBefore + sLineBreak +
    'DACL temp-before-write=' + ObservedTempDacl + sLineBreak +
    'DACL after=' + DaclAfter + sLineBreak +
    'SHA256 before=' + HashBefore + sLineBreak +
    'SHA256 after=' + HashAfter);
  Assert.AreEqual(DaclBefore, DaclAfter,
    'successful overwrite must preserve the protected destination DACL');
  Assert.AreEqual(DaclBefore, ObservedTempDacl,
    'temp DACL must match destination before PDF bytes are written');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')));
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.bak')));
end;

procedure TReportPdfSaveTests.Test_AtomicSave_DoesNotOverwriteConcurrentNewFile;
var
  Doc: TReportExportDocument;
  Dest: string;
  Raised: Boolean;
begin
  Dest := TPath.Combine(FTempDir, 'created-concurrently.pdf');
  Doc := CreateDocument;
  try
    SetReportVectorPdfTestHooks(nil, CreateConcurrentPdfDestination, nil);
    Raised := False;
    try
      TReportVectorPDFExporter.ExportDocumentAtomic(Doc, Dest);
    except
      on E: EOSError do
        Raised := True;
    end;
  finally
    Doc.Free;
    SetReportVectorPdfTestHooks(nil, nil, nil);
  end;
  Assert.IsTrue(Raised,
    'a destination created during export must cause a safe commit failure');
  Assert.AreEqual('concurrent-writer', TFile.ReadAllText(Dest),
    'the concurrent destination must not be overwritten');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FTempDir, '*.tmp')));
end;

initialization
  TDUnitX.RegisterTestFixture(TReportPdfSaveTests);

end.
