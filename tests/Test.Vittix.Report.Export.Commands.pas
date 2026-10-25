unit Test.Vittix.Report.Export.Commands;

{
  TReportExportDocument.Destroy leak guard (v1.0 freeze fix).

  The destructor deleted every registered temp file with an UNGUARDED
  TFile.Delete.  When one delete raises (file locked or held open
  exclusively), the destructor aborted mid-way: FTempFiles and FPages were
  never freed and the exception escaped Free.  The fix makes each delete
  best-effort and frees the owned lists in try/finally so inherited
  Destroy always runs.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vittix.Report.Export.Commands;

type
  [TestFixture]
  TExportCommandsTests = class
  public
    [Test] procedure Test_Destroy_SwallowsLockedTempFileDelete;
    [Test] procedure Test_Destroy_DeletesUnlockedTempFiles;
  end;

implementation

procedure TExportCommandsTests.Test_Destroy_SwallowsLockedTempFileDelete;
var
  Doc: TReportExportDocument;
  Lock: TFileStream;
  Path: string;
  Raised: Boolean;
begin
  Path := TPath.Combine(TPath.GetTempPath,
    'vittix-test-locked-' + TGUID.NewGuid.ToString + '.tmp');
  TFile.WriteAllText(Path, 'locked');
  Lock := TFileStream.Create(Path, fmOpenWrite or fmShareExclusive);
  try
    Doc := TReportExportDocument.Create;
    try
      Doc.AddTempFile(Path);
      Doc.AddPage(100, 100);

      Raised := False;
      try
        Doc.Free;
      except
        Raised := True;
      end;
      Doc := nil;
      // If Destroy raised here, FTempFiles and FPages leaked as well -
      // surfaced by the DUnitX leak counter as a second failure mode.
      Assert.IsFalse(Raised,
        'Destroy must swallow a locked-temp-file delete failure');
    finally
      Doc.Free;
    end;
  finally
    Lock.Free;
    TFile.Delete(Path);
  end;
end;

procedure TExportCommandsTests.Test_Destroy_DeletesUnlockedTempFiles;
var
  Doc: TReportExportDocument;
  Path: string;
begin
  Path := TPath.Combine(TPath.GetTempPath,
    'vittix-test-unlocked-' + TGUID.NewGuid.ToString + '.tmp');
  TFile.WriteAllText(Path, 'data');

  Doc := TReportExportDocument.Create;
  try
    Doc.AddTempFile(Path);
    Doc.AddPage(100, 100);
  finally
    Doc.Free;
  end;

  Assert.IsFalse(TFile.Exists(Path),
    'an unlocked registered temp file must still be deleted by Destroy');
end;

initialization
  TDUnitX.RegisterTestFixture(TExportCommandsTests);

end.
