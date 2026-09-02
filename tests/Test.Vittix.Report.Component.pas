unit Test.Vittix.Report.Component;

{
  Phase 4G-3: component-level engine configuration tests.

  TVittixReport.CreateEngine is the single engine-construction path used by
  Execute / Print / Export*.  These tests verify the wiring (parameters,
  two-pass flag, print events) without running a render pass, so they stay
  independent of datasets, GDI and the preview UI.
}

interface

uses
  DUnitX.TestFramework,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Component;

type
  [TestFixture]
  TReportComponentTests = class
  private
    FBeforeObjectCalls: Integer;
    procedure BeforeObjectHandler(Sender: TObject; AEngine: TObject;
      AObject: TReportObject; const Context: TExpressionContext;
      var ACanPrint: Boolean);
  public
    [Test] procedure Test_CreateEngine_WiresParameters;
    [Test] procedure Test_CreateEngine_WiresTwoPassRendering;
    [Test] procedure Test_CreateEngine_WiresPrintEvents;
    [Test] procedure Test_CreateEngine_NoDatasets_NoException;
    [Test] procedure Test_RendererPath_PropagatesTwoPassAndParameters;
  end;

{
  Standard Delphi test idiom: a descendant exposing protected members so the
  Execute/Print renderer-configuration seam can be exercised without adding
  public API to the component.
}
type
  TVittixReportAccess = class(TVittixReport);

implementation

uses
  System.Classes,
  System.SysUtils,
  Vittix.Report.Engine,
  Vittix.Report.Renderer,
  Vittix.Report.Model;

procedure TReportComponentTests.BeforeObjectHandler(Sender: TObject;
  AEngine: TObject; AObject: TReportObject; const Context: TExpressionContext;
  var ACanPrint: Boolean);
begin
  Inc(FBeforeObjectCalls);
end;

procedure TReportComponentTests.Test_CreateEngine_WiresParameters;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.Parameters.Text := 'Company=Acme';
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.AreEqual('Company=Acme', Engine.Parameters.Text.Trim);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_WiresTwoPassRendering;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.TwoPassRendering := False;
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.IsFalse(Engine.TwoPassRendering);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_WiresPrintEvents;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.OnBeforeObject := BeforeObjectHandler;
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        // The engine must carry the component's handler, not its own default.
        Assert.IsTrue(
          (TMethod(Engine.OnBeforeObject).Code = TMethod(Rpt.OnBeforeObject).Code) and
          (TMethod(Engine.OnBeforeObject).Data = TMethod(Rpt.OnBeforeObject).Data),
          'OnBeforeObject was not relayed to the engine');
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_CreateEngine_NoDatasets_NoException;
var
  Rpt   : TVittixReport;
  Model : TReportModel;
  Engine: TReportEngine;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Model := Rpt.GetModel;
    try
      Engine := Rpt.CreateEngine(Model);
      try
        Assert.IsNotNull(Engine);
      finally
        Engine.Free;
      end;
    finally
      Model.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

procedure TReportComponentTests.Test_RendererPath_PropagatesTwoPassAndParameters;
{
  Regression test for the Phase 4G-3 pre-commit audit finding: Execute and
  Print configure the renderer through TVittixReport.ConfigureRenderer, and
  TReportRenderer.Render overwrites the engine's TwoPassRendering from the
  renderer's own flag.  If the component's setting stops being mirrored onto
  the renderer, this test fails — CreateEngine alone was already correct, so
  the seam under test here is the renderer-configuration step itself.
}
var
  Rpt: TVittixReport;
  R  : TReportRenderer;
begin
  Rpt := TVittixReport.Create(nil);
  try
    Rpt.Parameters.Text := 'Company=Acme';

    // Component says two-pass OFF — the renderer must end up OFF too.
    Rpt.TwoPassRendering := False;
    R := TReportRenderer.Create;
    try
      TVittixReportAccess(Rpt).ConfigureRenderer(R);
      Assert.IsFalse(R.TwoPassRendering,
        'Renderer.TwoPassRendering was not set from the component');
      Assert.AreEqual('Company=Acme', R.Parameters.Text.Trim,
        'Renderer.Parameters was not set from the component');
    finally
      R.Free;
    end;

    // Default/True case must keep working as well.
    Rpt.TwoPassRendering := True;
    R := TReportRenderer.Create;
    try
      TVittixReportAccess(Rpt).ConfigureRenderer(R);
      Assert.IsTrue(R.TwoPassRendering);
    finally
      R.Free;
    end;
  finally
    Rpt.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TReportComponentTests);

end.
