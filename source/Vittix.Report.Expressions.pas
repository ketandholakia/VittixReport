unit Vittix.Report.Expressions;

{
  Vittix.Report.Expressions
  =========================
  TReportExpression.Evaluate resolves a string expression in the context of
  the current dataset row and page state.

  Evaluation order
  ----------------
  1. Aggregate functions  SUM(…), COUNT(…), AVG(…), MIN(…), MAX(…)
  2. System tokens        [PageNo], [TotalPages], [ReportTitle], [ReportDate]
  3. Dataset field tokens [FieldName]   → current field value as string
  4. Quoted string literal 'text'
  5. Arithmetic           +, -, *, /    on resolved tokens
  6. Numeric fallback
  7. String fallback

  System tokens (case-insensitive)
  ---------------------------------
    [PageNo]       Current page number (1-based)
    [TotalPages]   Total page count (0 while engine is running)
    [ReportTitle]  TReportModel.Title
    [ReportDate]   Date the report was generated (ShortDateStr format)
    [DateTime]     Date + time the report was generated
}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Aggregates,
  Vittix.Report.Context;

type
  TReportExpression = class
  public
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext): Variant;
  end;

implementation

// ---------------------------------------------------------------------------
// System token resolver
// ---------------------------------------------------------------------------

function ResolveSystemToken(
  const Token: string;
  const Context: TExpressionContext;
  out Value: string): Boolean;
begin
  Result := True;
  if SameText(Token, 'PageNo') then
    Value := IntToStr(Context.PageNumber)
  else if SameText(Token, 'TotalPages') then
    Value := IntToStr(Context.TotalPages)
  else if SameText(Token, 'ReportTitle') then
    Value := Context.ReportTitle
  else if SameText(Token, 'ReportDate') then
    Value := DateToStr(Context.ReportDate)
  else if SameText(Token, 'DateTime') then
    Value := DateTimeToStr(Context.ReportDate)
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
      // 2. Then dataset fields
      else if Assigned(ADataSet)
           and ADataSet.Active
           and (ADataSet.FindField(TokenName) <> nil) then
        Result := Result + ADataSet.FieldByName(TokenName).AsString
      else
        Result := Result + '0';

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
  Parts: TArray<string>;
  i: Integer;
  Acc: Double;
  Op: Char;
begin
  Parts := S.Replace('+',' + ')
            .Replace('-',' - ')
            .Replace('*',' * ')
            .Replace('/',' / ')
            .Split([' '], TStringSplitOptions.ExcludeEmpty);

  if Length(Parts) = 0 then
    Exit(0);

  Acc := StrToFloatDef(Parts[0], 0);
  i   := 1;

  while i < Length(Parts) - 1 do
  begin
    Op := Parts[i][1];

    case Op of
      '+': Acc := Acc + StrToFloatDef(Parts[i + 1], 0);
      '-': Acc := Acc - StrToFloatDef(Parts[i + 1], 0);
      '*': Acc := Acc * StrToFloatDef(Parts[i + 1], 0);
      '/':
        if StrToFloatDef(Parts[i + 1], 0) <> 0 then
          Acc := Acc / StrToFloatDef(Parts[i + 1], 1);
    end;

    Inc(i, 2);
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

end.
