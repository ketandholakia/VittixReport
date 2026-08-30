unit Test.Vittix.Runner.Baseline;

{
  Phase 3C-2b-1: read-only baseline loader tests.
  Most tests use LoadFromString so they never touch the filesystem.
  The canonical reports/regression_baselines.json is NEVER used as a
  test output target; file tests use temporary files only.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Baseline;

type
  [TestFixture]
  TBaselineLoaderTests = class
  private
    function Load(const AContent: string;
      out ABaseline: TRegressionBaseline;
      out AError: TBaselineParseError): Boolean;
    function MakeResult(const AName: string; APages: Integer): TReportPageResult;
  public
    [Test] procedure Test_ValidBaseline;
    [Test] procedure Test_EmptyJsonRejected;
    [Test] procedure Test_MalformedJsonRejected;
    [Test] procedure Test_ArrayRootRejected;
    [Test] procedure Test_StringRootRejected;
    [Test] procedure Test_NumberRootRejected;
    [Test] procedure Test_StringPageCountRejected;
    [Test] procedure Test_BooleanPageCountRejected;
    [Test] procedure Test_NullPageCountRejected;
    [Test] procedure Test_ObjectPageCountRejected;
    [Test] procedure Test_ArrayPageCountRejected;
    [Test] procedure Test_FractionalPageCountRejected;
    [Test] procedure Test_NegativePageCountRejected;
    [Test] procedure Test_ZeroPageCountRejected;
    [Test] procedure Test_NonVrtKeyRejected;
    [Test] procedure Test_DuplicateReportRejected;
    [Test] procedure Test_CaseInsensitiveLookup;
    [Test] procedure Test_MissingReportLookup;
    [Test] procedure Test_GetReportNames_PreservesOrder;
    [Test] procedure Test_LoadFromFile_MissingFile;
    [Test] procedure Test_LoadFromFile_Valid;
    [Test] procedure Test_LoadDoesNotModifySource;
    // Phase 3C-2b-2: reconciliation
    [Test] procedure Test_Reconcile_AllMatching;
    [Test] procedure Test_Reconcile_PageCountMismatch;
    [Test] procedure Test_Reconcile_MissingBaseline;
    [Test] procedure Test_Reconcile_OrphanBaseline;
    [Test] procedure Test_Reconcile_UsesUnionOfSets;
    [Test] procedure Test_Reconcile_CaseInsensitiveNames;
    [Test] procedure Test_Reconcile_IssuesAreDeterministic;
    [Test] procedure Test_Reconcile_DoesNotModifyBaseline;
    // Phase 3C-2c-2: strict failure policy
    [Test] procedure Test_StrictHasFailures_NoIssuesNoExecutionFailures;
    [Test] procedure Test_StrictHasFailures_Mismatch;
    [Test] procedure Test_StrictHasFailures_MissingBaseline;
    [Test] procedure Test_StrictHasFailures_OrphanBaseline;
    [Test] procedure Test_StrictHasFailures_ExecutionFailures;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

function TBaselineLoaderTests.Load(const AContent: string;
  out ABaseline: TRegressionBaseline;
  out AError: TBaselineParseError): Boolean;
begin
  Result := TRegressionBaseline.LoadFromString(AContent, ABaseline, AError);
end;

procedure TBaselineLoaderTests.Test_ValidBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Pages: Integer;
begin
  Assert.IsTrue(Load('{"01_simple_masterdata.vrt": 6, "41_twopass_totalpages.vrt": 75}',
    Baseline, Error));
  try
    Assert.AreEqual(2, Baseline.Count);
    Assert.IsTrue(Baseline.TryGetExpectedPages('01_simple_masterdata.vrt', Pages));
    Assert.AreEqual(6, Pages);
    Assert.IsTrue(Baseline.TryGetExpectedPages('41_twopass_totalpages.vrt', Pages));
    Assert.AreEqual(75, Pages);
    Assert.IsFalse(Baseline.TryGetExpectedPages('99_unknown.vrt', Pages));
    Assert.IsTrue(Baseline.ContainsReport('01_simple_masterdata.vrt'));
    Assert.IsFalse(Baseline.ContainsReport('99_unknown.vrt'));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_EmptyJsonRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
  Assert.IsNull(Baseline);
  Assert.IsFalse(Load('   '#13#10, Baseline, Error));
end;

procedure TBaselineLoaderTests.Test_MalformedJsonRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"01_simple_masterdata.vrt": 6,,}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
  Assert.IsNull(Baseline);
end;

procedure TBaselineLoaderTests.Test_ArrayRootRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('[{"a.vrt": 1}]', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_StringRootRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('"abc"', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_NumberRootRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('123', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_StringPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": "10"}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_BooleanPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": true}', Baseline, Error));
  Assert.IsFalse(Load('{"report.vrt": false}', Baseline, Error));
end;

procedure TBaselineLoaderTests.Test_NullPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": null}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_ObjectPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": {"pages": 10}}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_ArrayPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": [10]}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_FractionalPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": 10.5}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_NegativePageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": -3}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_ZeroPageCountRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  // No legitimate zero-page report exists in the regression suite.
  Assert.IsFalse(Load('{"report.vrt": 0}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_NonVrtKeyRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.txt": 10}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_DuplicateReportRejected;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(Load('{"report.vrt": 10, "report.vrt": 12}', Baseline, Error));
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_CaseInsensitiveLookup;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Pages: Integer;
begin
  Assert.IsTrue(Load('{"01_Simple_MasterData.vrt": 6}', Baseline, Error));
  try
    Assert.IsTrue(Baseline.TryGetExpectedPages('01_simple_masterdata.vrt', Pages));
    Assert.AreEqual(6, Pages);
    Assert.IsTrue(Baseline.TryGetExpectedPages('01_SIMPLE_MASTERDATA.VRT', Pages));
    Assert.AreEqual(6, Pages);
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_MissingReportLookup;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Pages: Integer;
begin
  Assert.IsTrue(Load('{"a.vrt": 1}', Baseline, Error));
  try
    Assert.IsFalse(Baseline.TryGetExpectedPages('b.vrt', Pages));
    Assert.IsFalse(Baseline.ContainsReport('b.vrt'));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_GetReportNames_PreservesOrder;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Names: TArray<string>;
begin
  Assert.IsTrue(Load('{"b.vrt": 2, "a.vrt": 1, "c.vrt": 3}', Baseline, Error));
  try
    Names := Baseline.GetReportNames;
    Assert.AreEqual(3, Length(Names));
    Assert.AreEqual('b.vrt', Names[0]);
    Assert.AreEqual('a.vrt', Names[1]);
    Assert.AreEqual('c.vrt', Names[2]);
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_LoadFromFile_MissingFile;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  Assert.IsFalse(TRegressionBaseline.LoadFromFile(
    TPath.Combine(TPath.GetTempPath, 'no_such_baseline_xyz_1234.json'),
    Baseline, Error));
  Assert.IsNull(Baseline);
  Assert.IsNotEmpty(Error.Message);
end;

procedure TBaselineLoaderTests.Test_LoadFromFile_Valid;
var
  FileName: string;
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Pages: Integer;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'vittix_baseline_test_valid.json');
  try
    TFile.WriteAllText(FileName, '{"01_simple_masterdata.vrt": 6}', TEncoding.UTF8);
    Assert.IsTrue(TRegressionBaseline.LoadFromFile(FileName, Baseline, Error));
    try
      Assert.AreEqual(1, Baseline.Count);
      Assert.IsTrue(Baseline.TryGetExpectedPages('01_simple_masterdata.vrt', Pages));
      Assert.AreEqual(6, Pages);
    finally
      Baseline.Free;
    end;
  finally
    TFile.Delete(FileName);
  end;
end;

procedure TBaselineLoaderTests.Test_LoadDoesNotModifySource;
var
  FileName: string;
  Before, After: string;
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'vittix_baseline_test_source.json');
  try
    Before := '{"01_simple_masterdata.vrt": 6}';
    TFile.WriteAllText(FileName, Before, TEncoding.UTF8);

    Assert.IsTrue(TRegressionBaseline.LoadFromFile(FileName, Baseline, Error));
    try
      Assert.AreEqual(1, Baseline.Count);
    finally
      Baseline.Free;
    end;

    After := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Assert.AreEqual(Before, After);
  finally
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;
end;

{ --- Phase 3C-2b-2: reconciliation tests --- }

function TBaselineLoaderTests.MakeResult(const AName: string;
  APages: Integer): TReportPageResult;
begin
  Result.ReportName := AName;
  Result.PageCount := APages;
end;

procedure TBaselineLoaderTests.Test_Reconcile_AllMatching;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5, "B.vrt": 10}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 5), MakeResult('B.vrt', 10)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsFalse(Rec.HasIssues);
    Assert.AreEqual(2, Rec.MatchingCount);
    Assert.AreEqual(0, Rec.MissingBaselineCount);
    Assert.AreEqual(0, Rec.OrphanBaselineCount);
    Assert.AreEqual(0, Rec.PageMismatchCount);
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_PageCountMismatch;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 6)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.AreEqual(1, Length(Rec.Issues));
    Assert.AreEqual(Ord(bikPageCountMismatch), Ord(Rec.Issues[0].Kind));
    Assert.AreEqual('A.vrt', Rec.Issues[0].ReportName);
    Assert.AreEqual(5, Rec.Issues[0].ExpectedPages);
    Assert.AreEqual(6, Rec.Issues[0].ActualPages);
    Assert.IsNotEmpty(Rec.Issues[0].Message);
    Assert.AreEqual(0, Rec.MatchingCount);
    Assert.AreEqual(1, Rec.PageMismatchCount);
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_MissingBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  // Empty baseline object is still valid with zero entries.
  Assert.IsTrue(Load('{}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 4)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.AreEqual(1, Length(Rec.Issues));
    Assert.AreEqual(Ord(bikMissingBaseline), Ord(Rec.Issues[0].Kind));
    Assert.AreEqual('A.vrt', Rec.Issues[0].ReportName);
    Assert.AreEqual(4, Rec.Issues[0].ActualPages);
    Assert.AreEqual(1, Rec.MissingBaselineCount);
    Assert.AreEqual(0, Baseline.Count); // no baseline entry was created
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_OrphanBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 7}', Baseline, Error));
  try
    Rec := TRegressionBaseline.Reconcile(Baseline, nil);
    Assert.AreEqual(1, Length(Rec.Issues));
    Assert.AreEqual(Ord(bikOrphanBaseline), Ord(Rec.Issues[0].Kind));
    Assert.AreEqual('A.vrt', Rec.Issues[0].ReportName);
    Assert.AreEqual(7, Rec.Issues[0].ExpectedPages);
    Assert.AreEqual(1, Rec.OrphanBaselineCount);
    Assert.AreEqual(1, Baseline.Count); // no baseline entry was removed
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_UsesUnionOfSets;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
  I, Missing, Orphan, Mismatch: Integer;
begin
  // Reports: A, B, C — Baseline: A, B, D
  Assert.IsTrue(Load('{"A.vrt": 5, "B.vrt": 10, "D.vrt": 2}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 5), MakeResult('B.vrt', 10), MakeResult('C.vrt', 3)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);

    Assert.AreEqual(2, Length(Rec.Issues));
    Assert.AreEqual('C.vrt', Rec.Issues[0].ReportName);
    Assert.AreEqual(Ord(bikMissingBaseline), Ord(Rec.Issues[0].Kind));
    Assert.AreEqual('D.vrt', Rec.Issues[1].ReportName);
    Assert.AreEqual(Ord(bikOrphanBaseline), Ord(Rec.Issues[1].Kind));

    Missing := 0; Orphan := 0; Mismatch := 0;
    for I := 0 to High(Rec.Issues) do
      case Rec.Issues[I].Kind of
        bikMissingBaseline: Inc(Missing);
        bikOrphanBaseline: Inc(Orphan);
        bikPageCountMismatch: Inc(Mismatch);
      end;
    Assert.AreEqual(1, Missing);
    Assert.AreEqual(1, Orphan);
    Assert.AreEqual(0, Mismatch);
    Assert.AreEqual(2, Rec.MatchingCount); // A and B
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_CaseInsensitiveNames;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"01_simple_masterdata.vrt": 6}', Baseline, Error));
  try
    Actual := [MakeResult('01_SIMPLE_MASTERDATA.VRT', 6)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsFalse(Rec.HasIssues);
    Assert.AreEqual(1, Rec.MatchingCount);
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_IssuesAreDeterministic;
var
  BaselineA, BaselineB: TRegressionBaseline;
  Error: TBaselineParseError;
  ActualA, ActualB: TArray<TReportPageResult>;
  RecA, RecB: TBaselineReconciliationResult;
  I: Integer;
begin
  // Same logical data, different insertion orders.
  Assert.IsTrue(Load('{"Z.vrt": 1, "A.vrt": 2, "M.vrt": 3}', BaselineA, Error));
  Assert.IsTrue(Load('{"M.vrt": 3, "A.vrt": 2, "Z.vrt": 1}', BaselineB, Error));
  try
    ActualA := [MakeResult('M.vrt', 9), MakeResult('A.vrt', 2), MakeResult('Z.vrt', 4)];
    ActualB := [MakeResult('Z.vrt', 4), MakeResult('A.vrt', 2), MakeResult('M.vrt', 9)];
    RecA := TRegressionBaseline.Reconcile(BaselineA, ActualA);
    RecB := TRegressionBaseline.Reconcile(BaselineB, ActualB);

    Assert.AreEqual(Length(RecA.Issues), Length(RecB.Issues));
    Assert.AreEqual(2, Length(RecA.Issues));
    for I := 0 to High(RecA.Issues) do
    begin
      Assert.AreEqual(RecA.Issues[I].ReportName, RecB.Issues[I].ReportName);
      Assert.AreEqual(Ord(RecA.Issues[I].Kind), Ord(RecB.Issues[I].Kind));
    end;
    // Sorted by case-insensitive name: M.vrt (mismatch) then Z.vrt (mismatch).
    Assert.AreEqual('M.vrt', RecA.Issues[0].ReportName);
    Assert.AreEqual('Z.vrt', RecA.Issues[1].ReportName);
  finally
    BaselineA.Free;
    BaselineB.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_Reconcile_DoesNotModifyBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
  Pages: Integer;
begin
  Assert.IsTrue(Load('{"A.vrt": 5, "B.vrt": 10}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 6), MakeResult('C.vrt', 1)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsTrue(Rec.HasIssues);

    // Public API only: count, entries and values unchanged.
    Assert.AreEqual(2, Baseline.Count);
    Assert.IsTrue(Baseline.TryGetExpectedPages('A.vrt', Pages));
    Assert.AreEqual(5, Pages);
    Assert.IsTrue(Baseline.TryGetExpectedPages('B.vrt', Pages));
    Assert.AreEqual(10, Pages);
    Assert.IsFalse(Baseline.ContainsReport('C.vrt'));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_StrictHasFailures_NoIssuesNoExecutionFailures;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 5)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsFalse(StrictHasFailures(Rec, 0));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_StrictHasFailures_Mismatch;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 6)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsTrue(StrictHasFailures(Rec, 0));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_StrictHasFailures_MissingBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5}', Baseline, Error));
  try
    Actual := [MakeResult('B.vrt', 2)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsTrue(StrictHasFailures(Rec, 0));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_StrictHasFailures_OrphanBaseline;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5, "Z.vrt": 9}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 5)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsTrue(Rec.HasIssues);
    Assert.IsTrue(StrictHasFailures(Rec, 0));
  finally
    Baseline.Free;
  end;
end;

procedure TBaselineLoaderTests.Test_StrictHasFailures_ExecutionFailures;
var
  Baseline: TRegressionBaseline;
  Error: TBaselineParseError;
  Actual: TArray<TReportPageResult>;
  Rec: TBaselineReconciliationResult;
begin
  Assert.IsTrue(Load('{"A.vrt": 5}', Baseline, Error));
  try
    Actual := [MakeResult('A.vrt', 5)];
    Rec := TRegressionBaseline.Reconcile(Baseline, Actual);
    Assert.IsFalse(Rec.HasIssues);
    Assert.IsTrue(StrictHasFailures(Rec, 1));
  finally
    Baseline.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBaselineLoaderTests);

end.
