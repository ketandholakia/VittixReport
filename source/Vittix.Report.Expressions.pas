unit Vittix.Report.Expressions;

{
  Vittix.Report.Expressions
  =========================
  TReportExpression.Evaluate resolves a string expression in the context of
  the current dataset row and page state.

  Phase 4B-1: this unit is now the stable public boundary only.  Evaluation
  itself lives in Vittix.Report.Expressions.Compat, which reproduces the
  characterized legacy behavior exactly.  The public signature and the
  observable behavior are unchanged; see
  docs/Phase4A-Expression-Compatibility-Contract.md (behavioral contract) and
  docs/Phase4B-Compatibility-Evaluator.md (migration record).

  Evaluation order (unchanged)
  ----------------------------
  1. Aggregate functions  SUM(…), COUNT(…), AVG(…), MIN(…), MAX(…)
  2. System tokens        [PageNo], [TotalPages], [RowNumber], [Param.Name], [ReportTitle]
  3. Dataset field tokens [FieldName]   → current field value as string
  4. Quoted string literal 'text'
  5. Arithmetic           +, -, *, /    on resolved tokens
  6. Numeric fallback
  7. String fallback

  System tokens (case-insensitive)
  --------------------------------
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
  System.Variants,
  Vittix.Report.Context,
  Vittix.Report.Expression.Mode,
  Vittix.Report.Expression.Language;

type
  TReportExpression = class
  public
    { Legacy-compatible evaluation (default mode). Existing callers use
      this signature; behavior is unchanged (Phase 4B-1 contract) unless
      the context explicitly requests modern mode via
      Context.ExpressionMode = emModern, which the engine sets only for
      reports whose ExpressionLanguageVersion is 1.
      Default(TExpressionContext) yields emLegacy. }
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext): Variant; overload;

    { Additive Phase 4B-2B API: explicit language-mode selection.
      emLegacy behaves exactly like the two-argument overload.
      emModern evaluates with the modern language semantics
      (real precedence, NULL propagation, Kleene logic, functions,
      composable aggregates) and raises EVittixExpressionError on
      parse/semantic failures. }
    class function Evaluate(
      const Expr: string;
      const Context: TExpressionContext;
      AMode: TReportExpressionMode): Variant; overload;

    { Additive validation. emLegacy always validates True (legacy has no
      diagnostics); emModern parses the expression with the modern parser. }
    class function Validate(
      const Expr: string;
      AMode: TReportExpressionMode): Boolean;

    { Maps a report-level ExpressionLanguageVersion to an expression mode.
      Returns False for unsupported values so callers raise a structured
      diagnostic instead of silently upgrading (Section 28). }
    class function ModeFromLanguageVersion(AVersion: Integer;
      out AMode: TReportExpressionMode): Boolean;
  end;

implementation

uses
  Vittix.Report.Expressions.Compat,
  Vittix.Report.Expression.Evaluator;

class function TReportExpression.Evaluate(
  const Expr: string;
  const Context: TExpressionContext): Variant;
begin
  // Context-carried mode: emLegacy by default (see TExpressionContext).
  Result := Evaluate(Expr, Context, Context.ExpressionMode);
end;

class function TReportExpression.Evaluate(
  const Expr: string;
  const Context: TExpressionContext;
  AMode: TReportExpressionMode): Variant;
begin
  if AMode = emModern then
    Result := TModernExpressionEngine.Evaluate(Expr, Context)
  else
    Result := TReportCompatExpressionEvaluator.Evaluate(Expr, Context);
end;

class function TReportExpression.Validate(
  const Expr: string;
  AMode: TReportExpressionMode): Boolean;
begin
  if AMode = emModern then
    Result := TModernExpressionEngine.Validate(Expr)
  else
    Result := True; // legacy mode has no diagnostics
end;

class function TReportExpression.ModeFromLanguageVersion(AVersion: Integer;
  out AMode: TReportExpressionMode): Boolean;
begin
  AMode := emLegacy;
  case AVersion of
    0: begin AMode := emLegacy; Result := True; end;
    1: begin AMode := emModern; Result := True; end;
  else
    Result := False;
  end;
end;

end.