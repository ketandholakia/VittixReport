unit Vittix.Report.ScriptHost.Adapter;

interface

uses
  System.Classes,
  System.SysUtils,
  Data.DB,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Utils;

type
  TScriptHostCommandResult = record
    Handled: Boolean;
    Unsupported: Boolean;
    Canceled: Boolean;
    TextSet: Boolean;
    UnsupportedCount: Integer;
    TextSetCount: Integer;
    TraceMessage: string;
  end;

  TReportScriptHostAdapter = class
  private
    function ParseScriptAssignment(const AScript: string; out AKey, AValue: string): Boolean;
    function SplitStatements(const AScript: string): TArray<string>;
    function ExecuteSingleBeforeObject(AObject: TReportObject; const AScript: string;
      var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
  public
    function ExecuteBeforeObject(AObject: TReportObject; const AScript: string;
      var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
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

function TReportScriptHostAdapter.SplitStatements(const AScript: string): TArray<string>;
var
  I: Integer;
  Ch: Char;
  InQuote: Boolean;
  Current: string;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    InQuote := False;
    Current := '';
    I := 1;
    while I <= Length(AScript) do
    begin
      Ch := AScript[I];
      if Ch = '''' then
      begin
        Current := Current + Ch;
        // Handle escaped single quote inside quoted text: ''
        if InQuote and (I < Length(AScript)) and (AScript[I + 1] = '''') then
        begin
          Inc(I);
          Current := Current + AScript[I];
        end
        else
          InQuote := not InQuote;
      end
      else if (Ch = ';') and not InQuote then
      begin
        Parts.Add(Current);
        Current := '';
      end
      else
        Current := Current + Ch;
      Inc(I);
    end;
    Parts.Add(Current);
    Result := Parts.ToStringArray;
  finally
    Parts.Free;
  end;
end;

function TReportScriptHostAdapter.ExecuteSingleBeforeObject(AObject: TReportObject;
  const AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
var
  Key: string;
  Value: string;
  B: Boolean;
  N: Integer;
  C: TColor;
  Lit: string;
  Arg: string;
  F: TField;
begin
  Result.Handled := False;
  Result.Unsupported := False;
  Result.Canceled := False;
  Result.TextSet := False;
  Result.UnsupportedCount := 0;
  Result.TextSetCount := 0;
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
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[CanPrintValue]: ' + AScript;
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
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[VisibleValue]: ' + AScript;
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
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
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
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'fontcolor' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).Font.Color := C;
      Result.TraceMessage := Format('ScriptSetFontColor: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'fontname' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if Value = '' then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[FontNameValue]: ' + AScript;
      Exit;
    end;
    TReportTextObject(AObject).Font.Name := Value;
    Result.TraceMessage := Format('ScriptSetFontName: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'halign' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'Left') then
      TReportTextObject(AObject).HAlign := taLeftJustify
    else if SameText(Value, 'Center') then
      TReportTextObject(AObject).HAlign := taCenter
    else if SameText(Value, 'Right') then
      TReportTextObject(AObject).HAlign := taRightJustify
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[HAlignValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetHAlign: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'valign' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'Top') then
      TReportTextObject(AObject).VAlign := taAlignTop
    else if SameText(Value, 'Center') then
      TReportTextObject(AObject).VAlign := taVerticalCenter
    else if SameText(Value, 'Bottom') then
      TReportTextObject(AObject).VAlign := taAlignBottom
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[VAlignValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetVAlign: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'printwhen' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).PrintWhen := Value;
    Result.TraceMessage := Format('ScriptSetPrintWhen: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'fontsize' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[FontSizeValue]: ' + AScript;
      Exit;
    end;
    if N < 1 then
      N := 1;
    TReportTextObject(AObject).Font.Size := N;
    Result.TraceMessage := Format('ScriptSetFontSize: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'fontcolorontrue' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).FontColorOnTrue := C;
      Result.TraceMessage := Format('ScriptSetFontColorOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'backgroundontrue' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).BackgroundOnTrue := C;
      Result.TraceMessage := Format('ScriptSetBackgroundOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'backgroundcondition' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).BackgroundCondition := Value;
    Result.TraceMessage := Format('ScriptSetBackgroundCondition: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'bordercolorcondition' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).BorderColorCondition := Value;
    Result.TraceMessage := Format('ScriptSetBorderColorCondition: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'bordercolorontrue' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).BorderColorOnTrue := C;
      Result.TraceMessage := Format('ScriptSetBorderColorOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'bordercolor' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).BorderColor := C;
      TReportTextObject(AObject).BorderVisible := True;
      Result.TraceMessage := Format('ScriptSetBorderColor: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
    Exit;
  end;

  if Key = 'transparent' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).Transparent := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).Transparent := False
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[TransparentValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetTransparent: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'autosize' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).AutoSize := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).AutoSize := False
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[AutoSizeValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetAutoSize: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'wordwrap' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).WordWrap := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).WordWrap := False
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[WordWrapValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetWordWrap: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'bordervisible' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).BorderVisible := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).BorderVisible := False
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[BorderVisibleValue]: ' + AScript;
      Exit;
    end;
    Result.TraceMessage := Format('ScriptSetBorderVisible: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
    Exit;
  end;

  if Key = 'borderwidth' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[BorderWidthValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).BorderWidth := N;
    TReportTextObject(AObject).BorderVisible := True;
    Result.TraceMessage := Format('ScriptSetBorderWidth: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'paddingleft' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[PaddingLeftValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingLeft := N;
    Result.TraceMessage := Format('ScriptSetPaddingLeft: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'paddingtop' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[PaddingTopValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingTop := N;
    Result.TraceMessage := Format('ScriptSetPaddingTop: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'paddingright' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[PaddingRightValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingRight := N;
    Result.TraceMessage := Format('ScriptSetPaddingRight: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'paddingbottom' then
  begin
    if not (AObject is TReportTextObject) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[PaddingBottomValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingBottom := N;
    Result.TraceMessage := Format('ScriptSetPaddingBottom: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
    Exit;
  end;

  if Key = 'text' then
  begin
    if (Length(Value) >= 8) and SameText(Copy(Value, 1, 6), 'Field(') and
       (Value[Length(Value)] = ')') then
    begin
      Arg := Trim(Copy(Value, 7, Length(Value) - 7));
      if (Length(Arg) >= 2) and (Arg[1] = '''') and (Arg[Length(Arg)] = '''') then
      begin
        Arg := Copy(Arg, 2, Length(Arg) - 2);
        Arg := StringReplace(Arg, '''''', '''', [rfReplaceAll]);
        if Trim(Arg) = '' then
        begin
          Result.Unsupported := True;
          Result.UnsupportedCount := 1;
          Result.TraceMessage := 'ScriptUnsupported[FieldName]: ' + AScript;
          Exit;
        end;
        if not (AObject is TReportTextObject) then
        begin
          Result.Unsupported := True;
          Result.UnsupportedCount := 1;
          Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
          Exit;
        end;

        F := nil;
        if Assigned(Context.DataSet) and Context.DataSet.Active then
          TryGetField(Context.DataSet, Arg, F);
        if Assigned(F) then
        begin
          TReportTextObject(AObject).Text := F.AsString;
          Result.TextSet := True;
          Result.TextSetCount := 1;
          Result.TraceMessage := Format('ScriptSetTextFromField: %s "%s" <- Field("%s")',
            [AObject.ClassName, AObject.Name, Arg]);
        end
        else
        begin
          TReportTextObject(AObject).Text := '';
          Result.TraceMessage := 'ScriptFieldResolveMiss: ' + Arg;
        end;
      end
      else
      begin
        Result.Unsupported := True;
        Result.UnsupportedCount := 1;
        Result.TraceMessage := 'ScriptUnsupported[FieldSyntax]: ' + AScript;
      end;
      Exit;
    end;

    if (Length(Value) >= 2) and (Value[1] = '''') and (Value[Length(Value)] = '''') then
    begin
      Lit := Copy(Value, 2, Length(Value) - 2);
      Lit := StringReplace(Lit, '''''', '''', [rfReplaceAll]);
      if AObject is TReportTextObject then
      begin
        TReportTextObject(AObject).Text := Lit;
        Result.TextSet := True;
        Result.TextSetCount := 1;
        Result.TraceMessage := Format('ScriptSetText: %s "%s" -> "%s"',
          [AObject.ClassName, AObject.Name, Lit]);
      end
      else
      begin
        Result.Unsupported := True;
        Result.UnsupportedCount := 1;
        Result.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      end;
    end
    else
    begin
      Result.Unsupported := True;
      Result.UnsupportedCount := 1;
      Result.TraceMessage := 'ScriptUnsupported[TextLiteral]: ' + AScript;
    end;
    Exit;
  end;

  Result.Handled := True;
  Result.Unsupported := True;
  Result.UnsupportedCount := 1;
  Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;
end;

function TReportScriptHostAdapter.ExecuteBeforeObject(AObject: TReportObject;
  const AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
var
  Parts: TArray<string>;
  Part: string;
  PartTrimmed: string;
  Single: TScriptHostCommandResult;
  TraceLines: TStringList;
begin
  Result.Handled := False;
  Result.Unsupported := False;
  Result.Canceled := False;
  Result.TextSet := False;
  Result.UnsupportedCount := 0;
  Result.TextSetCount := 0;
  Result.TraceMessage := '';

  Parts := SplitStatements(AScript);
  TraceLines := TStringList.Create;
  try
    for Part in Parts do
    begin
      PartTrimmed := Trim(Part);
      if PartTrimmed = '' then
        Continue;

      Single := ExecuteSingleBeforeObject(AObject, PartTrimmed, Context, ACanPrint);
      if not Single.Handled then
        Continue;

      Result.Handled := True;
      Result.Unsupported := Result.Unsupported or Single.Unsupported;
      Result.TextSet := Result.TextSet or Single.TextSet;
      Result.Canceled := Result.Canceled or Single.Canceled;
      Inc(Result.UnsupportedCount, Single.UnsupportedCount);
      Inc(Result.TextSetCount, Single.TextSetCount);
      if Single.TraceMessage <> '' then
        TraceLines.Add(Single.TraceMessage);

      if Single.Canceled then
        Break;
    end;

    Result.TraceMessage := TraceLines.Text.TrimRight;
  finally
    TraceLines.Free;
  end;
end;

end.
