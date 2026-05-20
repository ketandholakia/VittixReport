unit Frm.Main.PropertyEditHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Dialogs,
  Vcl.ValEdit,
  Vcl.Graphics,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.Objects.Text;

function EditColorPropertyRow(APropEditor: TValueListEditor; ARow: Integer;
  AGetCurrentTarget: TFunc<TReportObject>; ASetDirty: TProc<Boolean>): Boolean;
implementation

uses
  System.TypInfo,
  Vittix.Report.Commands;

function EditColorPropertyRow(APropEditor: TValueListEditor; ARow: Integer;
  AGetCurrentTarget: TFunc<TReportObject>; ASetDirty: TProc<Boolean>): Boolean;
var
  KeyName: string;
  ValueText: string;
  Dlg: TColorDialog;
  ColorValue: Integer;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= APropEditor.RowCount) then
    Exit;
  KeyName := APropEditor.Keys[ARow];
  if (Length(KeyName) >= 3) and (KeyName[1] = '[') and (KeyName[Length(KeyName)] = ']') then
    Exit;
  ValueText := APropEditor.Values[KeyName];
  if not TryStrToInt(ValueText, ColorValue) then
    ColorValue := clBlack;
  Dlg := TColorDialog.Create(nil);
  try
    Dlg.Color := TColor(ColorValue);
    if not Dlg.Execute then
      Exit;
    APropEditor.Values[KeyName] := IntToStr(Dlg.Color);
    if Assigned(ASetDirty) then
      ASetDirty(True);
    Result := True;
  finally
    Dlg.Free;
  end;
end;

end.
