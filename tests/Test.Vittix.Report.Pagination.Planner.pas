unit Test.Vittix.Report.Pagination.Planner;

{
  Phase A planner-skeleton tests (plan 2026-11-08, regression matrix U-1
  subset + lifecycle).  These pin the planner's initialization, page
  lifecycle, space math (including the footer reserve and the zero-height
  clamp of BandFitsOnPage), count/render mode behavior, and reset semantics.
  No row streaming, no continuation: Phase B+ concerns are absent by design.
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  Vittix.Report.Export.Commands,
  Vittix.Report.PagePlanner;

type
  [TestFixture]
  TPagePlannerTests = class
  private
    function NewDoc: TReportExportDocument;
  public
    [Test] procedure Planner_Initializes_Empty;
    [Test] procedure Planner_BeginPage_IncrementsNumber_AndAllocatesExportPage;
    [Test] procedure Planner_CountMode_DoesNotAllocateExportPages;
    [Test] procedure Planner_BeginPage_UsesSessionMetrics;
    [Test] procedure Planner_ResetSession_ClearsState;
    [Test] procedure Planner_CheckSpace_HonorsFooterReserve;
    [Test] procedure Planner_CheckSpace_ZeroHeightClampsToOne;
    [Test] procedure Planner_Cursor_AdvanceAndSet;
  end;

implementation

function TPagePlannerTests.NewDoc: TReportExportDocument;
begin
  Result := TReportExportDocument.Create;
end;

procedure TPagePlannerTests.Planner_Initializes_Empty;
var
  P: TReportPagePlanner;
begin
  P := TReportPagePlanner.Create;
  try
    Assert.AreEqual(0, P.PageNumber, 'fresh planner page number');
    Assert.AreEqual(0, P.CursorY, 'fresh planner cursor');
    Assert.IsTrue(P.CurrentExportPage = nil, 'fresh planner has no export page');
  finally
    P.Free;
  end;
end;

procedure TPagePlannerTests.Planner_BeginPage_IncrementsNumber_AndAllocatesExportPage;
var
  P: TReportPagePlanner;
  Doc: TReportExportDocument;
begin
  Doc := NewDoc;
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetMode(ppmRender);
    P.SetDocument(Doc);

    P.BeginPage(40);
    Assert.AreEqual(1, P.PageNumber, 'first BeginPage -> page 1');
    Assert.AreEqual(40, P.CursorY, 'cursor reset to top margin');
    Assert.IsTrue(P.CurrentExportPage <> nil, 'render mode allocates an export page');
    Assert.AreEqual(1, Doc.Pages.Count, 'document page allocated');
    Assert.AreEqual(400, Doc.Pages[0].Width, 'export page width from metrics');
    Assert.AreEqual(500, Doc.Pages[0].Height, 'export page height from metrics');

    P.BeginPage(40);
    Assert.AreEqual(2, P.PageNumber, 'second BeginPage -> page 2');
    Assert.AreEqual(2, Doc.Pages.Count, 'second document page allocated');
  finally
    P.Free;
    Doc.Free;
  end;
end;

procedure TPagePlannerTests.Planner_CountMode_DoesNotAllocateExportPages;
var
  P: TReportPagePlanner;
  Doc: TReportExportDocument;
begin
  Doc := NewDoc;
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetMode(ppmCount);
    P.SetDocument(Doc);

    P.BeginPage(40);
    P.BeginPage(40);
    Assert.AreEqual(2, P.PageNumber, 'count mode counts pages');
    Assert.AreEqual(0, Doc.Pages.Count,
      'count mode must not allocate export pages');
    Assert.IsTrue(P.CurrentExportPage = nil, 'no open export page in count mode');
  finally
    P.Free;
    Doc.Free;
  end;
end;

procedure TPagePlannerTests.Planner_BeginPage_UsesSessionMetrics;
var
  P: TReportPagePlanner;
  Doc, Doc2: TReportExportDocument;
begin
  Doc := NewDoc;
  Doc2 := NewDoc;
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetMode(ppmRender);
    P.SetDocument(Doc);
    P.BeginPage(40);

    // Rebinding the document (as BeginPass does between passes) must route
    // the next allocation to the new document with the new metrics.
    P.SetPageMetrics(300, 600);
    P.SetDocument(Doc2);
    P.BeginPage(40);

    Assert.AreEqual(1, Doc2.Pages.Count, 'allocation follows the bound document');
    Assert.AreEqual(300, Doc2.Pages[0].Width, 'allocation uses session metrics');
    Assert.AreEqual(600, Doc2.Pages[0].Height, 'allocation uses session metrics');
  finally
    P.Free;
    Doc.Free;
    Doc2.Free;
  end;
end;

procedure TPagePlannerTests.Planner_ResetSession_ClearsState;
var
  P: TReportPagePlanner;
begin
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetMode(ppmRender);
    P.BeginPage(40);
    P.AdvanceCursor(120);
    Assert.IsTrue(P.PageNumber > 0);

    P.ResetSession;
    Assert.AreEqual(0, P.PageNumber, 'reset clears the page number');
    Assert.AreEqual(0, P.CursorY, 'reset clears the cursor');
    Assert.IsTrue(P.CurrentExportPage = nil, 'reset clears the export page');
  finally
    P.Free;
  end;
end;

procedure TPagePlannerTests.Planner_CheckSpace_HonorsFooterReserve;
var
  P: TReportPagePlanner;
begin
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetCursor(300);
    // usable bottom = 500 - 40 (bottom margin) - 40 (footer) = 420
    Assert.IsFalse(P.CheckSpace(150, 40, 40),
      '450 > 420: must not fit past the footer reserve');
    Assert.IsTrue(P.CheckSpace(100, 40, 40),
      '400 <= 420: must fit within the footer reserve');
    Assert.IsTrue(P.CheckSpace(120, 40, 0),
      'without a footer the usable bottom is 460');
  finally
    P.Free;
  end;
end;

procedure TPagePlannerTests.Planner_CheckSpace_ZeroHeightClampsToOne;
var
  P: TReportPagePlanner;
begin
  P := TReportPagePlanner.Create;
  try
    P.SetPageMetrics(400, 500);
    P.SetCursor(500);
    // BandFitsOnPage clamps RequiredHeight to at least 1: 500+1 > 500-0-0.
    Assert.IsFalse(P.CheckSpace(0, 0, 0), 'clamped height must still respect page bounds');
    P.SetCursor(300);
    Assert.IsTrue(P.CheckSpace(0, 0, 0), 'clamped height fits when there is room');
  finally
    P.Free;
  end;
end;

procedure TPagePlannerTests.Planner_Cursor_AdvanceAndSet;
var
  P: TReportPagePlanner;
begin
  P := TReportPagePlanner.Create;
  try
    P.SetCursor(100);
    P.AdvanceCursor(50);
    Assert.AreEqual(150, P.CursorY, 'advance');
    P.SetCursor(30);
    Assert.AreEqual(30, P.CursorY, 'set');
  finally
    P.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPagePlannerTests);

end.
