Phase 4B-2B Modern .vrt Fixture Corpus
======================================

Every .vrt file in this directory is a MODERN-mode report: it declares
"ExpressionLanguageVersion": 1 and is loaded through the normal
TReportSerializer pipeline, where the version flows into
TReportEngine.ReportExpressionMode and selects the modern expression
evaluator at render time.

The legacy corpus (42 compatibility reports under /reports) intentionally
does NOT carry the version key and must never be converted: legacy mode
remains the permanent default and modern mode is explicit opt-in only.

Fixtures (all self-contained: no external parameters or named datasets):

  modern_precedence.vrt                 1 + 2 * 3 renders as 7 (modern precedence)
  modern_null.vrt                       NULL IS NULL renders as True
  modern_aggregate_composition.vrt      SUM([Amount]) + 1 renders as 36.5 (true composition)
  modern_boolean.vrt                    Kleene logic: FALSE AND NULL = False,
                                        TRUE OR NULL = True, [MissingField] IS NULL = True
  modern_functions.vrt                  UPPER/LOWER/ABS/IF/COALESCE with lazy args
  modern_tokenizer_dataresolution.vrt   field tokens, [PageNo], [RowNumber]
  modern_null_boolean_contract.vrt      TRUE AND TRUE, NOT FALSE, FALSE OR TRUE, 1 < 2
  modern_dates.vrt                      YEAR/MONTH/DAY over [ReportDate] (OD-18)
                                        (values follow the render date; the assertion
                                         of exact semantics lives in
                                         Test_Modern_DateFunctions)

Regression: Test.Vittix.Report.Phase4B2B.TPhase4B2BEndToEndTests loads every
fixture in this directory through the serializer + engine and asserts
modern rendering (Test_EndToEnd_AllModernFixturesRender).
