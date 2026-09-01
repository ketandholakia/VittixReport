unit Test.Vittix.Runner.ResultCollector;

{
  Phase 3F-6: focused tests for the extracted result collector
  (Vittix.Runner.ResultCollector). Only deterministic,
  pure/in-memory aspects are asserted.

  No report execution, no canonical reports, no canonical baseline,
  no GDI leaks, no global process state changes.
}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Vittix.Runner.Results,
  Vittix.Runner.ResultCollector;

type
  [TestFixture]
  TRunResultCollectorTests = class
  public
    [Test] procedure Test_Initialize_SetsReportsDiscovered;
    [Test] procedure Test_Initialize_EmptyReports;
    [Test] procedure Test_Append_PreservesOrder;
    [Test] procedure Test_Append_PreservesFields;
    [Test] procedure Test_Append_MultipleMixedResults;
  end;

implementation

procedure TRunResultCollectorTests.Test_Initialize_SetsReportsDiscovered;
var
  R: TRegressionRunResult;
begin
  TRunResultCollector.Initialize(R, 42);
  Assert.AreEqual(42, R.ReportsDiscovered);
  Assert.AreEqual(0, Length(R.Reports));
end;

procedure TRunResultCollectorTests.Test_Initialize_EmptyReports;
var
  R: TRegressionRunResult;
begin
  TRunResultCollector.Initialize(R, 0);
  Assert.AreEqual(0, R.ReportsDiscovered);
  Assert.AreEqual(0, Length(R.Reports));
end;

procedure TRunResultCollectorTests.Test_Append_PreservesOrder;
var
  R: TRegressionRunResult;
  A, B, C: TReportExecutionResult;
begin
  TRunResultCollector.Initialize(R, 3);
  A.ReportName := 'a.vrt';
  A.Status := resPassed;
  B.ReportName := 'b.vrt';
  B.Status := resFailed;
  C.ReportName := 'c.vrt';
  C.Status := resSkipped;

  TRunResultCollector.Append(R, A);
  TRunResultCollector.Append(R, B);
  TRunResultCollector.Append(R, C);

  Assert.AreEqual(3, Length(R.Reports));
  Assert.AreEqual('a.vrt', R.Reports[0].ReportName);
  Assert.AreEqual(resFailed, R.Reports[1].Status);
  Assert.AreEqual('c.vrt', R.Reports[2].ReportName);
end;

procedure TRunResultCollectorTests.Test_Append_PreservesFields;
var
  R: TRegressionRunResult;
  Rec: TReportExecutionResult;
begin
  TRunResultCollector.Initialize(R, 1);
  Rec.ReportName := 'test.vrt';
  Rec.Status := resFailed;
  Rec.PageCount := 6;
  Rec.HasPageCount := True;
  Rec.ExpectedPageCount := 6;
  Rec.HasExpectedPageCount := True;
  Rec.ErrorMessage := 'EClass: message';
  Rec.GdiLeakDelta := 25;

  TRunResultCollector.Append(R, Rec);

  Assert.AreEqual(1, Length(R.Reports));
  Assert.AreEqual('test.vrt', R.Reports[0].ReportName);
  Assert.AreEqual(resFailed, R.Reports[0].Status);
  Assert.AreEqual(6, R.Reports[0].PageCount);
  Assert.IsTrue(R.Reports[0].HasPageCount);
  Assert.AreEqual(6, R.Reports[0].ExpectedPageCount);
  Assert.IsTrue(R.Reports[0].HasExpectedPageCount);
  Assert.AreEqual('EClass: message', R.Reports[0].ErrorMessage);
  Assert.AreEqual(25, R.Reports[0].GdiLeakDelta);
end;

procedure TRunResultCollectorTests.Test_Append_MultipleMixedResults;
var
  R: TRegressionRunResult;
  Rec: TReportExecutionResult;
  I: Integer;
begin
  TRunResultCollector.Initialize(R, 5);

  for I := 1 to 5 do
  begin
    Rec.ReportName := Format('r%d.vrt', [I]);
    Rec.Status := resPassed;
    TRunResultCollector.Append(R, Rec);
  end;

  Rec.ReportName := 'leak.vrt';
  Rec.Status := resFailed;
  Rec.GdiLeakDelta := 30;
  TRunResultCollector.Append(R, Rec);

  Assert.AreEqual(6, Length(R.Reports));
  Assert.AreEqual(5, R.PassedCount);
  Assert.AreEqual(1, R.ExecutionFailureCount);
  Assert.AreEqual(0, R.SkippedCount);
  Assert.AreEqual(5, R.ReportsCheckedCount);
  Assert.IsFalse(R.IsSuccessful);
end;

initialization
  TDUnitX.RegisterTestFixture(TRunResultCollectorTests);

end.