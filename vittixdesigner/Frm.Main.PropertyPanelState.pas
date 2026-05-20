unit Frm.Main.PropertyPanelState;

interface

uses
  Vcl.StdCtrls,
  Vcl.Grids,
  Vittix.Report.Objects;

procedure SetPropertyPanelDirty(
  ACurrentPropertyTarget: TReportObject;
  AButton: TButton;
  var APropertyPanelDirty: Boolean;
  AValue: Boolean);

implementation

procedure SetPropertyPanelDirty(
  ACurrentPropertyTarget: TReportObject;
  AButton: TButton;
  var APropertyPanelDirty: Boolean;
  AValue: Boolean);
begin
  APropertyPanelDirty := AValue and Assigned(ACurrentPropertyTarget);
  if Assigned(AButton) then
  begin
    AButton.Enabled := APropertyPanelDirty;
    if APropertyPanelDirty then
    begin
      AButton.Caption := 'Apply *';
      AButton.Hint := 'Apply pending changes';
    end
    else
    begin
      AButton.Caption := 'Apply';
      AButton.Hint := 'Apply property changes';
    end;
  end;
end;

end.
