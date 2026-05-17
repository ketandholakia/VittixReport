unit ReportScriptHost.Adapter;

interface

uses
  System.SysUtils,
  Vcl.Graphics,
  Vittix.Report.Objects;

type
  TScriptHostCommandResult = record
    Handled: Boolean;
    Unsupported: Boolean;
    Canceled: Boolean;
    TextSet: Boolean;
    TraceMessage: string;
  end;

  TReportScriptHostAdapter = class
  private
    function ParseScriptAssignment(const AScript: string; out AKey, AValue: string): Boolean;
  public
    function ExecuteBeforeObject(AObject: TReportObject; const AScript: string;
      var ACanPrint: Boolean): TScriptHostCommandResult;
  end;

implementation

function TReportScriptHostAdapter.ParseScriptAssignment(const AScript: string; out AKey,
  AValue: string): Boolean;
var
  P: Integer;
begin
  AKey := '';
  AValue := '';
  P := Pos(':=', AScript);
  Result := P > 0;
  if not Result then
    Exit;
  AKey := LowerCase(Trim(Copy(AScript, 1, P - 1)));
  AValue := Trim(Copy(AScript, P + 2, MaxInt));
end;

function TReportScriptHostAdapter.ExecuteBeforeObject(AObject: TReportObject;
  const AScript: string; var ACanPrint: Boolean): TScriptHostCommandResult;
var
  Key: string;
  Value: string;
  B: Boolean;
  C: TColor;
  Lit: string;
begin
  Result.Handled := False;
  Result.Unsupported := False;
  Result.Canceled := False;
  Result.TextSet := False;
  Result.TraceMessage := '';

  if not ParseScriptAssignment(AScript, Key, Value) then
    Exit;

  Result.Handled := True;

  if Key = 'canprint' then
  begin
    if SameText(Value, 'False') then
    begin
      ACanPrint := False;
      Result.Canceled := True;
      if Assigned(AObject) then
        Result.TraceMessage := 'ScriptCanceledObject: ' + AObject.ClassName
      else
        Result.TraceMessage := 'ScriptCanceledObject: <nil>';
    end
    else
    begin
      Result.Unsupported := True;
      Result.TraceMessage := 'ScriptUnsupportedCommand: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'visible' then
  begin
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      Result.Unsupported := True;
      Result.TraceMessage := 'ScriptUnsupportedVisibleValue: ' + AScript;
      Exit;
    end;

    AObject.Visible := B;
    Result.TraceMessage := Format('ScriptSetVisible: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
    Exit;
  end;

  if Key = 'background' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.TraceMessage := 'ScriptUnsupportedForObjectType: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).Background := C;
      TReportTextObject(AObject).Transparent := False;
      Result.TraceMessage := Format('ScriptSetBackground: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.TraceMessage := 'ScriptUnsupportedColor: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'text' then
  begin
    if (Length(Value) >= 2) and (Value[1] = '''') and (Value[Length(Value)] = '''') then
    begin
      Lit := Copy(Value, 2, Length(Value) - 2);
      Lit := StringReplace(Lit, '''''', '''', [rfReplaceAll]);
      if AObject is TReportTextObject then
      begin
        TReportTextObject(AObject).Text := Lit;
        Result.TextSet := True;
        Result.TraceMessage := Format('ScriptSetText: %s "%s" -> "%s"',
          [AObject.ClassName, AObject.Name, Lit]);
      end
      else
      begin
        Result.Unsupported := True;
        Result.TraceMessage := 'ScriptUnsupportedForObjectType: ' + AObject.ClassName;
      end;
    end
    else
    begin
      Result.Unsupported := True;
      Result.TraceMessage := 'ScriptUnsupportedTextLiteral: ' + AScript;
    end;
    Exit;
  end;

  Result.Handled := False;
end;

end.

