unit Frm.Main.QuickActions;

interface

uses
  System.SysUtils,
  Vcl.ValEdit;

procedure HandleFontQuickClick(APropEditor: TValueListEditor; const AInvokeFontEdit: TProc);

implementation

procedure HandleFontQuickClick(APropEditor: TValueListEditor; const AInvokeFontEdit: TProc);
var
  I: Integer;
begin
  if not Assigned(APropEditor) then
    Exit;

  for I := 1 to APropEditor.RowCount - 1 do
    if SameText(APropEditor.Keys[I], 'Font') then
    begin
      APropEditor.Row := I;
      Break;
    end;

  if Assigned(AInvokeFontEdit) then
    AInvokeFontEdit();
end;

end.
