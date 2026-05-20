unit Frm.Main.DesignerHelpers;

interface

uses
  System.SysUtils;

procedure HandleDesignerSelectionChanged(
  const AUpdatePropertyPanel: TProc;
  const AUpdateMenuState: TProc;
  const ASyncReportStructureSelection: TProc);
procedure HandleDesignerModified(
  const ARefreshReportStructure: TProc;
  const AUpdateAll: TProc);
procedure HandleDesignerViewChanged(
  const AUpdateZoomControls: TProc;
  const AUpdateMenuState: TProc;
  const AUpdateStatusBar: TProc);

implementation

procedure HandleDesignerSelectionChanged(
  const AUpdatePropertyPanel: TProc;
  const AUpdateMenuState: TProc;
  const ASyncReportStructureSelection: TProc);
begin
  if Assigned(AUpdatePropertyPanel) then
    AUpdatePropertyPanel();
  if Assigned(AUpdateMenuState) then
    AUpdateMenuState();
  if Assigned(ASyncReportStructureSelection) then
    ASyncReportStructureSelection();
end;

procedure HandleDesignerModified(
  const ARefreshReportStructure: TProc;
  const AUpdateAll: TProc);
begin
  if Assigned(ARefreshReportStructure) then
    ARefreshReportStructure();
  if Assigned(AUpdateAll) then
    AUpdateAll();
end;

procedure HandleDesignerViewChanged(
  const AUpdateZoomControls: TProc;
  const AUpdateMenuState: TProc;
  const AUpdateStatusBar: TProc);
begin
  if Assigned(AUpdateZoomControls) then
    AUpdateZoomControls();
  if Assigned(AUpdateMenuState) then
    AUpdateMenuState();
  if Assigned(AUpdateStatusBar) then
    AUpdateStatusBar();
end;

end.
