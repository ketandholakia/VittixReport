unit Vittix.Report.PropertyBridge;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Vcl.ValEdit;

type
  TReportPropertyBridge = class
  private
    class var FRtti: TRttiContext;
  public
    class procedure LoadObjectToGrid(
      AObject: TObject;
      AGrid: TValueListEditor);

    class procedure SaveGridToObject(
      AObject: TObject;
      AGrid: TValueListEditor);
  end;

implementation

{ ================= Load → Grid ================= }

class procedure TReportPropertyBridge.LoadObjectToGrid(
  AObject: TObject;
  AGrid: TValueListEditor);
var
  T: TRttiType;
  P: TRttiProperty;
  V: TValue;
begin
  AGrid.Strings.BeginUpdate;
  try
    AGrid.Strings.Clear;

    if not Assigned(AObject) then Exit;

    T := FRtti.GetType(AObject.ClassType);

    for P in T.GetProperties do
    begin
      if P.Visibility <> mvPublished then Continue;
      if not P.IsReadable then Continue;

      try
        V := P.GetValue(AObject);
        AGrid.InsertRow(P.Name, V.ToString, True);
      except
        { skip unreadable props }
      end;
    end;

  finally
    AGrid.Strings.EndUpdate;
  end;
end;

{ ================= Grid → Object ================= }

class procedure TReportPropertyBridge.SaveGridToObject(
  AObject: TObject;
  AGrid: TValueListEditor);
var
  T: TRttiType;
  P: TRttiProperty;
  i: Integer;
  PropName, S: string;
  Kind: TTypeKind;
begin
  if not Assigned(AObject) then Exit;

  T := FRtti.GetType(AObject.ClassType);

  for i := 0 to AGrid.RowCount-1 do
  begin
    PropName := AGrid.Keys[i];
    S := AGrid.Values[PropName];

    if PropName = '' then Continue;

    P := T.GetProperty(PropName);
    if not Assigned(P) then Continue;
    if not P.IsWritable then Continue;

    Kind := P.PropertyType.TypeKind;

    try
      case Kind of

        tkInteger:
          P.SetValue(AObject, StrToIntDef(S,0));

        tkInt64:
          P.SetValue(AObject, StrToInt64Def(S,0));

        tkFloat:
          P.SetValue(AObject, StrToFloatDef(S,0));

        tkString, tkLString, tkWString, tkUString:
          P.SetValue(AObject, S);

        tkEnumeration:
          P.SetValue(
            AObject,
            TValue.FromOrdinal(
              P.PropertyType.Handle,
              GetEnumValue(P.PropertyType.Handle, S)
            )
          );

      end;

    except
      { ignore bad user input — keep designer stable }
    end;
  end;
end;

end.
