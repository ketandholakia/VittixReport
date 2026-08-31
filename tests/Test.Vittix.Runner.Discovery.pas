unit Test.Vittix.Runner.Discovery;

{
  Phase 3E-3: report discovery / classification tests.

  EnumerateReports and ClassifyReport are pure policy functions. Tests use
  temporary directories/files only, always cleaned up with try/finally.
  The canonical reports directory and baseline are never touched.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Discovery;

type
  [TestFixture]
  TDiscoveryTests = class
  private
    function MakeTempDir: string;
    procedure WriteReport(const ADir, AName, AContent: string);
  public
    // Enumeration
    [Test] procedure Test_Enumerate_SortedVrtFiles;
    [Test] procedure Test_Enumerate_IgnoresNonVrt;
    [Test] procedure Test_Enumerate_EmptyDirectory;
    [Test] procedure Test_Enumerate_DeterministicOrdering;
    // rmAll
    [Test] procedure Test_rmAll_NormalReport_Run;
    [Test] procedure Test_rmAll_CountsZero;
    [Test] procedure Test_rmAll_NoScriptContentRead;
    // Filter
    [Test] procedure Test_Filter_Matching;
    [Test] procedure Test_Filter_MismatchExcluded;
    [Test] procedure Test_Filter_CaseInsensitive;
    [Test] procedure Test_Filter_Empty;
    // Script modes (rmScriptOnly / rmScriptTraceOnly)
    [Test] procedure Test_ScriptMode_BeforeDetected;
    [Test] procedure Test_ScriptMode_AfterDetected;
    [Test] procedure Test_ScriptMode_NoScriptsExcluded;
    [Test] procedure Test_ScriptMode_WithScriptsRun;
    // Skip policy
    [Test] procedure Test_Skip_TestPrefix;
    [Test] procedure Test_Skip_16LargePreviewWarning;
    [Test] procedure Test_Skip_OrdinaryNotSkipped;
    // Critical precedence
    [Test] procedure Test_Precedence_ScriptModeTestNoScripts_Excluded;
    [Test] procedure Test_Precedence_ScriptModeTestWithScripts_Skip;
    [Test] procedure Test_Precedence_FilterBeforeSkipAndScriptMode;
    // Classification output
    [Test] procedure Test_Classification_OutputFields;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

function TDiscoveryTests.MakeTempDir: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'vittix_discovery_' + TGuid.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
end;

procedure TDiscoveryTests.WriteReport(const ADir, AName, AContent: string);
begin
  TFile.WriteAllText(TPath.Combine(ADir, AName), AContent, TEncoding.UTF8);
end;

procedure AssertNamesEqual(const AExpected: array of string;
  const AActual: TArray<string>);
var
  I: Integer;
begin
  Assert.AreEqual(Length(AExpected), Length(AActual));
  for I := 0 to High(AExpected) do
    Assert.AreEqual(AExpected[I], ExtractFileName(AActual[I]));
end;

// ---------------------------------------------------------------------------
// Enumeration
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_Enumerate_SortedVrtFiles;
var
  Dir: string;
  Files: TArray<string>;
begin
  Dir := MakeTempDir;
  try
    WriteReport(Dir, '02_b.vrt', '{}');
    WriteReport(Dir, '01_a.vrt', '{}');
    WriteReport(Dir, '03_c.vrt', '{}');
    Files := TReportDiscovery.EnumerateReports(Dir);
    AssertNamesEqual(['01_a.vrt', '02_b.vrt', '03_c.vrt'], Files);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Enumerate_IgnoresNonVrt;
var
  Dir: string;
  Files: TArray<string>;
begin
  Dir := MakeTempDir;
  try
    WriteReport(Dir, '01_a.vrt', '{}');
    WriteReport(Dir, '02_notes.txt', 'not a report');
    WriteReport(Dir, '03_c.vrt', '{}');
    WriteReport(Dir, '04_b.json', '{}');
    Files := TReportDiscovery.EnumerateReports(Dir);
    AssertNamesEqual(['01_a.vrt', '03_c.vrt'], Files);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Enumerate_EmptyDirectory;
var
  Dir: string;
  Files: TArray<string>;
begin
  Dir := MakeTempDir;
  try
    Files := TReportDiscovery.EnumerateReports(Dir);
    Assert.AreEqual(0, Length(Files));
  finally
    TDirectory.Delete(Dir, True);
  end;
end;
procedure TDiscoveryTests.Test_Enumerate_DeterministicOrdering;
var
  Dir: string;
  First: TArray<string>;
  Second: TArray<string>;
begin
  Dir := MakeTempDir;
  try
    WriteReport(Dir, 'zz_late.vrt', '{}');
    WriteReport(Dir, 'aa_first.vrt', '{}');
    WriteReport(Dir, 'mm_mid.vrt', '{}');
    First := TReportDiscovery.EnumerateReports(Dir);
    Second := TReportDiscovery.EnumerateReports(Dir);
    AssertNamesEqual(['aa_first.vrt', 'mm_mid.vrt', 'zz_late.vrt'], First);
    AssertNamesEqual(['aa_first.vrt', 'mm_mid.vrt', 'zz_late.vrt'], Second);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

// ---------------------------------------------------------------------------
// rmAll
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_rmAll_NormalReport_Run;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_normal.vrt');
    WriteReport(Dir, '01_normal.vrt',
      '{"objects":[{"OnBeforePrint": "Beep"}]}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_rmAll_CountsZero;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_normal.vrt');
    WriteReport(Dir, '01_normal.vrt',
      '{"objects":[{"OnBeforePrint": "Beep"},{"OnAfterPrint": "Beep"}]}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(0, C.ScriptBeforeCount);
    Assert.AreEqual(0, C.ScriptAfterCount);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_rmAll_NoScriptContentRead;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    // The file does not exist. In rmAll the report must never be read for
    // script counting, so classification still succeeds (raRun, empty filter).
    FileName := TPath.Combine(Dir, '01_missing.vrt');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raRun, C.Action);
    Assert.AreEqual(0, C.ScriptBeforeCount);
    Assert.AreEqual(0, C.ScriptAfterCount);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

// ---------------------------------------------------------------------------
// Filter
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_Filter_Matching;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_report.vrt');
    WriteReport(Dir, '01_report.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '01_report.vrt', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Filter_MismatchExcluded;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_report.vrt');
    WriteReport(Dir, '01_report.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '99_other.vrt', rmAll);
    Assert.AreEqual(raExcluded, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Filter_CaseInsensitive;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, 'my_report.vrt');
    WriteReport(Dir, 'my_report.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, 'MY_REPORT.VRT', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Filter_Empty;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_report.vrt');
    WriteReport(Dir, '01_report.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;
// ---------------------------------------------------------------------------
// Script modes
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_ScriptMode_BeforeDetected;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_scripts.vrt');
    WriteReport(Dir, '01_scripts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "Beep"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raRun, C.Action);
      Assert.AreEqual(1, C.ScriptBeforeCount);
      Assert.AreEqual(0, C.ScriptAfterCount);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_ScriptMode_AfterDetected;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_scripts.vrt');
    WriteReport(Dir, '01_scripts.vrt',
      '{"objects":[{"Name":"o1","OnAfterPrint": "Beep"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raRun, C.Action);
      Assert.AreEqual(0, C.ScriptBeforeCount);
      Assert.AreEqual(1, C.ScriptAfterCount);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_ScriptMode_NoScriptsExcluded;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_plain.vrt');
    WriteReport(Dir, '01_plain.vrt',
      '{"objects":[{"Name":"o1","Text":"no scripts"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raExcluded, C.Action);
      Assert.AreEqual(0, C.ScriptBeforeCount);
      Assert.AreEqual(0, C.ScriptAfterCount);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_ScriptMode_WithScriptsRun;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_scripts.vrt');
    WriteReport(Dir, '01_scripts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "Beep",' +
      '"OnAfterPrint": "Beep"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raRun, C.Action);
      Assert.AreEqual(1, C.ScriptBeforeCount);
      Assert.AreEqual(1, C.ScriptAfterCount);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

// ---------------------------------------------------------------------------
// Skip policy
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_Skip_TestPrefix;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, 'test_whatever.vrt');
    WriteReport(Dir, 'test_whatever.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raSkip, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Skip_16LargePreviewWarning;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '16_large_preview_warning.vrt');
    WriteReport(Dir, '16_large_preview_warning.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raSkip, C.Action);

    // Only the exact name is skipped; a similar name is not.
    WriteReport(Dir, '16_large_preview_warning2.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(
      TPath.Combine(Dir, '16_large_preview_warning2.vrt'), '', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Skip_OrdinaryNotSkipped;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '01_ordinary.vrt');
    WriteReport(Dir, '01_ordinary.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmAll);
    Assert.AreEqual(raRun, C.Action);

    // Legacy skip prefix is case-sensitive StartsWith('test').
    WriteReport(Dir, 'TEST_UPPER.vrt', '{}');
    C := TReportDiscovery.ClassifyReport(
      TPath.Combine(Dir, 'TEST_UPPER.vrt'), '', rmAll);
    Assert.AreEqual(raRun, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;
// ---------------------------------------------------------------------------
// Critical precedence
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_Precedence_ScriptModeTestNoScripts_Excluded;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, 'test_no_scripts.vrt');
    WriteReport(Dir, 'test_no_scripts.vrt',
      '{"objects":[{"Name":"o1","Text":"no scripts"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raExcluded, C.Action);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Precedence_ScriptModeTestWithScripts_Skip;
var
  Dir: string;
  FileName: string;
  Mode: TReportRunMode;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, 'test_with_scripts.vrt');
    WriteReport(Dir, 'test_with_scripts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "Beep"}]}');
    for Mode in [rmScriptOnly, rmScriptTraceOnly] do
    begin
      C := TReportDiscovery.ClassifyReport(FileName, '', Mode);
      Assert.AreEqual(raSkip, C.Action);
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TDiscoveryTests.Test_Precedence_FilterBeforeSkipAndScriptMode;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    // A mismatching filter wins over both the skip policy and the
    // script-mode exclusion: the file is never read and never counted.
    FileName := TPath.Combine(Dir, 'test_with_scripts.vrt');
    WriteReport(Dir, 'test_with_scripts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "Beep"}]}');
    C := TReportDiscovery.ClassifyReport(FileName, '99_other.vrt', rmScriptOnly);
    Assert.AreEqual(raExcluded, C.Action);
    Assert.AreEqual(0, C.ScriptBeforeCount);
    Assert.AreEqual(0, C.ScriptAfterCount);

    // Same for a plain report in rmAll.
    C := TReportDiscovery.ClassifyReport(FileName, '99_other.vrt', rmAll);
    Assert.AreEqual(raExcluded, C.Action);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

// ---------------------------------------------------------------------------
// Classification output
// ---------------------------------------------------------------------------

procedure TDiscoveryTests.Test_Classification_OutputFields;
var
  Dir: string;
  FileName: string;
  C: TReportClassification;
begin
  Dir := MakeTempDir;
  try
    FileName := TPath.Combine(Dir, '07_scripts.vrt');
    WriteReport(Dir, '07_scripts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "A","OnAfterPrint": "B"},' +
      '{"Name":"o2","OnBeforePrint": "A"}]}');
    C := TReportDiscovery.ClassifyReport(FileName, '', rmScriptOnly);
    Assert.AreEqual(FileName, C.FileName);
    Assert.AreEqual('07_scripts.vrt', C.ReportName);
    Assert.AreEqual(raRun, C.Action);
    Assert.AreEqual(2, C.ScriptBeforeCount);
    Assert.AreEqual(1, C.ScriptAfterCount);

    // Script counts stay zero in rmAll; Action determined by skip policy.
    WriteReport(Dir, 'test_counts.vrt',
      '{"objects":[{"Name":"o1","OnBeforePrint": "A"}]}');
    C := TReportDiscovery.ClassifyReport(
      TPath.Combine(Dir, 'test_counts.vrt'), '', rmAll);
    Assert.AreEqual('test_counts.vrt', C.ReportName);
    Assert.AreEqual(raSkip, C.Action);
    Assert.AreEqual(0, C.ScriptBeforeCount);
    Assert.AreEqual(0, C.ScriptAfterCount);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDiscoveryTests);

end.