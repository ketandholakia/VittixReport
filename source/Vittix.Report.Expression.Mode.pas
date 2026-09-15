unit Vittix.Report.Expression.Mode;

{
  Vittix.Report.Expression.Mode
  =============================
  Phase 4B-2B: the expression-language mode carrier.

  This unit has NO dependencies on purpose: it is referenced by the
  low-level context record (Vittix.Report.Context), the language core
  (Vittix.Report.Expression.Language) and the public facade
  (Vittix.Report.Expressions) without introducing a unit cycle.

  emLegacy is the FIRST value, so a Default(TExpressionContext) - i.e. an
  existing caller - always evaluates in legacy mode.  Modern mode is an
  explicit opt-in (report-level ExpressionLanguageVersion = 1).
}

interface

type
  TExpressionMode = (emLegacy, emModern);

  { Approved public alias (Phase 4B-2A OD-9). }
  TReportExpressionMode = TExpressionMode;

implementation

end.