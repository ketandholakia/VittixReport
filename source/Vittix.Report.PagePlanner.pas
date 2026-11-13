unit Vittix.Report.PagePlanner;

{
  Vittix.Report.PagePlanner
  =========================
  Phase A skeleton (owner decisions D1/D3, plan 2026-11-08 — see
  docs\Phase2-Pagination-Owner-Decision-Record.md and
  docs\Phase2-Pagination-Implementation-Plan.md).

  The planner is the engine's single page-allocation authority.  In Phase A
  it owns ONLY:

    * the page number (authoritative source for PageCount and every
      TExpressionContext.PageNumber),
    * the current page cursor Y,
    * the page metrics used by space decisions and export-page allocation,
    * the count/render mode and the bound export document,
    * the current export page allocated for the open page,
    * the BandFitsOnPage space decision (delegating the math to
      Vittix.Report.LayoutPagination so the fit rule keeps a single
      definition).

  Deliberately NOT here yet (later phases per the approved plan):
  row-level subreport streaming, continuation state, region stacks,
  canvas/metafile creation (still engine-owned in Phase A), band printing,
  footers, overlays and command-sink routing.

  Contract notes:
  * ResetSession returns the planner to the state BeginPass expects
    (page number 0, no cursor, no open export page).
  * BeginPage allocates the next page: it increments the page number and,
    in render mode with a bound document, allocates the export page.
    It does not create canvases or metafiles.
  * Every decision method is deterministic: identical inputs in identical
    order produce identical page counts in both planner modes.
}

interface

uses
  System.SysUtils,
  Vittix.Report.LayoutPagination,
  Vittix.Report.Export.Commands;

type
  TReportPagePlannerMode = (ppmCount, ppmRender);

  TReportPagePlanner = class
  private
    FMode: TReportPagePlannerMode;
    FPageNumber: Integer;
    FCursorY: Integer;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FDocument: TReportExportDocument;
    FCurrentExportPage: TReportExportPage;
    function GetCapturing: Boolean;
  public
    { Reset to the state BeginPass expects. }
    procedure ResetSession;
    { Page metrics used by space decisions and export-page allocation. }
    procedure SetPageMetrics(AWidth, AHeight: Integer);
    procedure SetMode(AMode: TReportPagePlannerMode);
    procedure SetDocument(ADocument: TReportExportDocument);
    procedure SetCursor(AValue: Integer);
    procedure AdvanceCursor(ADelta: Integer);
    procedure SetPageNumber(AValue: Integer);
    { Allocate the next page: increments the page number and, in render
      mode with a bound document, allocates the export page, then resets
      the cursor to the top margin. }
    procedure BeginPage(AMarginTop: Integer);
    { Mark the open export page closed (engine finalizes the visual page
      separately). }
    procedure ClosePage;
    { The BandFitsOnPage decision with planner-owned cursor and metrics.
      The bottom margin is passed live by the engine (read from the report
      model), preserving the original CheckSpace behavior exactly. }
    function CheckSpace(RequiredHeight, ABottomMargin,
      AFooterHeight: Integer): Boolean;
    property Mode: TReportPagePlannerMode read FMode;
    property PageNumber: Integer read FPageNumber;
    property CursorY: Integer read FCursorY;
    property CurrentExportPage: TReportExportPage read FCurrentExportPage;
  end;

implementation

function TReportPagePlanner.GetCapturing: Boolean;
begin
  Result := (FMode = ppmRender) and Assigned(FDocument);
end;

procedure TReportPagePlanner.ResetSession;
begin
  FPageNumber := 0;
  FCursorY := 0;
  FCurrentExportPage := nil;
end;

procedure TReportPagePlanner.SetPageMetrics(AWidth, AHeight: Integer);
begin
  FPageWidth := AWidth;
  FPageHeight := AHeight;
end;

procedure TReportPagePlanner.SetMode(AMode: TReportPagePlannerMode);
begin
  FMode := AMode;
end;

procedure TReportPagePlanner.SetDocument(ADocument: TReportExportDocument);
begin
  FDocument := ADocument;
end;

procedure TReportPagePlanner.SetCursor(AValue: Integer);
begin
  FCursorY := AValue;
end;

procedure TReportPagePlanner.AdvanceCursor(ADelta: Integer);
begin
  Inc(FCursorY, ADelta);
end;

procedure TReportPagePlanner.SetPageNumber(AValue: Integer);
begin
  FPageNumber := AValue;
end;

procedure TReportPagePlanner.BeginPage(AMarginTop: Integer);
begin
  Inc(FPageNumber);
  if GetCapturing then
    FCurrentExportPage := FDocument.AddPage(FPageWidth, FPageHeight)
  else
    FCurrentExportPage := nil;
  FCursorY := AMarginTop;
end;

procedure TReportPagePlanner.ClosePage;
begin
  FCurrentExportPage := nil;
end;

function TReportPagePlanner.CheckSpace(RequiredHeight, ABottomMargin,
  AFooterHeight: Integer): Boolean;
begin
  Result := BandFitsOnPage(FCursorY, RequiredHeight, FPageHeight,
    ABottomMargin, AFooterHeight);
end;

end.
