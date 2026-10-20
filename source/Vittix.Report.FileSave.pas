{ Vittix.Report.FileSave - atomic report-file write (DP-24 follow-up).

  Extracted from TfrmMain.SaveReportTo so the production save path is testable
  without the designer UI. The form keeps the user-visible error message;
  file mechanics live here.

  SaveToPath writes to a unique sibling temp file before replacing the target.
  A failed write leaves the existing target untouched. ReplaceFileW errors
  1176/1177 can leave a partial swap: the replacement temp is retained, and
  error 1177's original-file backup is also retained. The raised error names
  the recovery paths. Other documented ReplaceFileW failures retain the
  original target and replacement names; the uncommitted temp is cleaned.
}

unit Vittix.Report.FileSave;

interface

uses
  Vittix.Report.Model;

type
  TReportFileSaver = class
  public
    { Saves R to APath atomically.  See unit header for the exact contract. }
    class procedure SaveToPath(R: TReportModel; const APath: string);
  end;

{$IFDEF VITTIX_REPORT_TESTS}
type
  TReportFileWriteHook = procedure(R: TReportModel; const APath: string);
  TReportFileReplaceHook = function(const ATargetPath, ATempPath,
    ABackupPath: string): Boolean;

procedure SetReportFileSaverTestHooks(AWriteHook: TReportFileWriteHook;
  AReplaceHook: TReportFileReplaceHook);
{$ENDIF}

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  Vittix.Report.Serializer;

const
  { Documented ReplaceFileW partial-failure codes; the RTL does not declare
    them. }
  ERROR_UNABLE_TO_MOVE_REPLACEMENT   = 1176;
  ERROR_UNABLE_TO_MOVE_REPLACEMENT_2 = 1177;

{$IFDEF VITTIX_REPORT_TESTS}
var
  GReportFileWriteHook: TReportFileWriteHook;
  GReportFileReplaceHook: TReportFileReplaceHook;

procedure SetReportFileSaverTestHooks(AWriteHook: TReportFileWriteHook;
  AReplaceHook: TReportFileReplaceHook);
begin
  GReportFileWriteHook := AWriteHook;
  GReportFileReplaceHook := AReplaceHook;
end;
{$ENDIF}

procedure WriteReportTemp(R: TReportModel; const ATempPath: string);
begin
{$IFDEF VITTIX_REPORT_TESTS}
  if Assigned(GReportFileWriteHook) then
  begin
    GReportFileWriteHook(R, ATempPath);
    Exit;
  end;
{$ENDIF}
  TReportSerializer.SaveToFile(R, ATempPath);
end;

function ReplaceReportFile(const ATargetPath, ATempPath,
  ABackupPath: string): Boolean;
begin
{$IFDEF VITTIX_REPORT_TESTS}
  if Assigned(GReportFileReplaceHook) then
    Exit(GReportFileReplaceHook(ATargetPath, ATempPath, ABackupPath));
{$ENDIF}
  { Use no optional flags: this preserves default attribute/ACL merge errors
    as failures instead of silently accepting a changed security descriptor.
    REPLACEFILE_WRITE_THROUGH is documented as unsupported. }
  Result := ReplaceFile(PChar(ATargetPath), PChar(ATempPath),
    PChar(ABackupPath), 0, nil, nil);
end;

class procedure TReportFileSaver.SaveToPath(R: TReportModel; const APath: string);
var
  TempPath, BackupPath: string;
  ErrorCode: Integer;
  KeepTemp: Boolean;
  KeepBackup: Boolean;
begin
  { Keep temporary files beside the target so ReplaceFile stays on one volume.
    A unique name prevents a retry from overwriting a prior recovery file. }
  repeat
    TempPath := TPath.Combine(TPath.GetDirectoryName(APath),
      'vittix-' + TGUID.NewGuid.ToString + '.tmp');
  until not TFile.Exists(TempPath) and not TDirectory.Exists(TempPath);
  BackupPath := TempPath + '.bak';
  KeepTemp := False;
  KeepBackup := False;
  try
    WriteReportTemp(R, TempPath);
    if TFile.Exists(APath) then
    begin
      if not ReplaceReportFile(APath, TempPath, BackupPath) then
      begin
        ErrorCode := GetLastError;
        case ErrorCode of
          ERROR_UNABLE_TO_MOVE_REPLACEMENT:
            begin
              KeepTemp := True;
              RaiseLastOSError(ErrorCode,
                'The original remains at "' + APath + '" and the replacement '
                + 'was kept at "' + TempPath + '" for recovery.');
            end;
          ERROR_UNABLE_TO_MOVE_REPLACEMENT_2:
            begin
              KeepTemp := True;
              KeepBackup := True;
              RaiseLastOSError(ErrorCode,
                'The replacement was kept at "' + TempPath + '" and the '
                + 'original was kept at "' + BackupPath + '" for recovery.');
            end;
        else
          RaiseLastOSError(ErrorCode);
        end;
      end;
      { The previous file is now in BackupPath. The save is committed, so
        remove the old copy best-effort. }
      if TFile.Exists(BackupPath) then
        try
          TFile.Delete(BackupPath);
        except
          // A completed save remains successful if cleanup is denied.
        end;
    end
    else
      TFile.Move(TempPath, APath);
  except
    on E: Exception do
    begin
      if (not KeepTemp) and TFile.Exists(TempPath) then
        try
          TFile.Delete(TempPath);
        except
          // best-effort cleanup; the original failure is reported below
        end;
      if (not KeepBackup) and TFile.Exists(BackupPath) then
        try
          TFile.Delete(BackupPath);
        except
          // best-effort cleanup; the original failure is reported below
        end;
      raise;
    end;
  end;
end;

end.
