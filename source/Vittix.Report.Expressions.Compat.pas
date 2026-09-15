unit Vittix.Report.Expressions.Compat;

{
  Vittix.Report.Expressions.Compat
  ================================
  Phase 4B-1: the compatibility evaluator sitting behind
  TReportExpression.Evaluate (Vittix.Report.Expressions.pas).

  This unit reproduces the characterized legacy expression language exactly.
  It is deliberately NOT a modern expression engine and must not be
  "improved" here.  See docs/Phase4A-Expression-Compatibility-Contract.md for
  the behavioral contract and docs/Phase4B-Compatibility-Evaluator.md for the
  migration record.

  Evaluation order (identical to the pre-4B-1 implementation)
  ----------------------------------------------------------
  1. Aggregate prefix early return: SUM( COUNT( AVG( MIN( MAX( are matched
     case-insensitively against the raw, untrimmed expression text and
     delegate to TReportAggregates.TryEvaluate.  A successful aggregate
     returns immediately, so "SUM([Amount]) + 1" never evaluates "+ 1".
  2. Bracket-token expansion.  Each token is resolved in this order:
     system token -> parameter (Param. / Parameter. / Parameters.) ->
     report variable -> dataset field -> text '0' fallback.
  3. A lone bracket token is a value lookup, not an expression to re-parse,
     so punctuation inside the value is preserved.
  4. Comparison, checked before string literals so that 'a' = 'a' compares.
     Operators are searched in the order <= >= <> = < > while single-quoted
     regions are ignored.  Numeric operands compare as Double; anything else
     compares as case-insensitive text.
  5. Single-quoted string literal.
  6. true / false boolean literals.
  7. Flat, left-to-right arithmetic with no operator precedence.
  8. Numeric fallback (current locale).
  9. String fallback.

  Legacy limitations preserved on purpose: no operator precedence, no working
  parentheses, no AND/OR/NOT/!=, no NULL literal or NULL propagation,
  locale-dependent numeric conversion, silent malformed-input fallback, and no
  evaluator exceptions.
}

interface

uses
  System.SysUtils,
  System.Variants,
  Vittix.Report.Context;

type
  {
    Internal compatibility evaluator used by TReportExpression.Evaluate.

    It is public only so the facade and the differential compatibility
    harness can reach it; it is not part of the public report API.
  }
  TReportCompatExpressionEvaluator = class
  public
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext): Variant;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  Data.DB,
  Vittix.Report.Aggregates,
  Vittix.Report.Utils
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
// Token resolution: system token -> parameter -> variable -> field -> '0'
// ---------------------------------------------------------------------------

{ The legacy '0' fallback for an unresolved token, including its DEBUG
  diagnostic.  The fallback is text, never a numeric zero value. }
function ZeroFallback(const SourceExpr, TokenName, Reason: string): string;
begin
{$IFDEF DEBUG}
  DebugLogUnresolvedToken(SourceExpr, TokenName, Reason);
{$ENDIF}
  Result := '0';
end;

{ First case-insensitive parameter match wins, exactly like the legacy
  TryResolveParameter (which walked Names[] and read ValueFromIndex[]). }
function TryResolveParameter(const Context: TExpressionContext;
  const AName: string; out AValue: string): Boolean;
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

{ Resolves the system-token, parameter and report-variable namespaces.  A
  False result means "none of these namespaces", and the caller then tries the
  dataset fields.  The token text is used exactly as written between the
  brackets (no trimming), which the legacy contract requires. }
function TryResolveContextToken(const Token: string;
  const Context: TExpressionContext; out Value: string): Boolean;
var
  ParamName: string;
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

    // A missing parameter resolves to empty text, not to the '0' fallback.
    if not TryResolveParameter(Context, ParamName, Value) then
      Value := '';
  end
  else if Assigned(Context.Variables) and
          (Context.Variables.IndexOfName(Token) >= 0) then
    Value := Context.Variables.Values[Token]
  else
    Result := False;  // not a context token
end;

{ Field-name form of a bracket token: dataset qualifiers such as
  [Customers.Company], [Customers."Company"] and [Customers.'Company'] all
  collapse to the unquoted field name, and the qualifier is discarded (the
  current dataset is still the one being read). }
function FieldNameFromToken(const TokenName: string): string;
var
  DotPos: Integer;
begin
  Result := Trim(TokenName);
  DotPos := Pos('.', Result);
  if DotPos <= 0 then
    Exit;

  Result := Trim(Copy(Result, DotPos + 1, MaxInt));
  if (Length(Result) >= 2) and
     (((Result[1] = '"') and (Result[Length(Result)] = '"')) or
      ((Result[1] = '''') and (Result[Length(Result)] = ''''))) then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

{ Expands one bracket token to text.  Never raises: every failure path yields
  the legacy '0' text fallback. }
function ResolveTokenText(const SourceExpr, TokenName: string;
  const Context: TExpressionContext): string;
var
  FieldName: string;
  Field: TField;
begin
  FieldName := FieldNameFromToken(TokenName);

  if TryResolveContextToken(TokenName, Context, Result) then
    Exit;

  if Trim(TokenName) = '' then
    Exit(ZeroFallback(SourceExpr, TokenName, 'unknown token / unsupported token'));

  if not Assigned(Context.DataSet) and not Assigned(Context.UserDataSet) then
    Exit(ZeroFallback(SourceExpr, TokenName, 'dataset nil'));

  if not SourceActive(Context.DataSet, Context.UserDataSet) then
    Exit(ZeroFallback(SourceExpr, TokenName, 'dataset inactive'));

  if Assigned(Context.UserDataSet) then
  begin
    try
      Exit(SafeSourceFieldAsString(Context.DataSet, Context.UserDataSet, FieldName));
    except
      Exit(ZeroFallback(SourceExpr, FieldName, 'field conversion error'));
    end;
  end;

  if TryGetField(Context.DataSet, FieldName, Field) then
  begin
    try
      Exit(Field.AsString);
    except
      Exit(ZeroFallback(SourceExpr, FieldName, 'field conversion error'));
    end;
  end;

  Result := ZeroFallback(SourceExpr, FieldName, 'field missing');
end;

{ Single deterministic left-to-right scan over the raw expression text.  Text
  outside brackets is copied verbatim; text inside a '[' .. ']' pair is
  replaced by its resolved value.  An unterminated '[' consumes the rest of
  the text, which is the legacy behavior.  A TStringBuilder keeps the scan
  linear; the concatenation order is unchanged. }
function ExpandBracketTokens(const S: string;
  const Context: TExpressionContext): string;
var
  Builder: TStringBuilder;
  Index, CloseBracket: Integer;
  TokenName: string;
begin
  Builder := TStringBuilder.Create(Length(S));
  try
    Index := 1;
    while Index <= Length(S) do
    begin
      if S[Index] <> '[' then
      begin
        Builder.Append(S[Index]);
        Inc(Index);
        Continue;
      end;

      CloseBracket := Index + 1;
      while (CloseBracket <= Length(S)) and (S[CloseBracket] <> ']') do
        Inc(CloseBracket);

      TokenName := Copy(S, Index + 1, CloseBracket - Index - 1);
      Builder.Append(ResolveTokenText(S, TokenName, Context));
      Index := CloseBracket + 1;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

{ The token-shape test is applied to the original expression text, not to the
  expanded text. }
function IsSingleTokenExpression(const Expr: string): Boolean;
var
  S: string;
begin
  S := Trim(Expr);
  Result := (Length(S) >= 3) and (S[1] = '[') and
    (S[Length(S)] = ']') and (Pos(']', S) = Length(S));
end;

// ---------------------------------------------------------------------------
// Flat arithmetic (no operator precedence; strictly left to right)
// ---------------------------------------------------------------------------

{
  Cursor-based scanner for the legacy flat numeric form.

  It is a value type, so an evaluation allocates nothing on the heap.  The
  number and operator rules are the legacy ones: an optional leading sign,
  digits with '.' and ',' accepted as number characters (locale conversion is
  resolved by TryStrToFloat with the current locale), whitespace skipped
  between tokens, and a failed number read consuming the scanned characters
  while reporting False.
}
type
  TCompatArithmeticScanner = record
  private
    FText: string;
    FIndex: Integer;
    procedure SkipSeparators;
  public
    class function Start(const AText: string): TCompatArithmeticScanner; static;
    function ReadNumber(out AValue: Double): Boolean;
    function ReadOperator(out AOp: Char): Boolean;
  end;

class function TCompatArithmeticScanner.Start(
  const AText: string): TCompatArithmeticScanner;
begin
  Result.FText := AText;
  Result.FIndex := 1;
end;

procedure TCompatArithmeticScanner.SkipSeparators;
begin
  while (FIndex <= Length(FText)) and CharInSet(FText[FIndex], [#9, #10, #13, ' ']) do
    Inc(FIndex);
end;

function TCompatArithmeticScanner.ReadNumber(out AValue: Double): Boolean;
var
  Start: Integer;
begin
  SkipSeparators;
  Start := FIndex;
  if (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['+', '-']) then
    Inc(FIndex);
  while (FIndex <= Length(FText)) and CharInSet(FText[FIndex], ['0'..'9', '.', ',']) do
    Inc(FIndex);

  Result := TryStrToFloat(Copy(FText, Start, FIndex - Start), AValue);
  if not Result then
    AValue := 0;
end;

function TCompatArithmeticScanner.ReadOperator(out AOp: Char): Boolean;
begin
  SkipSeparators;
  Result := (FIndex <= Length(FText)) and
    CharInSet(FText[FIndex], ['+', '-', '*', '/']);
  if Result then
  begin
    AOp := FText[FIndex];
    Inc(FIndex);
  end;
end;

{ Evaluates the legacy flat arithmetic form.  Every operator is applied to the
  running accumulator, division by zero leaves the accumulator unchanged, and
  an unreadable operand truncates the expression and returns the accumulator
  scanned so far. }
function EvaluateFlatArithmetic(const S: string): Double;
var
  Scanner: TCompatArithmeticScanner;
  Acc, Value: Double;
  Op: Char;
begin
  Scanner := TCompatArithmeticScanner.Start(S);
  if not Scanner.ReadNumber(Acc) then
    Exit(0);

  while Scanner.ReadOperator(Op) do
  begin
    if not Scanner.ReadNumber(Value) then
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

{ Presence test only; the legacy scan is entered whenever any arithmetic
  character occurs anywhere in the expanded text. }
function ContainsArithmeticOperator(const S: string): Boolean;
begin
  Result := ContainsText(S, '+') or ContainsText(S, '-') or
    ContainsText(S, '*') or ContainsText(S, '/');
end;

// ---------------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------------

const
  { Searched in this exact order.  "<=" is therefore found before "<" and
    ">=" before ">", and "!=" degrades to "=" with a left operand such as
    "1 !", which is the characterized legacy behavior. }
  CComparisonOperators: array[0..5] of string =
    ('<=', '>=', '<>', '=', '<', '>');

{ Returns the first operator match of the first operator type that occurs at
  all, ignoring anything inside a single-quoted region. }
function FindComparisonOperator(const S: string; out AOp: string;
  out APos: Integer): Boolean;
var
  OperatorIndex, OpLen, Index: Integer;
  InQuote: Boolean;
begin
  Result := False;
  AOp := '';
  APos := 0;

  for OperatorIndex := Low(CComparisonOperators) to High(CComparisonOperators) do
  begin
    OpLen := Length(CComparisonOperators[OperatorIndex]);
    InQuote := False;
    for Index := 1 to Length(S) do
    begin
      if S[Index] = '''' then
        InQuote := not InQuote;

      if not InQuote and (Index + OpLen - 1 <= Length(S)) and
         (Copy(S, Index, OpLen) = CComparisonOperators[OperatorIndex]) then
      begin
        AOp := CComparisonOperators[OperatorIndex];
        APos := Index;
        Exit(True);
      end;
    end;
  end;
end;

{ Numeric operands compare as Double; every other pair compares as
  case-insensitive text. }
function CompareOperands(const Op, LStr, RStr: string): Boolean;
var
  LDbl, RDbl: Double;
begin
  if TryStrToFloat(LStr, LDbl) and TryStrToFloat(RStr, RDbl) then
  begin
    if Op = '<=' then Exit(LDbl <= RDbl);
    if Op = '>=' then Exit(LDbl >= RDbl);
    if Op = '<>' then Exit(LDbl <> RDbl);
    if Op = '=' then Exit(LDbl = RDbl);
    if Op = '<' then Exit(LDbl < RDbl);
    Exit(LDbl > RDbl);
  end;

  if Op = '<=' then Exit(CompareText(LStr, RStr) <= 0);
  if Op = '>=' then Exit(CompareText(LStr, RStr) >= 0);
  if Op = '<>' then Exit(not SameText(LStr, RStr));
  if Op = '=' then Exit(SameText(LStr, RStr));
  if Op = '<' then Exit(CompareText(LStr, RStr) < 0);
  Result := CompareText(LStr, RStr) > 0;
end;

{ Comparison is attempted before the string-literal stage so that
  "'a' = 'a'" compares instead of returning a literal.  Surrounding single
  quotes are stripped from each side before conversion. }
function TryEvaluateComparison(const S: string; out AValue: Boolean): Boolean;
var
  Op: string;
  OpPos: Integer;
  LStr, RStr: string;
begin
  Result := False;
  AValue := False;

  if not FindComparisonOperator(S, Op, OpPos) then
    Exit;

  LStr := Trim(Copy(S, 1, OpPos - 1));
  RStr := Trim(Copy(S, OpPos + Length(Op), MaxInt));

  if (Length(LStr) >= 2) and (LStr[1] = '''') and (LStr[Length(LStr)] = '''') then
    LStr := Copy(LStr, 2, Length(LStr) - 2);
  if (Length(RStr) >= 2) and (RStr[1] = '''') and (RStr[Length(RStr)] = '''') then
    RStr := Copy(RStr, 2, Length(RStr) - 2);

  AValue := CompareOperands(Op, LStr, RStr);
  Result := True;
end;

function IsSingleQuotedLiteral(const S: string): Boolean;
begin
  Result := (Length(S) >= 2) and (S[1] = '''') and (S[Length(S)] = '''');
end;

// ---------------------------------------------------------------------------
// Aggregate delegation
// ---------------------------------------------------------------------------

const
  { Prefix list, matched against the raw expression text. }
  CAggregatePrefixes: array[0..4] of string =
    ('SUM(', 'COUNT(', 'AVG(', 'MIN(', 'MAX(');

{ Matches the aggregate prefix on the untrimmed text and delegates the whole
  range scan to the existing aggregate subsystem.  A False result means "not
  an aggregate we could evaluate", and the caller continues with the normal
  token path.  The aggregate cache (Phase 3) stays inside TReportAggregates. }
function TryEvaluateAggregatePrefix(const Expr: string;
  const Context: TExpressionContext; out AValue: Variant): Boolean;
var
  Index: Integer;
begin
  AValue := Null;
  Result := False;

  for Index := Low(CAggregatePrefixes) to High(CAggregatePrefixes) do
    if StartsText(CAggregatePrefixes[Index], Expr) then
    begin
      Result := True;
      Break;
    end;

  if not Result then
    Exit;

  Result := TReportAggregates.TryEvaluate(Expr, Context, AValue);
end;

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

class function TReportCompatExpressionEvaluator.Evaluate(
  const Expr: string;
  const Context: TExpressionContext): Variant;
var
  S: string;
  AggValue: Variant;
  BoolValue: Boolean;
  DblValue: Double;
begin
  Result := '';

  if Trim(Expr) = '' then Exit;

  // Stage 1 — aggregate prefix early return.
  if TryEvaluateAggregatePrefix(Expr, Context, AggValue) then
    Exit(AggValue);

  // Stage 2 — bracket token expansion, then trim.
  S := Trim(ExpandBracketTokens(Expr, Context));

  // Stage 3 — a lone bracket token is a value lookup, not an expression to
  // re-parse from the returned text.  This preserves punctuation in values
  // such as invoice headings and bank references.
  if IsSingleTokenExpression(Expr) then
  begin
    if TryStrToFloat(S, DblValue) then
      Result := DblValue
    else
      Result := S;
    Exit;
  end;

  // Stage 4 — comparison (checked before the quoted-string literal so that
  // expressions such as 'hello' = 'hello' are evaluated as comparisons).
  if TryEvaluateComparison(S, BoolValue) then
  begin
    Result := BoolValue;
    Exit;
  end;

  // Stage 5 — single-quoted string literal.
  if IsSingleQuotedLiteral(S) then
  begin
    Result := Copy(S, 2, Length(S) - 2);
    Exit;
  end;

  // Stage 6 — boolean literals.
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

  // Stage 7 — flat arithmetic.
  if ContainsArithmeticOperator(S) then
  begin
    Result := EvaluateFlatArithmetic(S);
    Exit;
  end;

  // Stage 8 — numeric fallback.
  if TryStrToFloat(S, DblValue) then
  begin
    Result := DblValue;
    Exit;
  end;

  // Stage 9 — string fallback.
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
