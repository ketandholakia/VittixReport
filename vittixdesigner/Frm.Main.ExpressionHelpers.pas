unit Frm.Main.ExpressionHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vittix.Report.Context;

function ExpressionHelperTryGetSelectedField(AFields: TListBox; out AFieldName: string): Boolean;
procedure ExpressionHelperInsertField(AMemo: TMemo; AFields: TListBox);
procedure ExpressionHelperInsertText(AMemo: TMemo; const AText: string);

implementation

function ExpressionHelperTryGetSelectedField(AFields: TListBox; out AFieldName: string): Boolean;
begin
  AFieldName := '';
  Result := Assigned(AFields) and (AFields.ItemIndex >= 0);
  if not Result then
    Exit;
  AFieldName := Trim(AFields.Items[AFields.ItemIndex]);
  Result := AFieldName <> '';
end;

procedure ExpressionHelperInsertField(AMemo: TMemo; AFields: TListBox);
var
  FieldName: string;
begin
  if not ExpressionHelperTryGetSelectedField(AFields, FieldName) then
    Exit;
  if not Assigned(AMemo) then
    Exit;
  AMemo.SelText := '[' + FieldName + ']';
  AMemo.SetFocus;
end;

procedure ExpressionHelperInsertText(AMemo: TMemo; const AText: string);
begin
  if not Assigned(AMemo) then
    Exit;
  AMemo.SelText := AText;
  AMemo.SetFocus;
end;

end.
