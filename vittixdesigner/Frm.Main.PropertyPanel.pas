unit Frm.Main.PropertyPanel;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  Vcl.Controls,
  Vcl.StdCtrls,
  Winapi.Windows,
  Vittix.Report.Context,
  Vittix.Report.Objects,
  Vittix.Report.Bands,
  Vittix.Report.DesignerControl;

type
  TPropertyPanelUtils = record
    class function SamePropertyValue(const AOld, ANew: TValue): Boolean; static;
    class function BuildChangedPropertyBatch(AObj: TReportObject;
      const AOldByProp: TDictionary<string, TValue>;
      const APropNames: TArray<string>;
      out ChangedNames: TArray<string>;
      out OldValues: TArray<TValue>;
      out NewValues: TArray<TValue>): Boolean; static;
    class function IsControlWithinParent(AControl, AParent: TWinControl): Boolean; static;
    class function IsTextEditingControlFocused(AActiveControl: TWinControl; APropertiesPanel: TWinControl): Boolean; static;
    class procedure SendMessageToFocusedControl(AMsg: Cardinal); static;
    class procedure SendDeleteToFocusedControl; static;
    class function CurrentPropertyTarget(ADesigner: TVittixReportDesigner): TReportObject; static;
    class function SelectedObjectsSpanBands(ADesigner: TVittixReportDesigner): Boolean; static;
    class function ConfirmMixedBandVerticalLayout(ADesigner: TVittixReportDesigner): Boolean; static;
    class function ShortNodePreview(const S: string; AMaxLen: Integer): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Vcl.Dialogs,
  Vcl.Forms,
  Winapi.Messages;

class function TPropertyPanelUtils.SamePropertyValue(const AOld, ANew: TValue): Boolean;
begin
  if AOld.IsEmpty and ANew.IsEmpty then
    Exit(True);
  if AOld.IsEmpty or ANew.IsEmpty then
    Exit(False);

  if AOld.Kind <> ANew.Kind then
    Exit(False);

  case AOld.Kind of
    tkChar, tkWChar, tkInteger, tkInt64, tkEnumeration, tkSet:
      Exit(AOld.AsOrdinal = ANew.AsOrdinal);
    tkFloat:
      Exit(SameValue(AOld.AsExtended, ANew.AsExtended, 1E-12));
    tkClass:
      Exit(AOld.AsObject = ANew.AsObject);
    tkMethod:
      Exit(AOld.GetReferenceToRawData = ANew.GetReferenceToRawData);
  else
    Exit(False);
  end;
end;

class function TPropertyPanelUtils.BuildChangedPropertyBatch(AObj: TReportObject;
  const AOldByProp: TDictionary<string, TValue>;
  const APropNames: TArray<string>;
  out ChangedNames: TArray<string>; out OldValues: TArray<TValue>;
  out NewValues: TArray<TValue>): Boolean;
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  OldV, NewV: TValue;
  I, OutIdx: Integer;
begin
  SetLength(ChangedNames, 0);
  SetLength(OldValues, 0);
  SetLength(NewValues, 0);
  Result := False;
  if not Assigned(AObj) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(AObj.ClassType);
    if not Assigned(RttiType) then
      Exit;

    for I := 0 to High(APropNames) do
    begin
      if not AOldByProp.TryGetValue(APropNames[I], OldV) then
        Continue;
      Prop := RttiType.GetProperty(APropNames[I]);
      if not Assigned(Prop) or not Prop.IsReadable then
        Continue;
      NewV := Prop.GetValue(AObj);
      if SamePropertyValue(OldV, NewV) then
        Continue;
      OutIdx := Length(ChangedNames);
      SetLength(ChangedNames, OutIdx + 1);
      SetLength(OldValues, OutIdx + 1);
      SetLength(NewValues, OutIdx + 1);
      ChangedNames[OutIdx] := APropNames[I];
      OldValues[OutIdx] := OldV;
      NewValues[OutIdx] := NewV;
    end;
  finally
    Ctx.Free;
  end;

  Result := Length(ChangedNames) > 0;
end;

class function TPropertyPanelUtils.IsControlWithinParent(AControl, AParent: TWinControl): Boolean;
begin
  Result := False;
  if not Assigned(AControl) or not Assigned(AParent) then
    Exit;
  while Assigned(AControl) do
  begin
    if AControl = AParent then
      Exit(True);
    AControl := AControl.Parent;
  end;
end;

class function TPropertyPanelUtils.IsTextEditingControlFocused(AActiveControl,
  APropertiesPanel: TWinControl): Boolean;
begin
  Result := False;
  if not Assigned(AActiveControl) then
    Exit;
  if IsControlWithinParent(AActiveControl, APropertiesPanel) then
    Exit(True);
  Result := (AActiveControl is TCustomEdit) or (AActiveControl is TCustomComboBox);
end;

class procedure TPropertyPanelUtils.SendMessageToFocusedControl(AMsg: Cardinal);
var
  FocusedCtrl: TWinControl;
  FocusedWnd: HWND;
begin
  FocusedWnd := GetFocus;
  if FocusedWnd <> 0 then
  begin
    SendMessage(FocusedWnd, AMsg, 0, 0);
    Exit;
  end;
  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := Screen.ActiveCustomForm.ActiveControl;
  if Assigned(FocusedCtrl) and FocusedCtrl.HandleAllocated then
    SendMessage(FocusedCtrl.Handle, AMsg, 0, 0);
end;

class procedure TPropertyPanelUtils.SendDeleteToFocusedControl;
var
  FocusedCtrl: TWinControl;
  FocusedWnd: HWND;
begin
  FocusedWnd := GetFocus;
  if FocusedWnd <> 0 then
  begin
    SendMessage(FocusedWnd, WM_CLEAR, 0, 0);
    SendMessage(FocusedWnd, WM_KEYDOWN, VK_DELETE, 0);
    SendMessage(FocusedWnd, WM_KEYUP, VK_DELETE, 0);
    Exit;
  end;
  FocusedCtrl := Screen.ActiveControl;
  if not Assigned(FocusedCtrl) then
    FocusedCtrl := Screen.ActiveCustomForm.ActiveControl;
  if Assigned(FocusedCtrl) and FocusedCtrl.HandleAllocated then
  begin
    SendMessage(FocusedCtrl.Handle, WM_CLEAR, 0, 0);
    SendMessage(FocusedCtrl.Handle, WM_KEYDOWN, VK_DELETE, 0);
    SendMessage(FocusedCtrl.Handle, WM_KEYUP, VK_DELETE, 0);
  end;
end;

class function TPropertyPanelUtils.CurrentPropertyTarget(ADesigner: TVittixReportDesigner): TReportObject;
var
  Ctx: TRttiContext;
  T: TRttiType;
  F: TRttiField;
  V: TValue;
begin
  Result := nil;
  if not Assigned(ADesigner) then
    Exit;
  Result := ADesigner.PrimarySelected;
  if Assigned(Result) then
    Exit;
  Ctx := TRttiContext.Create;
  try
    T := Ctx.GetType(ADesigner.ClassType);
    if not Assigned(T) then Exit;
    F := T.GetField('FActiveBand');
    if not Assigned(F) then Exit;
    V := F.GetValue(ADesigner);
    if not V.IsEmpty and (V.AsObject is TReportObject) then
      Result := TReportObject(V.AsObject);
  finally
    Ctx.Free;
  end;
end;

class function TPropertyPanelUtils.SelectedObjectsSpanBands(ADesigner: TVittixReportDesigner): Boolean;
begin
  Result := False;
end;

class function TPropertyPanelUtils.ConfirmMixedBandVerticalLayout(ADesigner: TVittixReportDesigner): Boolean;
begin
  Result := True;
end;

class function TPropertyPanelUtils.ShortNodePreview(const S: string; AMaxLen: Integer): string;
var
  Text: string;
begin
  Text := Trim(StringReplace(StringReplace(S, sLineBreak, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
  if Length(Text) > AMaxLen then
    Result := Copy(Text, 1, AMaxLen - 3) + '...'
  else
    Result := Text;
end;

end.
