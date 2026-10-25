unit Test.Vittix.Report.SilentFailures;

{
  Silent-failure observability (v1.0 freeze fix, DP-36 pattern).

  The engine swallows four classes of failure behind frozen fallback
  semantics: band PrintWhen exceptions (band skipped), object PrintWhen
  exceptions (object skipped), subreport JSON parse failures (object
  skipped) and aggregate value conversion errors (row skipped).  Each is
  now counted in TReportTraversalDiagnostics and logged under DEBUG;
  rendered output is unchanged.

  The subreport parse failure is additionally CACHED (same owner + same
  JSON), so broken JSON is parsed once per report instead of once per
  master row.

  Red (compile): the four counters do not exist yet.
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Types,
  Data.DB,
  Datasnap.DBClient,
  Vittix.Report.Model,
  Vittix.Report.Engine,
  Vittix.Report.Bands,
  Vittix.Report.Objects,
  Vittix.Report.TraversalDiagnostics;

type
  [TestFixture]
  TSilentFailureDiagnosticsTests = class
  private
    function BuildEngine(out AModel: TReportModel;
      out AEngine: TReportEngine): TClientDataSet;
  public
    [Test] procedure Test_Counter_BandPrintWhenException;
    [Test] procedure Test_Counter_ObjectPrintWhenException;
    [Test] procedure Test_Counter_SubReportParseFailure_AttemptedOnce;
    [Test] procedure Test_Counter_AggregateConversionError;
  end;

implementation

function TSilentFailureDiagnosticsTests.BuildEngine(
  out AModel: TReportModel; out AEngine: TReportEngine): TClientDataSet;
var
  Band: TReportBand;
begin
  Result := TClientDataSet.Create(nil);
  Result.FieldDefs.Add('ID', ftInteger);
  Result.FieldDefs.Add('Name', ftString, 50);
  Result.CreateDataSet;
  Result.AppendRecord([1, 'First']);
  Result.AppendRecord([2, 'Second']);
  Result.AppendRecord([3, 'Third']);
  Result.First;

  AModel := TReportModel.Create;
  Band := TReportBand.Create;
  Band.BandType := btMasterData;
  Band.Height := 40;
  AModel.Objects.Add(Band);

  AEngine := TReportEngine.Create(AModel, Result);
end;

procedure TSilentFailureDiagnosticsTests.Test_Counter_BandPrintWhenException;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Snap: TReportTraversalSnapshot;
begin
  DS := BuildEngine(Model, Engine);
  try
    // Modern mode: a malformed PrintWhen raises EVittixExpressionError,
    // which the engine swallows into "band does not print".
    Model.ExpressionLanguageVersion := 1;
    TReportBand(Model.Objects[0]).PrintWhen := 'IF(';

    TReportTraversalDiagnostics.Reset;
    Engine.Prepare;
    Snap := TReportTraversalDiagnostics.Snapshot;

    Assert.IsTrue(Snap.BandPrintWhenExceptions >= 1,
      Format('band PrintWhen exceptions must be counted, got %d',
        [Snap.BandPrintWhenExceptions]));
  finally
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TSilentFailureDiagnosticsTests.Test_Counter_ObjectPrintWhenException;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Obj: TReportTextObject;
  Snap: TReportTraversalSnapshot;
begin
  DS := BuildEngine(Model, Engine);
  try
    Model.ExpressionLanguageVersion := 1;
    Obj := TReportTextObject.Create;
    Obj.Bounds := Rect(10, 10, 200, 30);
    Obj.Text := 'x';
    Obj.PrintWhen := 'IF(';
    TReportBand(Model.Objects[0]).Children.Add(Obj);

    TReportTraversalDiagnostics.Reset;
    Engine.Prepare;
    Snap := TReportTraversalDiagnostics.Snapshot;

    Assert.IsTrue(Snap.ObjectPrintWhenExceptions >= 1,
      Format('object PrintWhen exceptions must be counted, got %d',
        [Snap.ObjectPrintWhenExceptions]));
    Assert.AreEqual(0, Snap.BandPrintWhenExceptions,
      'the band itself has no PrintWhen; only the object expression fails');
  finally
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TSilentFailureDiagnosticsTests.Test_Counter_SubReportParseFailure_AttemptedOnce;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Sub: TReportSubReportObject;
  Snap: TReportTraversalSnapshot;
begin
  DS := BuildEngine(Model, Engine);
  try
    Sub := TReportSubReportObject.Create;
    Sub.Bounds := Rect(10, 10, 200, 35);
    Sub.ReportJSON := '{"objects": this is not json';
    TReportBand(Model.Objects[0]).Children.Add(Sub);

    TReportTraversalDiagnostics.Reset;
    Engine.Prepare;
    Snap := TReportTraversalDiagnostics.Snapshot;

    Assert.AreEqual(1, Snap.SubReportParseFailures,
      Format('the parse failure must be counted exactly once, got %d',
        [Snap.SubReportParseFailures]));
    Assert.AreEqual(1, Snap.SubReportParseAttempts,
      Format('broken JSON must be parsed once, not once per master row (3 rows), got %d attempts',
        [Snap.SubReportParseAttempts]));
    Assert.IsTrue(Snap.SubReportCacheHits >= 1,
      'later master rows must be served the cached failure');
  finally
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

procedure TSilentFailureDiagnosticsTests.Test_Counter_AggregateConversionError;
var
  DS: TClientDataSet;
  Model: TReportModel;
  Engine: TReportEngine;
  Footer: TReportBand;
  Obj: TReportTextObject;
  Snap: TReportTraversalSnapshot;
begin
  DS := BuildEngine(Model, Engine);
  try
    // Legacy mode: [Name] holds text, so SUM([Name]) hits the swallowed
    // variant-to-number conversion error on every row.
    Footer := TReportBand.Create;
    Footer.BandType := btReportSummary;
    Footer.Height := 40;
    Obj := TReportTextObject.Create;
    Obj.Bounds := Rect(10, 10, 300, 30);
    Obj.Text := 'SUM([Name])';
    Footer.Children.Add(Obj);
    Model.Objects.Add(Footer);

    TReportTraversalDiagnostics.Reset;
    Engine.Prepare;
    Snap := TReportTraversalDiagnostics.Snapshot;

    // At least one swallowed error per data row (two-pass rendering may
    // evaluate the summary band in both passes).
    Assert.IsTrue(Snap.AggregateValueErrors >= 3,
      Format('a swallowed conversion error per data row expected, got %d',
        [Snap.AggregateValueErrors]));
  finally
    Engine.Free;
    Model.Free;
    DS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSilentFailureDiagnosticsTests);

end.
