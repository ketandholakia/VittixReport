unit Vittix.Report.Expression.Migration;

{
  Vittix.Report.Expression.Migration
  ==================================
  Phase 4B-2B hardening: the migration ANALYZER.

  Given an expression and an evaluation context, the analyzer evaluates the
  expression in BOTH language modes through the public API
  (TReportExpression.Evaluate with an explicit mode) and classifies the
  difference.  It is an ANALYSIS tool only:

    * it never rewrites expressions
    * it never touches .vrt files or the serializer
    * it never changes language versions or engine state
    * it never mutates the dataset (read-only field access only)
    * it never touches the aggregate cache

  Cache safety: the analyzer runs on a COPY of the caller's context with
  Hooks := nil.  Both evaluators guard cache access with
  Assigned(Context.Hooks), so aggregates are recomputed fresh per analysis
  and no cache entry is read or written (OD-15/OD-16 state untouched).
  Limitation: qualified dataset references ([SomeName.Field]) resolve via
  Hooks.GetNamedDataSet, so they report UnknownDataSet during analysis;
  expressions using named datasets must be reviewed manually.

  Difference categories
  ---------------------
    mdSameResult       both modes returned the same typed value
    mdDifferentResult  both returned values of the same Variant type that differ
    mdTypeDifference   both returned values with different Variant types
    mdLegacyOnly       legacy produced a value; modern raised
    mdModernOnly       modern produced a value; legacy raised
    mdBothError        both modes raised

  Note: the frozen legacy compatibility evaluator is fail-soft (it never
  raises for expression input), so with the current evaluator pair the
  mdModernOnly and mdBothError categories are unreachable; they exist to
  keep the model complete for future evaluator combinations.
}

interface

uses
  System.SysUtils,
  System.Variants,
  Vittix.Report.Context,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Expression.Diagnostics;

type
  TExpressionMigrationDifference = (
    mdSameResult,
    mdDifferentResult,
    mdTypeDifference,
    mdLegacyOnly,
    mdModernOnly,
    mdBothError
  );

  TExpressionMigrationAnalysis = record
  private
    FExpression: string;
    FLegacyValue: Variant;
    FModernValue: Variant;
    FLegacyError: string;
    FModernError: string;
    FModernErrorCode: TExpressionDiagnosticCode;
    FDifference: TExpressionMigrationDifference;
  public
    property Expression: string read FExpression;
    { '' when the legacy evaluation produced a value. }
    property LegacyError: string read FLegacyError;
    { '' when the modern evaluation produced a value. }
    property ModernError: string read FModernError;
    { Valid only when ModernError <> ''. }
    property ModernErrorCode: TExpressionDiagnosticCode read FModernErrorCode;
    property LegacyValue: Variant read FLegacyValue;
    property ModernValue: Variant read FModernValue;
    property Difference: TExpressionMigrationDifference read FDifference;

    function LegacySucceeded: Boolean;
    function ModernSucceeded: Boolean;
  end;

  TExpressionMigrationAnalyzer = class
  public
    { Analyzes one expression. AContext is borrowed read-only; the analyzer
      never writes through it (the evaluation uses an internal copy). }
    class function Analyze(const AExpression: string;
      const AContext: TExpressionContext): TExpressionMigrationAnalysis;
  end;

implementation

uses
  Vittix.Report.Expressions,
  Vittix.Report.Expression.Evaluator;

{ TExpressionMigrationAnalysis }

function TExpressionMigrationAnalysis.LegacySucceeded: Boolean;
begin
  Result := FLegacyError = '';
end;

function TExpressionMigrationAnalysis.ModernSucceeded: Boolean;
begin
  Result := FModernError = '';
end;

{ TExpressionMigrationAnalyzer }

class function TExpressionMigrationAnalyzer.Analyze(const AExpression: string;
  const AContext: TExpressionContext): TExpressionMigrationAnalysis;
var
  LegacyCtx, ModernCtx: TExpressionContext;
begin
  Result := Default(TExpressionMigrationAnalysis);
  Result.FExpression := AExpression;
  Result.FModernErrorCode := SyntaxError;

  { Hook-free copies: no aggregate-cache interaction, no hook callbacks.
    Everything else (dataset, params, vars, page/row state) is shared
    read-only with the caller's context. }
  LegacyCtx := AContext;
  LegacyCtx.Hooks := nil;
  LegacyCtx.ExpressionMode := emLegacy;

  ModernCtx := AContext;
  ModernCtx.Hooks := nil;
  ModernCtx.ExpressionMode := emModern;

  try
    Result.FLegacyValue := TReportExpression.Evaluate(AExpression, LegacyCtx, emLegacy);
  except
    on E: Exception do
      Result.FLegacyError := E.Message;
  end;

  try
    Result.FModernValue := TReportExpression.Evaluate(AExpression, ModernCtx, emModern);
  except
    on E: EVittixExpressionError do
    begin
      Result.FModernError := E.Message;
      Result.FModernErrorCode := E.Code;
    end;
    on E: Exception do
    begin
      Result.FModernError := E.Message;
      Result.FModernErrorCode := EvaluationError;
    end;
  end;

  { Classification. }
  if Result.LegacySucceeded and Result.ModernSucceeded then
  begin
    if VarIsNull(Result.FLegacyValue) and VarIsNull(Result.FModernValue) then
      Result.FDifference := mdSameResult
    else if VarType(Result.FLegacyValue) <> VarType(Result.FModernValue) then
      Result.FDifference := mdTypeDifference
    else if VarSameValue(Result.FLegacyValue, Result.FModernValue) then
      Result.FDifference := mdSameResult
    else
      Result.FDifference := mdDifferentResult;
  end
  else if Result.LegacySucceeded then
    Result.FDifference := mdLegacyOnly
  else if Result.ModernSucceeded then
    Result.FDifference := mdModernOnly
  else
    Result.FDifference := mdBothError;
end;

end.
