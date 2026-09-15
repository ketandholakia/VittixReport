unit Vittix.Report.Expression.Diagnostics;

{
  Vittix.Report.Expression.Diagnostics
  ====================================
  Structured diagnostics for the modern expression evaluator.
  Immutable diagnostic records, ordered collection, counters.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TExpressionDiagnosticCode = (
    SyntaxError,
    UnknownField,
    UnknownDataSet,
    UnknownParameter,
    UnknownVariable,
    UnknownFunction,
    InvalidArgumentCount,
    InvalidArgument,
    TypeError,
    DivisionByZero,
    NullError,
    UnsupportedDataSet,
    LimitExceeded,
    EvaluationError,
    ImplicitConversion,
    NestedAggregate,
    { Phase 4B-2B hardening: granular codes. Appended AFTER the existing
      values so the ordinals of all previously published codes stay stable. }
    UnexpectedToken,
    UnexpectedEndOfExpression,
    InvalidNumber,
    InvalidString,
    InvalidComparison,
    NonAssociativeComparison,
    ExpressionTooLong,
    ExpressionTooDeep,
    TooManyNodes
  );

  TExpressionDiagnostic = record
  private
    FCode: TExpressionDiagnosticCode;
    FPosition: Integer;
    FLength: Integer;
    FMessage: string;
  public
    constructor Create(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);
    property Code: TExpressionDiagnosticCode read FCode;
    property Position: Integer read FPosition;
    property Length: Integer read FLength;
    property Message: string read FMessage;
  end;

  TExpressionDiagnostics = class
  private
    FItems: TList<TExpressionDiagnostic>;
    FErrorCount: Integer;
    FWarningCount: Integer;
    FMaxDiagnostics: Integer;
    procedure AddDiagnostic(const ADiagnostic: TExpressionDiagnostic);
  public
    constructor Create(AMaxDiagnostics: Integer = 64);
    destructor Destroy; override;

    procedure AddError(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);
    procedure AddWarning(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);

    function HasErrors: Boolean;
    function Count: Integer;
    function Errors: Integer;
    function Warnings: Integer;
    function Items: TArray<TExpressionDiagnostic>;

    procedure Clear;
  end;

  TExpressionStrictness = (esLenient, esStrict, esValidating);

implementation

{ TExpressionDiagnostic }

constructor TExpressionDiagnostic.Create(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);
begin
  FCode := ACode;
  FPosition := APosition;
  FLength := ALength;
  FMessage := AMessage;
end;

{ TExpressionDiagnostics }

constructor TExpressionDiagnostics.Create(AMaxDiagnostics: Integer = 64);
begin
  inherited Create;
  FItems := TList<TExpressionDiagnostic>.Create;
  FMaxDiagnostics := AMaxDiagnostics;
  FErrorCount := 0;
  FWarningCount := 0;
end;

destructor TExpressionDiagnostics.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TExpressionDiagnostics.AddDiagnostic(const ADiagnostic: TExpressionDiagnostic);
begin
  if FItems.Count >= FMaxDiagnostics then
    Exit;
  FItems.Add(ADiagnostic);
  case ADiagnostic.Code of
    SyntaxError, UnknownField, UnknownDataSet, UnknownParameter, UnknownVariable,
    UnknownFunction, InvalidArgumentCount, InvalidArgument, TypeError,
    DivisionByZero, NullError, UnsupportedDataSet, LimitExceeded, EvaluationError,
    NestedAggregate,
    UnexpectedToken, UnexpectedEndOfExpression, InvalidNumber, InvalidString,
    InvalidComparison, NonAssociativeComparison, ExpressionTooLong,
    ExpressionTooDeep, TooManyNodes:
      Inc(FErrorCount);
    ImplicitConversion:
      Inc(FWarningCount);
  else
    Inc(FWarningCount);
  end;
end;

procedure TExpressionDiagnostics.AddError(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);
begin
  AddDiagnostic(TExpressionDiagnostic.Create(ACode, APosition, ALength, AMessage));
end;

procedure TExpressionDiagnostics.AddWarning(const ACode: TExpressionDiagnosticCode; const APosition, ALength: Integer; const AMessage: string);
begin
  AddDiagnostic(TExpressionDiagnostic.Create(ACode, APosition, ALength, AMessage));
end;

function TExpressionDiagnostics.HasErrors: Boolean;
begin
  Result := FErrorCount > 0;
end;

function TExpressionDiagnostics.Count: Integer;
begin
  Result := FItems.Count;
end;

function TExpressionDiagnostics.Errors: Integer;
begin
  Result := FErrorCount;
end;

function TExpressionDiagnostics.Warnings: Integer;
begin
  Result := FWarningCount;
end;

function TExpressionDiagnostics.Items: TArray<TExpressionDiagnostic>;
begin
  Result := FItems.ToArray;
end;

procedure TExpressionDiagnostics.Clear;
begin
  FItems.Clear;
  FErrorCount := 0;
  FWarningCount := 0;
end;

end.