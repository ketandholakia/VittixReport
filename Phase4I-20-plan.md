# Phase 4I-20 Implementation Plan

## Scope and constraints

- Start from `549e0c456389bd0ce79b4499bb7010d3d3f9bd13` on `main`.
- Preserve all unrelated tracked and untracked worktree entries.
- Do not modify regression baselines automatically.
- Keep the Phase 4I-19 characterization files and fixture registrations. Do not delete them.
- Do not retain the old heuristic evaluator as a production fallback.
- Keep `TReportExpression.Evaluate(const Expr: string; const Context: TExpressionContext): Variant` as the rendering compatibility facade.
- No parse cache in this phase unless profiling demonstrates a concrete need; aggregate inner expressions will be parsed once and evaluated per row.

## Existing-engine findings

- `Vittix.Report.Expressions.pas` uses a quote-aware but heuristic scanner, left-to-right arithmetic, no precedence/parentheses/boolean grammar, and partial-evaluation fallbacks.
- `Vittix.Report.Aggregates.pas` reparses the inner expression for every dataset row and only iterates `Context.DataSet`; it ignores `Context.UserDataSet`.
- `TExpressionContext` contains borrowed dataset, bookmark, parameter, variable, page, and pass state. AST nodes must not store any of it.
- Rendering evaluates expressions repeatedly through band/object conditions, text/memo measurement and drawing, barcode/table guards, export, and the designer helper. The public facade must remain exception-safe.
- The existing single-quoted string syntax, system-token aliases, case rules, and safe unresolved-field fallback must be preserved unless a required Phase 4I-20 semantic change is explicitly tested.

## Implementation design

### New unit

Create `source/Vittix.Report.Expression.Parser.pas` containing:

1. `TExpressionTokenKind` and `TExpressionToken` with source positions.
2. `TExpressionLexer` with deterministic scanning, single-quoted strings (including doubled-quote contents), invariant numeric literals, identifiers, references, booleans, NULL, operators, parentheses, commas, and invalid-character diagnostics.
3. Explicit AST classes: literal, reference, unary, binary, and function-call nodes. Nodes retain source positions only and own no context or dataset state.
4. `TExpressionParser` implementing recursive-descent precedence:
   `OR < AND < NOT < comparison < additive < multiplicative < unary < primary`.
5. `TExpressionEvaluator` evaluating an AST against a per-call `TExpressionContext`.
6. Lightweight diagnostics with severity, message, source position, and error code.
7. Optional public `EvaluateWithDiagnostics` overload; the existing `Evaluate` facade remains unchanged and catches all unexpected exceptions.

### Grammar and language

- Support numbers, single-quoted strings, identifiers, `[field]`, `[Param.name]`, `[Parameter.name]`, `[Parameters.name]`, `[variable]`, `TRUE`, `FALSE`, `NULL`, `+ - * /`, unary `+ - NOT`, `= <> != < <= > >=`, `AND OR`, parentheses, commas, and only `SUM COUNT AVG MIN MAX`.
- `!=` is accepted as a synonym for `<>` because it is explicitly required.
- Unknown functions, malformed syntax, invalid characters, and unsupported function arity produce diagnostics and a safe result; they never raise into rendering and never fall back to partial heuristic evaluation.
- Preserve single-quote-only string literals. Do not add double-quoted strings or a new escaping language.
- Parse numeric literals using invariant `.` decimal syntax, not locale-dependent comma parsing.

### NULL and coercion policy

- Represent the NULL literal and NULL dataset values as Variant `Null`, never the string `'NULL'`.
- Use a simple deterministic policy rather than SQL three-valued logic:
  - arithmetic with NULL returns numeric `0`;
  - comparisons involving NULL return Boolean `False`;
  - boolean operations coerce NULL to Boolean `False` and use normal short-circuit rules;
  - aggregate math functions skip NULL values; `COUNT` counts non-NULL values.
- Preserve existing string/numeric coercion for ordinary values and preserve standalone field values such as hyphenated phone numbers.

### Resolution and aggregates

- Move field/system/parameter/variable resolution out of the heuristic scanner into the parser/evaluator layer, reusing `SafeSourceFieldValue`, `SafeSourceFieldAsString`, `SourceActive`, and existing context semantics.
- Preserve system-token aliases and the existing resolution order: system token, UserDataSet field, TDataSet field, then safe zero/empty fallback.
- Implement aggregates as AST function nodes. Parse the argument AST once, then evaluate it for each row.
- For `TDataSet`, preserve bookmark/group-boundary semantics with `try/finally`, disable/enable controls, and safe bookmark handling.
- For `TVittixUserDataSet`, iterate `First/Next/Eof` and resolve fields through `GetValue`; when it wraps a bookmark-capable TDataSet, save and restore the underlying position. Support the context's group bookmarks when the wrapped dataset permits them.
- Keep `TReportAggregates.TryEvaluate` as a compatibility wrapper over the new evaluator, but remove its dependency on `TReportExpression.Evaluate`.

### Public facade and safety

- `TReportExpression.Evaluate` parses and evaluates through the new pipeline.
- Empty input returns `''`.
- All parser/evaluator failures return a safe default (`0` for expression/evaluation errors, `Null` for an unsupported function result if chosen by tests) and populate diagnostics.
- No AST node stores `TExpressionContext`, dataset rows, parameters, variables, bookmarks, or temporary values.
- No old heuristic fallback is used for expressions accepted by the new grammar.

## Test transition

- Keep `tests/Test.Vittix.Report.ExpressionAudit.pas` registered and retained.
- Keep `tests/Test.Vittix.Report.Expressions.pas` and the broader characterization fixture.
- Do not rewrite expectations merely to make the suite green. Update only assertions whose behavior is intentionally changed by the explicit Phase 4I-20 contract (precedence, parentheses, comparisons, boolean operators, aggregate composition, UserDataSet aggregates, explicit NULL, malformed diagnostics), with clear comments documenting the migration.
- Add a focused new fixture, preferably `tests/Test.Vittix.Report.Expression.Parser.pas`, covering lexer tokens/positions, AST shape, parser precedence, evaluator semantics, diagnostics, aggregates, UserDataSet aggregates, NULL, malformed input, unknown functions, and context isolation.
- Add focused consumer tests through existing rendering seams where practical: PrintWhen, conditional styles, text/barcode/table expressions, export, designer helper path, and two-pass TotalPages. Reuse existing report fixtures where possible; do not add unrelated reports or baseline entries without authorization.

## Build and package changes

- Add the new runtime unit to `packages/VittixReportRuntime.dpk` and `packages/VittixReportRuntime.dproj`.
- Add the designer project reference if required by the Delphi project model.
- Add the new test unit to `tests/VittixReportTests.dpr`; add the dproj ItemGroup entry for IDE/project consistency if needed.
- Do not touch unrelated units, scripts, logs, scratch files, environment directories, or regression output.

## Verification sequence

1. Build `tests/VittixReportTests.dproj` Debug/Win32: 0 errors.
2. Run full DUnitX suite and record discovered/passed/failed/errored/skipped.
3. Build runtime package and VittixDesigner Release/Win32: 0 errors.
4. Run the required VittixRunner scenarios: default, strict, `40_export_xlsx.vrt`, `--scripts`, `--script-trace`, JSON, and strict JSON.
5. Compare page counts/output against `reports/regression_baselines.json`; do not update the baseline. Investigate every change to the responsible expression and treat unexplained changes as a blocker.
6. Verify malformed expressions and unknown functions do not raise through consumer paths.
7. Verify aggregate evaluation restores dataset/UserDataSet position and does not retain mutable state between two passes.
8. Perform a separate read-only acceptance audit for lexer correctness, precedence, AST ownership, context isolation, aggregate composition, UserDataSet support, NULL, diagnostics, API compatibility, consumer integration, two-pass safety, and regression output.
9. Repair any material audit finding and rerun affected verification.

## Commit boundary

After the audit passes, stage only Phase 4I-20 source, package, and test files. Create exactly one commit named:

`refactor: replace heuristic expression evaluator with AST`

Do not push.
