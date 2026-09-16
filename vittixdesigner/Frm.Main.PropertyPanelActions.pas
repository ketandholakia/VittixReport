unit Frm.Main.PropertyPanelActions;

interface

uses
  System.SysUtils,
  Winapi.Windows;

procedure HandleZoomApply(const AApplyZoom: TProc);
procedure HandleZoomToolbarChange(const AApplyToolbarZoomSelection: TProc);
procedure HandleZoomKeyDown(const AApplyZoom: TProc; var Key: Word);

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

procedure HandleZoomKeyDown(const AApplyZoom: TProc; var Key: Word);
begin
  if Key <> VK_RETURN then
    Exit;

  if Assigned(AApplyZoom) then
    AApplyZoom();
  Key := 0;
end;

end.
