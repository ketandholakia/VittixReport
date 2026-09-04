program VittixReportTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  Test.Vittix.Report.Engine in 'Test.Vittix.Report.Engine.pas',
  Test.Vittix.Report.Undo in 'Test.Vittix.Report.Undo.pas',
  Test.Vittix.Report.Objects.Chart in 'Test.Vittix.Report.Objects.Chart.pas',
  Test.Vittix.Report.Serializer in 'Test.Vittix.Report.Serializer.pas',
  Test.Vittix.Report.Expressions in 'Test.Vittix.Report.Expressions.pas',
  Test.Vittix.Report.Characterization in 'Test.Vittix.Report.Characterization.pas',
  Test.Vittix.Runner.Options in 'Test.Vittix.Runner.Options.pas',
  Vittix.Runner.Options in '..\Vittix.Runner.Options.pas',
  Vittix.Runner.Discovery in '..\Vittix.Runner.Discovery.pas',
  Test.Vittix.Runner.Discovery in 'Test.Vittix.Runner.Discovery.pas',
  Vittix.Runner.Baseline in '..\Vittix.Runner.Baseline.pas',
  Test.Vittix.Runner.Baseline in 'Test.Vittix.Runner.Baseline.pas',
  Vittix.Runner.Baseline.Legacy in '..\Vittix.Runner.Baseline.Legacy.pas',
  Test.Vittix.Runner.Baseline.Legacy in 'Test.Vittix.Runner.Baseline.Legacy.pas',
  Vittix.Runner.Baseline.Policy in '..\Vittix.Runner.Baseline.Policy.pas',
  Test.Vittix.Runner.Baseline.Policy in 'Test.Vittix.Runner.Baseline.Policy.pas',
  Vittix.Runner.Results in '..\Vittix.Runner.Results.pas',
  Test.Vittix.Runner.Results in 'Test.Vittix.Runner.Results.pas',
  Vittix.Runner.Formatting in '..\Vittix.Runner.Formatting.pas',
  Vittix.Runner.TextFormatter in '..\Vittix.Runner.TextFormatter.pas',
    Test.Vittix.Runner.Formatting in 'Test.Vittix.Runner.Formatting.pas',
  Vittix.Runner.JsonFormatter in '..\Vittix.Runner.JsonFormatter.pas',
  Test.Vittix.Runner.JsonFormatter in 'Test.Vittix.Runner.JsonFormatter.pas',
  Vittix.Runner.ScriptTrace in '..\Vittix.Runner.ScriptTrace.pas',
  Test.Vittix.Runner.ScriptTrace in 'Test.Vittix.Runner.ScriptTrace.pas',
  Vittix.Runner.ExportVerification in '..\Vittix.Runner.ExportVerification.pas',
  Test.Vittix.Runner.ExportVerification in 'Test.Vittix.Runner.ExportVerification.pas',
  Vittix.Runner.ResultCollector in '..\Vittix.Runner.ResultCollector.pas',
  Test.Vittix.Runner.ResultCollector in 'Test.Vittix.Runner.ResultCollector.pas',
  Vittix.Runner.Resources in '..\Vittix.Runner.Resources.pas',
  Test.Vittix.Runner.Resources in 'Test.Vittix.Runner.Resources.pas',
  Test.Vittix.Report.Objects in 'Test.Vittix.Report.Objects.pas',
  Test.Vittix.Report.Objects.Barcode in 'Test.Vittix.Report.Objects.Barcode.pas',
  Test.Vittix.Report.Objects.QR in 'Test.Vittix.Report.Objects.QR.pas',
  Test.Vittix.Report.ExportCapture in 'Test.Vittix.Report.ExportCapture.pas',
  Test.Vittix.Report.Export.HTML in 'Test.Vittix.Report.Export.HTML.pas',
  Test.Vittix.Report.Export.XLSX in 'Test.Vittix.Report.Export.XLSX.pas',
  Test.Vittix.Report.Serializer.Registry in 'Test.Vittix.Report.Serializer.Registry.pas',
  Test.Vittix.Report.Component in 'Test.Vittix.Report.Component.pas';

var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  nunitLogger : ITestLogger;
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
{$ENDIF}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //tell the runner how we will log things
    //Log to the console window
    logger := TDUnitXConsoleLogger.Create(true);
    runner.AddLogger(logger);
    //Generate an NUnit compatible XML File
    try
      nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      runner.AddLogger(nunitLogger);
    except
      // XML logger may fail if directory doesn't exist; ignore
    end;
    runner.FailsOnNoAsserts := False; //when true, Evaluates an empty test as a failure

    //Run tests
    results := runner.Execute;

    // Print summary to stdout so it can be captured
    Writeln;
    Writeln(Format('Tests Run: %d, Passed: %d, Failed: %d, Errors: %d, Skipped: %d',
      [results.TestCount,
       results.PassCount,
       results.FailureCount,
       results.ErrorCount,
       results.IgnoredCount]));

    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
