# Phase 4B-2B — Modern Expression Implementation

Status: implemented and hardened. This document records the final
architecture, the hardening pass (cache correctness, fixture corpus,
end-to-end verification, granular diagnostics, migration analyzer), and the
safety guarantees.

**Permanent defaults (do not change):**

* Legacy mode is the permanent default. `TReportExpression.Evaluate(Expr,
  Context)` and `Default(TExpressionContext)` always mean legacy.
* Modern mode requires an explicit report-level opt-in:
  `"ExpressionLanguageVersion": 1` in the `.vrt`.
* No automatic migration occurs — ever. The serializer rejects unsupported
  versions with a load diagnostic (`UNSUPPORTED_EXPRESSION_LANGUAGE`) and
  never upgrades a report silently.
* The frozen legacy reference (`Test.Vittix.Report.ExpressionLegacyReference`)
  remains untouched and authoritative.

## 1. Architecture

```
TReportExpression.Evaluate(Expr, Context)
  └─ Evaluate(Expr, Context, Context.ExpressionMode)
       ├─ emModern  → TModernExpressionEngine.Evaluate
       │                ├─ TExpressionTokenizer.Tokenize   → TArray<TExpressionToken>
       │                ├─ TModernExpressionParser.Parse    → TExpressionNode AST
       │                └─ TModernExpressionEvaluator.Evaluate → TExpressionValue
       └─ emLegacy  → TReportCompatExpressionEvaluator.Evaluate (fail-soft)

TReportModel.ExpressionLanguageVersion (0 = legacy, 1 = modern)
  └─ TReportEngine.ReportExpressionMode → propagated to Ctx.ExpressionMode
  └─ TReportTextExporter.ExportToFile  → ModeFromLanguageVersion fallback to
                                          legacy for unsupported versions
  └─ TReportSerializer: writes the key only when <> 0 (legacy .vrt byte shape
     unchanged); on load: absent → 0, 0 → legacy, 1 → modern, other → error.
```

Units:

| Unit | Role |
|------|------|
| `Vittix.Report.Expression.Mode` | `TExpressionMode = (emLegacy, emModern)` |
| `Vittix.Report.Expression.Language` | Token kinds, value kinds, AST nodes, catalogue, limits |
| `Vittix.Report.Expression.Tokenizer` | Real tokenizer with positions and diagnostics |
| `Vittix.Report.Expression.Evaluator` | Recursive-descent parser + pure evaluator |
| `Vittix.Report.Expression.Diagnostics` | Structured diagnostic codes/records |
| `Vittix.Report.Expression.Migration` | Migration analyzer (analysis only) |

## 2. Cache correctness

The Phase 3 execution-local aggregate cache (`TAggregateCacheEntry` in the
engine) captures the full identity of a modern/legacy aggregate evaluation:

* dataset identity
* expression text — **mode-prefixed** for modern (`#1'MODERN'#1`), so legacy
  and modern entries can never collide (OD-15)
* group range bookmarks
* page, total pages, row number, counting-pass flag
* parameters and variables (as text)
* dataset `Filter` / `Filtered` state

**Decision (audited, tested): the `Matches()` context identity is sufficient;
no mutation-generation counter was added.** Reasons:

* The cache is execution-local — cleared at the start of every pass
  (`ClearExecutionCaches` in `ExecutePass`), so stale entries cannot survive
  a render.
* `ReportTitle` and `ReportDate` are set once at `Prepare` start and are
  immutable during a pass, so they cannot cause staleness.
* Every supported mutable context input (parameters, variables, filter,
  page/row state, group range) is part of the identity; a change makes the
  old entry unreachable, which is equivalent to invalidation.

Mid-pass **row-data mutation is outside the engine execution contract** and
is not a cache-key input; the engine contract is a stable dataset during a
pass. This is documented and enforced by tests.

Cache tests (`TPhase4B2BModernEvaluatorTests`):

* `Test_Cache_MutationParameterInvalidates` — parameter mutation → new value
* `Test_Cache_MutationVariableInvalidates` — variable mutation → new value
* `Test_Cache_AggregateMutationInvalidates` — filter mutation → re-scan
* `Test_Cache_ModernModeIsolation` — `1 + 2 * 3` = 7 modern vs 9 legacy
* plus the pre-existing Phase 3 cache tests (cursor preservation, per-Prepare
  clearing, legacy isolation)

## 3. Parser error-path memory safety (hardening)

The parser now owns every subtree until `Parse` succeeds. All error exits
that would previously abandon already-built subtrees (`AllocNode` limit
failures, failed sub-parses, paren/arg aborts) free the detached nodes via
`FreeOrphans` before returning `nil`. `Tests Leaked: 0` across the whole
suite, including the new `TooManyNodes` stress test.

## 4. Granular diagnostics

New codes were **appended** to `TExpressionDiagnosticCode` so all previously
published ordinals stay stable. Messages at existing call sites are
unchanged; only the code classification became more precise.

| Code | Raised by |
|------|-----------|
| `UnexpectedToken` | trailing tokens, unexpected `IS`, failed expectations |
| `UnexpectedEndOfExpression` | operand expected, expression ends |
| `InvalidNumber` | `1.` / `.5` literals |
| `InvalidString` | unterminated string literal |
| `InvalidComparison` | number↔text, unordered booleans, invalid operator |
| `NonAssociativeComparison` | `1 < 2 < 3` |
| `ExpressionTooLong` | length > 4096 |
| `ExpressionTooDeep` | parser depth > 32 / eval depth > 128 |
| `TooManyNodes` | AST nodes > 512 / tokenizer guard |

The evaluator now propagates its internal first-error **code** into
`EVittixExpressionError.Code` (previously every evaluation error surfaced as
`EvaluationError`). `TExpressionDiagnostics` classifies all new codes as
errors.

`Test_Modern_DiagnosticCodes` asserts the exact code for each category.

## 5. Modern `.vrt` fixture corpus

`tests/fixtures/modern/` — every `.vrt` in this directory declares
`"ExpressionLanguageVersion": 1` and renders through the normal pipeline:

| Fixture | Proves |
|---------|--------|
| `modern_precedence.vrt` | `1 + 2 * 3` renders **7** (not 9) |
| `modern_arithmetic_composition.vrt` | precedence, parens, unary, division |
| `modern_null.vrt` | `NULL IS NULL` renders True |
| `modern_boolean.vrt` | Kleene: `FALSE AND NULL`=False, `TRUE OR NULL`=True, `[MissingField] IS NULL`=True |
| `modern_null_boolean_contract.vrt` | boolean literals and operators |
| `modern_functions.vrt` | UPPER/LOWER/ABS/IF/COALESCE (lazy args) |
| `modern_aggregate_composition.vrt` | `SUM([Amount]) + 1` renders **36.5** |
| `modern_tokenizer_dataresolution.vrt` | field tokens, `[PageNo]`, `[RowNumber]` |
| `modern_dates.vrt` | `YEAR`/`MONTH`/`DAY` over `[ReportDate]` (OD-18) |

All fixtures are self-contained (no external parameters or named datasets).
The 42 legacy fixtures under `/reports` are untouched and remain legacy (no
version key, no conversion, ever).

## 6. End-to-end verification

`TPhase4B2BEndToEndTests` loads real `.vrt` fixtures through
`TReportSerializer` → `TReportModel` (version = 1) → `TReportEngine` →
modern evaluator → export document, and asserts the rendered text:

* `Test_EndToEnd_ModernPrecedence` — rendered `7` proves modern selection
  (legacy would render 9)
* `Test_EndToEnd_ModernNullSemantics` — rendered `True` for `NULL IS NULL`
* `Test_EndToEnd_ModernAggregateComposition` — rendered `36.5` proves true
  composition (legacy truncates to the bare aggregate)
* `Test_EndToEnd_AllModernFixturesRender` — corpus regression: every fixture
  in `tests/fixtures/modern/` must load with version 1 and render text
  through the engine
* `Test_EndToEnd_TextExporterUsesModernMode` — `TReportTextExporter` honors
  the model's language version (`7` present, legacy `9` absent), and its
  fallback for unsupported versions (safe legacy default) is preserved

## 7. Migration analyzer

`Vittix.Report.Expression.Migration` — `TExpressionMigrationAnalyzer.Analyze
(Expression, Context)` evaluates the expression in **both** modes through the
public API and returns a `TExpressionMigrationAnalysis`:

```
LegacyValue / ModernValue      the two results
LegacyError / ModernError      '' when that mode succeeded
ModernErrorCode                structured modern diagnostic code
Difference                     mdSameResult | mdDifferentResult |
                               mdTypeDifference | mdLegacyOnly |
                               mdModernOnly | mdBothError
```

Classification: both succeed → same NULL → same; Variant types differ →
`mdTypeDifference`; values equal → `mdSameResult`; else `mdDifferentResult`.
Exactly one side succeeds → `mdLegacyOnly` / `mdModernOnly`; both raise →
`mdBothError`. The frozen legacy evaluator is fail-soft, so with the current
evaluator pair `mdModernOnly`/`mdBothError` are unreachable (kept for model
completeness).

**Safety rules (enforced and tested):** the analyzer never rewrites
expressions, never touches `.vrt` files, the serializer, the engine, or the
dataset. It runs on a context **copy with `Hooks := nil`**, so both
evaluators' `Assigned(Hooks)` guards skip the aggregate cache entirely — no
cache read, no cache write (OD-15/OD-16 state untouched). Limitation:
qualified dataset references (`[Name.Field]`) need `Hooks`, so they report
`UnknownDataSet` during analysis; such expressions require manual review.
The caller's context (including `Hooks` and `ExpressionMode`) is never
mutated.

Tests (`TPhase4B2BMigrationAnalyzerTests`): same result (`1 + 2`),
different result (`1 + 2 * 3`: 9 vs 7), type difference (`NULL` text vs
Null; `[NullText]` `''` vs Null), legacy-only (`abc`, `SUM()`), structured
modern codes through the analyzer, caller-context preservation, and
no-cache-interaction proof (zero hits during analysis; subsequent engine
evaluations miss-then-hit as normal).

## 8. Test summary

* Baseline before hardening: 602 DUnitX tests, green.
* Added: 4 cache correctness, 5 end-to-end modern (incl. corpus + exporter),
  1 diagnostic-code, 7 migration analyzer tests.
* Final: **620 tests, 620 passed, 0 failed, 0 errors, 0 leaked.**
* Headless regression: 41 passed, 0 failed, 1 skipped (expected warning
  fixture), all 42 legacy reports render with Vector PDF smoke output.

## 9. Known pre-existing issues (not addressed here)

* `packages/VittixReportRuntime.dproj` and `packages/VittixReportDesign.dproj`
  fail to build because the package search path resolves
  `Vittix.Report.Objects.Barcode.pas` against the QR stub (`stub_qr`),
  which lacks `IQrCode`/`TEcc`/`IQrSegment`. Unrelated to Phase 4B-2B.
* `build_runtime_dpk.ps1` places `param()` after a statement, which is
  invalid PowerShell. Unrelated to Phase 4B-2B.

*(Both were subsequently fixed in Phase 5 — see
`docs/Phase5-Quality-Benchmark-CI.md` §2.1 and §3.5.)*

## 10. OD-18 — date functions (post-4B follow-up)

The only expression item deliberately carried forward from Phase 4B-2A §19.

Implemented, modern mode only, additive and default-off:

| Function | Behaviour |
| --- | --- |
| `YEAR(d)` | four-digit year of a DateTime value |
| `MONTH(d)` | 1–12 |
| `DAY(d)` | 1–31 |

Semantics:

* a real DateTime operand is required. `[ReportDate]`/`[Date]`/`[DateTime]` and
  date dataset fields already resolve to a DateTime value, so this is the normal
  path. A non-date operand (`YEAR(1)`, `YEAR('abc')`, `DAY(TRUE)`) raises
  `InvalidArgument` with the message `… expects a date value` — a diagnosed
  error rather than a locale-dependent guess;
* **NULL propagates** (`YEAR(NULL)` is NULL), per §12.3;
* arity is 1, enforced at parse time;
* like every other scalar function they compose: `YEAR([ReportDate]) + 1`,
  `MONTH([ReportDate]) >= 1 AND MONTH([ReportDate]) <= 12`.

`fnYear`/`fnMonth`/`fnDay` were **appended** to `TExpressionFunction` so all
previously published ordinals stay stable — the same convention used for the
diagnostic codes.

Deliberately still out of scope (4B-2A §19 classed them Future): `DATE(...)`
literals, date arithmetic, and `DATEFORMAT`.

> **Scope note (do not misread).** "Phase 4B-2A fully implemented" means the
> designed modern language is implemented — it does **not** mean all conceivable
> date functionality exists. `DATE(...)` literals, date arithmetic and
> `DATEFORMAT` remain **deliberately classified Future**, not forgotten and not
> owed. They should be implemented only if an actual requirement emerges; they do
> not constitute an unfinished part of this phase.

Tests: `Test_Modern_DateFunctions` (values, composition, NULL propagation,
error cases, arity) plus the `modern_dates.vrt` corpus fixture, which proves the
functions parse and evaluate through the normal serializer → engine → export
pipeline.
