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
  System.SysUtils,
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

    // Vector PDF page-object structure (the /Contents-inside-the-page check).
    [Test] procedure Test_VectorPdf_WellFormedPage_True;
    [Test] procedure Test_VectorPdf_ContentsOutsidePage_False;
    [Test] procedure Test_VectorPdf_ExtraCloseBrace_False;
    [Test] procedure Test_VectorPdf_NoContents_False;
    [Test] procedure Test_VectorPdf_PageCountMismatch_False;
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

{ --- Vector PDF page-object structure -------------------------------------- }

function AsciiBytes(const S: AnsiString): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I - 1] := Ord(S[I]);
end;

// A well-formed page object: /Contents sits inside the page dictionary.
function WellFormedPage: TBytes;
begin
  Result := AsciiBytes(
    '3 0 obj' + #10 +
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << ' +
    '/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> ' +
    '/Contents 4 0 R >>' + #10 +
    'endobj' + #10);
end;

procedure TRunnerExportVerificationTests.Test_VectorPdf_WellFormedPage_True;
begin
  Assert.IsTrue(VectorPdfPageObjectsWellFormed(WellFormedPage, 1));
end;

// Regression for the E0 defect: /Contents emitted AFTER the page dictionary
// closes (the page dictionary is then one '>>' short / not balanced).
function ContentsOutsidePage: TBytes;
begin
  Result := AsciiBytes(
    '3 0 obj' + #10 +
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << ' +
    '/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> >> ' +
    '/Contents 4 0 R >>' + #10 +
    'endobj' + #10);
end;

procedure TRunnerExportVerificationTests.Test_VectorPdf_ContentsOutsidePage_False;
begin
  Assert.IsFalse(VectorPdfPageObjectsWellFormed(ContentsOutsidePage, 1));
end;

procedure TRunnerExportVerificationTests.Test_VectorPdf_ExtraCloseBrace_False;
var
  B: TBytes;
begin
  // Balanced-looking but an extra '>>' makes the depth go negative.
  B := AsciiBytes(
    '3 0 obj' + #10 +
    '<< /Type /Page /Resources << /Font << /F1 << /Type /Font >> >> >> >> ' +
    '/Contents 4 0 R >>' + #10 +
    'endobj' + #10);
  Assert.IsFalse(VectorPdfPageObjectsWellFormed(B, 1));
end;

procedure TRunnerExportVerificationTests.Test_VectorPdf_NoContents_False;
var
  B: TBytes;
begin
  B := AsciiBytes(
    '3 0 obj' + #10 +
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>' + #10 +
    'endobj' + #10);
  Assert.IsFalse(VectorPdfPageObjectsWellFormed(B, 1));
end;

procedure TRunnerExportVerificationTests.Test_VectorPdf_PageCountMismatch_False;
begin
  // One well-formed page object, but two pages expected.
  Assert.IsFalse(VectorPdfPageObjectsWellFormed(WellFormedPage, 2));
end;

initialization
  TDUnitX.RegisterTestFixture(TRunnerExportVerificationTests);

end.