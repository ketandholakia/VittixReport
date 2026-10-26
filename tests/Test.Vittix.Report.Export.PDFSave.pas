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
  System.IOUtils,
  System.Types,
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
  end;

implementation

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
  FTempDir := NewTempDir;
end;

procedure TReportPdfSaveTests.TearDown;
begin
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

initialization
  TDUnitX.RegisterTestFixture(TReportPdfSaveTests);

end.
