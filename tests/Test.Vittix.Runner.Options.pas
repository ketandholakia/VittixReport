unit Test.Vittix.Runner.Options;

{
  Phase 3C-1: deterministic unit tests for CLI option parsing.
  Tests call ParseOptions directly with explicit argument arrays and never
  depend on the actual process command line.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Runner.Options;

type
  [TestFixture]
  TRunnerOptionsTests = class
  private
    function Parse(const AArgs: array of string;
      out AOptions: TRunnerOptions): Boolean;
  public
    [Test] procedure Test_Defaults_NoOptions;
    [Test] procedure Test_ExplicitReports_OverridesProbe;
    [Test] procedure Test_ExplicitBaseline_OverridesDefault;
    [Test] procedure Test_ExplicitSampleData_OverridesDefault;
    [Test] procedure Test_ExplicitOutput_OverridesDefault;
    [Test] procedure Test_FilterSpaceSyntax;
    [Test] procedure Test_FilterEqualsSyntax;
    [Test] procedure Test_PositionalFilter_Preserved;
    [Test] procedure Test_FilterAndPositional_Conflict;
    [Test] procedure Test_DuplicateValueOption_Error;
    [Test] procedure Test_OptionWithoutValue_Error;
    [Test] procedure Test_UnknownOption_Error;
    [Test] procedure Test_ReportsAndBaseline_Independent;
    [Test] procedure Test_Help_LongSwitch;
    [Test] procedure Test_Help_ShortSwitch;
    [Test] procedure Test_Scripts_Switch;
    [Test] procedure Test_ScriptTrace_Switch;
    [Test] procedure Test_KeepVectorPDF_Switch;
    [Test] procedure Test_StrictFlag;
    [Test] procedure Test_StrictWithExistingOptions;
    [Test] procedure Test_StrictEqualsSyntaxRejected;
    [Test] procedure Test_StrictFalseSyntaxRejected;
    [Test] procedure Test_Pause_Switch;
    [Test] procedure Test_StrictWithFilterRejected;
    [Test] procedure Test_FilterBeforeStrictRejected;
    [Test] procedure Test_StrictWithScriptsRejected;
    [Test] procedure Test_ScriptsBeforeStrictRejected;
    [Test] procedure Test_StrictWithScriptTraceRejected;
    [Test] procedure Test_ScriptTraceBeforeStrictRejected;
    [Test] procedure Test_StrictWithKeepVectorPdfAccepted;
    [Test] procedure Test_StrictWithOutputAccepted;
    [Test] procedure Test_StrictWithBaselineAccepted;
    [Test] procedure Test_StrictWithReportsAccepted;
    // Phase 3D-5: --format options
    [Test] procedure Test_Format_DefaultIsText;
    [Test] procedure Test_Format_Text;
    [Test] procedure Test_Format_TextEquals;
    [Test] procedure Test_Format_Json;
    [Test] procedure Test_Format_JsonEquals;
    [Test] procedure Test_Format_JsonUpperCase;
    [Test] procedure Test_Format_CaseInsensitiveValue;
    [Test] procedure Test_Format_InvalidValue;
    [Test] procedure Test_Format_DuplicateFormat;
    [Test] procedure Test_Format_DuplicateTextText;
    [Test] procedure Test_Format_MissingValue;
    [Test] procedure Test_Format_EmptyValue;
    [Test] procedure Test_Format_StrictWithJson;
    [Test] procedure Test_Format_FilterWithJson;
    [Test] procedure Test_Format_ScriptsWithJson;
    [Test] procedure Test_Format_ScriptTraceWithJsonRejected;
    [Test] procedure Test_Format_KeepVectorPdfWithJson;
    [Test] procedure Test_Format_PauseWithJsonRejected;
  end;

implementation

function TRunnerOptionsTests.Parse(const AArgs: array of string;
  out AOptions: TRunnerOptions): Boolean;
var
  Args: TArray<string>;
  I: Integer;
begin
  SetLength(Args, Length(AArgs));
  for I := 0 to High(AArgs) do
    Args[I] := AArgs[I];
  Result := ParseOptions(Args, AOptions);
end;

procedure TRunnerOptionsTests.Test_Defaults_NoOptions;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse([], Options));
  Assert.AreEqual('', Options.ReportsPath);
  Assert.AreEqual('', Options.BaselineFile);
  Assert.AreEqual('', Options.SampleDataFile);
  Assert.AreEqual('', Options.OutputPath);
  Assert.AreEqual('', Options.Filter);
  Assert.AreEqual('', Options.ErrorMessage);
  Assert.IsFalse(Options.ScriptOnly);
  Assert.IsFalse(Options.ScriptTraceOnly);
  Assert.IsFalse(Options.KeepVectorPDF);
  Assert.IsFalse(Options.Pause);
  Assert.IsFalse(Options.Help);
end;

procedure TRunnerOptionsTests.Test_ExplicitReports_OverridesProbe;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--reports', 'C:\temp\reports'], Options));
  Assert.AreEqual('C:\temp\reports', Options.ReportsPath);
end;

procedure TRunnerOptionsTests.Test_ExplicitBaseline_OverridesDefault;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--baseline', 'C:\temp\my.json'], Options));
  Assert.AreEqual('C:\temp\my.json', Options.BaselineFile);
end;

procedure TRunnerOptionsTests.Test_ExplicitSampleData_OverridesDefault;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--sample-data', 'C:\temp\data.json'], Options));
  Assert.AreEqual('C:\temp\data.json', Options.SampleDataFile);
end;

procedure TRunnerOptionsTests.Test_ExplicitOutput_OverridesDefault;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--output', 'C:\temp\out'], Options));
  Assert.AreEqual('C:\temp\out', Options.OutputPath);
end;

procedure TRunnerOptionsTests.Test_FilterSpaceSyntax;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--filter', '40_export_xlsx.vrt'], Options));
  Assert.AreEqual('40_export_xlsx.vrt', Options.Filter);
end;

procedure TRunnerOptionsTests.Test_FilterEqualsSyntax;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--filter=40_export_xlsx.vrt'], Options));
  Assert.AreEqual('40_export_xlsx.vrt', Options.Filter);
end;

procedure TRunnerOptionsTests.Test_PositionalFilter_Preserved;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['40_export_xlsx.vrt'], Options));
  Assert.AreEqual('40_export_xlsx.vrt', Options.Filter);
end;

procedure TRunnerOptionsTests.Test_FilterAndPositional_Conflict;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--filter', 'a.vrt', 'b.vrt'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_DuplicateValueOption_Error;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--output', 'a', '--output', 'b'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_OptionWithoutValue_Error;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--baseline'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_UnknownOption_Error;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--bogus'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_ReportsAndBaseline_Independent;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--reports', 'D:\rep', '--baseline', 'D:\base.json'], Options));
  Assert.AreEqual('D:\rep', Options.ReportsPath);
  Assert.AreEqual('D:\base.json', Options.BaselineFile);
end;

procedure TRunnerOptionsTests.Test_Help_LongSwitch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--help'], Options));
  Assert.IsTrue(Options.Help);
end;

procedure TRunnerOptionsTests.Test_Help_ShortSwitch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['-h'], Options));
  Assert.IsTrue(Options.Help);
end;

procedure TRunnerOptionsTests.Test_Scripts_Switch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--scripts'], Options));
  Assert.IsTrue(Options.ScriptOnly);
end;

procedure TRunnerOptionsTests.Test_ScriptTrace_Switch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--script-trace'], Options));
  Assert.IsTrue(Options.ScriptTraceOnly);
end;

procedure TRunnerOptionsTests.Test_KeepVectorPDF_Switch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--keep-vector-pdf'], Options));
  Assert.IsTrue(Options.KeepVectorPDF);
end;

procedure TRunnerOptionsTests.Test_StrictFlag;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithExistingOptions;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--keep-vector-pdf'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.IsTrue(Options.KeepVectorPDF);
end;

procedure TRunnerOptionsTests.Test_StrictEqualsSyntaxRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--strict=true'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictFalseSyntaxRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--strict=false'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Pause_Switch;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['-pause'], Options));
  Assert.IsTrue(Options.Pause);
end;

procedure TRunnerOptionsTests.Test_StrictWithFilterRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--strict', '--filter', 'foo.vrt'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_FilterBeforeStrictRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--filter', 'foo.vrt', '--strict'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithScriptsRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--strict', '--scripts'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_ScriptsBeforeStrictRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--scripts', '--strict'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithScriptTraceRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--strict', '--script-trace'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_ScriptTraceBeforeStrictRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--script-trace', '--strict'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithKeepVectorPdfAccepted;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--keep-vector-pdf'], Options));
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithOutputAccepted;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--output', 'D:\out'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.AreEqual('D:\out', Options.OutputPath);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithBaselineAccepted;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--baseline', 'D:\base.json'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.AreEqual('D:\base.json', Options.BaselineFile);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_StrictWithReportsAccepted;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--reports', 'D:\reports'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.AreEqual('D:\reports', Options.ReportsPath);
  Assert.AreEqual('', Options.ErrorMessage);
end;
// =============================================
// Phase 3D-5: --format options tests
// =============================================

procedure TRunnerOptionsTests.Test_Format_DefaultIsText;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse([], Options));
  Assert.AreEqual(ofText, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_Text;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format', 'text'], Options));
  Assert.AreEqual(ofText, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_TextEquals;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format=text'], Options));
  Assert.AreEqual(ofText, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_Json;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format', 'json'], Options));
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_JsonEquals;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format=json'], Options));
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_JsonUpperCase;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format', 'JSON'], Options));
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_CaseInsensitiveValue;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--format', 'Json'], Options));
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_InvalidValue;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--format', 'xml'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_DuplicateFormat;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--format', 'json', '--format', 'text'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;
procedure TRunnerOptionsTests.Test_Format_DuplicateTextText;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--format', 'text', '--format', 'text'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_MissingValue;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--format'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_EmptyValue;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--format='], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_StrictWithJson;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--strict', '--format', 'json'], Options));
  Assert.IsTrue(Options.&Strict);
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_FilterWithJson;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--filter', 'report.vrt', '--format', 'json'], Options));
  Assert.AreEqual('report.vrt', Options.Filter);
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_ScriptsWithJson;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--scripts', '--format', 'json'], Options));
  Assert.IsTrue(Options.ScriptOnly);
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_ScriptTraceWithJsonRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['--script-trace', '--format', 'json'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_KeepVectorPdfWithJson;
var
  Options: TRunnerOptions;
begin
  Assert.IsTrue(Parse(['--keep-vector-pdf', '--format', 'json'], Options));
  Assert.IsTrue(Options.KeepVectorPDF);
  Assert.AreEqual(ofJson, Options.OutputFormat);
  Assert.AreEqual('', Options.ErrorMessage);
end;

procedure TRunnerOptionsTests.Test_Format_PauseWithJsonRejected;
var
  Options: TRunnerOptions;
begin
  Assert.IsFalse(Parse(['-pause', '--format', 'json'], Options));
  Assert.IsNotEmpty(Options.ErrorMessage);
end;

initialization
  TDUnitX.RegisterTestFixture(TRunnerOptionsTests);

end.
