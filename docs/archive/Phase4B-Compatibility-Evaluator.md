# Phase 4B-1 — Compatibility Expression Evaluator Replacement

Status: implemented. The evaluation implementation behind
`TReportExpression.Evaluate` was replaced by a compatibility evaluator that
reproduces the Phase 4A contract. No public API, `.vrt` schema, serializer,
designer, rendering, printing, pagination, export, or cache behavior changed.

## 1. Objective

Replace the internal implementation of the single expression entry point

```pascal
TReportExpression.Evaluate(const Expr: string;
  const Context: TExpressionContext): Variant
```

while preserving the behavior characterized in Phase 4A
(`docs/Phase4A-Expression-Compatibility-Contract.md`). The objective was
**equivalence, not improvement**: the new implementation must behave exactly
like the implementation it replaces, including its deliberate legacy
limitations. Modern expression semantics were explicitly out of scope.

## 2. Architecture

```text
consumers (objects, bands, engine, text export, aggregates)
        |
        v
TReportExpression.Evaluate            Vittix.Report.Expressions.pas  (facade)
        |
        v
TReportCompatExpressionEvaluator.Evaluate
                                      Vittix.Report.Expressions.Compat.pas
        |
        +--> aggregate prefix detection + delegation to TReportAggregates
        +--> ordered bracket-token resolution (system/parameter/variable/field/fallback)
        +--> comparison scanning (<= >= <> = < >, quote-aware)
        +--> single-quoted literal and true/false literal handling
        +--> flat left-to-right arithmetic scanner
        +--> numeric and string fallbacks
```

* `Vittix.Report.Expressions.pas` is now a thin, stable boundary. It keeps the
  public class, the public signature, and the documented behavior, and its only
  implementation statement is the delegation call.
* `Vittix.Report.Expressions.Compat.pas` (new) holds the compatibility
  evaluator: one internal class plus unit-level helpers in its implementation
  section. `TReportCompatExpressionEvaluator` is public only so the facade and
  the test-only differential harness can reach it; it is not part of the report
  API.
* No other unit changed. Every consumer still calls
  `TReportExpression.Evaluate`; a repository-wide search confirmed no unit
  defines a second evaluator or calls the compatibility class directly.

Dependency shape: `Aggregates` (interface) uses `Expressions` for the
inner-expression evaluation, `Expressions` (implementation) uses
`Expressions.Compat`, and `Expressions.Compat` (implementation) uses
`Aggregates`. The cycle passes through implementation sections only, which is
the pattern the unit already used before this phase.

Internal scanning helpers added in this phase:

* `ExpandBracketTokens` — one deterministic left-to-right scan over the raw
  expression text (`TStringBuilder` output, same concatenation order as the
  legacy character loop).
* `TCompatArithmeticScanner` — a value-type cursor for the flat numeric form
  (`ReadNumber` / `ReadOperator`), so an evaluation allocates no scanner heap
  object.
* `FindComparisonOperator` / `CompareOperands` / `TryEvaluateComparison`.
* `TryResolveContextToken`, `ResolveTokenText`, `FieldNameFromToken`,
  `TryResolveParameter`, `ZeroFallback`.

Per-evaluation heap allocation: one `TStringBuilder` per evaluation that reaches
token expansion, freed in a `finally`. No optimization work was performed in
this phase.

## 3. Compatibility strategy

1. The pre-change implementation was frozen verbatim as a test-only reference
   (`tests/Test.Vittix.Report.ExpressionLegacyReference.pas`) before the
   replacement, so equivalence could be measured rather than assumed.
2. The replacement was written as an independent implementation of the same
   rules — same stage order, same predicates, same helper calls
   (`TryGetField`, `SourceActive`, `SafeSourceFieldAsString`,
   `TReportAggregates.TryEvaluate`, `TryStrToFloat` with the current locale),
   same fallbacks — but with the fragile per-character string replacement
   replaced by explicit scanners.
3. A differential harness evaluates the same expression with both
   implementations and compares Variant type, Variant value, and failure
   behavior (section 5).
4. Every Phase 4A expectation was re-run unchanged through the real consumers.
5. Representative `.vrt` fixtures were executed end-to-end through the real
   headless runner, and the exported artifacts were compared byte-for-byte
   against a pre-change baseline.

## 4. Supported legacy semantics

The full contract is `docs/Phase4A-Expression-Compatibility-Contract.md`. The
replacement reproduces it as follows, and the tests in section 10 lock each
item:

| Area | Preserved behavior |
| --- | --- |
| Arithmetic | Flat, strictly left-to-right; no operator precedence (`1 + 2 * 3` = 9, `10 - 2 * 3` = 24) |
| Signed numbers | Optional leading sign per operand (`-5 + 3` = -2) |
| Division | Division by zero leaves the accumulator unchanged (`10 / 0` = 10) |
| Malformed arithmetic | Unreadable operand truncates the expression and returns the partial accumulator (`1 +` = 1); a leading non-number yields 0 |
| Parentheses | Not parsed; `(1 + 2)` = 0, `1 + (2 * 3)` = 1, `((1))` stays the text `((1))` |
| Comparisons | `<=`, `>=`, `<>`, `=`, `<`, `>` searched in that order while ignoring single-quoted regions; Boolean Variant result |
| Comparison typing | Both sides numeric as `Double`, otherwise case-insensitive text comparison |
| Boolean keywords | `AND`, `OR`, `NOT`, `!=` are not operators; their characterized results are asserted (`1 = 1 AND 2 = 2` = False, `1 != 2` = False) |
| Literals | Single quotes are the only string literal syntax; doubled quotes become one quote; `"` characters stay literal; `NULL` is the text `NULL` |
| Boolean literals | `true` / `false` (case-insensitive) as Boolean Variants |
| Fields | Current-row field values; null field `AsString` is empty text; missing field falls back to the text `0` |
| Qualified tokens | `[DataSet.Field]`, `[DataSet."Field"]`, `[DataSet.'Field']` discard the qualifier |
| Unterminated tokens | `[ID` consumes and resolves the remaining text as the token name |
| Parameters | `Param.`, `Parameter.`, `Parameters.`; case-insensitive; a missing parameter is empty text (not `0`) |
| Variables | `TStrings` lookup, `IndexOfName` / `Values` semantics, case-insensitive by default |
| System tokens | Page/row aliases, `ReportTitle`, `ReportDate`/`Date`, `DateTime`, `Time`, `RecNo`/`RowNumber`/`Line`/`Line#` with the dataset `RecNo` fallback |
| Result forms | Double for numeric, Integer for `COUNT`, Boolean for comparisons/literals, UnicodeString for text |
| Aggregate prefix | Matched case-insensitively on the raw, untrimmed text; success returns immediately, so `SUM([Amount]) + 1` never evaluates `+ 1` |
| Errors | No evaluator exception model; malformed input returns partial/zero/text |

One refinement of the Phase 4A wording, observed and locked in Phase 4B-1: a
*lone* unresolved token (`[MissingField]`) takes the single-token value path, so
the fallback text `0` is converted to a **Double 0.0**; the text form `'0'`
appears when the token is part of a larger expression that does not go numeric.
Phase 4A asserted the string form through `VarToStr`, which is identical for
both, so the distinction was previously unobservable.

## 5. Differential testing

`tests/Test.Vittix.Report.Phase4B.pas` contains a compatibility harness that
evaluates one expression with `TReportLegacyReferenceExpression.Evaluate`
(frozen legacy copy) and with `TReportExpression.Evaluate` (replacement) on the
same context, then asserts:

* identical failure/exception behavior (both messages are reported on mismatch),
* identical `VarType` of the result,
* identical `VarToStr` value.

The corpus (~180 expressions) covers arithmetic, parentheses, every comparison
operator, unsupported Boolean operators, `!=`, fields (including missing, null,
qualified, repeated, unterminated), parameters (all three prefixes, mixed case,
missing), variables, every system token, string literal forms, `NULL`, boolean
literals, all five aggregates, malformed aggregate shapes, and empty/whitespace
input. The same harness is applied to the expression strings discovered in the
representative `.vrt` fixtures.

Result: no divergence — the harness reported agreement for every expression,
including the malformed and unsupported forms.

Known scope limit: the harness cannot differentiate the aggregate *inner*
expression, because `TReportAggregates.TryEvaluate` always evaluates its inner
text with the production evaluator (one shared code path, by design). Inner
texts are compared directly instead (for example `[Qty] * [Rate]`), and the
aggregate stage itself is a single shared implementation used identically by
both outer evaluators.

The differential harness is test-only. There is no production
double-evaluation path and no runtime switch.

## 6. Consumer verification

Verified through real consumer paths, not only direct evaluator calls:

| Consumer | Source | Verification |
| --- | --- | --- |
| Text, field, label objects | `Vittix.Report.Objects` `ResolveDisplayText` | Field, arithmetic, missing-field and embedded-token text |
| Object `PrintWhen` | `ShouldPrintObject` | `1 = 1`, `1 = 0`, `[Qty] > 5`, `[MissingField] > 0`, `1`, `0`, `true`, `false`, `abc`, empty |
| Band `PrintWhen` | `Vittix.Report.Engine` band evaluation | Engine render with captured export commands: 3 rows printed vs 0 rows suppressed |
| Conditional colors | `TReportTextObject.ResolveTextStyle` | True/false font, background and border conditions |
| Band background condition | `TReportBand.Draw` path | Exercised by the engine render and by the fixture expression corpus |
| Text exporter | `Vittix.Report.Export.Text` | Header parameter token and per-row field values in the exported text |
| Barcode `PrintWhen` | `Vittix.Report.Objects.Barcode` | Engine render: commands captured when true, none when false |
| Aggregate inner expression | `TReportAggregates.TryEvaluate` | `SUM/COUNT/MIN/MAX([Qty] * [Rate])` evaluated per row |
| Aggregate in a report band | Engine summary band | `SUM([Amount])` rendered into a summary text command |
| Phase 3 aggregate cache | `TReportEngine` hooks | Evaluation counts, cache hit/miss, single traversal, cursor preserved |

## 7. Aggregate and cache integration

Aggregate evaluation is unchanged: the evaluator detects the prefix and calls
the existing `TReportAggregates.TryEvaluate`. Cache lookup, storage, bookmark
scanning and cursor restoration remain inside `TReportAggregates` and
`TReportEngine`. No caching logic moved into the new evaluator and no cache key
was broadened.

The Phase 3 cache still behaves exactly as characterized: repeated
`SUM([Amount])` on one context performs one traversal, reports one miss and one
hit, visits every row once, and leaves the caller cursor where it was. This is
asserted in `Test_Aggregate_Phase3Cache_RepeatedEvaluation_AndCursor`.

Unresolved Phase 4A dependency (documented, not changed): `Context.ReportTitle`
and `Context.ReportDate` are evaluator inputs but are not aggregate cache-key
fields. They are stable during normal engine execution; a script that mutates
report metadata inside a counting/rendering pass could still make a numeric
aggregate that references such a token stale. Phase 4B-1 deliberately does not
broaden the key.

## 8. Known limitations

* All legacy limitations in Phase 4A are preserved deliberately (section 9).
* The differential reference is a transcription of the pre-change algorithm.
  Its authority comes from being a verbatim copy of the replaced file, reviewed
  line by line; it is not an independent oracle.
* The harness cannot differentiate aggregate inner expressions (section 5).
* One `TStringBuilder` is allocated per evaluation that reaches token
  expansion. This was not tuned; the phase traded a micro-allocation for
  reviewable, non-quadratic scanning.
* `packages/VittixReportRuntime.dproj` does not declare the QR library search
  path in this environment, so a plain package build fails in
  `Vittix.Report.Objects.Barcode.pas` regardless of this phase. Supplying
  `DCC_UnitSearchPath` with `source\ThirdParty\QRCodeGenLib\...` makes the
  package build cleanly. This is a pre-existing project-file gap, untouched.

## 9. Deferred semantic improvements

Not implemented in Phase 4B-1, by instruction:

* operator precedence,
* conventional parentheses,
* Boolean operators `AND`, `OR`, `NOT`,
* inequality `!=`,
* a NULL literal and NULL propagation/coercion semantics,
* structured/typed evaluator errors (the silent-fallback model is kept),
* aggregate composition (`SUM([Amount]) + 1` still truncates after the
  aggregate),
* expression compilation / AST / parsed-expression caching,
* evaluator performance work.

## 10. Test results

Environment: Delphi 12 (Studio 23.0), Win32, Debug, tests executed from the
repository root.

| Run | Discovered | Passed | Failed | Errors |
| --- | ---: | ---: | ---: | ---: |
| Baseline before the replacement | 527 | 527 | 0 | 0 |
| After the replacement (564 = 527 + 37 new Phase 4B tests) | 564 | 564 | 0 | 0 |

Environment notes:

* The Phase 4B brief predicted `527 discovered / 505 passed / 0 failed / 22
  XLSX errors`. That expectation did **not** reproduce here: this environment
  reports 527/527 with no XLSX `Access is denied` errors. The XLSX export tests
  (`Test.Vittix.Report.Export.XLSX`) all passed, and no fixture was blocked.
* One environment condition is separately identified and unrelated to this
  phase: invoking the test executable from `tests\` instead of the repository
  root fails exactly one test,
  `Test.Vittix.Report.Phase1...Test_VRT_AllBundledFixtures_LoadSaveReload_PreserveModelShape`,
  with `Could not locate the repository reports directory.` The suite must be
  run from the repository root.
* No XLSX-export `Access is denied` error was observed in either the baseline or
  the post-change run, so nothing had to be classified as a known XLSX
  environment error.

New Phase 4B fixtures: 37 tests (1 differential corpus, arithmetic, parentheses,
comparisons, unsupported operators, fields, parameters, variables, system
tokens, strings, aggregates, aggregate cache, malformed input, five consumers,
and two `.vrt` fixture tests).

Builds performed:

| Project | Result |
| --- | --- |
| `tests/VittixReportTests.dproj` (Debug/Win32) | clean build, 0 errors |
| `VittixRunner.dproj` (Debug/Win32, Clean;Rebuild) | clean build, 0 errors |
| `vittixdesigner/VittixDesigner.dproj` (Debug/Win32) | clean build, 0 errors, no designer change needed |
| `packages/VittixReportRuntime.dproj` (Debug/Win32) | builds cleanly when the QR library search path is supplied (see section 8) |

## 11. `.vrt` fixture verification (end-to-end)

`VittixRunner` (the repository's headless regression runner) was built from the
pre-change sources and from the post-change sources, and executed twice with
`--keep-vector-pdf`, each run writing its exports to a separate directory.

| Comparison | Result |
| --- | --- |
| Runner stdout (42 report result lines, page counts, PASS/SKIP, GDI deltas; elapsed-ms normalized) | identical |
| Exported artifacts | 42 of 43 byte-identical; the only difference is `40_export_xlsx.vrt.xlsx`, whose OOXML parts are identical and which also differed between two runs of the *same* pre-change binary (archive timestamp metadata only) |
| Runner summary | 41 passed, 0 failed, 1 skipped before and after (`16_large_preview_warning.vrt` is skipped by design) |

Representative fixtures were also exercised inside the suite
(`Test_Fixtures_RepresentativeReports_*`): 17, 18, 20, 21, 22, 25, 26, 27, 28,
31, 34, 37. Each is loaded read-only, its `PrintWhen` / `Expression` / embedded
token text / band `BackColorCondition` strings are put through the differential
harness, and it is rendered through the engine with export capture. Each fixture
file's MD5 is taken before and after the test to prove the test did not modify
it. No `.vrt`, `reports/`, or serializer file changed in this phase.

## 12. Files changed

| Path | Change |
| --- | --- |
| `source/Vittix.Report.Expressions.Compat.pas` | new — compatibility evaluator |
| `source/Vittix.Report.Expressions.pas` | rewritten as the boundary facade (public API unchanged) |
| `packages/VittixReportRuntime.dpk` | +1 line: the new compatibility unit added to `contains` |
| `tests/Test.Vittix.Report.ExpressionLegacyReference.pas` | new — frozen legacy reference (test-only, not in the runtime package) |
| `tests/Test.Vittix.Report.Phase4B.pas` | new — Phase 4B compatibility, differential, consumer and fixture tests |
| `tests/VittixReportTests.dpr` | +2 units registered in the test project |
| `docs/Phase4B-Compatibility-Evaluator.md` | this document |

Untouched: `.vrt` files and `reports/`, serializer, model, engine, bands,
objects, aggregates, context, renderer, preview, print, exports, designer, and
all Phase 1/2/3/4A work in the working tree.

## 13. Risks, open items and Phase 4B-2 recommendation

Remaining compatibility uncertainty:

* Low. The differential corpus is broad but not exhaustive; exotic
  locale-dependent numeric input (for example mixed `,`/`.` forms) is compared
  behaviourally, not per locale.
* The aggregate inner-expression path cannot be differentiated (section 5); the
  aggregate stage is shared, so equivalence there is structural rather than
  measured.
* The aggregate cache key still omits `ReportTitle` / `ReportDate`
  (section 7) — unchanged and unresolved.
* `TStringBuilder` per-evaluation allocation was not measured for throughput;
  no regression was observed (runner page counts and pass/fail identical), but
  no benchmark was run.

Recommendation for Phase 4B-2: the replacement can proceed to legacy removal
(deleting `tests/Test.Vittix.Report.ExpressionLegacyReference.pas` and keeping
the differential corpus assertions as pure contract tests) once the project
decides it no longer wants the frozen oracle. A **modern/opt-in expression
semantics** phase is viable as a separate, explicitly opted-in mode, because:

* the evaluator now lives behind a single boundary and all consumers were shown
  to route through it;
* the legacy contract is executable and fully green, so a modern mode can be
  added beside it without silently changing existing reports;
* the remaining blockers are design decisions, not compatibility risk:
  precedence/parentheses/Boolean operators, NULL semantics, structured errors,
  aggregate composition, and the aggregate cache-key question.

Phase 4B-1 deliberately does not start that work: the new evaluator earned its
place by reproducing the old behavior, not by improving it.



