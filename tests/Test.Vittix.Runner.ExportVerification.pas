unit Test.Vittix.Runner.ExportVerification;

{
  Phase 3F-1: focused tests for the shared HTML smoke report predicate.
  IsHtmlSmokeReport is the single source of truth determining whether a
  report receives HTML export smoke verification; it must never drift
  between Vittix.Runner.Console and Vittix.Runner.Execution.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.ExportVerification;

type
  [TestFixture]
  TRunnerExportVerificationTests = class
  public
    [Test] procedure Test_ExactReportName_True;
    [Test] procedure Test_UpperCaseReportName_True;
    [Test] procedure Test_MixedCaseReportName_True;
    [Test] procedure Test_OtherVrtReport_False;
    [Test] procedure Test_EmptyString_False;
    [Test] procedure Test_WhitespacePaddedName_False;
  end;

implementation

procedure TRunnerExportVerificationTests.Test_ExactReportName_True;
begin
  Assert.IsTrue(IsHtmlSmokeReport('38_export_html.vrt'));
end;

procedure TRunnerExportVerificationTests.Test_UpperCaseReportName_True;
begin
  Assert.IsTrue(IsHtmlSmokeReport('38_EXPORT_HTML.VRT'));
end;

procedure TRunnerExportVerificationTests.Test_MixedCaseReportName_True;
begin
  Assert.IsTrue(IsHtmlSmokeReport('38_Export_Html.Vrt'));
end;

procedure TRunnerExportVerificationTests.Test_OtherVrtReport_False;
begin
  Assert.IsFalse(IsHtmlSmokeReport('40_export_xlsx.vrt'));
end;

procedure TRunnerExportVerificationTests.Test_EmptyString_False;
begin
  Assert.IsFalse(IsHtmlSmokeReport(''));
end;

procedure TRunnerExportVerificationTests.Test_WhitespacePaddedName_False;
begin
  Assert.IsFalse(IsHtmlSmokeReport(' 38_export_html.vrt'));
end;

initialization
  TDUnitX.RegisterTestFixture(TRunnerExportVerificationTests);

end.