unit Frm.Main.PropertyEditorHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Vcl.ValEdit,
  Vcl.Grids,
  Vittix.Report.Objects;

procedure ConfigurePropertyEditors(APropEditor: TValueListEditor; AObj: TReportObject;
  const AFieldNames: TArray<string>);

implementation

uses
  Frm.Main.PropertyHelpers;

procedure ConfigurePropertyEditors(APropEditor: TValueListEditor; AObj: TReportObject;
  const AFieldNames: TArray<string>);
var
  I, J: Integer;
  KeyName, ValueText: string;
  Ctx: TRttiContext;
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
  TypeData: PTypeData;
  EnumValue: Integer;
begin
  if not Assigned(APropEditor) then
    Exit;

  Ctx := TRttiContext.Create;
  try
    if Assigned(AObj) then
      RttiType := Ctx.GetType(AObj.ClassType)
    else
      RttiType := nil;

    for I := 1 to APropEditor.RowCount - 1 do
    begin
      KeyName := APropEditor.Keys[I];
      ValueText := APropEditor.Values[KeyName];

      if IsVisualGroupRow(KeyName) then
        Continue;

      if SameText(KeyName, 'DataField') then
      begin
        APropEditor.ItemProps[KeyName].EditStyle := esPickList;
        APropEditor.ItemProps[KeyName].PickList.BeginUpdate;
        try
          APropEditor.ItemProps[KeyName].PickList.Clear;
          APropEditor.ItemProps[KeyName].PickList.Add('');
          for J := 0 to High(AFieldNames) do
            APropEditor.ItemProps[KeyName].PickList.Add(AFieldNames[J]);
        finally
          APropEditor.ItemProps[KeyName].PickList.EndUpdate;
        end;
      end
      else if IsBandEventScriptRowKey(KeyName) or IsExpressionPropertyKey(KeyName) or
              IsColorPropertyKey(KeyName) then
      begin
        APropEditor.ItemProps[KeyName].EditStyle := esEllipsis;
      end
      else if SameText(ValueText, 'True') or SameText(ValueText, 'False') then
      begin
        APropEditor.ItemProps[KeyName].EditStyle := esPickList;
        APropEditor.ItemProps[KeyName].PickList.BeginUpdate;
        try
          APropEditor.ItemProps[KeyName].PickList.Clear;
          APropEditor.ItemProps[KeyName].PickList.Add('True');
          APropEditor.ItemProps[KeyName].PickList.Add('False');
        finally
          APropEditor.ItemProps[KeyName].PickList.EndUpdate;
        end;
      end
      else if Assigned(RttiType) then
      begin
        RttiProp := RttiType.GetProperty(KeyName);
        if Assigned(RttiProp) and Assigned(RttiProp.PropertyType) and
           (RttiProp.PropertyType.TypeKind = tkEnumeration) then
        begin
          APropEditor.ItemProps[KeyName].EditStyle := esPickList;
          APropEditor.ItemProps[KeyName].PickList.BeginUpdate;
          try
            APropEditor.ItemProps[KeyName].PickList.Clear;
            TypeData := GetTypeData(RttiProp.PropertyType.Handle);
            if Assigned(TypeData) then
              for EnumValue := TypeData.MinValue to TypeData.MaxValue do
                APropEditor.ItemProps[KeyName].PickList.Add(
                  GetEnumName(RttiProp.PropertyType.Handle, EnumValue));
          finally
            APropEditor.ItemProps[KeyName].PickList.EndUpdate;
          end;
        end;
      end;
    end;
  finally
    Ctx.Free;
  end;
end;

end.
