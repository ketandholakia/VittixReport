unit Frm.Main.ApplyHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Vcl.ValEdit,
  Vittix.Report.Model,
  Vittix.Report.Objects,
  Vittix.Report.PropertyBridge,
  Vittix.Report.DesignerControl,
  Frm.Main.PropertyPanel,
  Frm.Main.Commands;

procedure CapturePropertyChanges(AObj: TReportObject; APropEditor: TValueListEditor;
  out PropNames: TArray<string>; out OldByProp: TDictionary<string, TValue>);
procedure RemoveVisualGroupRows(APropEditor: TValueListEditor);
procedure ApplyPropertyPanel(
  ADesigner: TVittixReportDesigner;
  APropEditor: TValueListEditor;
  ACurrentPropertyTarget: TFunc<TReportObject>;
  var APropertyPanelDirty: Boolean;
  var AModified: Boolean;
  ARebuildLayout: TProc;
  AUpdateTitleBar: TProc;
  AUpdatePropertyPanel: TProc;
  ASetPropertyPanelDirty: TProc<Boolean>);

implementation

uses
  Frm.Main.PropertyHelpers;

procedure CapturePropertyChanges(AObj: TReportObject; APropEditor: TValueListEditor;
  out PropNames: TArray<string>; out OldByProp: TDictionary<string, TValue>);
var
  I, PropIndex: Integer;
  KeyName: string;
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
begin
  PropNames := nil;
  OldByProp := TDictionary<string, TValue>.Create;

  if (not Assigned(AObj)) or (not Assigned(APropEditor)) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(AObj.ClassType);
    if not Assigned(RttiType) then
      Exit;

    for I := 1 to APropEditor.RowCount - 1 do
    begin
      KeyName := APropEditor.Keys[I];
      if IsVisualGroupRow(KeyName) then
        Continue;
      if OldByProp.ContainsKey(KeyName) then
        Continue;

      Prop := RttiType.GetProperty(KeyName);
      if not Assigned(Prop) or not Prop.IsReadable or not Prop.IsWritable then
        Continue;

      OldByProp.Add(KeyName, Prop.GetValue(AObj));
      PropIndex := Length(PropNames);
      SetLength(PropNames, PropIndex + 1);
      PropNames[PropIndex] := KeyName;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure RemoveVisualGroupRows(APropEditor: TValueListEditor);
var
  I: Integer;
begin
  if not Assigned(APropEditor) then
    Exit;

  for I := APropEditor.RowCount - 1 downto 0 do
    if IsVisualGroupRow(APropEditor.Keys[I]) then
      APropEditor.Strings.Delete(I);
end;

procedure ApplyPropertyPanel(
  ADesigner: TVittixReportDesigner;
  APropEditor: TValueListEditor;
  ACurrentPropertyTarget: TFunc<TReportObject>;
  var APropertyPanelDirty: Boolean;
  var AModified: Boolean;
  ARebuildLayout: TProc;
  AUpdateTitleBar: TProc;
  AUpdatePropertyPanel: TProc;
  ASetPropertyPanelDirty: TProc<Boolean>);
var
  Obj: TReportObject;
  PropNames: TArray<string>;
  ChangedNames: TArray<string>;
  OldValues: TArray<TValue>;
  NewValues: TArray<TValue>;
  OldByProp: TDictionary<string, TValue>;
  Cmd: TPropertyBatchChangeCommand;
begin
  if not APropertyPanelDirty then
    Exit;

  Obj := nil;
  if Assigned(ACurrentPropertyTarget) then
    Obj := ACurrentPropertyTarget();
  if not Assigned(Obj) then
    Exit;

  CapturePropertyChanges(Obj, APropEditor, PropNames, OldByProp);
  try
    RemoveVisualGroupRows(APropEditor);
    TReportPropertyBridge.SaveGridToObject(Obj, APropEditor);

    if TPropertyPanelUtils.BuildChangedPropertyBatch(Obj, OldByProp, PropNames,
      ChangedNames, OldValues, NewValues) then
    begin
      Cmd := TPropertyBatchChangeCommand.Create(Obj, ChangedNames, OldValues, NewValues);
      if not Assigned(ADesigner) then
        Cmd.Free
      else if Assigned(ADesigner.Commands) then
        ADesigner.Commands.DoCommand(Cmd)
      else
        Cmd.Free;
    end;

    if Assigned(ADesigner) then
      ADesigner.RebuildLayout;
    AModified := True;
    if Assigned(AUpdateTitleBar) then
      AUpdateTitleBar();
    if Assigned(AUpdatePropertyPanel) then
      AUpdatePropertyPanel();
    if Assigned(ASetPropertyPanelDirty) then
      ASetPropertyPanelDirty(False);
    APropertyPanelDirty := False;
  finally
    OldByProp.Free;
  end;
end;

end.
