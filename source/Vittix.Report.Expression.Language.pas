unit Vittix.Report.Expression.Language;

{
  Vittix.Report.Expression.Language
  =================================
  Core language definitions: token kinds, value kinds, AST node types,
  function catalogue, limits, and evaluation context interface.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  Data.DB,
  Vittix.Report.Context,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Expression.Diagnostics;

type
  // Token kinds produced by the tokenizer
  TExpressionTokenKind = (
    tkEOF,
    tkIdentifier,
    tkNumber,
    tkString,
    tkBracketToken,
    tkPlus,
    tkMinus,
    tkMultiply,
    tkDivide,
    tkEqual,
    tkNotEqual,
    tkLessThan,
    tkGreaterThan,
    tkLessEqual,
    tkGreaterEqual,
    tkLeftParen,
    tkRightParen,
    tkComma,
    tkAnd,
    tkOr,
    tkNot,
    tkIs,
    tkNull,
    tkTrue,
    tkFalse
  );

  TExpressionToken = record
  private
    FKind: TExpressionTokenKind;
    FText: string;
    FPosition: Integer;
    FLength: Integer;
    FValue: Variant; // Parsed value for literals
  public
    constructor Create(const AKind: TExpressionTokenKind; const AText: string; const APosition, ALength: Integer; const AValue: Variant);
    property Kind: TExpressionTokenKind read FKind;
    property Text: string read FText;
    property Position: Integer read FPosition;
    property Length: Integer read FLength;
    property Value: Variant read FValue;
  end;

  // Value kinds for the strongly typed internal value
  TExpressionValueKind = (
    vkNull,
    vkBoolean,
    vkNumber,
    vkString,
    vkDateTime
  );

  TExpressionValue = record
  private
    FKind: TExpressionValueKind;
    FAsBoolean: Boolean;
    FAsNumber: Double;
    FAsString: string;
    FAsDateTime: TDateTime;
  public
    class function MakeNull: TExpressionValue; static;
    class function MakeBoolean(const AValue: Boolean): TExpressionValue; static;
    class function MakeNumber(const AValue: Double): TExpressionValue; static;
    class function MakeString(const AValue: string): TExpressionValue; static;
    class function MakeDateTime(const AValue: TDateTime): TExpressionValue; static;
  public
    property Kind: TExpressionValueKind read FKind;
    property AsBoolean: Boolean read FAsBoolean;
    property AsNumber: Double read FAsNumber;
    property AsString: string read FAsString;
    property AsDateTime: TDateTime read FAsDateTime;

    class operator Implicit(const AValue: Boolean): TExpressionValue;
    class operator Implicit(const AValue: Double): TExpressionValue;
    class operator Implicit(const AValue: string): TExpressionValue;
    class operator Implicit(const AValue: TDateTime): TExpressionValue;
    class operator Implicit(const AValue: Variant): TExpressionValue;

    function ToVariant: Variant;
    function IsNull: Boolean;
    function IsBoolean: Boolean;
    function IsNumber: Boolean;
    function IsString: Boolean;
    function IsDateTime: Boolean;
    function Truthiness: Boolean; // Kleene truthiness for AND/OR/NOT
  end;

  // AST node kinds
  TExpressionNodeKind = (
    nkLiteral,
    nkTokenRef,
    nkUnary,
    nkBinary,
    nkIsNull,
    nkCall,
    nkAggregate,
    nkConditional,
    nkParen
  );

  TExpressionUnaryOp = (uoPlus, uoMinus, uoNot);
  TExpressionBinaryOp = (boAdd, boSubtract, boMultiply, boDivide,
                         boEqual, boNotEqual, boLess, boGreater, boLessEqual, boGreaterEqual,
                         boAnd, boOr);
  TExpressionIsNullOp = (inoIsNull, inoIsNotNull);

  // Function signatures for the closed catalogue
  TExpressionFunction = (
    fnIf,
    fnCoalesce,
    fnAbs,
    fnRound,
    fnLeast,
    fnGreatest,
    fnUpper,
    fnLower,
    fnTrim,
    fnLen,
    fnSubstr,
    fnContains,
    fnStartsWith,
    fnEndsWith,
    fnSum,
    fnCount,
    fnAvg,
    fnMin,
    fnMax,
    { OD-18: date extraction. Appended AFTER the existing values so every
      previously published ordinal stays stable (same convention as the
      diagnostic codes). }
    fnYear,
    fnMonth,
    fnDay
  );

  TExpressionFunctionArity = record
  private
    FMinArgs: Integer;
    FMaxArgs: Integer; // -1 for variadic
    FLazyArgs: TArray<Integer>; // 0-based indices of lazy-evaluated arguments
  public
    constructor Create(const AMinArgs, AMaxArgs: Integer; const ALazyArgs: array of Integer);
    property MinArgs: Integer read FMinArgs;
    property MaxArgs: Integer read FMaxArgs;
    property LazyArgs: TArray<Integer> read FLazyArgs;
    function IsVariadic: Boolean;
    function IsLazy(const AArgIndex: Integer): Boolean;
  end;

  // Forward declaration for AST node
  TExpressionNode = class;

  TExpressionNode = class
  private
    FKind: TExpressionNodeKind;
    FPosition: Integer;
    FLength: Integer;
    FChildren: TArray<TExpressionNode>;
    // Payload fields (which fields are meaningful depends on FKind)
    FLiteralValue: TExpressionValue;   // nkLiteral
    FTokenText: string;                // nkTokenRef
    FQualifier: string;                // nkTokenRef
    FFieldName: string;                // nkTokenRef
    FHasQualifier: Boolean;            // nkTokenRef
    FUnaryOp: TExpressionUnaryOp;      // nkUnary
    FBinaryOp: TExpressionBinaryOp;    // nkBinary
    FIsNullOp: TExpressionIsNullOp;    // nkIsNull
    FFunc: TExpressionFunction;        // nkCall / nkAggregate
    FIsCoalesce: Boolean;              // nkConditional
    function GetChild(const AIndex: Integer): TExpressionNode;
    function GetChildCount: Integer;
  public
    constructor Create(const AKind: TExpressionNodeKind; const APosition, ALength: Integer);
    constructor CreateWithChildren(const AKind: TExpressionNodeKind; const APosition, ALength: Integer; const AChildren: array of TExpressionNode);
    destructor Destroy; override;
    // Factories (parser-facing)
    class function NewLiteral(const AValue: TExpressionValue; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewTokenRef(const ATokenText, AQualifier, AFieldName: string; AHasQualifier: Boolean; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewUnary(const AOp: TExpressionUnaryOp; AOperand: TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewBinary(const AOp: TExpressionBinaryOp; ALeft, ARight: TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewIsNull(const AOp: TExpressionIsNullOp; AOperand: TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewCall(const AFunc: TExpressionFunction; const AArgs: array of TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewAggregate(const AFunc: TExpressionFunction; AInner: TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewConditional(AIsCoalesce: Boolean; const AArgs: array of TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    class function NewParen(AExpr: TExpressionNode; const APosition, ALength: Integer): TExpressionNode; static;
    property Kind: TExpressionNodeKind read FKind;
    property Position: Integer read FPosition;
    property TextLength: Integer read FLength;
    property Children[const Index: Integer]: TExpressionNode read GetChild;
    property ChildCount: Integer read GetChildCount;
    property LiteralValue: TExpressionValue read FLiteralValue;
    property TokenText: string read FTokenText;
    property Qualifier: string read FQualifier;
    property FieldName: string read FFieldName;
    property HasQualifier: Boolean read FHasQualifier;
    property UnaryOp: TExpressionUnaryOp read FUnaryOp;
    property BinaryOp: TExpressionBinaryOp read FBinaryOp;
    property IsNullOp: TExpressionIsNullOp read FIsNullOp;
    property Func: TExpressionFunction read FFunc;
    property IsCoalesce: Boolean read FIsCoalesce;
  end;

  // Specific node types (as records for immutability, with factory functions)
  TExpressionLiteralNode = record
    Value: TExpressionValue;
  end;

  TExpressionTokenRefNode = record
    TokenText: string;
    HasQualifier: Boolean;
    Qualifier: string;
    FieldName: string;
  end;

  TExpressionUnaryNode = record
    Op: TExpressionUnaryOp;
    Operand: TExpressionNode;
  end;

  TExpressionBinaryNode = record
    Op: TExpressionBinaryOp;
    Left: TExpressionNode;
    Right: TExpressionNode;
  end;

  TExpressionIsNullNode = record
    Op: TExpressionIsNullOp;
    Operand: TExpressionNode;
  end;

  TExpressionCallNode = record
    Func: TExpressionFunction;
    Args: TArray<TExpressionNode>;
  end;

  TExpressionAggregateNode = record
    Func: TExpressionFunction;
    InnerExpr: TExpressionNode;
    HasDistinct: Boolean; // Not used in V1, reserved
  end;

  TExpressionConditionalNode = record
    IsCoalesce: Boolean; // False = IF, True = COALESCE
    Args: TArray<TExpressionNode>; // IF: [cond, then, else], COALESCE: [arg1, arg2, ...]
    LazyIndices: TArray<Integer>;
  end;

  TExpressionParenNode = record
    Expr: TExpressionNode;
  end;

  // Parser configuration and limits
  TExpressionLimits = record
    MaxExpressionLength: Integer;
    MaxParserDepth: Integer;
    MaxDefensiveDepth: Integer;
    MaxAstNodes: Integer;
    MaxFunctionArgs: Integer;
    MaxAggregatesPerExpr: Integer;
    MaxDiagnosticsPerEval: Integer;
    class function Default: TExpressionLimits; static;
  end;

  // Evaluation context interface (pure, no mutation)
  IExpressionEvaluationContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetDataSet: TDataSet;
    function GetUserDataSet: TObject;
    function GetGroupStart: TBookmark;
    function GetGroupEnd: TBookmark;
    function GetPageNumber: Integer;
    function GetTotalPages: Integer;
    function GetRowNumber: Integer;
    function GetReportTitle: string;
    function GetReportDate: TDateTime;
    function GetParameters: TStrings;
    function GetVariables: TStrings;
    function GetHooks: IReportRenderHooks;
    function IsCountingPass: Boolean;
  end;

  // Evaluation result with diagnostics
  TExpressionEvaluationResult = record
    Value: TExpressionValue;
    Diagnostics: TExpressionDiagnostics;
    function Success: Boolean;
  end;

  // Validation result (immutable, no AST exposed)
  TExpressionValidationResult = record
    Diagnostics: TExpressionDiagnostics;
    function IsValid: Boolean;
  end;

  // Expression language mode lives in Vittix.Report.Expression.Mode so the
  // low-level context record can carry it without a unit cycle.

implementation

{ TExpressionToken }

constructor TExpressionToken.Create(const AKind: TExpressionTokenKind; const AText: string; const APosition, ALength: Integer; const AValue: Variant);
begin
  FKind := AKind;
  FText := AText;
  FPosition := APosition;
  FLength := ALength;
  FValue := AValue;
end;

{ TExpressionValue }

class function TExpressionValue.MakeNull: TExpressionValue;
begin
  Result.FKind := vkNull;
  Result.FAsBoolean := False;
  Result.FAsNumber := 0;
  Result.FAsString := '';
  Result.FAsDateTime := 0;
end;

class function TExpressionValue.MakeBoolean(const AValue: Boolean): TExpressionValue;
begin
  Result.FKind := vkBoolean;
  Result.FAsBoolean := AValue;
  Result.FAsNumber := 0;
  Result.FAsString := '';
  Result.FAsDateTime := 0;
end;

class function TExpressionValue.MakeNumber(const AValue: Double): TExpressionValue;
begin
  Result.FKind := vkNumber;
  Result.FAsBoolean := False;
  Result.FAsNumber := AValue;
  Result.FAsString := '';
  Result.FAsDateTime := 0;
end;

class function TExpressionValue.MakeString(const AValue: string): TExpressionValue;
begin
  Result.FKind := vkString;
  Result.FAsBoolean := False;
  Result.FAsNumber := 0;
  Result.FAsString := AValue;
  Result.FAsDateTime := 0;
end;

class function TExpressionValue.MakeDateTime(const AValue: TDateTime): TExpressionValue;
begin
  Result.FKind := vkDateTime;
  Result.FAsBoolean := False;
  Result.FAsNumber := 0;
  Result.FAsString := '';
  Result.FAsDateTime := AValue;
end;

class operator TExpressionValue.Implicit(const AValue: Boolean): TExpressionValue;
begin
  Result := MakeBoolean(AValue);
end;

class operator TExpressionValue.Implicit(const AValue: Double): TExpressionValue;
begin
  Result := MakeNumber(AValue);
end;

class operator TExpressionValue.Implicit(const AValue: string): TExpressionValue;
begin
  Result := MakeString(AValue);
end;

class operator TExpressionValue.Implicit(const AValue: TDateTime): TExpressionValue;
begin
  Result := MakeDateTime(AValue);
end;

class operator TExpressionValue.Implicit(const AValue: Variant): TExpressionValue;
var
  VT: TVarType;
begin
  VT := VarType(AValue);
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Result := MakeNull
  else if VT = varBoolean then
    Result := MakeBoolean(AValue)
  else if VT in [varSmallint, varInteger, varSingle, varDouble, varCurrency,
                 varShortInt, varByte, varWord, varLongWord, varInt64] then
    Result := MakeNumber(VarAsType(AValue, varDouble))
  else if VT = varDate then
    Result := MakeDateTime(AValue)
  else
    Result := MakeString(VarToStr(AValue));
end;

function TExpressionValue.ToVariant: Variant;
begin
  case FKind of
    vkNull: Result := Null;
    vkBoolean: Result := FAsBoolean;
    vkNumber: Result := FAsNumber;
    vkString: Result := FAsString;
    vkDateTime: Result := FAsDateTime;
  else
    Result := Null;
  end;
end;

function TExpressionValue.IsNull: Boolean;
begin
  Result := FKind = vkNull;
end;

function TExpressionValue.IsBoolean: Boolean;
begin
  Result := FKind = vkBoolean;
end;

function TExpressionValue.IsNumber: Boolean;
begin
  Result := FKind = vkNumber;
end;

function TExpressionValue.IsString: Boolean;
begin
  Result := FKind = vkString;
end;

function TExpressionValue.IsDateTime: Boolean;
begin
  Result := FKind = vkDateTime;
end;

function TExpressionValue.Truthiness: Boolean;
var
  S: string;
  D: Double;
begin
  case FKind of
    vkNull: Exit(False);
    vkBoolean: Exit(FAsBoolean);
    vkNumber: Exit(FAsNumber <> 0);
    vkDateTime: Exit(False); // DateTime is not truthy
    vkString:
    begin
      S := Trim(LowerCase(FAsString));
      if S = '' then Exit(False);
      if (S = '0') or (S = 'false') or (S = 'no') or (S = 'n') or (S = 'off') then Exit(False);
      if (S = '1') or (S = 'true') or (S = 'yes') or (S = 'y') or (S = 'on') then Exit(True);
      if TryStrToFloat(S, D) then Exit(D <> 0);
      Exit(False);
    end;
  else
    Exit(False);
  end;
end;

{ TExpressionFunctionArity }

constructor TExpressionFunctionArity.Create(const AMinArgs, AMaxArgs: Integer; const ALazyArgs: array of Integer);
var
  I: Integer;
begin
  FMinArgs := AMinArgs;
  FMaxArgs := AMaxArgs;
  SetLength(FLazyArgs, Length(ALazyArgs));
  for I := 0 to High(ALazyArgs) do
    FLazyArgs[I] := ALazyArgs[I];
end;

function TExpressionFunctionArity.IsVariadic: Boolean;
begin
  Result := FMaxArgs = -1;
end;

function TExpressionFunctionArity.IsLazy(const AArgIndex: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FLazyArgs) do
    if FLazyArgs[I] = AArgIndex then
      Exit(True);
  Result := False;
end;

{ TExpressionNode }

constructor TExpressionNode.Create(const AKind: TExpressionNodeKind; const APosition, ALength: Integer);
begin
  inherited Create;
  FKind := AKind;
  FPosition := APosition;
  FLength := ALength;
  FChildren := nil;
end;

constructor TExpressionNode.CreateWithChildren(const AKind: TExpressionNodeKind; const APosition, ALength: Integer; const AChildren: array of TExpressionNode);
var
  I: Integer;
begin
  Create(AKind, APosition, ALength);
  SetLength(FChildren, Length(AChildren));
  for I := 0 to High(AChildren) do
    FChildren[I] := AChildren[I];
end;

destructor TExpressionNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FChildren) do
    FChildren[I].Free;
  inherited;
end;

function TExpressionNode.GetChild(const AIndex: Integer): TExpressionNode;
begin
  if (AIndex >= 0) and (AIndex < Length(FChildren)) then
    Result := FChildren[AIndex]
  else
    Result := nil;
end;

function TExpressionNode.GetChildCount: Integer;
begin
  Result := Length(FChildren);
end;

{ TExpressionNode factories }

class function TExpressionNode.NewLiteral(const AValue: TExpressionValue; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.Create(nkLiteral, APosition, ALength);
  Result.FLiteralValue := AValue;
end;

class function TExpressionNode.NewTokenRef(const ATokenText, AQualifier, AFieldName: string; AHasQualifier: Boolean; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.Create(nkTokenRef, APosition, ALength);
  Result.FTokenText := ATokenText;
  Result.FQualifier := AQualifier;
  Result.FFieldName := AFieldName;
  Result.FHasQualifier := AHasQualifier;
end;

class function TExpressionNode.NewUnary(const AOp: TExpressionUnaryOp; AOperand: TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkUnary, APosition, ALength, [AOperand]);
  Result.FUnaryOp := AOp;
end;

class function TExpressionNode.NewBinary(const AOp: TExpressionBinaryOp; ALeft, ARight: TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkBinary, APosition, ALength, [ALeft, ARight]);
  Result.FBinaryOp := AOp;
end;

class function TExpressionNode.NewIsNull(const AOp: TExpressionIsNullOp; AOperand: TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkIsNull, APosition, ALength, [AOperand]);
  Result.FIsNullOp := AOp;
end;

class function TExpressionNode.NewCall(const AFunc: TExpressionFunction; const AArgs: array of TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkCall, APosition, ALength, AArgs);
  Result.FFunc := AFunc;
end;

class function TExpressionNode.NewAggregate(const AFunc: TExpressionFunction; AInner: TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkAggregate, APosition, ALength, [AInner]);
  Result.FFunc := AFunc;
end;

class function TExpressionNode.NewConditional(AIsCoalesce: Boolean; const AArgs: array of TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkConditional, APosition, ALength, AArgs);
  Result.FIsCoalesce := AIsCoalesce;
end;

class function TExpressionNode.NewParen(AExpr: TExpressionNode; const APosition, ALength: Integer): TExpressionNode;
begin
  Result := TExpressionNode.CreateWithChildren(nkParen, APosition, ALength, [AExpr]);
end;

{ TExpressionLimits }

class function TExpressionLimits.Default: TExpressionLimits;
begin
  Result.MaxExpressionLength := 4096;
  Result.MaxParserDepth := 32;
  Result.MaxDefensiveDepth := 128;
  Result.MaxAstNodes := 512;
  Result.MaxFunctionArgs := 16;
  Result.MaxAggregatesPerExpr := 8;
  Result.MaxDiagnosticsPerEval := 64;
end;

{ TExpressionEvaluationResult }

function TExpressionEvaluationResult.Success: Boolean;
begin
  Result := not Diagnostics.HasErrors;
end;

{ TExpressionValidationResult }

function TExpressionValidationResult.IsValid: Boolean;
begin
  Result := not Diagnostics.HasErrors;
end;

end.