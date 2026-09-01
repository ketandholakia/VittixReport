unit Test.Vittix.Runner.Baseline.Policy;

{
  Phase 3F-5: tests for the extracted baseline policy layer
  (Vittix.Runner.Baseline.Policy). Tests cover the policy decisions that are
  new to this layer and not already covered by Test.Vittix.Runner.Baseline
  or Test.Vittix.Runner.Baseline.Legacy.

  Filesystem behavior uses nonexistent temp paths so no files are created or
  modified. reports/ and regression_baselines.json are never touched.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Vittix.Runner.Baseline,
  Vittix.Runner.Baseline.Legacy,
  Vittix.Runner.Baseline.Policy;

type
  [TestFixture]
  TBaselinePolicyTests = class
  public
    [Test] procedure Test_ResolveBaselineFilePath_NoExplicit;
    [Test] procedure Test_ResolveBaselineFilePath_WithExplicit;
    [Test] procedure Test_LoadStrictBaseline_NonExistentFile;
    [Test] procedure Test_EvaluateNonStrictReport_Match;
    [Test] procedure Test_EvaluateNonStrictReport_Mismatch;
    [Test] procedure Test_EvaluateNonStrictReport_NoExpectedPages;
  end;

implementation

function TempBaselineFileName: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'VittixBaselinePolicy_' + IntToStr(Random(100000000)) + '.json');
end;

procedure TBaselinePolicyTests.Test_ResolveBaselineFilePath_NoExplicit;
var
  Path: string;
begin
  Path := ResolveBaselineFilePath('C:\reports', '');
  Assert.AreEqual(TPath.Combine('C:\reports', 'regression_baselines.json'), Path);
end;

procedure TBaselinePolicyTests.Test_ResolveBaselineFilePath_WithExplicit;
var
  Path: string;
begin
  Path := ResolveBaselineFilePath('C:\reports', 'C:\custom\baseline.json');
  Assert.AreEqual(TPath.GetFullPath('C:\custom\baseline.json'), Path);
end;

procedure TBaselinePolicyTests.Test_LoadStrictBaseline_NonExistentFile;
var
  LB: TRegressionBaseline;
  Diag: string;
  FileName: string;
begin
  FileName := TempBaselineFileName;
  Assert.IsFalse(TFile.Exists(FileName));
  Assert.IsFalse(LoadStrictBaseline(FileName, LB, Diag));
  Assert.IsNull(LB);
  Assert.IsTrue(Diag <> '');
  Assert.IsTrue(Diag.Contains('Error: strict regression baseline could not be loaded:'));
  Assert.IsTrue(Diag.Contains(FileName));
  Assert.IsTrue(Diag.Contains('Baseline file not found:'));
end;

procedure TBaselinePolicyTests.Test_EvaluateNonStrictReport_Match;
var
  LB: TLegacyBaseline;
  D: TNonStrictReportDecision;
  FileName: string;
begin
  FileName := TempBaselineFileName;
  LB := TLegacyBaseline.LoadOrEmpty(FileName);
  LB.RegisterReport('test.vrt', 5);
  D := EvaluateNonStrictReport(LB, 'test.vrt', 5);
  Assert.IsTrue(D.HasExpectedPages);
  Assert.AreEqual(5, D.ExpectedPages);
  Assert.IsFalse(D.Mismatch);
  Assert.IsEmpty(D.ErrorMessage);
  Assert.IsFalse(D.ShouldRegister);
  LB.Free;
end;

procedure TBaselinePolicyTests.Test_EvaluateNonStrictReport_Mismatch;
var
  LB: TLegacyBaseline;
  D: TNonStrictReportDecision;
  FileName: string;
begin
  FileName := TempBaselineFileName;
  LB := TLegacyBaseline.LoadOrEmpty(FileName);
  LB.RegisterReport('test.vrt', 5);
  D := EvaluateNonStrictReport(LB, 'test.vrt', 10);
  Assert.IsTrue(D.HasExpectedPages);
  Assert.AreEqual(5, D.ExpectedPages);
  Assert.IsTrue(D.Mismatch);
  Assert.AreEqual('Pagination mismatch: Expected 5 pages, got 10', D.ErrorMessage);
  Assert.IsFalse(D.ShouldRegister);
  LB.Free;
end;

procedure TBaselinePolicyTests.Test_EvaluateNonStrictReport_NoExpectedPages;
var
  LB: TLegacyBaseline;
  D: TNonStrictReportDecision;
  FileName: string;
begin
  FileName := TempBaselineFileName;
  LB := TLegacyBaseline.LoadOrEmpty(FileName);
  D := EvaluateNonStrictReport(LB, 'test.vrt', 10);
  Assert.IsFalse(D.HasExpectedPages);
  Assert.IsFalse(D.Mismatch);
  Assert.IsEmpty(D.ErrorMessage);
  Assert.IsTrue(D.ShouldRegister);
  LB.Free;
end;

initialization
  TDUnitX.RegisterTestFixture(TBaselinePolicyTests);
end.