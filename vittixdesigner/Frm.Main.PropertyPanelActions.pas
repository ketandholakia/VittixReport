unit Frm.Main.PropertyPanelActions;

interface

uses
  System.SysUtils,
  Winapi.Windows;

procedure HandleZoomApply(const AApplyZoom: TProc);
procedure HandleZoomToolbarChange(const AApplyToolbarZoomSelection: TProc);
procedure HandleViewToggleClick(const AUpdateViewState: TProc);
procedure HandleZoomKeyDown(const AApplyZoom: TProc; var Key: Word);
procedure HandleViewToggleIndex(AIndex: Integer; const AShowGrid, ASnapGrid, AShowRulers, AShowMargins: TProc);

implementation

procedure HandleZoomApply(const AApplyZoom: TProc);
begin
  if Assigned(AApplyZoom) then
    AApplyZoom();
end;

procedure HandleZoomToolbarChange(const AApplyToolbarZoomSelection: TProc);
begin
  if Assigned(AApplyToolbarZoomSelection) then
    AApplyToolbarZoomSelection();
end;

procedure HandleViewToggleClick(const AUpdateViewState: TProc);
begin
  if Assigned(AUpdateViewState) then
    AUpdateViewState();
end;

procedure HandleZoomKeyDown(const AApplyZoom: TProc; var Key: Word);
begin
  if Key <> VK_RETURN then
    Exit;

  if Assigned(AApplyZoom) then
    AApplyZoom();
  Key := 0;
end;

procedure HandleViewToggleIndex(AIndex: Integer; const AShowGrid, ASnapGrid, AShowRulers, AShowMargins: TProc);
begin
  case AIndex of
    0:
      if Assigned(AShowGrid) then
        AShowGrid();
    1:
      if Assigned(ASnapGrid) then
        ASnapGrid();
    2:
      if Assigned(AShowRulers) then
        AShowRulers();
    3:
      if Assigned(AShowMargins) then
        AShowMargins();
  end;
end;

end.
