unit Vittix.Report.Expression.Evaluator;

{
  Vittix.Report.Expression.Evaluator
  ==================================
  Modern expression language: recursive-descent parser, pure evaluator,
  and the TModernExpressionEngine facade.

  Phase 4B-2B. This engine is COMPLETELY SEPARATE from the legacy
  compatibility evaluator (Vittix.Report.Expressions.Compat):
    - Legacy reports keep using TReportCompatExpressionEvaluator.
    - Modern semantics are EXPLICIT OPT-IN via
      TReportExpression.Evaluate(Expression, Context, emModern).

  Semantics implemented per the approved Phase 4B-2A design:
    OD-1  Empty/all-null aggregates: SUM/AVG/MIN/MAX -> NULL, COUNT -> 0.
    OD-2  NULL arithmetic propagates NULL.
    OD-3  COUNT skips NULL values.
    OD-5  Three-valued logic: TRUE / FALSE / UNKNOWN. A comparison with a
          NULL operand yields UNKNOWN (represented as the NULL value).
          At a render boundary the consumer maps UNKNOWN -> FALSE through
          the existing ConditionVariantToBool semantics.
    OD-15 Aggregate cache identity is mode-prefixed so legacy and modern
          aggregates never collide in the Phase 3 execution-local cache.
    OD-16 Cache identity includes parameters/variables/page/row/group
          state, so any mutation changes the identity and stale entries
          become unreachable (execution-local, no global state).

  Security model: pure expression evaluation only. No I/O, no dynamic
  code execution, no RTTI invocation, no filesystem/network access.
}

interface

uses
  System.SysUtils,
  System.Math,
  System.StrUtils,
  System.Variants,
  Data.DB,
  Vittix.Report.Context,
  Vittix.Report.Expression.Language,
  Vittix.Report.Expression.Diagnostics;

type
  { Structured evaluator error. Semantic/parse failures surface as this
    exception, never as raw internal exceptions. }
  EVittixExpressionError = class(Exception)
  private
    FCode: TExpressionDiagnosticCode;
    FPosition: Integer;
  public
    constructor Create(const ACode: TExpressionDiagnosticCode;
      const APosition: Integer; const AMessage: string);
    property Code: TExpressionDiagnosticCode read FCode;
    property Position: Integer read FPosition;
  end;

  { Parser + evaluator entry points. }
  TModernExpressionEngine = class
  public
    { Parse-only validation. Returns True when the expression parses
      within the safety limits and only references known functions. }
    class function Validate(const AExpression: string): Boolean; overload;
    class function Validate(const AExpression: string;
      out AErrorMessages: TArray<string>): Boolean; overload;

    { Parse + evaluate. AContext supplies the data capabilities. }
    class function Evaluate(const AExpression: string;
      const AContext: TExpressionContext): Variant;
  end;

implementation

uses
  System.Generics.Collections,
  Vittix.Report.Expression.Tokenizer;

const
  { Mode marker for the Phase 3 aggregate cache. Legacy entries use the
    raw expression text; modern entries are prefixed so the two modes can
    never collide (OD-15). }
  CModernCacheKeyPrefix = #1'MODERN'#1;

{ EVittixExpressionError }

constructor EVittixExpressionError.Create(const ACode: TExpressionDiagnosticCode;
  const APosition: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FCode := ACode;
  FPosition := APosition;
end;

type
  TModernExpressionParser = class
  private
    FTokens: TArray<TExpressionToken>;
    FIndex: Integer;
    FDiagnostics: TExpressionDiagnostics;
    FLimits: TExpressionLimits;
    FDepth: Integer;
    FNodeCount: Integer;
    FInAggregate: Integer; // nesting guard > 0 while inside an aggregate
    { Frees already-built subtree roots that a failing parse step would
      otherwise abandon (memory-safety: the AST is owned exclusively by
      the caller of Parse only when Parse succeeds). }
    procedure FreeOrphans(const ANodes: array of TExpressionNode);
    function Current: TExpressionToken;
    function Next: TExpressionToken;
    function ExpectKind(const AKind: TExpressionTokenKind; const AMsg: string): Boolean;
    procedure Error(const ACode: TExpressionDiagnosticCode; const AToken: TExpressionToken; const AMsg: string);
    function ParseExpression: TExpressionNode;      // OR level
    function ParseAnd: TExpressionNode;
    function ParseNot: TExpressionNode;
    function ParseComparison: TExpressionNode;
    function ParseAdditive: TExpressionNode;
    function ParseMultiplicative: TExpressionNode;
    function ParseUnary: TExpressionNode;
    function ParsePrimary: TExpressionNode;
    function ParseCall(const AToken: TExpressionToken): TExpressionNode;
    function ParseArgs(out AArgs: TArray<TExpressionNode>): Boolean;
    class function LookupFunction(const AName: string; out AFunc: TExpressionFunction): Boolean; static;
    class function IsAggregateFunc(const AFunc: TExpressionFunction): Boolean; static;
    function AllocNode: Boolean;
  public
    function Parse(const AText: string; ALimits: TExpressionLimits;
      ADiagnostics: TExpressionDiagnostics; out ATree: TExpressionNode): Boolean;
  end;

procedure TModernExpressionParser.FreeOrphans(const ANodes: array of TExpressionNode);
var
  I: Integer;
begin
  for I := 0 to High(ANodes) do
    ANodes[I].Free;
end;

{ TModernExpressionParser }

function TModernExpressionParser.Current: TExpressionToken;
begin
  if FIndex <= High(FTokens) then
    Result := FTokens[FIndex]
  else
    Result := TExpressionToken.Create(tkEOF, '', Length(FTokens), 0, Null);
end;

function TModernExpressionParser.Next: TExpressionToken;
begin
  Result := Current;
  if FIndex <= High(FTokens) then
    Inc(FIndex);
end;

procedure TModernExpressionParser.Error(const ACode: TExpressionDiagnosticCode;
  const AToken: TExpressionToken; const AMsg: string);
begin
  FDiagnostics.AddError(ACode, AToken.Position, AToken.Length, AMsg);
end;

function TModernExpressionParser.ExpectKind(const AKind: TExpressionTokenKind;
  const AMsg: string): Boolean;
begin
  Result := Current.Kind = AKind;
  if not Result then
    Error(UnexpectedToken, Current, AMsg + ' but found "' + Current.Text + '"')
  else
    Next;
end;

function TModernExpressionParser.AllocNode: Boolean;
begin
  Inc(FNodeCount);
  Result := FNodeCount <= FLimits.MaxAstNodes;
  if not Result then
    Error(TooManyNodes, Current,
      Format('Expression exceeds maximum of %d AST nodes', [FLimits.MaxAstNodes]));
end;

class function TModernExpressionParser.IsAggregateFunc(const AFunc: TExpressionFunction): Boolean;
begin
  Result := AFunc in [fnSum, fnCount, fnAvg, fnMin, fnMax];
end;

class function TModernExpressionParser.LookupFunction(const AName: string; out AFunc: TExpressionFunction): Boolean;
var
  Upper: string;
begin
  Upper := System.SysUtils.UpperCase(AName);
  Result := True;
  if Upper = 'IF' then AFunc := fnIf
  else if Upper = 'COALESCE' then AFunc := fnCoalesce
  else if Upper = 'ABS' then AFunc := fnAbs
  else if Upper = 'ROUND' then AFunc := fnRound
  else if Upper = 'LEAST' then AFunc := fnLeast
  else if Upper = 'GREATEST' then AFunc := fnGreatest
  else if Upper = 'UPPER' then AFunc := fnUpper
  else if Upper = 'LOWER' then AFunc := fnLower
  else if Upper = 'TRIM' then AFunc := fnTrim
  else if Upper = 'LEN' then AFunc := fnLen
  else if Upper = 'SUBSTR' then AFunc := fnSubstr
  else if Upper = 'CONTAINS' then AFunc := fnContains
  else if Upper = 'STARTSWITH' then AFunc := fnStartsWith
  else if Upper = 'ENDSWITH' then AFunc := fnEndsWith
  else if Upper = 'SUM' then AFunc := fnSum
  else if Upper = 'COUNT' then AFunc := fnCount
  else if Upper = 'AVG' then AFunc := fnAvg
  else if Upper = 'MIN' then AFunc := fnMin
  else if Upper = 'MAX' then AFunc := fnMax
  else if Upper = 'YEAR' then AFunc := fnYear
  else if Upper = 'MONTH' then AFunc := fnMonth
  else if Upper = 'DAY' then AFunc := fnDay
  else
    Result := False;
end;

function TModernExpressionParser.Parse(const AText: string; ALimits: TExpressionLimits;
  ADiagnostics: TExpressionDiagnostics; out ATree: TExpressionNode): Boolean;
var
  Tokenizer: TExpressionTokenizer;
begin
  ATree := nil;
  FDiagnostics := ADiagnostics;
  FLimits := ALimits;
  FIndex := 0;
  FDepth := 0;
  FNodeCount := 0;
  FInAggregate := 0;

  if Length(AText) > FLimits.MaxExpressionLength then
  begin
    ADiagnostics.AddError(ExpressionTooLong, 1, Length(AText),
      Format('Expression length %d exceeds maximum %d', [Length(AText), FLimits.MaxExpressionLength]));
    Exit(False);
  end;

  Tokenizer := TExpressionTokenizer.Create(FLimits);
  try
    FTokens := Tokenizer.Tokenize(AText, ADiagnostics);
  finally
    Tokenizer.Free;
  end;

  if ADiagnostics.HasErrors then
    Exit(False);

  Inc(FDepth);
  try
    ATree := ParseExpression;
  finally
    Dec(FDepth);
  end;

  if not ADiagnostics.HasErrors then
    if Current.Kind <> tkEOF then
      Error(UnexpectedToken, Current,
        Format('Unexpected token "%s" after end of expression', [Current.Text]));

  if ADiagnostics.HasErrors then
  begin
    FreeAndNil(ATree);
    Exit(False);
  end;
  Result := ATree <> nil;
end;

function TModernExpressionParser.ParseExpression: TExpressionNode;
var
  Left, Right: TExpressionNode;
  StartToken: TExpressionToken;
begin
  Inc(FDepth);
  try
    if FDepth > FLimits.MaxParserDepth then
    begin
      Error(ExpressionTooDeep, Current,
        Format('Expression nesting exceeds maximum depth %d', [FLimits.MaxParserDepth]));
      Exit(nil);
    end;
    Result := ParseAnd;
    while (Current.Kind = tkOr) and not FDiagnostics.HasErrors do
    begin
      StartToken := Next;
      Left := Result;
      Right := ParseAnd;
      if not AllocNode then
      begin
        FreeOrphans([Left, Right]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewBinary(boOr, Left, Right, StartToken.Position, StartToken.Length);
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseAnd: TExpressionNode;
var
  Left, Right: TExpressionNode;
  StartToken: TExpressionToken;
begin
  Inc(FDepth);
  try
    Result := ParseNot;
    while (Current.Kind = tkAnd) and not FDiagnostics.HasErrors do
    begin
      StartToken := Next;
      Left := Result;
      Right := ParseNot;
      if not AllocNode then
      begin
        FreeOrphans([Left, Right]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewBinary(boAnd, Left, Right, StartToken.Position, StartToken.Length);
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseNot: TExpressionNode;
var
  StartToken: TExpressionToken;
  Operand: TExpressionNode;
begin
  Inc(FDepth);
  try
    if Current.Kind = tkNot then
    begin
      StartToken := Next;
      Operand := ParseNot;
      if not AllocNode then
      begin
        FreeOrphans([Operand]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewUnary(uoNot, Operand, StartToken.Position, StartToken.Length);
      Exit;
    end;
    Result := ParseComparison;
    // IS NULL / IS NOT NULL postfix (Section 15)
    if not FDiagnostics.HasErrors and (Current.Kind = tkIs) then
    begin
      Next; // consume IS
      if Current.Kind = tkNot then
      begin
        Next;
        if not ExpectKind(tkNull, 'Expected NULL after IS NOT') then
        begin
          Result.Free;
          Exit(nil);
        end;
        if not AllocNode then
        begin
          Result.Free;
          Exit(nil);
        end;
        Result := TExpressionNode.NewIsNull(inoIsNotNull, Result, Current.Position, Current.Length);
      end
      else
      begin
        if not ExpectKind(tkNull, 'Expected NULL after IS') then
        begin
          Result.Free;
          Exit(nil);
        end;
        if not AllocNode then
        begin
          Result.Free;
          Exit(nil);
        end;
        Result := TExpressionNode.NewIsNull(inoIsNull, Result, Current.Position, Current.Length);
      end;
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseComparison: TExpressionNode;
var
  Left, Right: TExpressionNode;
  Op: TExpressionBinaryOp;
  StartToken: TExpressionToken;
begin
  Inc(FDepth);
  try
    Result := ParseAdditive;
    if FDiagnostics.HasErrors then Exit;

    Op := boEqual;
    case Current.Kind of
      tkEqual:        Op := boEqual;
      tkNotEqual:     Op := boNotEqual;
      tkLessThan:     Op := boLess;
      tkGreaterThan:  Op := boGreater;
      tkLessEqual:    Op := boLessEqual;
      tkGreaterEqual: Op := boGreaterEqual;
    else
      Exit; // no comparison operator present
    end;
    StartToken := Next;
    Left := Result;
    Right := ParseAdditive;
    if FDiagnostics.HasErrors then
    begin
      FreeOrphans([Left, Right]);
      Exit(nil);
    end;
    if not AllocNode then
    begin
      FreeOrphans([Left, Right]);
      Exit(nil);
    end;
    Result := TExpressionNode.NewBinary(Op, Left, Right, StartToken.Position, StartToken.Length);

    // Comparisons are non-associative (Section 13).
    if Current.Kind in [tkEqual, tkNotEqual, tkLessThan, tkGreaterThan,
                        tkLessEqual, tkGreaterEqual] then
    begin
      Error(NonAssociativeComparison, Current,
        'Comparisons are non-associative; use AND to combine comparisons');
      Result := nil;
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseAdditive: TExpressionNode;
var
  Left, Right: TExpressionNode;
  Op: TExpressionBinaryOp;
  StartToken: TExpressionToken;
begin
  Inc(FDepth);
  try
    Result := ParseMultiplicative;
    while not FDiagnostics.HasErrors and (Current.Kind in [tkPlus, tkMinus]) do
    begin
      StartToken := Next;
      if StartToken.Kind = tkPlus then Op := boAdd else Op := boSubtract;
      Left := Result;
      Right := ParseMultiplicative;
      if not AllocNode then
      begin
        FreeOrphans([Left, Right]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewBinary(Op, Left, Right, StartToken.Position, StartToken.Length);
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseMultiplicative: TExpressionNode;
var
  Left, Right: TExpressionNode;
  Op: TExpressionBinaryOp;
  StartToken: TExpressionToken;
begin
  Inc(FDepth);
  try
    Result := ParseUnary;
    while not FDiagnostics.HasErrors and (Current.Kind in [tkMultiply, tkDivide]) do
    begin
      StartToken := Next;
      if StartToken.Kind = tkMultiply then Op := boMultiply else Op := boDivide;
      Left := Result;
      Right := ParseUnary;
      if not AllocNode then
      begin
        FreeOrphans([Left, Right]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewBinary(Op, Left, Right, StartToken.Position, StartToken.Length);
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseUnary: TExpressionNode;
var
  StartToken: TExpressionToken;
  Operand: TExpressionNode;
begin
  Inc(FDepth);
  try
    if Current.Kind = tkMinus then
    begin
      StartToken := Next;
      Operand := ParseUnary;
      if not AllocNode then
      begin
        FreeOrphans([Operand]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewUnary(uoMinus, Operand, StartToken.Position, StartToken.Length);
      Exit;
    end;
    if Current.Kind = tkPlus then
    begin
      StartToken := Next;
      Operand := ParseUnary;
      if not AllocNode then
      begin
        FreeOrphans([Operand]);
        Exit(nil);
      end;
      Result := TExpressionNode.NewUnary(uoPlus, Operand, StartToken.Position, StartToken.Length);
      Exit;
    end;
    Result := ParsePrimary;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionParser.ParseArgs(out AArgs: TArray<TExpressionNode>): Boolean;
var
  Args: TList<TExpressionNode>;
begin
  Result := False;
  AArgs := nil;
  Args := TList<TExpressionNode>.Create;
  try
    if not ExpectKind(tkLeftParen, 'Expected "("') then Exit;
    if Current.Kind = tkRightParen then
    begin
      Next;
      Exit(True);
    end;
    while True do
    begin
      if Args.Count >= FLimits.MaxFunctionArgs then
      begin
        Error(LimitExceeded, Current,
          Format('Function exceeds maximum of %d arguments', [FLimits.MaxFunctionArgs]));
        FreeOrphans(Args.ToArray);
        Exit;
      end;
      Args.Add(ParseExpression);
      if FDiagnostics.HasErrors then
      begin
        FreeOrphans(Args.ToArray);
        Exit;
      end;
      if Current.Kind = tkComma then
      begin
        Next;
        Continue;
      end;
      if not ExpectKind(tkRightParen, 'Expected "," or ")"') then
      begin
        FreeOrphans(Args.ToArray);
        Exit;
      end;
      Break;
    end;
    AArgs := Args.ToArray;
    Result := True;
  finally
    Args.Free;
  end;
end;

function TModernExpressionParser.ParseCall(const AToken: TExpressionToken): TExpressionNode;
var
  Func: TExpressionFunction;
  Args: TArray<TExpressionNode>;
  ArgErr: string;
begin
  Result := nil;
  if not LookupFunction(AToken.Text, Func) then
  begin
    Error(UnknownFunction, AToken, Format('Unknown function "%s"', [AToken.Text]));
    Exit;
  end;

  if IsAggregateFunc(Func) then
  begin
    if FInAggregate > 0 then
    begin
      Error(NestedAggregate, AToken, 'Nested aggregates are not allowed');
      Exit;
    end;
    Inc(FInAggregate);
    try
      if not ParseArgs(Args) then Exit;
      if Length(Args) <> 1 then
      begin
        Error(InvalidArgumentCount, AToken,
          Format('%s expects exactly 1 argument, got %d', [AToken.Text, Length(Args)]));
        FreeOrphans(Args);
        Exit;
      end;
      if not AllocNode then
      begin
        FreeOrphans(Args);
        Exit;
      end;
      Result := TExpressionNode.NewAggregate(Func, Args[0], AToken.Position, AToken.Length);
    finally
      Dec(FInAggregate);
    end;
    Exit;
  end;

  if not ParseArgs(Args) then Exit;

  // Arity checks for the closed catalogue
  ArgErr := '';
  case Func of
    fnIf:
      if Length(Args) <> 3 then
        ArgErr := Format('IF expects 3 arguments, got %d', [Length(Args)]);
    fnCoalesce:
      if Length(Args) < 1 then
        ArgErr := 'COALESCE expects at least 1 argument';
    fnAbs, fnUpper, fnLower, fnTrim, fnLen, fnYear, fnMonth, fnDay:
      if Length(Args) <> 1 then
        ArgErr := Format('%s expects 1 argument, got %d', [AToken.Text, Length(Args)]);
    fnRound:
      if (Length(Args) < 1) or (Length(Args) > 2) then
        ArgErr := Format('ROUND expects 1 or 2 arguments, got %d', [Length(Args)]);
    fnSubstr:
      if Length(Args) <> 3 then
        ArgErr := Format('SUBSTR expects 3 arguments, got %d', [Length(Args)]);
    fnContains, fnStartsWith, fnEndsWith:
      if Length(Args) <> 2 then
        ArgErr := Format('%s expects 2 arguments, got %d', [AToken.Text, Length(Args)]);
    fnLeast, fnGreatest:
      if Length(Args) < 1 then
        ArgErr := Format('%s expects at least 1 argument', [AToken.Text]);
  end;
  if ArgErr <> '' then
  begin
    Error(InvalidArgumentCount, AToken, ArgErr);
    FreeOrphans(Args);
    Exit;
  end;

  if not AllocNode then
  begin
    FreeOrphans(Args);
    Exit;
  end;

  if Func = fnIf then
    Result := TExpressionNode.NewConditional(False, Args, AToken.Position, AToken.Length)
  else if Func = fnCoalesce then
    Result := TExpressionNode.NewConditional(True, Args, AToken.Position, AToken.Length)
  else
    Result := TExpressionNode.NewCall(Func, Args, AToken.Position, AToken.Length);
end;

function TModernExpressionParser.ParsePrimary: TExpressionNode;
var
  Token: TExpressionToken;
  Inner: TExpressionNode;
  Content, Qual, NamePart: string;
  DotPos: Integer;
begin
  Inc(FDepth);
  try
    if FDepth > FLimits.MaxParserDepth then
    begin
      Error(ExpressionTooDeep, Current,
        Format('Expression nesting exceeds maximum depth %d', [FLimits.MaxParserDepth]));
      Exit(nil);
    end;

    Token := Current;
    case Token.Kind of
      tkNumber:
        begin
          Next;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewLiteral(TExpressionValue.MakeNumber(Token.Value), Token.Position, Token.Length);
        end;
      tkString:
        begin
          Next;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewLiteral(TExpressionValue.MakeString(Token.Text), Token.Position, Token.Length);
        end;
      tkTrue:
        begin
          Next;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewLiteral(TExpressionValue.MakeBoolean(True), Token.Position, Token.Length);
        end;
      tkFalse:
        begin
          Next;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewLiteral(TExpressionValue.MakeBoolean(False), Token.Position, Token.Length);
        end;
      tkNull:
        begin
          Next;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewLiteral(TExpressionValue.MakeNull, Token.Position, Token.Length);
        end;
      tkLeftParen:
        begin
          Next;
          Inner := ParseExpression;
          if FDiagnostics.HasErrors then
          begin
            Inner.Free;
            Exit(nil);
          end;
          if not ExpectKind(tkRightParen, 'Expected ")"') then
          begin
            Inner.Free;
            Exit(nil);
          end;
          if not AllocNode then
          begin
            Inner.Free;
            Exit(nil);
          end;
          Result := TExpressionNode.NewParen(Inner, Token.Position, Token.Length);
        end;
      tkIdentifier:
        begin
          // Function call (identifier followed by '(')
          if (FIndex + 1 <= High(FTokens)) and (FTokens[FIndex + 1].Kind = tkLeftParen) then
          begin
            Next; // consume the identifier; ParseCall consumes the '('
            Result := ParseCall(Token);
            Exit;
          end;
          // Bare identifier: NOT a field reference (Section 11)
          Error(SyntaxError, Token,
            Format('Bare identifier "%s" is not a data reference; use [%s]', [Token.Text, Token.Text]));
          Exit(nil);
        end;
      tkBracketToken:
        begin
          Next;
          Content := Token.Text;
          DotPos := Pos('.', Content);
          if DotPos > 0 then
          begin
            Qual := System.SysUtils.Trim(Copy(Content, 1, DotPos - 1));
            NamePart := System.SysUtils.Trim(Copy(Content, DotPos + 1, MaxInt));
          end
          else
          begin
            Qual := '';
            NamePart := System.SysUtils.Trim(Content);
          end;
          // Strip quote decorations from parts
          NamePart := StringReplace(NamePart, '"', '', [rfReplaceAll]);
          NamePart := StringReplace(NamePart, '''', '', [rfReplaceAll]);
          Qual := StringReplace(Qual, '"', '', [rfReplaceAll]);
          Qual := StringReplace(Qual, '''', '', [rfReplaceAll]);
          if (NamePart = '') and (Qual = '') then
          begin
            Error(UnknownField, Token, 'Empty data reference "[]"');
            Exit(nil);
          end;
          if not AllocNode then Exit(nil);
          Result := TExpressionNode.NewTokenRef(Content, Qual, NamePart, DotPos > 0, Token.Position, Token.Length);
        end;
      tkIs:
        begin
          // IS NULL / IS NOT NULL is consumed at comparison level after an
          // operand; a leading IS is a syntax error.
          Error(UnexpectedToken, Token, 'Unexpected IS');
          Exit(nil);
        end;
      tkEOF:
        begin
          Error(UnexpectedEndOfExpression, Token, 'Unexpected end of expression');
          Exit(nil);
        end;
    else
      Error(UnexpectedToken, Token, Format('Unexpected token "%s"', [Token.Text]));
      Exit(nil);
    end;
  finally
    Dec(FDepth);
  end;
end;

type
  TModernExpressionEvaluator = class
  private
    FContext: TExpressionContext;
    FLimits: TExpressionLimits;
    FExpressionText: string;
    FDepth: Integer;
    FFailed: Boolean;
    FFirstError: string;
    FFirstErrorPos: Integer;
    FFirstErrorCode: TExpressionDiagnosticCode;
    function Fail(const ACode: TExpressionDiagnosticCode; APosition: Integer;
      const AMsg: string): TExpressionValue;
    function EvalNode(ANode: TExpressionNode): TExpressionValue;
    function ResolveToken(ANode: TExpressionNode): TExpressionValue;
    function SystemTokenValue(const AName: string; out AFound: Boolean): TExpressionValue;
    function ToNumber(const V: TExpressionValue; out N: Double): Boolean;
    function DisplayValue(const V: TExpressionValue): TExpressionValue;
    function CompareValues(const AOp: TExpressionBinaryOp;
      const L, R: TExpressionValue): TExpressionValue;
    function Arithmetic(const AOp: TExpressionBinaryOp;
      const L, R: TExpressionValue): TExpressionValue;
    function EvalAggregate(ANode: TExpressionNode): TExpressionValue;
    function EvalCall(ANode: TExpressionNode): TExpressionValue;
    function EvalCall2(ANode: TExpressionNode; Func: TExpressionFunction;
      const Args: TArray<TExpressionNode>): TExpressionValue;
    function EvalConditional(ANode: TExpressionNode): TExpressionValue;
    function EvalBinary(ANode: TExpressionNode): TExpressionValue;
  public
    constructor Create(const AContext: TExpressionContext;
      const ALimits: TExpressionLimits; const AExpressionText: string);
    function Evaluate(ARoot: TExpressionNode): TExpressionValue;
    property Failed: Boolean read FFailed;
    property FirstError: string read FFirstError;
    property FirstErrorPos: Integer read FFirstErrorPos;
    property FirstErrorCode: TExpressionDiagnosticCode read FFirstErrorCode;
  end;

{ TModernExpressionEvaluator }

constructor TModernExpressionEvaluator.Create(const AContext: TExpressionContext;
  const ALimits: TExpressionLimits; const AExpressionText: string);
begin
  inherited Create;
  FContext := AContext;
  FLimits := ALimits;
  FExpressionText := AExpressionText;
  FDepth := 0;
  FFailed := False;
  FFirstError := '';
  FFirstErrorPos := 0;
  FFirstErrorCode := EvaluationError;
end;

function TModernExpressionEvaluator.Fail(const ACode: TExpressionDiagnosticCode;
  APosition: Integer; const AMsg: string): TExpressionValue;
begin
  if not FFailed then
  begin
    FFailed := True;
    FFirstError := AMsg;
    FFirstErrorPos := APosition;
    FFirstErrorCode := ACode;
  end;
  Result := TExpressionValue.MakeNull;
end;

function TModernExpressionEvaluator.ToNumber(const V: TExpressionValue; out N: Double): Boolean;
var
  FS: TFormatSettings;
begin
  case V.Kind of
    vkNumber:
      begin
        N := V.AsNumber;
        Exit(True);
      end;
    vkString:
      begin
        // Invariant numeric promotion - no regional dependence (Section 10)
        FS := TFormatSettings.Create;
        FS.DecimalSeparator := '.';
        FS.ThousandSeparator := #0;
        Result := TryStrToFloat(V.AsString, N, FS);
        if not Result then
        begin
          FS := TFormatSettings.Create;
          Result := TryStrToFloat(V.AsString, N, FS);
        end;
      end;
    vkDateTime:
      begin
        N := V.AsDateTime;
        Exit(True);
      end;
  else
    Result := False;
  end;
end;

function TModernExpressionEvaluator.DisplayValue(const V: TExpressionValue): TExpressionValue;
var
  FS: TFormatSettings;
begin
  case V.Kind of
    vkNumber:
      begin
        FS := TFormatSettings.Create;
        FS.DecimalSeparator := '.';
        Result := TExpressionValue.MakeString(FloatToStr(V.AsNumber, FS));
      end;
    vkBoolean:
      if V.AsBoolean then
        Result := TExpressionValue.MakeString('true')
      else
        Result := TExpressionValue.MakeString('false');
    vkDateTime:
      Result := TExpressionValue.MakeString(DateTimeToStr(V.AsDateTime));
  else
    Result := V;
  end;
end;

function TModernExpressionEvaluator.SystemTokenValue(const AName: string;
  out AFound: Boolean): TExpressionValue;
var
  U: string;
begin
  AFound := True;
  U := System.SysUtils.UpperCase(AName);
  if (U = 'PAGENO') or (U = 'PAGE') or (U = 'PAGE#') then
    Result := TExpressionValue.MakeNumber(FContext.PageNumber)
  else if (U = 'TOTALPAGES') or (U = 'TOTALPAGES#') then
    Result := TExpressionValue.MakeNumber(FContext.TotalPages)
  else if (U = 'ROWNUMBER') or (U = 'RECNO') or (U = 'LINE') or (U = 'LINE#') then
    Result := TExpressionValue.MakeNumber(FContext.RowNumber)
  else if U = 'REPORTTITLE' then
    Result := TExpressionValue.MakeString(FContext.ReportTitle)
  else if (U = 'REPORTDATE') or (U = 'DATE') or (U = 'TIME') or (U = 'DATETIME') then
    Result := TExpressionValue.MakeDateTime(FContext.ReportDate)
  else
  begin
    AFound := False;
    Result := TExpressionValue.MakeNull;
  end;
end;

function TModernExpressionEvaluator.ResolveToken(ANode: TExpressionNode): TExpressionValue;
var
  QualU: string;
  Field: TField;
  DS: TDataSet;
  Found: Boolean;
  Idx: Integer;
begin
  if not ANode.HasQualifier then
  begin
    // Unqualified: system tokens first, then current dataset field.
    // Modern mode: missing field resolves to NULL (Section 15).
    Result := SystemTokenValue(ANode.FieldName, Found);
    if Found then Exit;
    if Assigned(FContext.DataSet) and FContext.DataSet.Active then
    begin
      Field := FContext.DataSet.FindField(ANode.FieldName);
      if Assigned(Field) then
      begin
        Result := Field.Value;
        Exit;
      end;
    end;
    Result := TExpressionValue.MakeNull;
    Exit;
  end;

  QualU := System.SysUtils.UpperCase(ANode.Qualifier);

  if (QualU = 'PARAM') or (QualU = 'PARAMS') or (QualU = 'PARAMETER') or
     (QualU = 'PARAMETERS') then
  begin
    if Assigned(FContext.Parameters) then
    begin
      Idx := FContext.Parameters.IndexOfName(ANode.FieldName);
      if Idx >= 0 then
        Exit(TExpressionValue.MakeString(FContext.Parameters.Values[ANode.FieldName]));
    end;
    Exit(Fail(UnknownParameter, ANode.Position,
      Format('Unknown parameter "%s"', [ANode.FieldName])));
  end;

  if (QualU = 'VAR') or (QualU = 'VARS') or (QualU = 'VARIABLE') or
     (QualU = 'VARIABLES') then
  begin
    if Assigned(FContext.Variables) then
    begin
      Idx := FContext.Variables.IndexOfName(ANode.FieldName);
      if Idx >= 0 then
        Exit(TExpressionValue.MakeString(FContext.Variables.Values[ANode.FieldName]));
    end;
    Exit(Fail(UnknownVariable, ANode.Position,
      Format('Unknown variable "%s"', [ANode.FieldName])));
  end;

  if QualU = 'SYSTEM' then
  begin
    Result := SystemTokenValue(ANode.FieldName, Found);
    if Found then Exit;
    Exit(Fail(UnknownField, ANode.Position,
      Format('Unknown system value "%s"', [ANode.FieldName])));
  end;

  // Dataset qualifier: only registered datasets may be referenced (Section 12).
  if not Assigned(FContext.Hooks) then
    Exit(Fail(UnknownDataSet, ANode.Position,
      Format('Unknown dataset "%s"', [ANode.Qualifier])));
  DS := FContext.Hooks.GetNamedDataSet(ANode.Qualifier);
  if not Assigned(DS) then
    Exit(Fail(UnknownDataSet, ANode.Position,
      Format('Unknown dataset "%s"', [ANode.Qualifier])));
  if not DS.Active then
    Exit(Fail(UnsupportedDataSet, ANode.Position,
      Format('Dataset "%s" is not active', [ANode.Qualifier])));
  Field := DS.FindField(ANode.FieldName);
  if not Assigned(Field) then
    Exit(Fail(UnknownField, ANode.Position,
      Format('Unknown field "%s" in dataset "%s"', [ANode.FieldName, ANode.Qualifier])));
  Result := Field.Value;
end;

function TModernExpressionEvaluator.CompareValues(const AOp: TExpressionBinaryOp;
  const L, R: TExpressionValue): TExpressionValue;
var
  LN, RN: Double;
  LNum, RNum: Boolean;
  Cmp: Integer;
begin
  // NULL comparisons follow three-valued semantics (Section 16).
  if L.IsNull or R.IsNull then
    Exit(TExpressionValue.MakeNull); // UNKNOWN

  LNum := (L.Kind = vkNumber) or (L.Kind = vkDateTime);
  RNum := (R.Kind = vkNumber) or (R.Kind = vkDateTime);

  if LNum and RNum then
  begin
    LN := L.AsNumber;
    if L.Kind = vkDateTime then LN := L.AsDateTime;
    RN := R.AsNumber;
    if R.Kind = vkDateTime then RN := R.AsDateTime;
    if LN < RN then Cmp := -1
    else if LN > RN then Cmp := 1
    else Cmp := 0;
  end
  else if LNum or RNum then
  begin
    // Mixed numeric/string: promote the string side to a number.
    if LNum then
    begin
      if not ToNumber(R, RN) then
        Exit(Fail(InvalidComparison, 0,
          Format('Cannot compare number with text "%s"', [R.AsString])));
      LN := L.AsNumber;
    end
    else
    begin
      if not ToNumber(L, LN) then
        Exit(Fail(InvalidComparison, 0,
          Format('Cannot compare number with text "%s"', [L.AsString])));
      RN := R.AsNumber;
    end;
    if LN < RN then Cmp := -1
    else if LN > RN then Cmp := 1
    else Cmp := 0;
  end
  else if (L.Kind = vkBoolean) and (R.Kind = vkBoolean) then
  begin
    // Only equality/inequality are defined for booleans.
    if AOp in [boLess, boGreater, boLessEqual, boGreaterEqual] then
      Exit(Fail(InvalidComparison, 0, 'Boolean values cannot be ordered'));
    if L.AsBoolean = R.AsBoolean then Cmp := 0 else Cmp := 1;
  end
  else
  begin
    // Text comparisons are case-insensitive (Section 16).
    if L.Kind = vkDateTime then
      Cmp := CompareStr(DateTimeToStr(L.AsDateTime), DateTimeToStr(R.AsDateTime))
    else
      Cmp := CompareText(L.AsString, R.AsString);
  end;

  case AOp of
    boEqual:        Result := TExpressionValue.MakeBoolean(Cmp = 0);
    boNotEqual:     Result := TExpressionValue.MakeBoolean(Cmp <> 0);
    boLess:         Result := TExpressionValue.MakeBoolean(Cmp < 0);
    boGreater:      Result := TExpressionValue.MakeBoolean(Cmp > 0);
    boLessEqual:    Result := TExpressionValue.MakeBoolean(Cmp <= 0);
    boGreaterEqual: Result := TExpressionValue.MakeBoolean(Cmp >= 0);
  else
    Result := Fail(InvalidComparison, 0, 'Invalid comparison operator');
  end;
end;

function TModernExpressionEvaluator.Arithmetic(const AOp: TExpressionBinaryOp;
  const L, R: TExpressionValue): TExpressionValue;
var
  LN, RN, Res: Double;
begin
  // NULL arithmetic propagates NULL (OD-2).
  if L.IsNull or R.IsNull then
    Exit(TExpressionValue.MakeNull);

  if (L.Kind = vkBoolean) or (R.Kind = vkBoolean) then
    Exit(Fail(InvalidArgument, 0, 'Boolean operands are not valid in arithmetic'));

  if not ToNumber(L, LN) then
    Exit(Fail(InvalidArgument, 0,
      Format('Invalid numeric operand "%s"', [L.AsString])));
  if not ToNumber(R, RN) then
    Exit(Fail(InvalidArgument, 0,
      Format('Invalid numeric operand "%s"', [R.AsString])));

  case AOp of
    boAdd:      Res := LN + RN;
    boSubtract: Res := LN - RN;
    boMultiply: Res := LN * RN;
    boDivide:
      if RN = 0 then
        Exit(Fail(DivisionByZero, 0, 'Division by zero'))
      else
        Res := LN / RN;
  else
    Exit(Fail(InvalidArgument, 0, 'Invalid arithmetic operator'));
  end;
  Result := TExpressionValue.MakeNumber(Res);
end;

function TModernExpressionEvaluator.EvalAggregate(ANode: TExpressionNode): TExpressionValue;
var
  Func: TExpressionFunction;
  Inner: TExpressionNode;
  Sum, MinVal, MaxVal: Double;
  Count: Integer;
  NonNull: Integer;
  FirstVal: Boolean;
  SaveBM, RowBM: TBookmark;
  AtGroupEnd: Boolean;
  V: TExpressionValue;
  N: Double;
  CacheKey: string;
  Cached: Variant;
begin
  Result := TExpressionValue.MakeNull;
  Func := ANode.Func;
  Inner := ANode.Children[0];

  if not Assigned(FContext.DataSet) or not FContext.DataSet.Active then
  begin
    Fail(UnsupportedDataSet, ANode.Position, 'Aggregate requires an active dataset');
    Exit;
  end;

  // Phase 3 execution-local aggregate cache, mode-isolated (OD-15/OD-16):
  // identity includes expression text (mode-prefixed), dataset position,
  // page/row state, group range, parameters and variables via Matches().
  CacheKey := CModernCacheKeyPrefix + FExpressionText;
  if Assigned(FContext.Hooks) and
     FContext.Hooks.TryGetAggregateCache(CacheKey, FContext, Cached) then
  begin
    Result := Cached;
    Exit;
  end;

  Sum := 0.0;
  MinVal := 0.0;
  MaxVal := 0.0;
  Count := 0;
  NonNull := 0;
  FirstVal := True;

  SaveBM := FContext.DataSet.GetBookmark;
  FContext.DataSet.DisableControls;
  try
    if FContext.GroupStart <> nil then
      FContext.DataSet.GotoBookmark(FContext.GroupStart)
    else
      FContext.DataSet.First;

    while not FContext.DataSet.Eof do
    begin
      AtGroupEnd := False;
      if FContext.GroupEnd <> nil then
      begin
        RowBM := FContext.DataSet.GetBookmark;
        try
          AtGroupEnd := FContext.DataSet.CompareBookmarks(RowBM, FContext.GroupEnd) = 0;
        finally
          FContext.DataSet.FreeBookmark(RowBM);
        end;
      end;
      if AtGroupEnd then Break;

      V := EvalNode(Inner);
      if FFailed then Exit;

      // COUNT counts non-null values; others skip NULL (OD-1/OD-3).
      if not V.IsNull then
      begin
        Inc(NonNull);
        if Func = fnCount then
          Inc(Count)
        else if ToNumber(V, N) then
        begin
          if Func = fnSum then Sum := Sum + N
          else if Func = fnAvg then
          begin
            Sum := Sum + N;
            Inc(Count);
          end
          else if Func = fnMin then
          begin
            if FirstVal or (N < MinVal) then MinVal := N;
            FirstVal := False;
          end
          else if Func = fnMax then
          begin
            if FirstVal or (N > MaxVal) then MaxVal := N;
            FirstVal := False;
          end;
        end
        else
        begin
          Fail(InvalidArgument, ANode.Position,
            Format('%s argument is not numeric', [ANode.TokenText]));
          Exit;
        end;
      end;
      FContext.DataSet.Next;
    end;
  finally
    if FContext.DataSet.Active and FContext.DataSet.BookmarkValid(SaveBM) then
      FContext.DataSet.GotoBookmark(SaveBM);
    FContext.DataSet.FreeBookmark(SaveBM);
    FContext.DataSet.EnableControls;
  end;

  // Empty or all-null input: SUM/AVG/MIN/MAX -> NULL, COUNT -> 0 (OD-1).
  case Func of
    fnCount: Result := TExpressionValue.MakeNumber(NonNull);
    fnSum:
      if NonNull = 0 then Result := TExpressionValue.MakeNull
      else Result := TExpressionValue.MakeNumber(Sum);
    fnAvg:
      if NonNull = 0 then Result := TExpressionValue.MakeNull
      else Result := TExpressionValue.MakeNumber(Sum / NonNull);
    fnMin:
      if NonNull = 0 then Result := TExpressionValue.MakeNull
      else Result := TExpressionValue.MakeNumber(MinVal);
    fnMax:
      if NonNull = 0 then Result := TExpressionValue.MakeNull
      else Result := TExpressionValue.MakeNumber(MaxVal);
  end;

  if Assigned(FContext.Hooks) then
    FContext.Hooks.StoreAggregateCache(CacheKey, FContext, Result.ToVariant);
end;

function TModernExpressionEvaluator.EvalCall(ANode: TExpressionNode): TExpressionValue;
var
  Func: TExpressionFunction;
  Args: TArray<TExpressionNode>;
  V: TExpressionValue;
  N, Digits: Double;
  I, Best: Integer;
  Ns: TArray<Double>;
  S: string;
  AllNum: Boolean;
begin
  Result := TExpressionValue.MakeNull;
  Func := ANode.Func;
  SetLength(Args, ANode.ChildCount);
  for I := 0 to ANode.ChildCount - 1 do
    Args[I] := ANode.Children[I];

  case Func of
    fnAbs:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        if not ToNumber(V, N) then
          Exit(Fail(InvalidArgument, ANode.Position, 'ABS argument is not numeric'));
        Result := TExpressionValue.MakeNumber(Abs(N));
      end;
    fnRound:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        if not ToNumber(V, N) then
          Exit(Fail(InvalidArgument, ANode.Position, 'ROUND argument is not numeric'));
        Digits := 0;
        if Length(Args) > 1 then
        begin
          V := EvalNode(Args[1]);
          if FFailed or V.IsNull then Exit;
          if not ToNumber(V, Digits) then
            Exit(Fail(InvalidArgument, ANode.Position, 'ROUND digits argument is not numeric'));
        end;
        Result := TExpressionValue.MakeNumber(RoundTo(N, -Trunc(Digits)));
      end;
    fnLeast, fnGreatest:
      begin
        SetLength(Ns, Length(Args));
        AllNum := True;
        for I := 0 to High(Args) do
        begin
          V := EvalNode(Args[I]);
          if FFailed or V.IsNull then Exit;
          if not ToNumber(V, Ns[I]) then
          begin
            AllNum := False;
            Break;
          end;
        end;
        if not AllNum then
          Exit(Fail(InvalidArgument, ANode.Position,
            Format('%s arguments must be numeric', [ANode.TokenText])));
        Best := 0;
        for I := 1 to High(Ns) do
          if (Func = fnLeast) and (Ns[I] < Ns[Best]) then Best := I
          else if (Func = fnGreatest) and (Ns[I] > Ns[Best]) then Best := I;
        Result := TExpressionValue.MakeNumber(Ns[Best]);
      end;
  else
    begin
      // handled in EvalCall2
      Result := EvalCall2(ANode, Func, Args);
    end;
  end;
end;

function TModernExpressionEvaluator.EvalCall2(ANode: TExpressionNode;
  Func: TExpressionFunction; const Args: TArray<TExpressionNode>): TExpressionValue;
var
  V: TExpressionValue;
  N, Digits: Double;
  S: string;
  I: Integer;
  Y, M, D: Word;
  FnName: string;
begin
  Result := TExpressionValue.MakeNull;
  case Func of
    fnUpper, fnLower, fnTrim:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        S := DisplayValue(V).AsString;
        case Func of
          fnUpper: Result := TExpressionValue.MakeString(System.SysUtils.UpperCase(S));
          fnLower: Result := TExpressionValue.MakeString(System.SysUtils.LowerCase(S));
          fnTrim:  Result := TExpressionValue.MakeString(System.SysUtils.Trim(S));
        end;
      end;
    fnLen:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        S := DisplayValue(V).AsString;
        Result := TExpressionValue.MakeNumber(Length(S));
      end;
    fnSubstr:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        S := DisplayValue(V).AsString;
        V := EvalNode(Args[1]);
        if FFailed or V.IsNull then Exit;
        if not ToNumber(V, N) then
          Exit(Fail(InvalidArgument, ANode.Position, 'SUBSTR start argument is not numeric'));
        V := EvalNode(Args[2]);
        if FFailed or V.IsNull then Exit;
        if not ToNumber(V, Digits) then
          Exit(Fail(InvalidArgument, ANode.Position, 'SUBSTR length argument is not numeric'));
        if (Trunc(N) < 1) or (Trunc(Digits) < 0) or (Trunc(N) > Length(S)) then
          Exit(Fail(InvalidArgument, ANode.Position, 'SUBSTR start/length out of range'));
        Result := TExpressionValue.MakeString(Copy(S, Trunc(N), Trunc(Digits)));
      end;
    fnContains, fnStartsWith, fnEndsWith:
      begin
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        S := DisplayValue(V).AsString;
        V := EvalNode(Args[1]);
        if FFailed or V.IsNull then Exit;
        // Case-insensitive text searching (Section 19).
        case Func of
          fnContains:
            Result := TExpressionValue.MakeBoolean(ContainsText(S, DisplayValue(V).AsString));
          fnStartsWith:
            begin
              N := Length(DisplayValue(V).AsString);
              Result := TExpressionValue.MakeBoolean(
                (N = 0) or SameText(Copy(S, 1, Trunc(N)), DisplayValue(V).AsString));
            end;
          fnEndsWith:
            begin
              N := Length(DisplayValue(V).AsString);
              Result := TExpressionValue.MakeBoolean(
                (N = 0) or SameText(Copy(S, Length(S) - Trunc(N) + 1, Trunc(N)),
                  DisplayValue(V).AsString));
            end;
        end;
      end;
    fnYear, fnMonth, fnDay:
      begin
        // OD-18: date extraction. NULL propagates (Section 12.3); a non-date
        // operand is a diagnosed error rather than a locale-dependent guess.
        V := EvalNode(Args[0]);
        if FFailed or V.IsNull then Exit;
        if not V.IsDateTime then
        begin
          if Func = fnYear then FnName := 'YEAR'
          else if Func = fnMonth then FnName := 'MONTH'
          else FnName := 'DAY';
          Exit(Fail(InvalidArgument, ANode.Position,
            Format('%s expects a date value', [FnName])));
        end;
        Y := 0; M := 0; D := 0;
        System.SysUtils.DecodeDate(V.AsDateTime, Y, M, D);
        case Func of
          fnYear:  Result := TExpressionValue.MakeNumber(Y);
          fnMonth: Result := TExpressionValue.MakeNumber(M);
          fnDay:   Result := TExpressionValue.MakeNumber(D);
        end;
      end;
  else
    Fail(UnknownFunction, ANode.Position, 'Unknown scalar function');
  end;
  for I := 0 to 0 do; // no-op to keep I used
end;

function TModernExpressionEvaluator.EvalConditional(ANode: TExpressionNode): TExpressionValue;
var
  I: Integer;
  V: TExpressionValue;
begin
  Result := TExpressionValue.MakeNull;
  if ANode.IsCoalesce then
  begin
    // COALESCE: first non-null argument; lazy evaluation.
    for I := 0 to ANode.ChildCount - 1 do
    begin
      V := EvalNode(ANode.Children[I]);
      if FFailed then Exit;
      if not V.IsNull then
        Exit(V);
    end;
    Exit; // all null -> NULL
  end;
  // IF: condition uses the consumer truthiness mapping (OD-5):
  // UNKNOWN/NULL -> False, matching ConditionVariantToBool semantics.
  V := EvalNode(ANode.Children[0]);
  if FFailed then Exit;
  if V.Truthiness then
    Result := EvalNode(ANode.Children[1])
  else
    Result := EvalNode(ANode.Children[2]);
end;

function TModernExpressionEvaluator.EvalNode(ANode: TExpressionNode): TExpressionValue;
var
  L, R: TExpressionValue;
  N: Double;
begin
  Result := TExpressionValue.MakeNull;
  if ANode = nil then Exit;

  Inc(FDepth);
  try
    if FDepth > FLimits.MaxDefensiveDepth then
    begin
      Fail(ExpressionTooDeep, ANode.Position,
        Format('Evaluation depth exceeds maximum %d', [FLimits.MaxDefensiveDepth]));
      Exit;
    end;

    case ANode.Kind of
      nkLiteral: Result := ANode.LiteralValue;
      nkTokenRef: Result := ResolveToken(ANode);
      nkParen: Result := EvalNode(ANode.Children[0]);
      nkAggregate: Result := EvalAggregate(ANode);
      nkCall: Result := EvalCall(ANode);
      nkConditional: Result := EvalConditional(ANode);
      nkIsNull:
        begin
          L := EvalNode(ANode.Children[0]);
          if FFailed then Exit;
          if ANode.IsNullOp = inoIsNull then
            Result := TExpressionValue.MakeBoolean(L.IsNull)
          else
            Result := TExpressionValue.MakeBoolean(not L.IsNull);
        end;
      nkUnary:
        begin
          L := EvalNode(ANode.Children[0]);
          if FFailed then Exit;
          if ANode.UnaryOp = uoNot then
          begin
            // Kleene NOT (Section 14): NOT UNKNOWN -> UNKNOWN.
            if L.IsNull then
              Result := TExpressionValue.MakeNull
            else if L.Kind <> vkBoolean then
              Result := Fail(InvalidArgument, ANode.Position,
                'NOT requires a Boolean operand')
            else
              Result := TExpressionValue.MakeBoolean(not L.AsBoolean);
            Exit;
          end;
          if L.IsNull then Exit; // NULL propagates (OD-2)
          if not ToNumber(L, N) then
            Exit(Fail(InvalidArgument, ANode.Position,
              'Unary operator requires a numeric operand'));
          if ANode.UnaryOp = uoMinus then
            Result := TExpressionValue.MakeNumber(-N)
          else
            Result := TExpressionValue.MakeNumber(N);
        end;
      nkBinary: Result := EvalBinary(ANode);
    end;
  finally
    Dec(FDepth);
  end;
end;

function TModernExpressionEvaluator.EvalBinary(ANode: TExpressionNode): TExpressionValue;
var
  L, R: TExpressionValue;
  Op: TExpressionBinaryOp;
begin
  Result := TExpressionValue.MakeNull;
  Op := ANode.BinaryOp;

  if Op in [boAnd, boOr] then
  begin
    L := EvalNode(ANode.Children[0]);
    if FFailed then Exit;
    // Kleene short-circuit (Section 14).
    if (not L.IsNull) and (L.Kind = vkBoolean) then
    begin
      if (Op = boAnd) and (not L.AsBoolean) then
        Exit(TExpressionValue.MakeBoolean(False));
      if (Op = boOr) and L.AsBoolean then
        Exit(TExpressionValue.MakeBoolean(True));
    end;
    R := EvalNode(ANode.Children[1]);
    if FFailed then Exit;
    // Kleene truth table with UNKNOWN represented as NULL.
    if L.IsNull or R.IsNull then
    begin
      if L.Kind = vkBoolean then
      begin
        if (Op = boAnd) and (not L.AsBoolean) then
          Exit(TExpressionValue.MakeBoolean(False));
        if (Op = boOr) and L.AsBoolean then
          Exit(TExpressionValue.MakeBoolean(True));
      end;
      if R.Kind = vkBoolean then
      begin
        if (Op = boAnd) and (not R.AsBoolean) then
          Exit(TExpressionValue.MakeBoolean(False));
        if (Op = boOr) and R.AsBoolean then
          Exit(TExpressionValue.MakeBoolean(True));
      end;
      Exit(TExpressionValue.MakeNull); // UNKNOWN
    end;
    if (L.Kind <> vkBoolean) or (R.Kind <> vkBoolean) then
      Exit(Fail(InvalidArgument, ANode.Position, 'AND/OR require Boolean operands'));
    if Op = boAnd then
      Result := TExpressionValue.MakeBoolean(L.AsBoolean and R.AsBoolean)
    else
      Result := TExpressionValue.MakeBoolean(L.AsBoolean or R.AsBoolean);
    Exit;
  end;

  if Op in [boEqual, boNotEqual, boLess, boGreater, boLessEqual, boGreaterEqual] then
  begin
    L := EvalNode(ANode.Children[0]);
    if FFailed then Exit;
    R := EvalNode(ANode.Children[1]);
    if FFailed then Exit;
    Result := CompareValues(Op, L, R);
    Exit;
  end;

  L := EvalNode(ANode.Children[0]);
  if FFailed then Exit;
  R := EvalNode(ANode.Children[1]);
  if FFailed then Exit;
  Result := Arithmetic(Op, L, R);
end;

function TModernExpressionEvaluator.Evaluate(ARoot: TExpressionNode): TExpressionValue;
begin
  FDepth := 0;
  Result := EvalNode(ARoot);
end;

{ Shared parse helper (implementation only). }
function ParseModernExpression(const AExpression: string;
  ADiagnostics: TExpressionDiagnostics; out ATree: TExpressionNode): Boolean;
var
  Parser: TModernExpressionParser;
begin
  Parser := TModernExpressionParser.Create;
  try
    Result := Parser.Parse(AExpression, TExpressionLimits.Default, ADiagnostics, ATree);
  finally
    Parser.Free;
  end;
end;

class function TModernExpressionEngine.Evaluate(const AExpression: string;
  const AContext: TExpressionContext): Variant;
var
  Diagnostics: TExpressionDiagnostics;
  Tree: TExpressionNode;
  Evaluator: TModernExpressionEvaluator;
  Value: TExpressionValue;
begin
  Diagnostics := TExpressionDiagnostics.Create;
  Tree := nil;
  try
    if not ParseModernExpression(AExpression, Diagnostics, Tree) then
    begin
      if Diagnostics.Count > 0 then
        raise EVittixExpressionError.Create(
          Diagnostics.Items[0].Code, Diagnostics.Items[0].Position,
          Diagnostics.Items[0].Message);
      raise EVittixExpressionError.Create(SyntaxError, 1,
        'Expression could not be parsed');
    end;
    Evaluator := TModernExpressionEvaluator.Create(AContext,
      TExpressionLimits.Default, AExpression);
    try
      Value := Evaluator.Evaluate(Tree);
      if Evaluator.Failed then
        raise EVittixExpressionError.Create(Evaluator.FirstErrorCode,
          Evaluator.FirstErrorPos, Evaluator.FirstError);
      Result := Value.ToVariant;
    finally
      Evaluator.Free;
    end;
  finally
    Tree.Free;
    Diagnostics.Free;
  end;
end;

class function TModernExpressionEngine.Validate(const AExpression: string;
  out AErrorMessages: TArray<string>): Boolean;
var
  Diagnostics: TExpressionDiagnostics;
  Tree: TExpressionNode;
  Items: TArray<TExpressionDiagnostic>;
  List: TList<string>;
  I: Integer;
begin
  Diagnostics := TExpressionDiagnostics.Create;
  Tree := nil;
  List := TList<string>.Create;
  try
    Result := ParseModernExpression(AExpression, Diagnostics, Tree);
    Items := Diagnostics.Items;
    for I := 0 to High(Items) do
      List.Add(Items[I].Message);
    AErrorMessages := List.ToArray;
  finally
    List.Free;
    Tree.Free;
    Diagnostics.Free;
  end;
end;

class function TModernExpressionEngine.Validate(const AExpression: string): Boolean;
var
  Errors: TArray<string>;
begin
  Result := Validate(AExpression, Errors);
end;

end.
