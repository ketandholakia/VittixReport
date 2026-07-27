unit Vittix.Report.ScriptHost.Adapter;

interface

uses
  System.Classes,
  System.SysUtils, System.Generics.Collections,
  System.UITypes,
  Data.DB,
  Vcl.Graphics,
  Vittix.Report.Objects,
  Vittix.Report.Context,
  Vittix.Report.Utils,
  Vittix.Report.Model;

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

  TScriptCommandHandler = procedure(
    AObject: TReportObject;
    const Value, AScript: string;
    var Context: TExpressionContext;
    var ACanPrint: Boolean;
    var AResult: TScriptHostCommandResult
  ) of object;

  TReportScriptHostAdapter = class
  private
    FHandlers: TDictionary<string, TScriptCommandHandler>;
    procedure InitHandlers;
    function ParseScriptAssignment(const AScript: string; out AKey, AValue: string): Boolean;
    function SplitStatements(const AScript: string): TArray<string>;
    function StripOuterQuotes(const S: string): string;
    function ExecuteSingleBeforeObject(AObject: TReportObject; const AScript: string;
      var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cmd_Canprint(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Visible(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Anchorright(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Anchorbottom(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Background(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontcolor(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontname(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Halign(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Valign(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Printwhen(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontbold(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontitalic(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Datafield(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Displayformat(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Editmask(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Expression(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontcolorcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontsize(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Fontcolorontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Backgroundontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Backgroundcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Bordercolorcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Bordercolorontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Bordercolor(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Stretch(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Center(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Proportional(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Transparent(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Autosize(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Wordwrap(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Bordervisible(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Borderwidth(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Paddingleft(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Paddingtop(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Paddingright(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Paddingbottom(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure Cmd_Text(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
    procedure EngineObjectBeforePrint(AReport: TReportModel; AObject: TReportObject;
      const AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean);
    procedure EngineObjectAfterPrint(AReport: TReportModel; AObject: TReportObject;
      const AScript: string; var Context: TExpressionContext);
    function ExecuteBeforeObject(AObject: TReportObject; const AScript: string;
      var Context: TExpressionContext; var ACanPrint: Boolean): TScriptHostCommandResult;
    function ExecuteAfterObject(AObject: TReportObject; const AScript: string;
      var Context: TExpressionContext): TScriptHostCommandResult;
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

function TReportScriptHostAdapter.StripOuterQuotes(const S: string): string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
    Result := Copy(Result, 2, Length(Result) - 2);
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
  Handler: TScriptCommandHandler;
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

  Result.Handled := True;
  if FHandlers.TryGetValue(Key, Handler) then
  begin
    Handler(AObject, Value, AScript, Context, ACanPrint, Result);
  end
  else
  begin
    Result.Unsupported := True;
    Result.UnsupportedCount := 1;
    Result.TraceMessage := 'ScriptUnsupported[UnknownCommand]: ' + AScript;
  end;
end;

constructor TReportScriptHostAdapter.Create;
begin
  inherited;
  FHandlers := TDictionary<string, TScriptCommandHandler>.Create;
  InitHandlers;
end;

destructor TReportScriptHostAdapter.Destroy;
begin
  FHandlers.Free;
  inherited;
end;

procedure TReportScriptHostAdapter.InitHandlers;
var
  Handler: TScriptCommandHandler;
begin
  Handler := Cmd_Canprint;
  FHandlers.Add('canprint', Handler);
  Handler := Cmd_Visible;
  FHandlers.Add('visible', Handler);
  Handler := Cmd_Anchorright;
  FHandlers.Add('anchorright', Handler);
  Handler := Cmd_Anchorbottom;
  FHandlers.Add('anchorbottom', Handler);
  Handler := Cmd_Background;
  FHandlers.Add('background', Handler);
  Handler := Cmd_Fontcolor;
  FHandlers.Add('fontcolor', Handler);
  Handler := Cmd_Fontname;
  FHandlers.Add('fontname', Handler);
  Handler := Cmd_Halign;
  FHandlers.Add('halign', Handler);
  Handler := Cmd_Valign;
  FHandlers.Add('valign', Handler);
  Handler := Cmd_Printwhen;
  FHandlers.Add('printwhen', Handler);
  Handler := Cmd_Fontbold;
  FHandlers.Add('fontbold', Handler);
  Handler := Cmd_Fontitalic;
  FHandlers.Add('fontitalic', Handler);
  Handler := Cmd_Datafield;
  FHandlers.Add('datafield', Handler);
  Handler := Cmd_Displayformat;
  FHandlers.Add('displayformat', Handler);
  Handler := Cmd_Editmask;
  FHandlers.Add('editmask', Handler);
  Handler := Cmd_Expression;
  FHandlers.Add('expression', Handler);
  Handler := Cmd_Fontcolorcondition;
  FHandlers.Add('fontcolorcondition', Handler);
  Handler := Cmd_Fontsize;
  FHandlers.Add('fontsize', Handler);
  Handler := Cmd_Fontcolorontrue;
  FHandlers.Add('fontcolorontrue', Handler);
  Handler := Cmd_Backgroundontrue;
  FHandlers.Add('backgroundontrue', Handler);
  Handler := Cmd_Backgroundcondition;
  FHandlers.Add('backgroundcondition', Handler);
  Handler := Cmd_Bordercolorcondition;
  FHandlers.Add('bordercolorcondition', Handler);
  Handler := Cmd_Bordercolorontrue;
  FHandlers.Add('bordercolorontrue', Handler);
  Handler := Cmd_Bordercolor;
  FHandlers.Add('bordercolor', Handler);
  Handler := Cmd_Stretch;
  FHandlers.Add('stretch', Handler);
  Handler := Cmd_Center;
  FHandlers.Add('center', Handler);
  Handler := Cmd_Proportional;
  FHandlers.Add('proportional', Handler);
  Handler := Cmd_Transparent;
  FHandlers.Add('transparent', Handler);
  Handler := Cmd_Autosize;
  FHandlers.Add('autosize', Handler);
  Handler := Cmd_Wordwrap;
  FHandlers.Add('wordwrap', Handler);
  Handler := Cmd_Bordervisible;
  FHandlers.Add('bordervisible', Handler);
  Handler := Cmd_Borderwidth;
  FHandlers.Add('borderwidth', Handler);
  Handler := Cmd_Paddingleft;
  FHandlers.Add('paddingleft', Handler);
  Handler := Cmd_Paddingtop;
  FHandlers.Add('paddingtop', Handler);
  Handler := Cmd_Paddingright;
  FHandlers.Add('paddingright', Handler);
  Handler := Cmd_Paddingbottom;
  FHandlers.Add('paddingbottom', Handler);
  Handler := Cmd_Text;
  FHandlers.Add('text', Handler);
end;

procedure TReportScriptHostAdapter.Cmd_Canprint(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if SameText(Value, 'False') then
    begin
      ACanPrint := False;
      AResult.Canceled := True;
      if Assigned(AObject) then
        AResult.TraceMessage := 'ScriptCanceledObject: ' + AObject.ClassName
      else
        AResult.TraceMessage := 'ScriptCanceledObject: <nil>';
    end
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[CanPrintValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Visible(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[VisibleValue]: ' + AScript;
      Exit;
    end;

    AObject.Visible := B;
    AResult.TraceMessage := Format('ScriptSetVisible: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Anchorright(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[AnchorRightValue]: ' + AScript;
      Exit;
    end;
    AObject.AnchorRight := B;
    AResult.TraceMessage := Format('ScriptSetAnchorRight: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Anchorbottom(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[AnchorBottomValue]: ' + AScript;
      Exit;
    end;
    AObject.AnchorBottom := B;
    AResult.TraceMessage := Format('ScriptSetAnchorBottom: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Background(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).Background := C;
      TReportTextObject(AObject).Transparent := False;
      AResult.TraceMessage := Format('ScriptSetBackground: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Fontcolor(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) and not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).Font.Color := C;
      AResult.TraceMessage := Format('ScriptSetFontColor: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Fontname(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if Value = '' then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[FontNameValue]: ' + AScript;
      Exit;
    end;
    TReportTextObject(AObject).Font.Name := Value;
    AResult.TraceMessage := Format('ScriptSetFontName: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Halign(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
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
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[HAlignValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetHAlign: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Valign(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
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
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[VAlignValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetVAlign: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Printwhen(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).PrintWhen := Value;
    AResult.TraceMessage := Format('ScriptSetPrintWhen: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Fontbold(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[FontBoldValue]: ' + AScript;
      Exit;
    end;
    if B then
      TReportTextObject(AObject).Font.Style := TReportTextObject(AObject).Font.Style + [fsBold]
    else
      TReportTextObject(AObject).Font.Style := TReportTextObject(AObject).Font.Style - [fsBold];
    AResult.TraceMessage := Format('ScriptSetFontBold: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Fontitalic(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[FontItalicValue]: ' + AScript;
      Exit;
    end;
    if B then
      TReportTextObject(AObject).Font.Style := TReportTextObject(AObject).Font.Style + [fsItalic]
    else
      TReportTextObject(AObject).Font.Style := TReportTextObject(AObject).Font.Style - [fsItalic];
    AResult.TraceMessage := Format('ScriptSetFontItalic: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Datafield(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) and not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if AObject is TReportTextObject then
    begin
      TReportTextObject(AObject).DataField := Value;
      AResult.TraceMessage := Format('ScriptSetDataField: %s "%s" -> "%s"',
        [AObject.ClassName, AObject.Name, Value]);
    end
    else
    begin
      TReportImageObject(AObject).DataField := Value;
      AResult.TraceMessage := Format('ScriptSetDataField: %s "%s" -> "%s"',
        [AObject.ClassName, AObject.Name, Value]);
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Displayformat(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportFieldObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportFieldObject(AObject).DisplayFormat := StripOuterQuotes(Value);
    AResult.TraceMessage := Format('ScriptSetDisplayFormat: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, TReportFieldObject(AObject).DisplayFormat]);
end;

procedure TReportScriptHostAdapter.Cmd_Editmask(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportFieldObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportFieldObject(AObject).EditMask := StripOuterQuotes(Value);
    AResult.TraceMessage := Format('ScriptSetEditMask: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, TReportFieldObject(AObject).EditMask]);
end;

procedure TReportScriptHostAdapter.Cmd_Expression(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).Expression := Value;
    AResult.TraceMessage := Format('ScriptSetExpression: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Fontcolorcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).FontColorCondition := Value;
    AResult.TraceMessage := Format('ScriptSetFontColorCondition: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Fontsize(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[FontSizeValue]: ' + AScript;
      Exit;
    end;
    if N < 1 then
      N := 1;
    TReportTextObject(AObject).Font.Size := N;
    AResult.TraceMessage := Format('ScriptSetFontSize: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Fontcolorontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).FontColorOnTrue := C;
      AResult.TraceMessage := Format('ScriptSetFontColorOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Backgroundontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).BackgroundOnTrue := C;
      AResult.TraceMessage := Format('ScriptSetBackgroundOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Backgroundcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).BackgroundCondition := Value;
    AResult.TraceMessage := Format('ScriptSetBackgroundCondition: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Bordercolorcondition(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    TReportTextObject(AObject).BorderColorCondition := Value;
    AResult.TraceMessage := Format('ScriptSetBorderColorCondition: %s "%s" -> "%s"',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Bordercolorontrue(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      TReportTextObject(AObject).BorderColorOnTrue := C;
      AResult.TraceMessage := Format('ScriptSetBorderColorOnTrue: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Bordercolor(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    try
      C := StringToColor(Value);
      if AObject is TReportTextObject then
      begin
        TReportTextObject(AObject).BorderColor := C;
        TReportTextObject(AObject).BorderVisible := True;
      end
      else
      begin
        TReportImageObject(AObject).BorderColor := C;
        TReportImageObject(AObject).BorderVisible := True;
      end;
      AResult.TraceMessage := Format('ScriptSetBorderColor: %s "%s" -> %s',
        [AObject.ClassName, AObject.Name, Value]);
    except
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ColorValue]: ' + AScript;
    end;
end;

procedure TReportScriptHostAdapter.Cmd_Stretch(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[StretchValue]: ' + AScript;
      Exit;
    end;
    TReportImageObject(AObject).Stretch := B;
    AResult.TraceMessage := Format('ScriptSetStretch: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Center(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[CenterValue]: ' + AScript;
      Exit;
    end;
    TReportImageObject(AObject).Center := B;
    AResult.TraceMessage := Format('ScriptSetCenter: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Proportional(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      B := True
    else if SameText(Value, 'False') then
      B := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ProportionalValue]: ' + AScript;
      Exit;
    end;
    TReportImageObject(AObject).Proportional := B;
    AResult.TraceMessage := Format('ScriptSetProportional: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, BoolToStr(B, True)]);
end;

procedure TReportScriptHostAdapter.Cmd_Transparent(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).Transparent := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).Transparent := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[TransparentValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetTransparent: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Autosize(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).AutoSize := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).AutoSize := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[AutoSizeValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetAutoSize: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Wordwrap(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
      TReportTextObject(AObject).WordWrap := True
    else if SameText(Value, 'False') then
      TReportTextObject(AObject).WordWrap := False
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[WordWrapValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetWordWrap: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Bordervisible(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) and not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if SameText(Value, 'True') then
    begin
      if AObject is TReportTextObject then
        TReportTextObject(AObject).BorderVisible := True
      else
        TReportImageObject(AObject).BorderVisible := True;
    end
    else if SameText(Value, 'False') then
    begin
      if AObject is TReportTextObject then
        TReportTextObject(AObject).BorderVisible := False
      else
        TReportImageObject(AObject).BorderVisible := False;
    end
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[BorderVisibleValue]: ' + AScript;
      Exit;
    end;
    AResult.TraceMessage := Format('ScriptSetBorderVisible: %s "%s" -> %s',
      [AObject.ClassName, AObject.Name, Value]);
end;

procedure TReportScriptHostAdapter.Cmd_Borderwidth(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) and not (AObject is TReportImageObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[BorderWidthValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    if AObject is TReportTextObject then
    begin
      TReportTextObject(AObject).BorderWidth := N;
      TReportTextObject(AObject).BorderVisible := True;
    end
    else
    begin
      TReportImageObject(AObject).BorderWidth := N;
      TReportImageObject(AObject).BorderVisible := True;
    end;
    AResult.TraceMessage := Format('ScriptSetBorderWidth: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Paddingleft(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[PaddingLeftValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingLeft := N;
    AResult.TraceMessage := Format('ScriptSetPaddingLeft: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Paddingtop(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[PaddingTopValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingTop := N;
    AResult.TraceMessage := Format('ScriptSetPaddingTop: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Paddingright(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[PaddingRightValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingRight := N;
    AResult.TraceMessage := Format('ScriptSetPaddingRight: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Paddingbottom(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
begin
    if not (AObject is TReportTextObject) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      Exit;
    end;
    if not TryStrToInt(Value, N) then
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[PaddingBottomValue]: ' + AScript;
      Exit;
    end;
    if N < 0 then
      N := 0;
    TReportTextObject(AObject).PaddingBottom := N;
    AResult.TraceMessage := Format('ScriptSetPaddingBottom: %s "%s" -> %d',
      [AObject.ClassName, AObject.Name, N]);
end;

procedure TReportScriptHostAdapter.Cmd_Text(AObject: TReportObject; const Value, AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean; var AResult: TScriptHostCommandResult);
var
  B: Boolean; N: Integer; C: TColor; Lit: string; Arg: string; F: TField;
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
          AResult.Unsupported := True;
          AResult.UnsupportedCount := 1;
          AResult.TraceMessage := 'ScriptUnsupported[FieldName]: ' + AScript;
          Exit;
        end;
        if not (AObject is TReportTextObject) then
        begin
          AResult.Unsupported := True;
          AResult.UnsupportedCount := 1;
          AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
          Exit;
        end;

        F := nil;
        if Assigned(Context.DataSet) and Context.DataSet.Active then
          TryGetField(Context.DataSet, Arg, F);
        if Assigned(F) then
        begin
          TReportTextObject(AObject).Text := F.AsString;
          AResult.TextSet := True;
          AResult.TextSetCount := 1;
          AResult.TraceMessage := Format('ScriptSetTextFromField: %s "%s" <- Field("%s")',
            [AObject.ClassName, AObject.Name, Arg]);
        end
        else
        begin
          TReportTextObject(AObject).Text := '';
          AResult.TraceMessage := 'ScriptFieldResolveMiss: ' + Arg;
        end;
      end
      else
      begin
        AResult.Unsupported := True;
        AResult.UnsupportedCount := 1;
        AResult.TraceMessage := 'ScriptUnsupported[FieldSyntax]: ' + AScript;
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
        AResult.TextSet := True;
        AResult.TextSetCount := 1;
        AResult.TraceMessage := Format('ScriptSetText: %s "%s" -> "%s"',
          [AObject.ClassName, AObject.Name, Lit]);
      end
      else
      begin
        AResult.Unsupported := True;
        AResult.UnsupportedCount := 1;
        AResult.TraceMessage := 'ScriptUnsupported[ObjectType]: ' + AObject.ClassName;
      end;
    end
    else
    begin
      AResult.Unsupported := True;
      AResult.UnsupportedCount := 1;
      AResult.TraceMessage := 'ScriptUnsupported[TextLiteral]: ' + AScript;
    end;
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

procedure TReportScriptHostAdapter.EngineObjectBeforePrint(AReport: TReportModel; AObject: TReportObject;
  const AScript: string; var Context: TExpressionContext; var ACanPrint: Boolean);
begin
  ExecuteBeforeObject(AObject, AScript, Context, ACanPrint);
end;

function TReportScriptHostAdapter.ExecuteAfterObject(AObject: TReportObject;
  const AScript: string; var Context: TExpressionContext): TScriptHostCommandResult;
var
  DummyCanPrint: Boolean;
begin
  DummyCanPrint := True;
  Result := ExecuteBeforeObject(AObject, AScript, Context, DummyCanPrint);
end;

procedure TReportScriptHostAdapter.EngineObjectAfterPrint(AReport: TReportModel; AObject: TReportObject;
  const AScript: string; var Context: TExpressionContext);
begin
  ExecuteAfterObject(AObject, AScript, Context);
end;

end.
