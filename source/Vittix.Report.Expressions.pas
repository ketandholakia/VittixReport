unit Vittix.Report.Expressions;

{
  Vittix.Report.Expressions
  =========================
  TReportExpression.Evaluate resolves a string expression in the context of
  the current dataset row and page state.

  Evaluation order
  ----------------
  1. Aggregate functions  SUM(…), COUNT(…), AVG(…), MIN(…), MAX(…)
  2. System tokens        [PageNo], [TotalPages], [RowNumber], [Param.Name], [ReportTitle]
  3. Dataset field tokens [FieldName]   → current field value as string
  4. Quoted string literal 'text'
  5. Arithmetic           +, -, *, /    on resolved tokens
  6. Numeric fallback
  7. String fallback

  System tokens (case-insensitive)
  ---------------------------------
    [PageNo]       Current page number (1-based)
    [TotalPages]   Total page count (0 while engine is running)
    [RowNumber]    Current master row number (1-based)
    [Param.Name]   Runtime report parameter value
    [ReportTitle]  TReportModel.Title
    [ReportDate]   Date the report was generated (ShortDateStr format)
    [DateTime]     Date + time the report was generated
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Context,
  Vittix.Report.Utils;

type
  TReportExpression = class
  public
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext): Variant;
  end;

implementation

uses
  Vittix.Report.Aggregates
  {$IFDEF DEBUG}
  , Winapi.Windows
  {$ENDIF}
  ;

{$IFDEF DEBUG}
const
  CExprDiagMaxMessages = 200;

var
  GExprDiagSeen: TStringList;
  GExprDiagCount: Integer;

procedure DebugLogUnresolvedToken(const Expr, TokenName, Reason: string);
var
  Key: string;
  Msg: string;
begin
  if GExprDiagCount >= CExprDiagMaxMessages then
    Exit;

  if not Assigned(GExprDiagSeen) then
  begin
    GExprDiagSeen := TStringList.Create;
    GExprDiagSeen.Sorted := True;
    GExprDiagSeen.Duplicates := dupIgnore;
  end;

  Key := Expr + '|' + TokenName + '|' + Reason;
  if GExprDiagSeen.IndexOf(Key) >= 0 then
    Exit;

  GExprDiagSeen.Add(Key);
  Inc(GExprDiagCount);

  Msg := Format(
    '[VittixReport][Expr] Unresolved token "[%s]" in "%s": %s; using 0 fallback',
    [TokenName, Expr, Reason]);
  OutputDebugString(PChar(Msg));
end;
{$ENDIF}

// ---------------------------------------------------------------------------
// System token resolver
// ---------------------------------------------------------------------------

function ResolveSystemToken(
  const Token: string;
  const Context: TExpressionContext;
  out Value: string): Boolean;
var
  ParamName: string;

  function TryResolveParameter(const AName: string; out AValue: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if not Assigned(Context.Parameters) then
      Exit;

    for I := 0 to Context.Parameters.Count - 1 do
      if SameText(Context.Parameters.Names[I], AName) then
      begin
        AValue := Context.Parameters.ValueFromIndex[I];
        Exit(True);
      end;
  end;
begin
  Result := True;
  if SameText(Token, 'PageNo') or
     SameText(Token, 'Page') or
     SameText(Token, 'Page#') then
    Value := IntToStr(Context.PageNumber)
  else if SameText(Token, 'TotalPages') or
          SameText(Token, 'TotalPages#') then
    Value := IntToStr(Context.TotalPages)
  else if SameText(Token, 'ReportTitle') then
    Value := Context.ReportTitle
  else if SameText(Token, 'ReportDate') or
          SameText(Token, 'Date') then
    Value := DateToStr(Context.ReportDate)
  else if SameText(Token, 'DateTime') then
    Value := DateTimeToStr(Context.ReportDate)
  else if SameText(Token, 'Time') then
    Value := TimeToStr(Context.ReportDate)
  else if SameText(Token, 'RecNo') or
          SameText(Token, 'RowNumber') or
          SameText(Token, 'Line') or
          SameText(Token, 'Line#') then
  begin
    if Context.RowNumber > 0 then
      Value := IntToStr(Context.RowNumber)
    else if Assigned(Context.DataSet) and Context.DataSet.Active then
      Value := IntToStr(Context.DataSet.RecNo)
    else
      Value := '0';
  end
  else if SameText(Copy(Token, 1, 6), 'Param.') or
          SameText(Copy(Token, 1, 10), 'Parameter.') or
          SameText(Copy(Token, 1, 11), 'Parameters.') then
  begin
    if SameText(Copy(Token, 1, 6), 'Param.') then
      ParamName := Copy(Token, 7, MaxInt)
    else if SameText(Copy(Token, 1, 10), 'Parameter.') then
      ParamName := Copy(Token, 11, MaxInt)
    else
      ParamName := Copy(Token, 12, MaxInt);

    if not TryResolveParameter(ParamName, Value) then
      Value := '';
  end
  else
    Result := False;  // not a system token
end;

// ---------------------------------------------------------------------------
// Field + system token replacer
// ---------------------------------------------------------------------------

function ResolveFieldTokens(
  const S: string;
  ADataSet: TDataSet;
  const Context: TExpressionContext): string;
var
  i, j: Integer;
  TokenName, TokenValue: string;
  F: TField;
begin
  Result := '';
  i := 1;

  while i <= Length(S) do
  begin
    if S[i] = '[' then
    begin
      j := i + 1;
      while (j <= Length(S)) and (S[j] <> ']') do Inc(j);

      TokenName := Copy(S, i + 1, j - i - 1);

      // 1. Try system tokens first
      if ResolveSystemToken(TokenName, Context, TokenValue) then
        Result := Result + TokenValue
      else if Trim(TokenName) = '' then
      begin
{$IFDEF DEBUG}
        DebugLogUnresolvedToken(S, TokenName, 'unknown token / unsupported token');
{$ENDIF}
        Result := Result + '0';
      end
      // 2. Then dataset fields
      else if not Assigned(ADataSet) then
      begin
{$IFDEF DEBUG}
        DebugLogUnresolvedToken(S, TokenName, 'dataset nil');
{$ENDIF}
        Result := Result + '0';
      end
      else if not ADataSet.Active then
      begin
{$IFDEF DEBUG}
        DebugLogUnresolvedToken(S, TokenName, 'dataset inactive');
{$ENDIF}
        Result := Result + '0';
      end
      else if TryGetField(ADataSet, TokenName, F) then
      begin
        try
          Result := Result + F.AsString;
        except
{$IFDEF DEBUG}
          DebugLogUnresolvedToken(S, TokenName, 'field conversion error');
{$ENDIF}
          Result := Result + '0';
        end;
      end
      else
      begin
{$IFDEF DEBUG}
        DebugLogUnresolvedToken(S, TokenName, 'field missing');
{$ENDIF}
        Result := Result + '0';
      end;

      i := j + 1;
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Simple arithmetic parser
// ---------------------------------------------------------------------------

function EvalSimpleMath(const S: string): Double;
var
  I: Integer;
  Acc: Double;
  Op: Char;
  Value: Double;

  procedure SkipSpaces;
  begin
    while (I <= Length(S)) and CharInSet(S[I], [#9, #10, #13, ' ']) do
      Inc(I);
  end;

  function ReadNumber(out AValue: Double): Boolean;
  var
    Start: Integer;
  begin
    SkipSpaces;
    Start := I;
    if (I <= Length(S)) and CharInSet(S[I], ['+', '-']) then
      Inc(I);
    while (I <= Length(S)) and CharInSet(S[I], ['0'..'9', '.', ',']) do
      Inc(I);
    Result := TryStrToFloat(Copy(S, Start, I - Start), AValue);
    if not Result then
      AValue := 0;
  end;

  function ReadOperator(out AOp: Char): Boolean;
  begin
    SkipSpaces;
    Result := (I <= Length(S)) and CharInSet(S[I], ['+', '-', '*', '/']);
    if Result then
    begin
      AOp := S[I];
      Inc(I);
    end;
  end;

begin
  I := 1;
  if not ReadNumber(Acc) then
    Exit(0);

  while ReadOperator(Op) do
  begin
    if not ReadNumber(Value) then
      Break;

    case Op of
      '+': Acc := Acc + Value;
      '-': Acc := Acc - Value;
      '*': Acc := Acc * Value;
      '/': if Value <> 0 then Acc := Acc / Value;
    end;
  end;
  Result := Acc;
end;

function TryEvalComparison(const S: string; out B: Boolean): Boolean;
const
  Ops: array[0..5] of string = ('<=', '>=', '<>', '=', '<', '>');
var
  Op: string;
  P: Integer;
  LStr, RStr: string;
  LDbl, RDbl: Double;
  LIsNum, RIsNum: Boolean;
begin
  Result := False;
  B := False;

  for Op in Ops do
  begin
    P := Pos(Op, S);
    if P > 0 then
    begin
      LStr := Trim(Copy(S, 1, P - 1));
      RStr := Trim(Copy(S, P + Length(Op), MaxInt));

      if (Length(LStr) >= 2) and (LStr[1] = '''') and (LStr[Length(LStr)] = '''') then
        LStr := Copy(LStr, 2, Length(LStr) - 2);
      if (Length(RStr) >= 2) and (RStr[1] = '''') and (RStr[Length(RStr)] = '''') then
        RStr := Copy(RStr, 2, Length(RStr) - 2);

      LIsNum := TryStrToFloat(LStr, LDbl);
      RIsNum := TryStrToFloat(RStr, RDbl);

      if LIsNum and RIsNum then
      begin
        if Op = '<=' then B := LDbl <= RDbl
        else if Op = '>=' then B := LDbl >= RDbl
        else if Op = '<>' then B := LDbl <> RDbl
        else if Op = '=' then B := LDbl = RDbl
        else if Op = '<' then B := LDbl < RDbl
        else if Op = '>' then B := LDbl > RDbl;
      end
      else
      begin
        if Op = '<=' then B := CompareText(LStr, RStr) <= 0
        else if Op = '>=' then B := CompareText(LStr, RStr) >= 0
        else if Op = '<>' then B := not SameText(LStr, RStr)
        else if Op = '=' then B := SameText(LStr, RStr)
        else if Op = '<' then B := CompareText(LStr, RStr) < 0
        else if Op = '>' then B := CompareText(LStr, RStr) > 0;
      end;

      Result := True;
      Exit;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Main Evaluate
// ---------------------------------------------------------------------------

class function TReportExpression.Evaluate(
  const Expr: string;
  const Context: TExpressionContext): Variant;
var
  S:        string;
  AggValue: Variant;
  DblValue: Double;
begin
  Result := '';

  if Trim(Expr) = '' then Exit;

  // Step 1 — aggregate functions
  if StartsText('SUM(',   Expr) or StartsText('COUNT(', Expr) or
     StartsText('AVG(',   Expr) or StartsText('MIN(',   Expr) or
     StartsText('MAX(',   Expr) then
  begin
    if TReportAggregates.TryEvaluate(Expr, Context, AggValue) then
      Exit(AggValue);
  end;

  // Steps 2+3 — system tokens and field tokens
  S := ResolveFieldTokens(Expr, Context.DataSet, Context);
  S := Trim(S);

  // Step 4 — quoted string literal
  if (Length(S) >= 2)
     and (S[1] = '''')
     and (S[Length(S)] = '''') then
  begin
    Result := Copy(S, 2, Length(S) - 2);
    Exit;
  end;

  // Step 4b — boolean literals
  if SameText(S, 'true') then
  begin
    Result := True;
    Exit;
  end;
  if SameText(S, 'false') then
  begin
    Result := False;
    Exit;
  end;

  // Step 4c — comparison operators
  var BoolValue: Boolean;
  if TryEvalComparison(S, BoolValue) then
  begin
    Result := BoolValue;
    Exit;
  end;

  // Step 5 — arithmetic detection
  if ContainsText(S, '+') or ContainsText(S, '-') or
     ContainsText(S, '*') or ContainsText(S, '/') then
  begin
    Result := EvalSimpleMath(S);
    Exit;
  end;

  // Step 6 — numeric fallback
  if TryStrToFloat(S, DblValue) then
  begin
    Result := DblValue;
    Exit;
  end;

  // Step 7 — string fallback
  Result := S;
end;

{$IFDEF DEBUG}
initialization
  GExprDiagSeen := nil;
  GExprDiagCount := 0;

finalization
  GExprDiagSeen.Free;
{$ENDIF}

end.
