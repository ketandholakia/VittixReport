unit Frm.Main.ViewHelpers;

interface

uses
  Vcl.CheckLst, Vcl.ComCtrls,
  Vittix.Report.DesignerControl;

procedure ConfigureViewToggleStrip(ACheckListBox: TCheckListBox);
procedure UpdateStatusBar(AStatusBar: TStatusBar; ADesigner: TVittixReportDesigner);

implementation

uses
  System.SysUtils,
  Vittix.Report.Objects;

procedure ConfigureViewToggleStrip(ACheckListBox: TCheckListBox);
begin
  if not Assigned(ACheckListBox) then
    Exit;

  ACheckListBox.Items.BeginUpdate;
  try
    ACheckListBox.Items.Clear;
    ACheckListBox.Items.Add('Grid');
    ACheckListBox.Items.Add('Snap');
    ACheckListBox.Items.Add('Ruler');
    ACheckListBox.Items.Add('Margin');
  finally
    ACheckListBox.Items.EndUpdate;
  end;
  ACheckListBox.Hint := 'Quick view toggles: Grid, Snap, Ruler, Margin';
  ACheckListBox.ShowHint := True;
end;

procedure UpdateStatusBar(AStatusBar: TStatusBar; ADesigner: TVittixReportDesigner);
var
  SelCount: Integer;
  Obj: TReportObject;
begin
  if not Assigned(AStatusBar) or not Assigned(ADesigner) then
    Exit;

  SelCount := ADesigner.SelectedCount;

  if SelCount = 0 then
    AStatusBar.Panels[0].Text := 'No selection'
  else if SelCount = 1 then
  begin
    Obj := ADesigner.PrimarySelected;
    if Assigned(Obj) then
      AStatusBar.Panels[0].Text :=
        'Selected: ' + Obj.ClassName +
        ' | X=' + IntToStr(Obj.Bounds.Left) +
        ' Y=' + IntToStr(Obj.Bounds.Top) +
        ' W=' + IntToStr(Obj.Bounds.Width) +
        ' H=' + IntToStr(Obj.Bounds.Height)
    else
      AStatusBar.Panels[0].Text := '1 object selected';
  end
  else
    AStatusBar.Panels[0].Text :=
      IntToStr(SelCount) + ' objects selected | Reference: last selected';

  if AStatusBar.Panels.Count > 2 then
    AStatusBar.Panels[2].Text := 'Zoom: ' + IntToStr(ADesigner.Zoom) + '%';
end;

end.
