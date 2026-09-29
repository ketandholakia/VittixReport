# Phase 4A — Expression Compatibility Contract

Status: characterized. No production expression, cache, layout, serialization,
or public API code changed in this phase.

Phase 4B-1 status: the implementation behind `TReportExpression.Evaluate` was
replaced by the compatibility evaluator in
`Vittix.Report.Expressions.Compat` (migration record:
`docs/Phase4B-Compatibility-Evaluator.md`). This contract was re-run unchanged,
differentially against a frozen copy of the replaced implementation, and is
green. One refinement is recorded there: a lone `[MissingField]` token returns a
Double `0.0` because the fallback text goes through the single-token numeric
path, which `VarToStr` makes indistinguishable from the text form in the table
below.

## Scope and architecture

The sole evaluator entry point is `TReportExpression.Evaluate` in
`Vittix.Report.Expressions`. It is not a tokenizer, AST, or precedence parser.
It performs, in order: aggregate-prefix detection; bracket-token replacement;
comparison scanning; single-quoted literal and boolean-literal handling; a
flat numeric scan; numeric fallback; and string fallback. Aggregate evaluation
is `TReportAggregates.TryEvaluate`, which rescans a `TDataSet` bounded by the
context group bookmarks.

## Confirmed syntax and legacy semantics

| Input | Actual result | Result type |
| --- | --- | --- |
| `1 + 2 * 3` | `9` | Double |
| `10 - 2 * 3` | `24` | Double |
| `(1 + 2) * 3` | `0` | Double |
| `1 + (2 * 3)` | `1` | Double |
| `1 = 1`, `2 <= 2` | `True` | Boolean |
| `'ALICE' = [Name]` | `True` | Boolean |
| `1 = 1 AND 2 = 2` | `False` | Boolean |
| `NOT (1 = 2)` | `False` | Boolean |
| `[MissingField]` | `'0'` | String |
| `[NullText]` | `''` | String |
| `NULL` | `'NULL'` | String |
| `'hello'` | `hello` | String |
| `"hello"` | `"hello"` | String |
| `1 +` | `1` | Double |
| `SUM([Amount]) + 1` | `SUM([Amount])` | Variant numeric |
| `COUNT([NullText])` | counts empty-string token values | Variant numeric |

Comparison searches `<=`, `>=`, `<>`, `=`, `<`, and `>` in that operator-type
order, ignoring operators inside single quotes. Numeric operands are compared
as `Double`; otherwise it performs case-insensitive text comparison. `AND`,
`OR`, `NOT`, and `!=` are not operators. Single quotes are the only string
literal syntax. Arithmetic accepts an optional signed numeric token, uses the
current locale's `TryStrToFloat`, scans left-to-right, ignores division by zero
(leaving the accumulator unchanged), and silently truncates when it cannot
read the next operand.

Bracket tokens are case-insensitive for system tokens and parameters. Supported
aliases include page/row tokens and `Param.`, `Parameter.`, and `Parameters.`.
Variables are looked up in `TStrings`; fields are resolved from the current
dataset after system tokens. A dataset-qualified field token discards the
qualifier and still reads the current dataset.

## NULL, errors, and coercion

There is no NULL literal or propagation model. Literal `NULL` is text. Null
field `AsString` becomes empty text, so it changes aggregate `COUNT` behavior:
the aggregate sees a non-null empty string and counts it. Missing, inactive, or
unavailable field tokens become text `0`. Unknown functions and malformed
aggregate starts fall through to string output; malformed math commonly returns
zero or a partial accumulator. These paths do not raise evaluator exceptions.

## Consumer matrix

| Consumer | Source | Evaluation path | Expected value |
| --- | --- | --- | --- |
| Text, field, label, memo objects | `Expression` or text | `TReportExpression.Evaluate` then `VarToStr` | display text |
| Object visibility | `PrintWhen` | object condition helper | Boolean/coercible value |
| Band visibility | `PrintWhen` | engine condition coercion | Boolean/coercible value |
| Conditional colours | font/background/border conditions | object condition helper | Boolean/coercible value |
| Barcode and table rendering | `PrintWhen` / expression text | object helpers | text/Boolean |
| Text exporter | object expression and `PrintWhen` | export text helper | text/Boolean |
| Aggregates | aggregate inner expression | evaluator called per scanned row | numeric-compatible value |
| Scripts/designer persistence | properties assigned by adapter/serializer | evaluated later by the paths above | expression text |

No expression evaluation was found in grouping or sorting logic; grouping reads
its configured field directly. Preview and export share the engine/object
paths above.

## Real `.vrt` inventory

The checked-in fixtures use simple bracket fields (`[CustomerName]`, `[Qty]`),
system rows (`[RecNo]`), arithmetic (`[Qty] * [Rate]`), comparisons
(` [Amount] > 1000`, `[GroupName] = 'Labels'`), `PrintWhen` booleans
(`0`, `1`, `true`, `false`, `abc`), missing-field probes, runtime parameters
(`[Param.ReportTitle]`, `[Param.AmountInWords]`), and report variables
(`[CompanyName]`). Representative fixtures are 17–22, 25–28, 31, 34, and 37.
No checked-in fixture was changed.

## Compatibility requirements

### MUST PRESERVE

- Ordered resolution and all bracket-token fallback behavior.
- Flat, left-to-right arithmetic; unsupported parentheses and boolean keywords.
- Case-insensitive string comparisons and single-quoted literal handling.
- Aggregate-prefix early return, including composed-expression truncation.
- Silent malformed-expression fallback and current Variant result forms.

### MUST CHARACTERIZE FURTHER

- Date/currency locale effects and all provider-specific null conversions.
- Grouped aggregate behavior with nested group ranges.
- Object/band condition coercion for every Variant type.
- Script-driven mutation during a rendering pass.

### CANDIDATES FOR FUTURE IMPROVEMENT

Operator precedence, parentheses, true NULL semantics, Boolean logic, `!=`,
structured errors, and aggregate composition are deliberately deferred.

## Phase 3 cache interaction

The aggregate cache remains compatible with confirmed stable inputs: dataset,
expression text, group bookmarks, page/pass/row metadata, parameters,
variables, and dataset filter state are keyed. It must remain execution- and
pass-local.

One Phase 4B investigation remains: `ReportTitle` and report date are visible
to the evaluator but are not cache-key fields. They are stable in normal engine
execution, but a script that mutates report state between evaluations could
make a numeric aggregate using such a token stale. This phase documents the
possibility and does not alter the cache.

## Future evaluator boundary

Do not introduce an abstraction yet. A replacement must first preserve the
existing `Evaluate(const Expr; const Context): Variant` boundary, consume the
same dataset, bookmark range, page/pass, parameter, variable, and report
metadata context, and delegate aggregate range evaluation explicitly. Phase 4B
should add a compatibility-mode evaluator behind that existing entry point,
with the Phase 4A tests as its contract.

## Phase 4B-1 implementation status

Implemented as described above. The boundary is unchanged
(`TReportExpression.Evaluate`), the compatibility evaluator sits behind it, and
the public class, properties, registration, serializer format and `.vrt` schema
are untouched. All Phase 4A tests pass unchanged, the legacy behavior is
additionally locked by a differential harness and by an end-to-end
`VittixRunner` fixture comparison, and the deferred improvement list in this
document (precedence, parentheses, Boolean logic, `NULL`, `!=`, structured
errors, aggregate composition) is still deferred. See
`docs/Phase4B-Compatibility-Evaluator.md` for evidence, test counts and the
remaining open items.
