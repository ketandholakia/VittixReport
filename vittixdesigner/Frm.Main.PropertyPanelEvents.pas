unit Frm.Main.PropertyPanelEvents;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Grids,
  Vcl.ValEdit;

procedure HandlePropEditorKeyDown(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AApplyPropertyPanel: TProc;
  const AIsPropertyPanelDirty: TFunc<Boolean>;
  var Key: Word);
procedure HandlePropEditorSelectCell(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AUpdateHintForRow: TProc<Integer>;
  ACol, ARow: Integer;
  var CanSelect: Boolean);
procedure HandlePropEditorSetEditText(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AIsLoadingPropertyPanel: TFunc<Boolean>;
  const ASetPropertyPanelDirty: TProc<Boolean>;
  const AUpdateHintForRow: TProc<Integer>;
  ACol, ARow: Integer;
  const Value: string);
procedure HandlePropEditorDblClick(
  APropEditor: TValueListEditor;
  const AEditFontPropertyRow: TFunc<Integer, Boolean>);
procedure HandlePropEditorEditButtonClick(
  APropEditor: TValueListEditor;
  const AEditBandEventScriptRow: TFunc<Integer, Boolean>;
  const AEditExpressionPropertyRow: TFunc<Integer, Boolean>;
  const AEditColorPropertyRow: TFunc<Integer, Boolean>);

implementation

function IsNavigationKey(AKey: Word): Boolean;
begin
  Result := (AKey = VK_UP) or (AKey = VK_DOWN) or (AKey = VK_LEFT) or
    (AKey = VK_RIGHT) or (AKey = VK_HOME) or (AKey = VK_END) or
    (AKey = VK_PRIOR) or (AKey = VK_NEXT) or (AKey = VK_TAB);
end;

procedure HandlePropEditorKeyDown(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AApplyPropertyPanel: TProc;
  const AIsPropertyPanelDirty: TFunc<Boolean>;
  var Key: Word);
begin
  if not Assigned(APropEditor) then
    Exit;
  if (APropEditor.Row > 0) and Assigned(AIsVisualGroupRow) and AIsVisualGroupRow(APropEditor.Keys[APropEditor.Row]) then
  begin
    if not IsNavigationKey(Key) then
      Key := 0;
    Exit;
  end;
  if Key = VK_RETURN then
  begin
    if Assigned(AIsPropertyPanelDirty) and AIsPropertyPanelDirty() and Assigned(AApplyPropertyPanel) then
      AApplyPropertyPanel();
    Key := 0;
  end;
end;

procedure HandlePropEditorSelectCell(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AUpdateHintForRow: TProc<Integer>;
  ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  if Assigned(APropEditor) and (ARow > 0) and Assigned(AIsVisualGroupRow) and
     AIsVisualGroupRow(APropEditor.Keys[ARow]) and (ACol > 0) then
    CanSelect := False;
  if Assigned(AUpdateHintForRow) then
    AUpdateHintForRow(ARow);
end;

procedure HandlePropEditorSetEditText(
  APropEditor: TValueListEditor;
  const AIsVisualGroupRow: TFunc<string, Boolean>;
  const AIsLoadingPropertyPanel: TFunc<Boolean>;
  const ASetPropertyPanelDirty: TProc<Boolean>;
  const AUpdateHintForRow: TProc<Integer>;
  ACol, ARow: Integer;
  const Value: string);
begin
  if not Assigned(APropEditor) then
    Exit;
  if Assigned(AIsLoadingPropertyPanel) and AIsLoadingPropertyPanel() then
    Exit;
  if (ARow <= 0) or (ARow >= APropEditor.RowCount) then
    Exit;
  if Assigned(AIsVisualGroupRow) and AIsVisualGroupRow(Trim(APropEditor.Keys[ARow])) then
    Exit;
  if Assigned(ASetPropertyPanelDirty) then
    ASetPropertyPanelDirty(True);
  if Assigned(AUpdateHintForRow) then
    AUpdateHintForRow(ARow);
end;

procedure HandlePropEditorDblClick(
  APropEditor: TValueListEditor;
  const AEditFontPropertyRow: TFunc<Integer, Boolean>);
begin
  if Assigned(APropEditor) and Assigned(AEditFontPropertyRow) then
    AEditFontPropertyRow(APropEditor.Row);
end;

procedure HandlePropEditorEditButtonClick(
  APropEditor: TValueListEditor;
  const AEditBandEventScriptRow: TFunc<Integer, Boolean>;
  const AEditExpressionPropertyRow: TFunc<Integer, Boolean>;
  const AEditColorPropertyRow: TFunc<Integer, Boolean>);
begin
  if Assigned(APropEditor) then
  begin
    if Assigned(AEditBandEventScriptRow) and AEditBandEventScriptRow(APropEditor.Row) then Exit;
    if Assigned(AEditExpressionPropertyRow) and AEditExpressionPropertyRow(APropEditor.Row) then Exit;
    if Assigned(AEditColorPropertyRow) then AEditColorPropertyRow(APropEditor.Row);
  end;
end;

end.
