{ Tests for the production report save path (TReportFileSaver.SaveToPath).

  These cover the DP-24 save fix end to end at the file level:
    - first save creates a loadable report (TFile.Move path);
    - a subsequent save replaces it with updated, loadable contents
      (ReplaceFile path - the path that used to raise "Path is empty");
    - injected partial writes and ordinary replacement failures preserve the
      original bytes;
    - documented partial ReplaceFile failures preserve recoverable files.

  Designer FCurrentFile/modified-state and cancelled Save-As behavior remain
  call-site contracts, checked by source review and manual UI verification. }

unit Test.Vittix.Report.FileSave;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  DUnitX.TestFramework,
  Vittix.Report.Model,
  Vittix.Report.Serializer,
  Vittix.Report.LoadResult,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.FileSave;

type
  [TestFixture]
  TReportFileSaverTests = class
  strict private
    FDir: string;
    function ReportPath(const AName: string): string;
    function MakeReport(const ATitle: string): TReportModel;
    function LoadTitle(const APath: string): string;
    function RecoveryFileCount: Integer;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;

    [Test] procedure FirstSave_CreatesLoadableReport;
    [Test] procedure SecondSave_ReplacesWithUpdatedContents;
    [Test] procedure WriteFailure_PreservesOriginalBytesAndCleansPartialTemp;
    [Test] procedure ReplacementFailure_PreservesOriginalBytesAndCleansTemp;
    [Test] procedure ReplaceFile1176_PreservesOriginalAndReplacement;
    [Test] procedure ReplaceFile1177_PreservesBackupAndReplacement;
    [Test] procedure FailedSave_LeavesModelSavable;
  end;

implementation

var
  InjectedTempPath: string;
  InjectedBackupPath: string;

procedure InjectPartialWriteFailure(R: TReportModel; const APath: string);
var
  Stream: TFileStream;
  PartialBytes: TBytes;
begin
  InjectedTempPath := APath;
  TReportSerializer.SaveToFile(R, APath);
  PartialBytes := TEncoding.UTF8.GetBytes('partial write failure');
  Stream := TFileStream.Create(APath, fmOpenWrite or fmShareExclusive);
  try
    Stream.Position := Stream.Size;
    Stream.WriteBuffer(PartialBytes[0], Length(PartialBytes));
  finally
    Stream.Free;
  end;
  raise EWriteError.Create('injected failure after partial write');
end;

function InjectReplace1176(const ATargetPath, ATempPath,
  ABackupPath: string): Boolean;
begin
  InjectedTempPath := ATempPath;
  InjectedBackupPath := ABackupPath;
  SetLastError(1176);
  Result := False;
end;

function InjectReplace1177(const ATargetPath, ATempPath,
  ABackupPath: string): Boolean;
begin
  InjectedTempPath := ATempPath;
  InjectedBackupPath := ABackupPath;
  { Model the documented partial state: the original moved to backup while
    the replacement remains at its temporary name. }
  TFile.Move(ATargetPath, ABackupPath);
  SetLastError(1177);
  Result := False;
end;

function FilesAreEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Exit(False);
end;

{ TReportFileSaverTests }

procedure TReportFileSaverTests.Setup;
begin
  SetReportFileSaverTestHooks(nil, nil);
  InjectedTempPath := '';
  InjectedBackupPath := '';
  FDir := TPath.Combine(TPath.GetTempPath,
    Format('vittix-filesave-%s-%d',
      [FormatDateTime('yyyymmdd-hhnnss-zzz', Now), GetTickCount]));
  TDirectory.CreateDirectory(FDir);
end;

procedure TReportFileSaverTests.TearDown;
begin
  SetReportFileSaverTestHooks(nil, nil);
  if TDirectory.Exists(FDir) then
    TDirectory.Delete(FDir, True);
end;

function TReportFileSaverTests.RecoveryFileCount: Integer;
begin
  Result := Length(TDirectory.GetFiles(FDir, '*.tmp*'));
end;

function TReportFileSaverTests.ReportPath(const AName: string): string;
begin
  Result := TPath.Combine(FDir, AName);
end;

function TReportFileSaverTests.MakeReport(const ATitle: string): TReportModel;
var
  B: TReportBand;
  L: TReportTextObject;
begin
  Result := TReportModel.Create;
  Result.Title := ATitle;
  B := TReportBand.Create;
  B.Name := 'TopBand';
  B.BandType := btPageHeader;
  L := TReportTextObject.Create;
  L.Name := 'MarkerLabel';
  L.Text := ATitle;
  B.Children.Add(L);
  Result.Objects.Add(B);
end;

function TReportFileSaverTests.LoadTitle(const APath: string): string;
var
  M: TReportModel;
begin
  M := TReportSerializer.LoadFromFile(APath);
  try
    Result := M.Title;
  finally
    M.Free;
  end;
end;

procedure TReportFileSaverTests.FirstSave_CreatesLoadableReport;
var
  M: TReportModel;
  P: string;
begin
  P := ReportPath('first-save.vrt');
  Assert.IsFalse(TFile.Exists(P), 'precondition: target must not exist');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
  finally
    M.Free;
  end;
  Assert.IsTrue(TFile.Exists(P), 'first save must create the report file');
  Assert.AreEqual('marker-A', LoadTitle(P), 'saved report must load back');
  Assert.AreEqual(0, RecoveryFileCount, 'temp file must not remain');
end;

procedure TReportFileSaverTests.SecondSave_ReplacesWithUpdatedContents;
var
  M: TReportModel;
  P: string;
begin
  P := ReportPath('second-save.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
    // Second save goes through the ReplaceFile branch: the target exists.
    M.Title := 'marker-B';
    TReportTextObject(TReportBand(M.Objects[0]).Children[0]).Text := 'marker-B';
    TReportFileSaver.SaveToPath(M, P);
  finally
    M.Free;
  end;
  Assert.IsTrue(TFile.Exists(P), 'file must exist after the replacing save');
  Assert.AreEqual('marker-B', LoadTitle(P),
    'second save must publish the updated contents');
  Assert.AreEqual(0, RecoveryFileCount,
    'temporary and backup files must not remain after success');
end;

procedure TReportFileSaverTests.WriteFailure_PreservesOriginalBytesAndCleansPartialTemp;
var
  M: TReportModel;
  P: string;
  OriginalBytes: TBytes;
  Raised: Boolean;
begin
  P := ReportPath('write-failure.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
    OriginalBytes := TFile.ReadAllBytes(P);
    M.Title := 'marker-B';
    SetReportFileSaverTestHooks(InjectPartialWriteFailure, nil);
    Raised := False;
    try
      TReportFileSaver.SaveToPath(M, P);
    except
      on E: EWriteError do
        Raised := True;
    end;
    Assert.IsTrue(Raised, 'injected partial write must be reported as failure');
    Assert.IsTrue(FilesAreEqual(OriginalBytes, TFile.ReadAllBytes(P)),
      'write failure must preserve the exact original bytes');
    Assert.AreEqual(0, RecoveryFileCount,
      'partial uncommitted temp output must be cleaned after write failure');
  finally
    M.Free;
  end;
end;

procedure TReportFileSaverTests.ReplacementFailure_PreservesOriginalBytesAndCleansTemp;
var
  M: TReportModel;
  P: string;
  Lock: TFileStream;
  Raised: Boolean;
  OriginalBytes: TBytes;
begin
  P := ReportPath('locked-target.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
  finally
    M.Free;
  end;
  OriginalBytes := TFile.ReadAllBytes(P);

  // Controlled failure: hold an exclusive handle on the target so the
  // underlying ReplaceFile cannot swap the new file in.
  Lock := TFileStream.Create(P, fmOpenRead or fmShareExclusive);
  try
    Raised := False;
    M := MakeReport('marker-B');
    try
      try
        TReportFileSaver.SaveToPath(M, P);
      except
        on E: Exception do
          Raised := True;
      end;
    finally
      M.Free;
    end;
  finally
    Lock.Free;
  end;

  Assert.IsTrue(Raised,
    'a failed replacement must raise, never report success');
  Assert.IsTrue(FilesAreEqual(OriginalBytes, TFile.ReadAllBytes(P)),
    'ordinary replacement failure must preserve exact original bytes');
  Assert.AreEqual('marker-A', LoadTitle(P), 'original report must remain loadable');
  Assert.AreEqual(0, RecoveryFileCount,
    'temp file must be cleaned after an ordinary replacement failure');
end;

procedure TReportFileSaverTests.ReplaceFile1176_PreservesOriginalAndReplacement;
var
  M: TReportModel;
  P: string;
  OriginalBytes: TBytes;
  ErrorText: string;
begin
  P := ReportPath('partial-1176.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
    OriginalBytes := TFile.ReadAllBytes(P);
    M.Title := 'marker-B';
    TReportTextObject(TReportBand(M.Objects[0]).Children[0]).Text := 'marker-B';
    SetReportFileSaverTestHooks(nil, InjectReplace1176);
    ErrorText := '';
    try
      TReportFileSaver.SaveToPath(M, P);
    except
      on E: EOSError do
        ErrorText := E.Message;
    end;
    Assert.IsTrue(ErrorText <> '', '1176 partial replacement must be reported');
    Assert.IsTrue(FilesAreEqual(OriginalBytes, TFile.ReadAllBytes(P)),
      '1176 leaves the original at the target path');
    Assert.IsTrue(TFile.Exists(InjectedTempPath),
      '1176 replacement temp must be kept for recovery');
    Assert.AreEqual('marker-B', LoadTitle(InjectedTempPath),
      'retained replacement must be loadable');
    Assert.IsTrue(Pos(InjectedTempPath, ErrorText) > 0,
      'failure message must identify the retained replacement path');
    SetReportFileSaverTestHooks(nil, nil);
    M.Title := 'marker-C';
    TReportTextObject(TReportBand(M.Objects[0]).Children[0]).Text := 'marker-C';
    TReportFileSaver.SaveToPath(M, P);
    Assert.AreEqual('marker-C', LoadTitle(P),
      'a subsequent save must still publish its intended report');
    Assert.AreEqual('marker-B', LoadTitle(InjectedTempPath),
      'a later save must not overwrite the retained recovery replacement');
  finally
    M.Free;
  end;
end;

procedure TReportFileSaverTests.ReplaceFile1177_PreservesBackupAndReplacement;
var
  M: TReportModel;
  P: string;
  ErrorText: string;
begin
  P := ReportPath('partial-1177.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);
    M.Title := 'marker-B';
    TReportTextObject(TReportBand(M.Objects[0]).Children[0]).Text := 'marker-B';
    SetReportFileSaverTestHooks(nil, InjectReplace1177);
    ErrorText := '';
    try
      TReportFileSaver.SaveToPath(M, P);
    except
      on E: EOSError do
        ErrorText := E.Message;
    end;
    Assert.IsTrue(ErrorText <> '', '1177 partial replacement must be reported');
    Assert.IsFalse(TFile.Exists(P),
      '1177 partial state moves the original from the target path');
    Assert.IsTrue(TFile.Exists(InjectedBackupPath),
      '1177 original must remain under the requested backup path');
    Assert.IsTrue(TFile.Exists(InjectedTempPath),
      '1177 replacement temp must remain available');
    Assert.AreEqual('marker-A', LoadTitle(InjectedBackupPath),
      'backup must contain the original loadable report');
    Assert.AreEqual('marker-B', LoadTitle(InjectedTempPath),
      'temp must contain the new loadable report');
    Assert.IsTrue((Pos(InjectedBackupPath, ErrorText) > 0) and
      (Pos(InjectedTempPath, ErrorText) > 0),
      'failure message must identify both recovery files');
    SetReportFileSaverTestHooks(nil, nil);
    M.Title := 'marker-C';
    TReportTextObject(TReportBand(M.Objects[0]).Children[0]).Text := 'marker-C';
    TReportFileSaver.SaveToPath(M, P);
    Assert.AreEqual('marker-C', LoadTitle(P),
      'a subsequent save must be possible after the partial replacement');
    Assert.AreEqual('marker-A', LoadTitle(InjectedBackupPath),
      'a later save must not overwrite the retained original backup');
    Assert.AreEqual('marker-B', LoadTitle(InjectedTempPath),
      'a later save must not overwrite the retained replacement');
  finally
    M.Free;
  end;
end;

procedure TReportFileSaverTests.FailedSave_LeavesModelSavable;
var
  M: TReportModel;
  P, Salvage: string;
  Lock: TFileStream;
  Raised: Boolean;
begin
  P := ReportPath('state.vrt');
  M := MakeReport('marker-A');
  try
    TReportFileSaver.SaveToPath(M, P);

    Lock := TFileStream.Create(P, fmOpenRead or fmShareExclusive);
    try
      M.Title := 'marker-B';
      Raised := False;
      try
        TReportFileSaver.SaveToPath(M, P);
      except
        on E: Exception do
          Raised := True;
      end;
      Assert.IsTrue(Raised, 'failed save must not report success');
    finally
      Lock.Free;
    end;

    // The existing file remains at its original path with the previous
    // revision and no temporary artifacts after an ordinary failure.
    Assert.IsTrue(TFile.Exists(P), 'document must remain at its original path');
    Assert.AreEqual(1, Length(TDirectory.GetFiles(FDir)),
      'no stray files may remain after a failed save');
    Assert.AreEqual('marker-A', LoadTitle(P),
      'the on-disk document is still the previous revision');

    // The in-memory model is unharmed: it can still be saved elsewhere,
    // publishing the modification the failed save could not write.
    Salvage := ReportPath('salvage.vrt');
    TReportFileSaver.SaveToPath(M, Salvage);
    Assert.AreEqual('marker-B', LoadTitle(Salvage),
      'the live report must stay savable after the failed attempt');
  finally
    M.Free;
  end;
end;

end.
