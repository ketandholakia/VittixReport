# Phase 4B-2A — Modern Expression Semantics Design & Compatibility Strategy

Status: **design specification only**. No production code, `.vrt` file, serializer,
evaluator, engine, designer, rendering, print, export, public API or cache was
changed in this phase. The only repository artifact added is this document.

Audience: the implementers of Phase 4B-2B (modern evaluator) and the project
owners who must approve the open decisions in section 29.

How to read this document:

* Sections 1–4 frame the boundary and the constraints.
* Sections 5–19 define the proposed modern language.
* Sections 20–23 define how it coexists with legacy reports (the core risk
  control), the `.vrt` strategy, the designer and migration.
* Sections 24–27 define the future implementation shape, cache, performance and
  safety envelope.
* Sections 28–30 define the test matrix, the open decisions and the phase plan.
* Appendix A is the required decision table, Appendix B the example corpus that
  will become tests, Appendix C the repository evidence index.

All statements about current behavior are grounded in the units and tests listed
in Appendix C, not in assumptions.

## 1. Executive Summary

VittixReport now has exactly one expression entry point,
`TReportExpression.Evaluate(Expr, Context): Variant`, protected by an executable
legacy contract (Phase 4A), a compatibility implementation (Phase 4B-1), a
frozen legacy reference plus a differential harness, and an end-to-end fixture
baseline. 564 tests pass, 0 fail.

The legacy language is, by design, a report-friendly but semantically weak
mini-language: flat left-to-right arithmetic, no operator precedence, no working
parentheses, no Boolean operators, no `!=`, no real NULL, aggregate-prefix
truncation, locale-dependent numeric parsing, and silent fallbacks. The
repository already contains an audit unit
(`Test.Vittix.Report.ExpressionAudit`) with 31 tests whose names all end in
`_CurrentBehavior`, i.e. the project has already formally recorded these as
defects it does not want to keep forever. The designer also already *advertises*
a function that does not exist: the expression editor label reads
`Enter dynamic expression (e.g. IF(<Dataset.Value> < 0, clRed, clBlack))`.

This document specifies a modern expression language that fixes those defects
without touching a single existing report:

1. **A real language**: tokenizer → recursive-descent parser → immutable AST →
   evaluator, with a conventional precedence table, real parentheses, Boolean
   logic, `!=`, a NULL model, a small typed function set, and true aggregate
   composition.
2. **A hard compatibility boundary**: `TReportExpression.Evaluate(Expr, Context)`
   keeps legacy semantics *forever*. Modern semantics are reachable only through
   an explicitly mode-carrying path, and the mode's zero value is legacy, so any
   call site that was not deliberately migrated stays legacy by construction.
3. **Template-level selection**: the mode is declared in the report
   (`"ExpressionLanguageVersion": 1`), defaulting to legacy when absent, which
   is true for all 42 checked-in reports.
4. **Measured migration risk**: this phase evaluated all 75 non-empty
   expressions in the checked-in fixture corpus under both semantics. 74 of 75
   produce identical *rendered* results; exactly one (`[MissingField] + 1`)
   differs visibly. No report changes its page count.
5. **Reuse of existing infrastructure**: the `.vrt` `Version` mechanism,
   unknown-key tolerance, unknown-object preservation, `TReportLoadResult`
   diagnostics, the whitelisted script-command dispatcher, the engine-owned cache
   pattern and the `IReportRenderHooks` interface are reused rather than
   reinvented.

The recommended Phase 4B-2B scope is deliberately small: a parser/evaluator, a
closed function catalogue, aggregate composition, structured diagnostics, an
additive evaluator overload, an additive context field, and an additive `.vrt`
key — all default-off, with the legacy path unchanged.

## 2. Current Legacy Boundary

### 2.1 Authoritative sources

| Artifact | Role |
| --- | --- |
| `source/Vittix.Report.Expressions.pas` | Public boundary `TReportExpression.Evaluate`; delegates; no other public member |
| `source/Vittix.Report.Expressions.Compat.pas` | Compatibility implementation (Phase 4B-1): 9 ordered stages |
| `source/Vittix.Report.Aggregates.pas` | `TReportAggregates.TryEvaluate` — the only aggregate traversal |
| `source/Vittix.Report.Context.pas` | `TExpressionContext` and `IReportRenderHooks` |
| `source/Vittix.Report.Utils.pas` | `TryGetField`, `SourceActive`, `SafeSourceFieldValue/AsString`, `ConditionVariantToBool` |
| `docs/Phase4A-Expression-Compatibility-Contract.md` | Behavioral contract (`MUST PRESERVE` list) |
| `docs/Phase4B-Compatibility-Evaluator.md` | Migration record, differential and end-to-end evidence |
| `tests/Test.Vittix.Report.Phase4A.pas`, `Test.Vittix.Report.Phase4B.pas`, `Test.Vittix.Report.ExpressionLegacyReference.pas` | Executable contract + frozen oracle |
| `tests/Test.Vittix.Report.ExpressionAudit.pas` | 31 `_CurrentBehavior` tests — the project's own defect list |
| `vittixdesigner/Frm.ExpressionHelper.pas`, `Frm.ExpressionEditor.pas` | Current authoring UX and its templates |
| `reports/*.vrt` (42 files) | Real-world usage corpus (`"Version": 2`) |

### 2.2 Legacy evaluation order (unchanged, must stay reachable forever)

```text
1  aggregate prefix SUM( COUNT( AVG( MIN( MAX(  → TReportAggregates.TryEvaluate
                                                 → on success: immediate return (truncates tail)
2  bracket-token expansion:  system token → [Param.|Parameter.|Parameters.] →
                            report variable → dataset field → text '0'
3  single lone token  → value lookup (numeric if parseable, else text)
4  comparison (<= >= <> = < > in that order, quote-aware, numeric-as-Double
              else case-insensitive text)
5  single-quoted literal
6  true / false literals
7  flat left-to-right arithmetic (+ - * / with signed operands, /0 no-op)
8  numeric fallback (current locale)
9  string fallback
```

### 2.3 Legacy characteristics that bound the modern design

Measured from source, tests and fixtures during this phase:

| Observation | Evidence |
| --- | --- |
| 42 reports, all `"Version": 2`, no expression-language key anywhere | `reports/*.vrt` |
| 75 non-empty expressions total (Expression + PrintWhen + condition properties); **max length 22 chars, mean 10.4** | fixture scan |
| Only 11 distinct `Expression` values and 10 distinct `PrintWhen` values exist in the whole corpus | fixture scan |
| 112 `Text` values contain embedded `[...]` tokens — embedded-token text is the dominant dynamic-text mechanism | fixture scan |
| No function is used in any fixture | fixture scan |
| The designer's only function-bearing hint is the unsupported `IF(...)` example | `Frm.ExpressionEditor.pas:39` |
| Boolean condition values in practice are `0`, `1`, `true`, `false`, `abc`, and comparisons | `PrintWhen` corpus |
| Aggregate truncation is real and audited (`SUM([Amount]) + 1` → 350; `1 + SUM([Amount])` → 1) | `ExpressionAudit` |
| Aggregates silently do not work over `TVittixUserDataSet` | `ExpressionAudit` (`Audit_Aggregate_UserDataSet_ReturnsLiteralText_CurrentBehavior`) |
| Consumer Boolean coercion is a fixed mapping: `0/false/no/n/off` → False, `1/true/yes/y/on` → True, numeric ≠ 0, Null/empty → False, anything else → False | `Utils.ConditionVariantToBool` |
| Text comparison is case-insensitive; there is no case-sensitive path | `Expressions.Compat.CompareOperands` |
| Numeric parsing uses the current locale (`TryStrToFloat` with no format settings) | compatibility evaluator |
| Named datasets exist and are reachable from the evaluation context | `IReportRenderHooks.GetNamedDataSet`, `TReportEngine.GetNamedDataSet` |
| The script subsystem is already a whitelisted command dispatcher (`Cmd_Printwhen`, `Cmd_Expression`, …), not free-form code | `Vittix.Report.ScriptHost.Adapter` |

### 2.4 Consumers that must keep working unchanged

`TReportTextObject.ResolveDisplayText` (Expression, DataField, embedded `Text`
tokens), memo objects, `ShouldPrintObject`, band `PrintWhen` (engine),
`TReportBand.Draw` `BackColorCondition`, `ResolveConditionalStyle`
(font/background/border conditions), barcode and table object-local `PrintWhen`
helpers, `TReportTextExporter`, `TReportAggregates` inner-expression evaluation,
and the designer preview/check path. Every one of them reads a `Variant` and then
uses `VarToStr` or `ConditionVariantToBool`. **No consumer understands types
beyond those two coercions** — the single most important constraint on the
modern design: modern semantics may change what the evaluator returns, but the
*shape* of the return value must remain consumable by `VarToStr` and
`ConditionVariantToBool`.

## 3. Goals

1. Define a complete, unambiguous modern expression language for VittixReport
   (lexical rules, types, operators, precedence, NULL, functions, aggregates,
   errors, locale, dates, safety, limits).
2. Define a selection mechanism that cannot change the meaning of any existing
   report, and prove that property by construction (mode zero value = legacy;
   the two-argument `Evaluate` is permanently legacy).
3. Define the future architecture (tokenizer/parser/AST/evaluator) and its
   ownership, dependency and cache boundaries, consistent with the existing unit
   graph and the Phase 3 cache.
4. Define a test matrix that a future implementation must satisfy, including a
   compatibility corpus that runs both semantics over the same input and asserts
   the *intended* divergence set explicitly.
5. Quantify the migration surface from real evidence (the 42 fixtures) rather
   than intuition, and define a migration strategy (analyze → attest → convert →
   re-verify, with no silent rewriting).
6. Reuse existing infrastructure (`.vrt` version key, load-result diagnostics,
   hooks interface, engine-owned caches, whitelisted functions) instead of
   inventing parallel mechanisms.

## 4. Non-Goals

* Implementing anything. No tokenizer, parser, AST, evaluator, function, mode
  switch, `.vrt` key, designer change, or test is added by this phase.
* Changing legacy behavior. The compatibility contract is frozen; the modern
  language is an addition, never a replacement.
* Replacing `TReportExpression.Evaluate(Expr, Context)`. Its semantics are now
  part of the product contract.
* A general-purpose scripting or expression runtime (no user-defined functions,
  no statements, no loops, no assignment, no I/O, no object-model access).
* Redesigning the `.vrt` schema, serializer, designer property system,
  rendering, printing, pagination, exports or the Phase 3 cache.
* Fixing unrelated legacy defects (bookmark-less datasets, subreport traversal,
  page retention) — these are Phase 1 GAP items, not expression semantics.
* Full SQL or Delphi-language compatibility. Where SQL and Delphi disagree
  (notably `NOT` precedence) this document chooses for *report readability* and
  records the deviation explicitly.

## 5. Proposed Modern Language

### 5.1 Shape of the language

A modern expression is a single **value expression**: it has no statements, no
side effects, and always produces exactly one value (possibly NULL). Grammar
(recursive descent, EBNF):

```text
expression       := or_expr ;
or_expr          := and_expr ( 'OR' and_expr )* ;
and_expr         := not_expr ( 'AND' not_expr )* ;
not_expr         := 'NOT' not_expr | comparison ;
comparison       := additive ( comp_op additive )? ;            { single, non-associative }
comp_op          := '=' | '<>' | '!=' | '<' | '>' | '<=' | '>=' | 'IS' [ 'NOT' ] 'NULL' ;
additive         := multiplicative ( ('+' | '-') multiplicative )* ;
multiplicative   := unary ( ('*' | '/') unary )* ;
unary            := ('+' | '-') unary | primary ;                { numeric sign only }
primary          := literal
                  | '[' token_ref ']'
                  | identifier '(' [ argument ( ',' argument )* ] ')'
                  | '(' expression ')' ;
argument         := expression ;
literal          := NUMBER | STRING | 'TRUE' | 'FALSE' | 'NULL' ;
token_ref        := system_or_param_or_var_or_field   { see section 14 }
```

Deliberate properties:

* **No comparison chains.** `1 < 2 < 3` is a `SyntaxError`, not a silent
  boolean-versus-number comparison (legacy's `a < b < c` equivalent is exactly
  the class of bug the `ExpressionAudit` unit records).
* **No bare identifiers as fields.** A bare identifier is only legal as a
  function name followed by `(`. `abc` alone is `SyntaxError` (its legacy meaning
  is the literal text `abc`; see section 17 for the lenient fallback that keeps
  fixture behavior identical).
* **No implicit concatenation.** Text is composed with `+` (see section 13).
  The legacy "replace `[...]` inside text and hope for the best" path stays in
  compatibility mode only.
* **Functions are the only callable construct.** No member access, no indexing,
  no `IF` as an operator.

### 5.2 Language elements and their status

| Element | Legacy | Modern proposal |
| --- | --- | --- |
| Number literal | locale `TryStrToFloat`, `,` allowed | invariant `.`, digits only, no separators (section 18) |
| String literal | `'...'`, doubled quote escapes; `"` is literal | identical (`'...'` only; `"` remains a literal character, not a delimiter) |
| Boolean literal | `true` / `false` (case-insensitive) | identical, now first-class in Boolean logic |
| NULL literal | text `'NULL'` | Variant `Null` (section 12) |
| Field reference | `[Name]`, `[Ds.Name]` (qualifier discarded) | identical syntax; qualifier honoured when it names a known dataset (section 14) |
| Parameter | `[Param.X]`, `[Parameter.X]`, `[Parameters.X]` | identical (all three aliases kept) |
| Variable | `[Name]` after system/param resolution | identical, plus an optional explicit `[Var.Name]` alias (section 14) |
| System token | `[PageNo] [TotalPages] [RowNumber] [RecNo] [ReportTitle] [ReportDate] [Date] [DateTime] [Time] [Page] [Page#] [TotalPages#] [Line] [Line#]` | identical set and resolution order |
| Arithmetic | flat L→R | precedence-correct (section 9) |
| Comparison | same operators, case-insensitive text | same operators + `!=` + `IS [NOT] NULL`, typed comparison rules (section 7) |
| Boolean logic | none | `AND`, `OR`, `NOT` (section 11) |
| Parentheses | not parsed | conventional grouping (section 10) |
| Functions | none (only aggregates) | closed catalogue (section 15) |
| Aggregates | prefix-only, truncating | true first-class function calls with composition (section 16) |
| Errors | silent fallback | structured diagnostics + configurable strictness (section 17) |

## 6. Lexical Rules

### 6.1 Token classes

```text
whitespace      space, tab, CR, LF  → separator only, never significant
number          digits with one optional '.'  e.g. 0  42  3.5   (see section 18)
string          '...'  with '' as an escaped quote; no escape sequences
identifier      letter | '_' followed by letters, digits, '_'   (case-insensitive)
bracket token   '[' ... ']'   (contents preserved verbatim; see 6.3)
operators       + - * / = <> != < > <= >= ( ) ,
keywords        AND OR NOT IS NULL TRUE FALSE   (case-insensitive)
```

### 6.2 Case sensitivity

* Keywords and **function names are case-insensitive** (`sum`, `SUM`, `Sum`), to
  match legacy aggregate prefix matching and the designer's templates.
* Field / parameter / variable token names keep their existing resolution
  semantics: system tokens and parameters are case-insensitive, variables use
  `TStrings.IndexOfName` (case-insensitive by default), fields use `TryGetField`.
* String literals are case-sensitive. Text *comparison* is case-insensitive
  (section 13) — this asymmetry is deliberate and matches the legacy contract.

### 6.3 Bracket tokens

Inside `[` … `]` the contents are taken **verbatim** (the bracket syntax is the
compatibility surface and must not be re-lexed). The modern parser does not
tokenize the inside; it resolves it through the same resolution chain as legacy
(section 14). Consequences to preserve deliberately:

* `[Under_Score]` and `[Customers.'Name']` keep working.
* A missing `]` is a `SyntaxError` in modern mode (legacy silently consumed the
  rest of the text — `Test_Fields_RepeatedAndQualifiedTokens` asserts `[ID` → `1`
  in legacy mode).
* `[` and `]` may not be nested.

### 6.4 Whitespace and comments

Whitespace is insignificant outside literals and bracket tokens. **No comment
syntax is proposed** for V1: report expressions are stored inside JSON strings,
are short (maximum 22 characters in the entire checked-in corpus) and benefit
from being trivially round-trippable. If comments become necessary later, `{}` is
the preferred choice (it collides with neither JSON nor the current tokens).

### 6.5 Escape rules

Only one escape exists: `''` inside a single-quoted literal means one quote
(unchanged from legacy). No backslash escapes, no `\n`, no Unicode escapes — a
report string literal cannot introduce control characters, which keeps text
export and HTML/PDF export safe by construction.

### 6.6 Reserved words

`AND`, `OR`, `NOT`, `IS`, `NULL`, `TRUE`, `FALSE` are reserved and cannot be
function names or bare identifiers. Names in the closed function catalogue
(section 15) are reserved in the sense that an unknown name with `(` is an
`UnknownFunction` diagnostic, never a field lookup.

## 7. Type System

### 7.1 Recommended type set — six types, deliberately small

| Type | Variant form produced | Rationale |
| --- | --- | --- |
| `Null` | `varNull` | real absence of a value (section 12) |
| `Boolean` | `varBoolean` | conditions, `PrintWhen`, conditional colors |
| `Number` | `varDouble`; `varInt64` when both operands are integral and the operator preserves integrality (`COUNT`, integer `+ - *`) | every numeric consumer reads `Double`; matches `TryStrToFloat` and float dataset fields |
| `String` | `varUString` | `VarToStr` target; case-insensitive comparison; text export |
| `DateTime` | `varDate` | `[ReportDate]`, `[DateTime]`, date fields, future date functions |
| `Currency` | **not a distinct language type** | currency fields surface as `varCurrency`; the language treats them as `Number` and passes the variant through unchanged where no arithmetic is required |

Rejected alternatives:

* **Decimal/BigDecimal** — the repository has no decimal arithmetic, rounding or
  formatting policy; `FormatFieldDisplayValue` and every exporter operate on
  `Variant`/`Double`. A decimal type would create a second numeric world with no
  consumer.
* **Object/record types** — excluded by the security model (section 27).
* **Set/array types** — needed by no consumer; aggregates return scalars.
* **Int64 as a user-visible type** — kept only as an output nuance (`COUNT`
  currently returns `varInteger`, asserted by `Test_Aggregate_SimpleFunctions`),
  never as a promotion source.

### 7.2 Promotion rules (the decision table for mixed operands)

| Operator class | Left | Right | Result |
| --- | --- | --- | --- |
| `+ - * /` | `Number` | `Number` | `Number` (integrality preserved for `+ - *` of integers; `/` always yields `Number`) |
| `+` | `String` | `String` | `String` — concatenation, no implicit numeric formatting |
| `+ - * /` | `Number` | numeric `String` | `Number` — string converted invariantly after trim; conversion failure ⇒ `InvalidArgument` |
| `+ - * /` | `Number` | non-numeric `String` | `InvalidArgument` (never implicit concatenation) |
| `+ - * /` | any | `Null` | `Null` (propagate) |
| `+ - * /` | `Boolean` / `DateTime` | anything | `InvalidArgument` |
| comparisons | `Number` | `Number` | numeric compare |
| comparisons | `Number` | numeric `String` | numeric compare (string converted) |
| comparisons | `String` | `String` | case-insensitive text compare |
| comparisons | `Number` / `DateTime` / `Boolean` | non-numeric `String` | `InvalidArgument` |
| comparisons | `DateTime` | `DateTime` | chronological compare |
| comparisons | `DateTime` | `Number` | `InvalidArgument` (no implicit epoch) |
| comparisons | any | `Null` | `Null` (UNKNOWN) unless `IS [NOT] NULL` |
| `AND` / `OR` / `NOT` | truthiness of any non-NULL operand | — | `Boolean` (section 11) |

### 7.3 Promotion examples (legacy column measured, not reasoned)

| Expression | Legacy result (measured) | Modern | Why |
| --- | --- | --- | --- |
| `1 + 2.5` | `3.5` (varDouble) | `3.5` | numeric |
| `'10' + 5` | `0` (varDouble) | `15` | numeric-string promotion |
| `'a' + 5` | `0` (varDouble) | `InvalidArgument` → `NULL` | no implicit concatenation |
| `'a' + 'b'` | `a' + 'b` (varUString) | `'ab'` | legacy sees one quoted literal, not a concatenation |
| `1 = '1'` | `True` (varBoolean) | `True` | quotes are stripped, both sides numeric |
| `1 = 'a'` | `False` (varBoolean) | `InvalidArgument` → `NULL` | typed compare |
| `NULL + 1` | `0` (varDouble) | `NULL` | NULL propagation |
| `'5' * '4'` | `5' * '4` (varUString) | `20` | legacy treats it as one quoted literal |
| `[Qty] * [Rate]` (float fields) | `7` (varDouble) | `7` | unchanged |
| `[MissingField]` (lone token) | `0` (varDouble) | `NULL` + `UnknownField` | section 12/17 decision |

The choice in `'10' + 5` is deliberate: many report fields are text-typed (codes,
dates, quantities loaded as text), and silently inventing a number from a
non-numeric string is precisely the legacy trap the compatibility unit documents.
Numeric strings are promoted; non-numeric strings produce a diagnosable error
instead of `0`.

## 8. Operator Table

Legend: `N` Number, `S` String, `B` Boolean, `D` DateTime, `X` Null.

| Operator | Arity | Legacy semantics | Proposed modern semantics | Result type |
| --- | --- | --- | --- | --- |
| `+` | binary | numeric add, flat; ignores non-numbers ⇒ truncation | numeric add when either side is numeric; concatenation when both are `String`; `Null` propagates | `N` / `S` / `X` |
| `-` | binary | numeric subtract, flat | numeric subtract; `Null` propagates | `N` / `X` |
| `*` | binary | numeric multiply, flat | numeric multiply; `Null` propagates | `N` / `X` |
| `/` | binary | numeric divide; `/0` leaves accumulator unchanged | numeric divide; `/0` ⇒ `DivisionByZero` diagnostic, result `NULL` | `N` / `X` |
| `+` (unary) | unary prefix | accepted as a number sign by the scanner | numeric identity; non-numeric operand ⇒ `InvalidArgument` | `N` |
| `-` (unary) | unary prefix | accepted as a number sign | numeric negation; non-numeric operand ⇒ `InvalidArgument` | `N` |
| `=` | binary | numeric-as-`Double`, else case-insensitive text | typed compare (7.2); `Null` operand ⇒ UNKNOWN | `B` / `X` |
| `<>` | binary | `not SameText` / `<>` on numbers | structural negation of `=`; `Null` operand ⇒ UNKNOWN | `B` / `X` |
| `!=` | binary | **not** an operator (degrades to `=` with a `'x !'` left operand) | exact synonym of `<>` | `B` / `X` |
| `<` `>` `<=` `>=` | binary | numeric if both numeric, else `CompareText` | typed compare; text is case-insensitive; mixed number/non-numeric-string ⇒ `InvalidArgument` | `B` / `X` |
| `IS NULL` | postfix pair | not supported | `True` when the operand is `Null`, else `False`; never UNKNOWN | `B` |
| `IS NOT NULL` | postfix pair | not supported | negation of `IS NULL`; never UNKNOWN | `B` |
| `AND` | binary | not an operator | Kleene logic, left-associative, short-circuit | `B` / `X` |
| `OR` | binary | not an operator | Kleene logic, left-associative, short-circuit | `B` / `X` |
| `NOT` | unary prefix | not an operator | Kleene negation, right-associative | `B` / `X` |
| `(` `)` | grouping | literal characters that break the number scan | conventional grouping (section 10) | — |
| `,` | separator | literal character (no function calls exist) | function argument separator | — |

Not proposed for V1: `%` (modulo), `^`/`**` (power), `&`/`|` (bitwise),
`LIKE`, `IN`, `BETWEEN`, `??`. Each is either unjustified by the corpus or
expressible with the catalogue (`LEAST`/`GREATEST`, `CONTAINS`, `STARTSWITH`).

## 9. Precedence and Associativity

### 9.1 Proposed precedence table (highest binds first)

| Level | Operators | Associativity | Notes |
| --- | --- | --- | --- |
| 1 | `[token]`, literals, `func( )`, `( expr )` | — | primaries |
| 2 | unary `+` `-` | right | numeric sign only |
| 3 | `*` `/` | left | |
| 4 | `+` `-` (binary) | left | string concatenation for `+` when both operands are `String` |
| 5 | `=` `<>` `!=` `<` `>` `<=` `>=` `IS [NOT] NULL` | **non-associative** | at most one comparison per expression level; a chain is a `SyntaxError` |
| 6 | `NOT` | right | unary; sits *below* comparison |
| 7 | `AND` | left | short-circuit |
| 8 | `OR` | left | short-circuit |

### 9.2 Why this table and not the literal candidate from the brief

* The candidate table in the brief is essentially this one. It is adopted, with
  one structural correction: `NOT` appears **once**, between `AND` and
  comparison. The pre-existing design note
  `docs/Phase4I-20-ExpressionEngineDesign.md` lists `NOT` twice (both above
  `comparison` and inside the numeric unary level), which makes `NOT 1 + 1`
  ambiguous. A single level removes the ambiguity and keeps `NOT a = b` reading
  as `NOT (a = b)`.
* Comparison is deliberately **non-associative** rather than
  left-associative. Legacy's silent `(a < b) < c` is the worst kind of bug: it
  compares a Boolean with a Number and falls back to text comparison. A
  `SyntaxError` is strictly better than a wrong number on an invoice.
* Unary numeric sign binds tighter than `*` so `-2 * 3` is `(-2) * 3` (= -6),
  which matches both Delphi and user expectation.

### 9.3 Comparison with Delphi and SQL

| Construct | Delphi | SQL | VittixReport modern | Why |
| --- | --- | --- | --- | --- |
| `NOT a = b` | `(NOT a) = b` | `NOT (a = b)` | `NOT (a = b)` | report author intent; `(NOT a) = b` is almost always a mistake in a condition |
| `AND` / `OR` / `NOT` precedence | `and` > `or`, `not` highest | `NOT` > `AND` > `OR` | `NOT` > `AND` > `OR` | matches SQL, which is the vocabulary of report authors |
| comparison chaining `a < b < c` | type error | syntax error | `SyntaxError` | never silently wrong |

### 9.4 Worked examples with expected modern results (legacy column measured)

`A` = `True`, `B` = `False`, `C` = `False` where used.

| Expression | Legacy result (measured) | Modern result | Modern type | Reason |
| --- | --- | --- | --- | --- |
| `1 + 2 * 3` | `9` | `7` | Number | `*` before `+` |
| `10 - 2 * 3` | `24` | `4` | Number | `*` before `-` |
| `(1 + 2) * 3` | `0` | `9` | Number | parentheses |
| `1 + (2 * 3)` | `1` | `7` | Number | parentheses |
| `10 / 2 * 3` | `15` | `15` | Number | left-associative same level |
| `2 - 3 - 4` | `-5` | `-5` | Number | left-associative |
| `-2 * 3` | `-6` | `-6` | Number | unary binds tighter |
| `2 + -3` | `-1` | `-1` | Number | unary sign on operand |
| `1 < 2 AND 3 < 4` | `True` | `True` | Boolean | legacy got it right by luck (`<` is found before `=`) |
| `1 = 1 AND 2 = 2` | `False` | `True` | Boolean | headline behavioural fix |
| `1 = 2 OR 2 = 2` | `False` | `True` | Boolean | same |
| `NOT (1 = 2)` | `False` | `True` | Boolean | `NOT` of a comparison |
| `NOT 1 = 2` | `False` | `True` | Boolean | parsed as `NOT (1 = 2)` |
| `A OR B AND C` | `False` (text compare) | `True` | Boolean | `T OR (F AND F)` |
| `A AND B OR C` | `False` (text compare) | `False` | Boolean | `(T AND F) OR F` |
| `1 + 2 > 2` | `False` | `True` | Boolean | arithmetic before comparison |
| `1 < 2 < 3` | `True` (text compare of `1` vs `2 < 3`) | `SyntaxError` | — | non-associative comparison |
| `1 > 2 < 3` | `True` (text compare) | `SyntaxError` | — | same |
| `SUM([Amount]) + 1` (sum 35.5) | `35.5` | `36.5` | Number | aggregate composition |
| `1 + SUM([Amount])` | `1` | `36.5` | Number | aggregate composition |
| `SUM([Qty]) > 100` | `16` (the aggregate; the tail is discarded) | `False` | Boolean | aggregate inside a comparison |
| `IF(SUM([Amount]) > 1000, 'High', 'Low')` | `True` (text compare of `IF(SUM(10.5)` vs `1000, …`) | `'Low'` | String | aggregate inside a conditional function |

Note on the `A OR B AND C` rows: `A`, `B`, `C` stand for Boolean-valued
tokens/variables. Legacy compares them as text, which is why it can produce
`True` by accident; the modern column is what a precedence-correct parser
produces.

## 10. Parentheses

* Conventional grouping; arbitrary nesting up to the configured depth limit
  (recommended 32, hard cap 128 — section 18/limits).
* `(` `)` are ordinary tokens; the legacy "parentheses break the numeric scan"
  behaviour is confined to compatibility mode.
* Empty parentheses are only legal as a function argument list (`COUNT()`); a
  bare `()` is a `SyntaxError`.
* Unbalanced parentheses are a `SyntaxError` reported with the offending token
  position; legacy instead returned `0`, `1`, or the raw text.

| Expression | Legacy result (measured) | Modern | Modern type |
| --- | --- | --- | --- |
| `(1 + 2) * 3` | `0` | `9` | Number |
| `1 + (2 * 3)` | `1` | `7` | Number |
| `((1 + 2) * 3)` | `0` | `9` | Number |
| `((1))` | text `'((1))'` | `1` | Number |
| `2 * (3 + 4)` | `2` (scan stops at `(`) | `14` | Number |
| `2 * (3 + 4) / 7` | `2` | `2` | Number (coincidentally equal) |
| `(1` | text `'(1'` | `SyntaxError` | — |
| `1)` | text `'1)'` | `SyntaxError` | — |
| `NOT ([Qty] = 1)` | `False` (text compare) | `False` | Boolean |
| `IF(([Qty] + 1) * 2 > 10, 'Y', 'N')` | text `'IF((2 + 1) * 2 > 10, …'` | `'Y'` | String |

## 11. Boolean Semantics

### 11.1 Boolean literals and truthiness

* `true` / `false` (case-insensitive) are Boolean literals — they already exist
  in legacy (`SameText(S, 'true')`), so this is an addition in *use*, not in
  syntax.
* Any non-NULL value can be used where a Boolean is expected; it is coerced by
  **truthiness**, and the definition of truthiness is the repository's existing
  consumer contract `ConditionVariantToBool` (measured mapping):
  `Null`/empty → `False`; Boolean → itself; numeric → `<> 0`;
  `'0' 'false' 'no' 'n' 'off'` (trimmed, case-insensitive) → `False`;
  `'1' 'true' 'yes' 'y' 'on'` → `True`; a numeric string → `<> 0`;
  any other text → `False`.
* Rationale for reusing this mapping rather than inventing a second one: the
  consumers of `PrintWhen` and the conditional-colour properties *already* apply
  it to whatever the evaluator returns, and the checked-in corpus depends on it
  (`PrintWhen` values `0`, `1`, `true`, `false`, `abc`). A modern Boolean model
  that disagreed with the consumers would create two contradictory truths for the
  same property.
* Consequence to document for authors: a non-empty non-numeric string is *false*,
  not true. `[Remarks]` alone is therefore a poor condition; the language
  provides explicit predicates instead (`LEN(TRIM([Remarks])) > 0`).

### 11.2 Operators, precedence, associativity

| Operator | Precedence | Associativity | Evaluation |
| --- | --- | --- | --- |
| `NOT` | 6 (below comparison, above `AND`) | right (unary) | Kleene negation |
| `AND` | 7 | left | short-circuit |
| `OR` | 8 (lowest) | left | short-circuit |

Short-circuit is specified, not incidental:

* The right operand of `AND` is evaluated only when the left operand is `True`;
  the right operand of `OR` only when the left operand is `False`.
* Justification from this repository: aggregate operands are expensive
  (Phase 3 measured one full dataset scan per uncached aggregate; the cache
  exists precisely because of that), and `x / 0` is a real authoring hazard.
  `[Rate] > 0 AND [Qty] / [Rate] > 5` must not scan or divide when the guard
  fails. A strict (non-short-circuit) evaluator would make guards useless.
* Short-circuit also means an `UnknownField` diagnostic in the untaken branch is
  *not* produced. Documented so diagnostics are never read as "the whole
  expression was evaluated".

### 11.3 Kleene three-valued tables (T = True, F = False, U = UNKNOWN)

```text
AND        T   F   U            OR         T   F   U            NOT
T          T   F   U            T          T   T   T            T -> F
F          F   F   F            F          T   F   U            F -> T
U          U   F   U            U          T   U   U            U -> U
```

Rules that fall out of the tables and are worth stating for authors:

* `FALSE AND U` = `FALSE`, `TRUE OR U` = `TRUE` — a definitely-decided operand
  wins (this is the property that makes NULL-safe guards possible).
* `NOT U` = `U` (never `True`).
* `TRUE AND U` = `U`, `FALSE OR U` = `U`.

### 11.4 NULL interaction and the consumer boundary

The evaluator returns a `Variant`; a modern Boolean result is either
`varBoolean` or `varNull` (UNKNOWN). Consumers then coerce with
`ConditionVariantToBool`, where `Null` → `False`. The *specified* meaning is
therefore:

* **UNKNOWN in a condition suppresses the object/band.** This is adopted
  deliberately rather than invented: it is exactly what the existing consumer
  coercion already does for a Null result, it is the conservative choice for
  report output (nothing prints unless the condition is provably true), and it
  keeps `IF(UNKNOWN, a, b)` returning `b` (the "not true" branch) consistent with
  `PrintWhen`. No consumer change is required.
* If the project prefers "UNKNOWN means print" for a specific property, that must
  be an explicit opt-in per property — **not** recommended, because it would make
  a null field print objects that a missing boolean currently suppresses.

### 11.5 Non-Boolean operands

* Numeric and String operands are accepted through truthiness (`[Qty] AND [Flag]`,
  `'true' AND 1`).
* `DateTime` operands are a `TypeError` (a date is not a condition).
* `Null` operands follow the Kleene tables (never coerced to `False` *before*
  the operator, which is the subtle difference from `ConditionVariantToBool`).
  `IS NULL` / `IS NOT NULL` exist so authors can test for null explicitly instead
  of relying on the coercion.

### 11.6 Examples

| Expression | Legacy result (measured) | Modern result | Modern type |
| --- | --- | --- | --- |
| `TRUE AND FALSE` | text `'TRUE AND FALSE'` → consumer-coerced `False` | `False` | Boolean |
| `NOT TRUE` | text `'NOT TRUE'` → coerced `False` | `False` | Boolean |
| `1 = 1 AND 2 = 2` | `False` | `True` | Boolean |
| `1 = 2 OR 2 = 2` | `False` | `True` | Boolean |
| `1 < 2 AND 3 < 4` | `True` | `True` | Boolean |
| `NOT (1 = 2)` | `False` | `True` | Boolean |
| `[Qty] > 1 AND [Qty] < 5` (Qty 2) | `True` (text compare by accident) | `True` | Boolean |
| `[Qty] > 5 AND [Qty] < 1` (Qty 2) | `False` | `False` | Boolean |
| `[NullFlag] AND TRUE` | `False` | `U` (varNull) | Null |
| `[NullFlag] OR TRUE` | `False` | `True` | Boolean |
| `NOT [NullFlag]` | `False` | `U` (varNull) | Null |
| `[Rate] > 0 AND [Qty] / [Rate] > 5` | `False` | `True`/`False`, guarded | Boolean |

## 12. NULL Semantics

### 12.1 The decision

Modern mode introduces a **real NULL** and uses **three-valued (Kleene) logic**
for comparisons and Boolean operators, with an explicit `IS NULL` /
`IS NOT NULL` test. SQL was used as the *reference model* because report authors
already think in SQL terms and because Kleene logic is the only well-defined way
to keep "unknown" from being silently treated as "false" *inside* an expression.
SQL semantics were **not** adopted wholesale:

* `NULL + 1` yields `NULL`, not `0`, and not a type error — propagation is the
  least surprising behaviour and keeps arithmetic composable.
* NULL never *raises*. A report with a null amount must still print.
* At the consumer boundary NULL is *not* three-valued: the existing
  `ConditionVariantToBool` coercion renders UNKNOWN as "not true" (section 11.4)
  and `VarToStr(Null)` renders as empty text, so the printed outcome of an
  unknown value is "blank / suppressed" rather than an error page.

### 12.2 NULL is a language value, not the text `'NULL'`

| Input | Legacy (measured) | Modern |
| --- | --- | --- |
| `NULL` | text `'NULL'` (varUString) | `varNull` |
| `NULL + 1` | `0` (varDouble) | `varNull` |
| `NULL = NULL` | `True` (text compare of `'NULL'`) | `UNKNOWN` (`varNull`) |
| `NULL = 1` | `False` | `UNKNOWN` |
| `NULL <> 1` | `True` | `UNKNOWN` |
| `NULL IS NULL` | text `'NULL IS NULL'` | `True` (varBoolean) |
| `NULL IS NOT NULL` | text `'NULL IS NOT NULL'` | `False` (varBoolean) |

Note the last two rows of legacy: `'NULL IS NULL'` is text that
`ConditionVariantToBool` coerces to `False` — i.e. in legacy *every* `IS NULL`
style test silently fails. That is the strongest argument for adding a real NULL
model and explicit predicates.

### 12.3 Full NULL rules

| Context | Rule | Result |
| --- | --- | --- |
| NULL literal | produces `varNull` | `Null` |
| NULL field (`TField.IsNull`) | resolves to `varNull` (legacy used `AsString` → `''`) | `Null` |
| NULL parameter/variable | `'x='` with no value, or a missing name | `Null` + `UnknownParameter` diagnostic |
| Unknown field token | | `Null` + `UnknownField` diagnostic (decision: section 29 OD-8) |
| Arithmetic `+ - * /` with a NULL operand | propagate | `Null` |
| Unary `+`/`-` on NULL | propagate | `Null` |
| String concatenation with NULL (`+` where both are String) | propagate | `Null` |
| Comparison `= <> != < > <= >=` with a NULL operand | UNKNOWN | `Null` |
| `IS NULL` | true when the operand is `Null` | `True`/`False`, never UNKNOWN |
| `IS NOT NULL` | negation of `IS NULL` | `True`/`False` |
| `AND` / `OR` / `NOT` | Kleene tables (section 11.3) | `Boolean` or `Null` |
| `IF(cond, a, b)` with UNKNOWN `cond` | else branch, consistent with "not true" | `b` |
| `COALESCE(a, b, …)` | first non-NULL argument; NULL if all are NULL | value or `Null` |
| `UPPER/LOWER/TRIM/LEN/SUBSTR/…` with NULL | propagate | `Null` |
| `CONTAINS/STARTSWITH/ENDSWITH` with NULL | propagate | `Null` |
| Aggregate `SUM/AVG/MIN/MAX` | NULL inputs are **skipped** | number, or `Null` when no row contributed |
| Aggregate `COUNT([f])` | counts rows where `f IS NOT NULL` | `Integer` |
| Aggregate `COUNT()` | counts rows in range | `Integer` |
| Division by zero | `DivisionByZero` diagnostic, propagate a "no value" result | `Null` (never `0` silently, never an exception) |
| Rendering a NULL | `VarToStr(Null)` = `''` (consumer unchanged) | blank cell |
| Consumer coercion of NULL | `ConditionVariantToBool(Null)` = `False` (consumer unchanged) | not printed |

### 12.4 Why `IS NULL` / `IS NOT NULL` are proposed

1. **Without them the modern language cannot express the most common report
   requirement.** "Print the discount only when it exists" is
   `IF([Discount] IS NOT NULL, …)`. The alternative (`[Discount] <> NULL`) is
   UNKNOWN by definition and therefore *never* true — a trap.
2. **Legacy's substitute is broken.** Legacy tests "nullness" by emptiness
   (`[Discount] <> ''`) because null and empty were conflated by `AsString`; that
   also cannot distinguish a genuinely empty string from a null.
3. **They are the only NULL-safe predicates**, are constant-time, are not
   affected by Kleene logic, and need no new operator precedence (they are part
   of the comparison level).
4. **Aggregate reference behaviour needs them**: `COUNT([f])` counts non-null
   values, and `COUNT([f]) <> COUNT()` is the canonical "are there nulls?" test —
   which only makes sense if nullness is observable.

### 12.5 NULL and the aggregate `COUNT` change (the highest-risk item)

Measured legacy: `COUNT([NullText])` = `3` for three rows whose `NullText` is
null, because legacy converts the null field to `''` and then counts it as a
value. Modern: `COUNT([NullText])` = `0`, while `COUNT()` = `3`.

This is the single most visible NULL-related migration change and it is
*documented in the Phase 4A contract as a defect* ("Null field values become
empty text... so it changes aggregate COUNT behavior: the aggregate sees a
non-null empty string and counts it"). It is flagged as OD-3 (section 29)
because a project that prefers "count nulls as values" must say so explicitly.

### 12.6 What NULL deliberately does not mean

* NULL is **not** `0` (legacy) and **not** `''` (legacy's rendering of a null
  field). Both conflations are the root cause of the audited defects
  `Audit_NULL_Literal_IsString_CurrentBehavior` and
  `Audit_NULL_Plus_One_IsZero_CurrentBehavior`.
* NULL is **not** False: the *coercion* is False, the *value* is unknown. The
  distinction is what makes `FALSE AND NULL` = `FALSE` and `TRUE OR NULL` =
  `TRUE` possible.
* NULL is **not** an error. No NULL path may abort a report render.

## 13. String Semantics

### 13.1 Literals and concatenation

* Single quotes only; `''` escapes a quote; `"` is an ordinary character (not a
  delimiter) — identical to legacy, so no existing literal changes meaning.
* `+` concatenates when **both** operands are `String`. Numeric values are not
  implicitly formatted into text (no hidden locale-dependent `FloatToStr`).
  `IF(...)` and `TOSTRING()` (future) are the explicit ways to mix types.
* Mixed `String`/`Number` with `+` where the string is not numeric is
  `InvalidArgument` (section 7.2) — a deliberate refusal to guess.

### 13.2 Comparison

* `String` vs `String` compares **case-insensitively** (`CompareText`
  equivalence), inherited from the legacy contract. This is a language-level
  decision, not an implementation detail: `'ALICE' = [Name]` must keep working,
  and the whole `PrintWhen` corpus relies on text comparison.
* No culture/locale collation is introduced: `CompareText` behaviour is kept so
  comparisons stay stable across locale settings (only *conversion* rules differ,
  see section 18 — comparison does not).
* Case-sensitive comparison is **not** proposed as an operator (`==`, `EXACT()`).
  An author who needs it writes `UPPER(a) = UPPER(b)`. Kept out of V1 to avoid
  operator proliferation.

### 13.3 Function categorization (evidence-based)

Key: **Required** = needed to express requirements already visible in the product;
**Useful** = beneficial and cheap, not required for the first modern release;
**Future** = plausible, unjustified today; **Not recommended** = should not be
added at all.

| Function | Class | Justification / evidence |
| --- | --- | --- |
| `+` (concat) | Required | reports compose literals with tokens (112 fixture `Text` values embed tokens; `Total: [Amount]` style text) |
| `IF(cond, a, b)` | Required | the designer's expression editor already advertises `IF(...)`; conditional formatting needs it |
| `COALESCE(a, b, …)` | Required | the clean way to give a NULL a displayable default; pairs with NULL semantics |
| `UPPER(s)` / `LOWER(s)` | Required | text normalization for headings/banners and case-safe comparisons |
| `TRIM(s)` | Required | dataset text fields commonly carry padding (`CollapseWhitespace` already exists in Utils for the same reason) |
| `LEN(s)` | Required | length-based conditions and width diagnostics |
| `SUBSTR(s, start, len?)` | Required | substrings of codes/invoice numbers (1-based, clamped, never raises) |
| `CONTAINS(s, sub)` / `STARTSWITH` / `ENDSWITH` | Required | the Boolean text predicates that `AND`/`OR` exist to combine; case-insensitive to match comparison semantics |
| `ABS(n)` / `ROUND(n, digits?)` | Required | money/quantity presentation; `ROUND` half-away-from-zero (Delphi's banker's rounding surprises report authors) |
| `LEAST(a, b, …)` / `GREATEST(a, b, …)` | Required | scalar min/max cannot be `MIN`/`MAX` (section 16.4 name collision) |
| `YEAR/MONTH/DAY(d)` | Useful | date fields exist (`[ReportDate]`, date columns) but no fixture needs extraction today |
| `IIF(...)` alias of `IF`, `TOSTRING`, `TONUMBER` | Useful | familiarity plus explicit, diagnosable conversion |
| `DATEFORMAT(d, pattern)` | Useful | date *formatting* currently relies on `DateToStr`/`DisplayFormat` |
| `REPLACE`, `PADLEFT`, `PADRIGHT` | Useful | fixed-width invoice/report layouts |
| `SPLIT`, `JOIN`, `LOOKUP`, regex predicates | Future | no evidence of need; each adds type and safety surface |
| `CASE WHEN … THEN …` | Future | nested `IF` covers V1 |
| `EXEC`, `EVAL`, `RUN`, dynamic identifier construction | Not recommended | violates the pure-expression safety model (section 27) |
| Filesystem / registry / HTTP / environment functions | Not recommended | host-application concern, not report-expression responsibility |
| `RANDOM`, `NOW` as a *value* function, `GUID` | Not recommended | non-deterministic output breaks the existing baseline workflow (`reports/regression_baselines.json` assumes deterministic renders) |
| `SETVAR`, assignment, any side effect | Not recommended | expressions must not mutate report state (also required by the cache design, section 25) |

### 13.4 Text semantics examples

| Expression | Legacy (measured) | Modern | Modern type |
| --- | --- | --- | --- |
| `'hello'` | `hello` | `hello` | String |
| `'a''b'` | `a'b` | `a'b` | String |
| `'a' = 'A'` | `True` | `True` | Boolean |
| `'B' > 'a'` | `True` | `True` | Boolean |
| `UPPER('acme')` | text `UPPER('acme')` | `ACME` | String |
| `LEN('abcd')` | text | `4` | Number |
| `SUBSTR('abcdef', 2, 3)` | text | `bcd` | String |
| `CONTAINS('Acme Corp', 'corp')` | text | `True` | Boolean |
| `TRIM('  x ')` | text | `x` | String |
| `'a' + 'b'` | text `a' + 'b` | `ab` | String |
| `'a' + NULL` | `0` | `NULL` | Null |

## 14. Field / Parameter / Variable Access

### 14.1 Keep the bracket syntax — no new field syntax

`[FieldName]` **remains the only field syntax**. Evidence: all 42 fixtures use
it; 112 `Text` values embed it; the designer inserts exactly that form
(`InsertText('[' + FieldName + ']')`); the Phase 4A/4B corpora assert it. Adding
bare identifiers as fields would be breaking *and* would collide with the fixture
`PrintWhen` value `abc` (legacy text) — which is why bare identifiers stay
illegal in modern mode rather than becoming field references.

### 14.2 Resolution order (unchanged, but now explicit and diagnosable)

For a token `[X]` the modern evaluator resolves in exactly the legacy order:

```text
1  system token      (case-insensitive) PageNo Page Page# TotalPages TotalPages#
                                        RowNumber RecNo Line Line# ReportTitle
                                        ReportDate Date DateTime Time
2  parameter alias   Param.X | Parameter.X | Parameters.X        (case-insensitive)
3  report variable   TStrings.IndexOfName / Values                (TStrings default)
4  dataset field     TryGetField(current dataset)
5  modern only       unknown → NULL + diagnostic      [legacy: text '0']
```

Documented consequences, deliberately preserved:

* **Shadowing.** `[ReportTitle]` resolves to the *system* token before any
  variable of that name (measured: legacy returns the context title, not the
  report variable). Modern keeps this order; the designer should warn when a
  variable name collides with a system token or a parameter prefix.
* **Case-insensitivity asymmetry.** `[caption]` finds the variable `Caption`
  (measured), but `[ PageNo ]` does *not* match the system token because token
  text is used verbatim (measured: legacy treats it as a missing field). Modern
  preserves both, and both are asserted Phase 4B tests.

### 14.3 Qualified references

| Form | Legacy | Modern proposal |
| --- | --- | --- |
| `[Field]` | current dataset field | identical |
| `[DataSet.Field]`, `[DataSet."Field"]`, `[DataSet.'Field']` | qualifier is **discarded**; the current dataset is read (measured: `[DataSet.Name]` → current row `Name`) | qualifier is **honoured** when it matches a named dataset via `IReportRenderHooks.GetNamedDataSet`; otherwise fall back to the current dataset with an `UnknownDataSet` diagnostic |
| `[Param.X]` | parameter (takes precedence over dataset qualification) | identical |
| `[Var.X]` | not supported | new optional alias (14.4) |

Rationale for honouring the qualifier: master/detail reports bind bands to named
datasets and the hooks interface already exposes them; silently discarding the
qualifier means a token that *looks* qualified reads a different row. The checked-in
corpus contains exactly one qualified token (`45_landscape_summary.vrt`, inside a
memo `Text`, alongside a band `"DataSetName": "Companies"`) and no build registers
a dataset with that name, so modern mode falls back to the current dataset and the
value is unchanged; only a diagnostic is added. The analyzer flags every qualified
token, so the practical migration cost stays zero until a report actually declares
the dataset at runtime.

### 14.4 Parameters and variables: keep the syntax, add one alias

* Keep `[Param.X]`, `[Parameter.X]`, `[Parameters.X]` (fixture evidence:
  `[Param.ReportTitle]`, `[Param.AmountInWords]`, `[Param.BankText]`,
  `[Param.FilterSummary]`).
* Keep the bare `[CompanyName]` variable form (fixture evidence:
  `[CompanyName]`, `[CompanyAddress]`, `[ReportFooter]`).
* Add an **optional** explicit alias `[Var.CompanyName]` so an author can remove
  the ambiguity between variable, parameter and field. Pure addition; the bare
  form keeps working with the existing resolution order.
* Do **not** introduce un-bracketed `Param.X` / `Var.X`: it would collide with
  bare-identifier text (`abc`) and the future function-name space.

### 14.5 `TVittixUserDataSet`

Legacy cannot aggregate over a `TVittixUserDataSet` (audited:
`Audit_Aggregate_UserDataSet_ReturnsLiteralText_CurrentBehavior` returns literal
text). Modern mode must define the same field-read order
(`SafeSourceFieldValue` prefers the UserDataSet), but aggregate traversal over a
`UserDataSet` is a separate open item (OD-11): either (a) modern aggregates
require a `TDataSet` and otherwise report `UnsupportedDataSet`, or (b) a
forward-cursor traversal is implemented for `TVittixUserDataSet`. Recommended for
4B-2B: (a) — an explicit diagnostic instead of silent literal text.

## 15. Function Model

### 15.1 Rules

1. **Closed whitelist.** A function exists only if it is in the catalogue
   (13.3). Unknown names are `UnknownFunction` diagnostics; they never resolve to
   fields, variables or text.
2. **Case-insensitive names**, like the legacy aggregate prefix matching
   (`sum([Amount])` works today).
3. **Fixed arity**, checked at parse time where possible; wrong arity is
   `InvalidArgumentCount`, never a runtime crash.
4. **Lazy where it matters**: `IF`, `IIF` and `COALESCE` evaluate arguments on
   demand; every other function evaluates all arguments strictly. Rationale:
   aggregate operands are expensive and `DivisionByZero` must stay guardable
   (section 11.2).
5. **Pure and deterministic.** No function may read or write global state, the
   filesystem, the registry, the clock (the `[ReportDate]`/`[Time]` *tokens*
   remain context values) or the report model. No function may mutate the
   context, the dataset cursor position or the cache. Aggregates are the only
   functions that move the cursor, and they restore it (existing
   `TReportAggregates` behaviour).
6. **No user-defined functions** in V1. Adding a function requires a code change
   plus tests — report files must not be able to extend the runtime.
7. **NULL in, NULL out** for scalar functions (section 12.3) unless the function
   is explicitly NULL-aware (`COALESCE`, `IS NULL`).
8. Return types are fixed per function and documented, so authors can reason
   about promotion without running anything.

### 15.2 Argument evaluation and the aggregate interaction

* A function argument may contain aggregates:
  `ROUND(SUM([Amount]) / 3, 2)`.
* **Design requirement for 4B-2B:** aggregate nodes must be evaluated at most
  once per (expression, group, pass) even when the expression is evaluated per
  row. Today the engine's aggregate cache provides this for identical expression
  text, so the modern evaluator must not defeat it by rewriting text, and the
  parse/plan layer must not duplicate aggregate subtrees.
* Only `COALESCE`, `LEAST`, `GREATEST` and the aggregates are variadic; every
  other function has fixed arity.

### 15.3 Catalogue for Phase 4B-2B (minimum viable set)

```text
Conditional   IF(cond, a, b)                     lazy
              COALESCE(v1, v2, ...)              lazy
Numeric       ABS(n)
              ROUND(n, digits)                   half away from zero
              LEAST(a, b, ...)  GREATEST(a, b, ...)
Text          UPPER(s)  LOWER(s)  TRIM(s)  LEN(s)
              SUBSTR(s, start[, len])
              CONTAINS(s, sub)  STARTSWITH(s, pre)  ENDSWITH(s, suf)
Aggregate     SUM(x)  COUNT([x])  AVG(x)  MIN(x)  MAX(x)      (section 16)
```

Everything else in 13.3 is explicitly deferred.

### 15.4 Function error matrix

| Situation | Diagnostic | Lenient result |
| --- | --- | --- |
| Unknown name | `UnknownFunction` | `Null` |
| Wrong argument count | `InvalidArgumentCount` | `Null` |
| Wrong argument type | `InvalidArgument` | `Null` |
| Aggregate with no dataset | `UnsupportedDataSet` | `Null` |
| Aggregate inside an aggregate | `SyntaxError` (parse time) | `Null` |
| `SUBSTR` index/length out of range | clamped, no diagnostic | clamped result |

## 16. Aggregate Model

### 16.1 Names and arity

| Function | Arity | Meaning |
| --- | --- | --- |
| `SUM(x)` | 1 | sum of non-NULL `x` over the range |
| `COUNT()` / `COUNT(*)` | 0/1 | row count over the range |
| `COUNT(x)` | 1 | count of rows where `x IS NOT NULL` |
| `AVG(x)` | 1 | sum / count over non-NULL values; `Null` when the count is 0 |
| `MIN(x)` / `MAX(x)` | 1 | extremum over non-NULL values; `Null` when no value |

Names stay exactly as legacy (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`) because they
are the only functions the product has ever advertised.

### 16.2 Scope

* **Group scope** is inherited from the evaluation context: the engine supplies
  `Context.GroupStart` / `Context.GroupEnd` bookmarks for group headers/footers,
  and `TReportAggregates` already scans that bounded range and restores the
  cursor. Modern mode reuses this exact traversal.
* **Dataset scope** is the current dataset. Aggregates never implicitly traverse
  named datasets, master/detail relations or subreport data. A qualified
  aggregate (`SUM([Detail.Amount])`) is **not** proposed for V1 (OD-12): it needs
  a defined row-synchronisation rule between datasets, which the Phase 1 GAP-002
  analysis already flags as expensive and under-specified.
* The aggregate prefix is no longer required to be at the start of the
  expression; aggregate nodes may appear anywhere a value is expected.

### 16.3 Composition (the headline difference from legacy)

| Expression (sum = 35.5, qty = 16) | Legacy (measured) | Modern |
| --- | --- | --- |
| `SUM([Amount])` | `35.5` | `35.5` |
| `SUM([Amount]) + 1` | `35.5` | `36.5` |
| `1 + SUM([Amount])` | `1` | `36.5` |
| `SUM([Amount]) * 2` | `35.5` | `71` |
| `SUM([Qty]) > 100` | `16` (tail discarded) | `False` |
| `ROUND(SUM([Amount]) / 3, 2)` | `35.5` | `11.83` |
| `IF(SUM([Amount]) > 1000, 'High', 'Low')` | `True` (accidental text compare) | `'Low'` |
| `SUM([Amount]) + SUM([Qty])` | `35.5` (second aggregate discarded) | `51.5` |
| `SUM([Qty] * [Rate])` | `32` | `32` |
| `SUM([Qty] * [Rate]) + 1` | `32` | `33` |

This is a **Very High** migration risk item in the abstract but **zero-risk** in
practice for the checked-in corpus: no fixture uses an aggregate inside a larger
expression. The analyzer (section 23) must flag every expression where an
aggregate is not the entire expression.

### 16.4 `MIN`/`MAX` name collision — resolved explicitly

Legacy treats any `MIN(`/`MAX(` prefix as an aggregate. Modern mode keeps
`MIN`/`MAX`/`SUM`/`AVG`/`COUNT` **reserved for aggregates** and provides scalar
`LEAST`/`GREATEST` instead of overloading `MIN`/`MAX` by argument count, because:

* arity-based dispatch (`MIN(a, b)` scalar vs `MIN(x)` aggregate) is ambiguous
  the moment a group has one row or an argument is itself aggregatable, and it
  would force the parser to decide scope before it knows the context;
* `LEAST`/`GREATEST` are the SQL-standard scalar spellings;
* it keeps a single, greppable rule: "`SUM/COUNT/AVG/MIN/MAX` always scan a
  range".

### 16.5 Nested aggregates and re-entrancy

* `SUM(AVG([x]))` is a `SyntaxError`. The inner aggregate is row-independent, so
  nesting either re-scans the range per row (O(n²)) or has no defined meaning.
* Aggregates inside an aggregate argument list are rejected; an aggregate inside
  a *scalar function* argument is allowed (`ROUND(SUM(x), 2)`).
* Re-entrancy rule: an aggregate scan may not start while another aggregate scan
  over the same dataset is in progress (guard flag + diagnostic), so a
  pathological expression cannot multiply dataset scans.

### 16.6 Empty ranges and NULL inputs

| Case | Legacy (measured) | Modern |
| --- | --- | --- |
| `SUM` over an empty range | `0` | `Null` (OD-1) |
| `COUNT()` over an empty range | `0` | `0` |
| `COUNT([f])`, all `f` null | counts them (measured `3`) | `0` (OD-3) |
| `AVG`, no non-NULL value | `0` | `Null` |
| `MIN`/`MAX`, no non-NULL value | `0` | `Null` |
| `SUM` with some nulls | skips non-numeric only; nulls became `''` and failed conversion | skips nulls explicitly |

Rendering note: a NULL aggregate renders as an empty cell (`VarToStr`), so
`SUM` over an empty group prints blank unless the author writes
`COALESCE(SUM([Amount]), 0)`. OD-1 asks the project to confirm this preference,
since legacy printed `0`.

## 17. Error Model

### 17.1 Principle

**Compatibility mode keeps the silent-fallback model forever.** Modern mode
produces *structured diagnostics* and — at render time — *defined fallbacks*.
It does not abort a report and does not raise by default. A 5 000-page print run
must not fail because one field name was misspelled; equally, the author must be
told exactly what was wrong and where.

### 17.2 Categories and codes

| Code | Raised when | Lenient result | Strict behaviour |
| --- | --- | --- | --- |
| `SyntaxError` | unbalanced parentheses, missing `]`, trailing operator, comparison chain, bad token | `Null` | raise `EReportExpressionError` |
| `UnknownField` | token is not a system token, parameter, variable or dataset field | `Null` | raise |
| `UnknownDataSet` | `[Ds.Field]` qualifier names no known dataset | fall back to the current dataset, keep `UnknownDataSet` | raise |
| `UnknownParameter` | `[Param.X]` not found | `Null` | raise |
| `UnknownVariable` | `[Var.X]` not found | `Null` | raise |
| `UnknownFunction` | name with `(` is not in the catalogue | `Null` | raise |
| `InvalidArgumentCount` | wrong arity | `Null` | raise |
| `InvalidArgument` | wrong type / unusable value (non-numeric string in arithmetic) | `Null` | raise |
| `TypeError` | incompatible operand types (`DateTime` vs `Number`, `Boolean` in arithmetic) | `Null` | raise |
| `DivisionByZero` | `/` with a zero divisor | `Null` | raise |
| `NullError` | NULL used where the host policy demands a value | `Null` | raise |
| `UnsupportedDataSet` | aggregate with no usable dataset/`UserDataSet` | `Null` | raise |
| `LimitExceeded` | length/depth/node/aggregate limits | `Null` | raise |
| `EvaluationError` | anything unexpected inside a function | `Null` | raise |
| `ImplicitConversion` | value parsed with a locale fallback (section 18) | value | warning only |

### 17.3 Delivery mechanisms

1. **Per-evaluation diagnostics object** (parser/evaluator-owned, freed with it):
   an ordered list of `(Code, Position, Message)` plus counters, mirroring the
   `TExpressionDiagnostics` sketch in
   `docs/Phase4I-20-ExpressionEngineDesign.md`. Not surfaced to end users during
   normal rendering; available to tests and tools.
2. **Additive validation API** for the designer and CI:
   `TReportExpression.Validate(Expr, Context, Mode)` returning an immutable
   validation result (no AST escapes, no context retained). This is the only
   public addition proposed in this phase (section 26).
3. **Diagnostics counters** in the existing Phase 2 infrastructure
   (`TReportTraversalDiagnostics`): additive fields such as
   `ExpressionEvaluations`, `ExpressionErrors`, `ExpressionWarnings`,
   `AggregateScansAvoided`. The Phase 2/3 precedent is process-local,
   diagnostic-only counters that never influence control flow.
4. **DEBUG channel**: `OutputDebugString` per unique diagnostic, exactly like the
   compatibility evaluator's `DebugLogUnresolvedToken` (200-message cap,
   deduplicated).

### 17.4 Strictness levels

```text
esLenient     (default at render time) : diagnostics collected, defined fallback returned
esStrict      (default for tests/CI)   : the first diagnostic raises EReportExpressionError
esValidating  (designer)               : no evaluation; collect every diagnostic
```

* Modern mode defaults to **lenient at render**, preserving the operational
  expectation that a report always prints.
* Strictness is a host/engine setting, not a per-property flag, so a report
  behaves identically wherever it runs.
* The legacy path ignores strictness entirely: `Evaluate(Expr, Context)` can
  never raise because of a modern diagnostic and never consults the mode.

### 17.5 What is explicitly not proposed

* No change to legacy fallbacks (text `'0'`, silent truncation, `/0` no-op).
* No exception type leaking into legacy consumers.
* No "error value" Variant (a magic string): diagnostics stay outside the value
  channel so `VarToStr`/`ConditionVariantToBool` semantics remain clean.
* No log file and no UI popup from the evaluator itself.

## 18. Locale Rules

### 18.1 The ambiguity legacy only survives by luck

Legacy treats `,` as a *number character*
(`CharInSet(S[I], ['0'..'9', '.', ','])`) because it has no other use for the
character. The moment multi-argument function calls exist, `,` must be the
argument separator, and `IF(a,1,5)` becomes ambiguous: is `1,5` one number
(one-point-five) or two arguments? This phase settles it.

### 18.2 Decision — invariant literals, locale-tolerant runtime values

| Context | Rule |
| --- | --- |
| **Number literals in expression text** | invariant: `.` is the decimal separator, digits only, no group separators, no exponent in V1. `10.5` is always ten-point-five. `,` is never part of a literal. |
| `1234,50` | `SyntaxError` (OD-14 records the alternative: accept it as a *diagnosed* locale value) |
| **Dataset field values** | already typed (`Float`/`Currency`/`Integer`/`String`); no parsing, hence no locale dependence. A `String` field used numerically is parsed invariantly first, then with the current locale, with an `ImplicitConversion` warning. |
| **Parameter / variable values** (`TStrings` text) | parsed invariantly first; on failure the current locale is tried and an `ImplicitConversion` warning is recorded — this preserves apps that supply `1,5` from a localized UI. |
| **Comparison / collation** | unchanged from legacy (`CompareText` equivalence); no culture-sensitive collation. |
| **Formatting output** | `VarToStr`/`FloatToStr` keep the current locale (unchanged), so printed numbers do not change. |

### 18.3 Rationale

* **Portability.** A `.vrt` authored under a German locale must produce the same
  arithmetic everywhere. Legacy does not (the same file parses differently). The
  invariant rule costs nothing for the corpus: all 75 fixture expressions are
  integers, field tokens or `[Qty] * [Rate]`.
* **Unambiguity.** With `,` reserved as the argument separator the grammar stays
  LL(1)-friendly and diagnostics stay precise.
* **No output change.** Only *parsing* becomes invariant; *formatting* remains
  locale-sensitive, so rendered text is unchanged. This is the trick that makes
  the change invisible in reports while making them portable.
* Compatibility mode is untouched: it keeps `TryStrToFloat` with the current
  locale, as the Phase 4A contract requires.

## 19. Date/Time Decision

| Item | Decision |
| --- | --- |
| Date/time **literals** (`DATE(...)`, `DATETIME(...)`, `#2026-01-01#`) | **Not in 4B-2B** (Future). No fixture uses dates in expressions; a literal would embed an ambiguous locale/format decision in the template, and parameter/field values already cover the need. |
| Date/time **arithmetic** (`[DueDate] - [InvoiceDate]`) | **Not in 4B-2B**. If needed later, define a difference in days as `Number` plus an explicit `DAYS()`, never by overloading `-`. |
| Date/time **type** | Yes (`varDate`), so fields, parameters, `IS NULL` and comparisons work. |
| Date/time **comparisons** | Allowed (`[InvoiceDate] >= [CutoffDate]`), chronological; `DateTime` vs `Number` is `TypeError`. |
| Date/time **extraction** (`YEAR/MONTH/DAY`) | Useful, deferred; already listed in 13.3. |
| Date/time **formatting** | Out of scope for the language. `[ReportDate]`/`[Date]` keep their existing `DateToStr`/`DateTimeToStr` formatting (changing it would alter printed headers = compatibility break); object-level `DisplayFormat` remains the mechanism; `DATEFORMAT()` is a future nicety. |
| **System date tokens** | `[ReportDate]`, `[Date]`, `[DateTime]`, `[Time]` keep their exact legacy values and formatting in modern mode. They stay *context values*, not clock reads, so a render remains deterministic (required by the baseline workflow). |

Classification requested by the brief: dates are **"Phase 4B"** for
types/comparisons, **"future"** for literals and arithmetic, and
**"unsupported"** for locale-independent date formatting inside the language.

## 20. Compatibility Mode Strategy

### 20.1 The five candidate strategies

| Strategy | Description | Verdict |
| --- | --- | --- |
| **A. Legacy always legacy; modern requires explicit opt-in** | the mode is carried explicitly; everything untouched stays legacy | **Adopted as the safety property** |
| **B. Global application-level mode** | one process-wide switch flips every report | **Rejected as the primary mechanism**: a single deployment setting would silently change the meaning of every existing `.vrt` (arithmetic, aggregates, missing fields). Acceptable only as a host-level default for *new* reports, never as a retroactive switch. |
| **C. Per-report mode** | the report declares its language version | **Adopted as the primary selection mechanism**, because the unit of authoring, review, migration and rollback is exactly one report file |
| **D. Per-expression mode** | each property chooses legacy/modern | **Rejected**: per-property state in `.vrt` (schema churn), a report whose semantics cannot be read as a whole, two diagnostic models in the designer, and a test matrix multiplied by the number of expression properties |
| **E. Template format version selects semantics** | bump `Version` and every report changes language | **Rejected as the carrier**: `"Version": 2` already drives property-loading branches in every object serializer, so overloading it would couple schema evolution to semantics. A sibling key is used instead (section 21). |

### 20.2 Recommended mechanism (layered, all additive)

```text
Layer 4  TReportExpression.Validate(Expr, Context, Mode)   designer / CI only
Layer 3  TReportExpression.Evaluate(Expr, Context, Mode)   additive overload (explicit mode)
Layer 2  TExpressionContext.ExpressionMode                 additive record field, zero = legacy
Layer 1  TReportModel.ExpressionLanguageVersion            additive model property
         `.vrt` key "ExpressionLanguageVersion"            absent = 0 = legacy
```

Load order in the engine: `.vrt` key → model property → context field on every
context the engine builds (band `PrintWhen`, object draws, exporter contexts,
subreport child contexts — all of which already copy the incoming context; the
measured construction points are `Ctx0` in the band-evaluation path, the render
context, and the text exporter's context builder).

### 20.3 Why this cannot change an existing report

1. **The two-argument `Evaluate(Expr, Context)` is permanently legacy.** It has
   no mode parameter and never consults one, so every call site that exists today
   keeps legacy semantics *even if* a future change forgets to migrate a consumer.
2. **The mode's zero value is legacy.** `Default(TExpressionContext)` and every
   hand-built test context are legacy; a report loaded from a file without the key
   is legacy; a `TReportModel` created in code is legacy.
3. **Explicit selection only.** Modern semantics require a `.vrt` key, a model
   property assignment, or an explicit call with a mode argument. There is no
   ambient default, no environment variable and no global flag.
4. **Mixed reports are safe.** One process may render a modern report and a legacy
   report; nothing but the process is shared. (Per-expression mixing inside one
   report is deliberately *not* supported — strategy D.)
5. **Rollback is one key.** Deleting `"ExpressionLanguageVersion"` (or setting it
   to `0`) returns a report to legacy semantics with no data loss, because the mode
   never rewrites expression text.

### 20.4 Consequences to accept explicitly

* The engine must pass the mode into every context it constructs. This is
  mechanical and additive (Phase 4B-2B), and is the *only* change required in the
  engine beyond exposing the layer-1/2 fields.
* A modern report opened in an older build renders with legacy semantics and can
  therefore print differently. That build cannot know better, so the newer build
  must warn (section 21) and the designer must show the mode prominently
  (section 22).
* Aggregates are cached per expression text (Phase 3). The same text can now mean
  two things, so the cache key must include the mode — see section 25.

## 21. `.vrt` Version Strategy

### 21.1 No schema change now — and what a future one looks like

Nothing is added to `.vrt` in this phase. The planned change is **additive**, at
the document root, beside the existing version key:

```json
{
  "Version": 2,
  "ExpressionLanguageVersion": 1,
  "Title": "...",
  "Objects": [ ... ]
}
```

Facts that make this safe (all measured in the current serializer):

* The root object is built in one place (`Root.AddPair('Version',
  TJSONNumber.Create(2))`) and read back in one place (`if
  Assigned(Root.GetValue('Version')) then Version := Trunc(...)`), then threaded
  into every object serializer as `AVersion`. Adding one sibling key follows the
  same pattern and needs no per-object changes.
* Reading a v1 file (no `Version` key) already works: the loader tolerates missing
  keys, so a file without `ExpressionLanguageVersion` loads as legacy.
* **Unknown keys are tolerated and unknown object classes are preserved** as
  `TReportUnknownObject` with the raw JSON written back on save. That is the
  existing forward-compatibility guarantee and exactly what a new key needs.
* `TReportLoadResult` already provides structured diagnostics for the
  transactional load path, so a "this report requires a newer expression
  language" warning has a natural home.

### 21.2 Version values

| Value | Meaning |
| --- | --- |
| absent or `0` | legacy language (the compatibility contract) |
| `1` | modern language as specified in this document (Phase 4B-2B) |
| `> 1` | reserved for future language revisions; a build that does not know the value must warn and evaluate as legacy |

### 21.3 Why not reuse `Version`

`Version` is a *format* version (v1 = no `Children[]`, no `FieldNames[]`;
v2 = current) and drives conditional property loading in every object serializer.
Overloading it to also mean "expression language 1" would force every future
language revision to pretend to be a file-format revision and vice versa.

### 21.4 Forward/backward matrix

| Producer | Consumer | Behaviour |
| --- | --- | --- |
| Legacy build | legacy file | unchanged |
| Legacy build | modern file (key present) | loads, evaluates **legacy**, and must emit a load warning ("report requires expression language version 1") |
| Modern build | legacy file | loads, evaluates legacy — byte-identical to today |
| Modern build | modern file | evaluates modern (opt-in succeeded) |

The only asymmetry is row 2, which is why the warning is a requirement, not a
nicety.

## 22. Designer Strategy

No designer change in this phase. Recommended future direction:

1. **Mode indicator per report.** A visible badge in the standalone designer
   (`Legacy expressions` / `Modern expressions v1`) plus a toggle that writes
   `ExpressionLanguageVersion` into the model. Because the mode is report-level,
   the toggle belongs to the report, not to a property editor.
2. **Mode-aware expression editor.** The existing
   `TfrmExpressionEditor.EditExpression` / `TfrmExpressionHelper.PromptExpression`
   pair is the natural host. Additions: parse/validate on edit through the
   additive `Validate` API (`esValidating`), inline error markers with token
   positions, and a result preview — the helper already evaluates for its "Check"
   button, so that call site simply gains the mode argument.
3. **Fix the misleading hint.** `Frm.ExpressionEditor.pas` currently advertises
   `IF(<Dataset.Value> < 0, clRed, clBlack)` — a function and syntax legacy mode
   does not support. The label must become mode-aware: legacy keeps today's
   templates (all of `Frm.ExpressionHelper`'s templates are legacy-valid), modern
   mode advertises `IF(...)`, `COALESCE(...)`, `UPPER(...)` etc.
4. **Mode-aware template/insert buttons.** The current set (`[Field] > 0`,
   `[Field] = 'Text'`, `[Field] <> ''`, `[Amount] > 1000`, `[Qty] > 5`, plus the
   operator buttons) stays; modern mode *adds* `AND`/`OR`/`NOT`, `IF`,
   `COALESCE`, parentheses and `!=` — additions only, never replacements.
5. **Compatibility warnings.** Switching a report to modern mode runs the
   compatibility analyzer (section 23) and shows the diff list before the mode
   change is committed. Variable names that shadow a system token or a parameter
   prefix (`ReportTitle`, `Param.X`) warn.
6. **No silent rewriting.** The designer may offer "make intent explicit with
   parentheses" or "rewrite to the modern equivalent" as *reviewed* suggestions
   with a before/after diff — never as an automatic migration on save.
7. **Designer preview must respect the mode.** The designer's preview path builds
   its own context; that context must carry the report's mode, otherwise preview
   and print would disagree.

## 23. Migration Strategy

### 23.1 Measured migration surface (the actual corpus)

A scan of all 42 checked-in reports counted **159 string values** across every
expression-bearing property (`Text`, `Expression`, `PrintWhen`,
`BackColorCondition`, `FontColorCondition`, `BackgroundCondition`,
`BorderColorCondition`) that contain at least one `[...]` token. Of these, the
distinct `Expression` values are 11 and the distinct `PrintWhen` values are 10.
Exactly one value uses a dataset-qualified token
(`45_landscape_summary.vrt`: `[Companies."CompanyName"]` inside a memo `Text`,
alongside a band `"DataSetName": "Companies"`); six use `[Param.X]`.

Evaluating those values under both semantics (legacy results measured with the
Phase 4B-1 evaluator; modern results per this specification):

| Value | Legacy outcome | Modern outcome | Differs? |
| --- | --- | --- | --- |
| `[CompanyName]`, `[CompanyAddress]`, `[ReportFooter]` (declared in `37_report_variables.vrt`) | variable text | same | no |
| `[Param.ReportTitle]`, `[Param.AmountInWords]`, `[Param.BankText]`, `[Param.FilterSummary]` | parameter text | same | no |
| `[Qty] * [Rate]` | product | product | no |
| `[RecNo]`, `[ReportTitle]` | number / title | same | no |
| `[Companies."CompanyName"]` (report 45) | qualifier ignored, current dataset read | qualifier unknown → `UnknownDataSet` diagnostic, then the *same* fallback value | no (diagnostic only) |
| `[MissingField] + 1` (fixtures 22, 25, 26, 28) | prints `1` (fabricated) | prints blank (`Null`) | **yes** |
| `[MissingField] >` (fixtures 22, 25, 26, 28) | `True` → the object **prints** | `SyntaxError` → `Null` → the object is **suppressed** | **yes** |
| `[MissingField] > 0` | `False` | `False` | no |
| `[Qty] > 5` | `False` | `False` | no |
| `1=0`, `1=1`, `0`, `1`, `true`, `false` | False/True | identical | no |
| `abc` | text → not printed | `SyntaxError` → `Null` → not printed | no (diagnostic only) |
| any token whose field/variable/parameter is genuinely missing | renders `0` | renders blank | **yes**, when it occurs |

Summary: **74 of 75 distinct expressions produce the same rendered outcome; 2
distinct expressions across 4 fixtures change outcome; no report changes its page
count, its data traversal or its export structure.** Both changed values are
already wrong in the legacy sense (one prints a fabricated `1`, the other prints
because a malformed condition accidentally evaluates `True`), which is exactly
what the analyzer and diagnostics exist to surface.

### 23.2 Compatibility analyzer (future tool)

```
For each expression-bearing property in a report:
    legacy   := TReportExpression.Evaluate(text, ctx)
    modern   := TReportExpression.Evaluate(text, ctx, modeModern)
    if type or value differs, or the modern evaluation emits a diagnostic:
        record  (object path, property, text, legacy value, modern value, reason)
```

This is a direct reuse of the Phase 4B-1 differential harness pattern, which is
already proven on a 180-expression corpus. The analyzer is *read-only*: it never
writes, and it needs no report execution beyond a context.

### 23.3 Migration rules

| Rule | Statement |
| --- | --- |
| **Warn, never surprise** | Switching a report to modern mode must present the analyzer diff first. |
| **No automatic rewriting** | The mode change never edits expression text. Reports are immutable inputs to the migration. |
| **Require attestation for changes** | If the analyzer reports a difference, the user must explicitly accept each one (per expression, not per report) before the mode is committed. |
| **Preserve legacy mode indefinitely** | Legacy mode is not deprecated by this design. The compatibility evaluator stays in the product. |
| **Manual approval for semantic rewrites** | Optional rewrite suggestions (e.g. `[MissingField] + 1` → `COALESCE([MissingField], 0) + 1`) are offered as reviewed diffs, never applied silently. |
| **Round-trip verification** | After migration, the regression runner (`VittixRunner`) plus `reports/regression_baselines.json` must be re-run; a page-count change is a migration failure by definition. |
| **Rollback** | Remove the key. Nothing else to undo. |

### 23.4 Documented semantic changes and the reason each is acceptable

| Change | Why it is acceptable under opt-in |
| --- | --- |
| Flat arithmetic → precedence | the flat result is the audited defect (`Audit_Precedence_AddMul_LeftToRight_CurrentBehavior`); modern mode exists precisely to fix it |
| No parenthesis parsing → grouping | `(1 + 2) * 3` = 0 today; modern returns 9 |
| `AND`/`OR`/`NOT`/`!=` unsupported → supported | the designer already advertises Boolean-style conditions; `1 = 1 AND 2 = 2` = False today |
| Aggregate prefix truncation → composition | `SUM([Amount]) + 1` silently discards `+ 1` today |
| Missing field `'0'` → NULL + diagnostic | printing a fabricated `0` is a data-integrity defect; blank plus a diagnostic is honest |
| Null field → `''` → NULL | null/empty conflation is the root cause of the `COUNT` and arithmetic defects |
| Silent fallback → structured diagnostics | the audited `_CurrentBehavior` tests exist to record that silence is wrong |
| Locale parsing → invariant literals | portability; formatting unchanged so printed output is unchanged |
| `COUNT([f])` counts nulls → skips nulls | SQL convention; flagged OD-3 |

## 24. AST / Evaluator Architecture

### 24.1 Recommended pipeline

**tokenizer → recursive-descent parser → immutable AST → evaluator**, matching
the architecture already sketched in
`docs/Phase4I-20-ExpressionEngineDesign.md`, with these Phase 4B-2A refinements:

* one `NOT` level (section 9.2), not two;
* `IS [NOT] NULL` as a comparison-level form;
* NULL/type-aware nodes instead of "safe default" nodes;
* a diagnostics object rather than silent defaults;
* an explicit mode on the entry point.

Recursive descent is preferred over a Pratt/precedence-climbing parser because the
grammar is tiny (8 levels), the precedence table is fixed, error positions fall out
naturally, and it matches the existing design note (so future review has one
document, not two). A Pratt parser remains viable if the operator set grows.

### 24.2 Proposed unit graph (no cycles)

```text
Vittix.Report.Expression.Language.pas   (new)
    uses: System.*, Data.DB, Vittix.Report.Context, Vittix.Report.Utils
    contains: tokenizer, parser, AST nodes, evaluator, function catalogue,
              diagnostics, limits
    must NOT use: Objects, Bands, Engine, Model, Serializer  (no cycles, no VCL)

Vittix.Report.Expressions.pas           (existing boundary, unchanged signature)
    Evaluate(Expr, Context)                  → legacy evaluator (unchanged)
    Evaluate(Expr, Context, Mode)            → mode dispatch (new overload)
    Validate(Expr, Context, Mode)            → diagnostics (new overload)

Vittix.Report.Expressions.Compat.pas    (existing, unchanged)
Vittix.Report.Aggregates.pas            (existing; may delegate to the language
                                         unit for its inner-expression evaluation
                                         in a later phase)
```

Aggregate delegation: the modern evaluator must call the *existing*
`TReportAggregates.TryEvaluate` (or a refactored equivalent that keeps the bookmark
scan, cursor restoration and cache hooks) and must not grow a second traversal.
Because `Aggregates` imports `Expressions` in its interface, the language unit
receives an aggregate callback, or the aggregate unit is refactored to depend on
the language unit instead (the inverse of today's cycle). This is a 4B-2B
implementation decision, recorded here so it is not discovered late.

### 24.3 Conceptual node types

```text
TExpressionNode (abstract; SourcePos; Evaluate(Context): Variant)
  TLiteralNode        Number | String | Boolean | DateTime | Null
  TTokenNode          [Field] | [Ds.Field] | [Param.X] | [Var.X] | [SystemToken]
  TUnaryNode          + - NOT
  TBinaryNode         + - * /  = <> != < > <= >=  AND OR
  TIsNullNode         IS NULL / IS NOT NULL
  TCallNode           FuncName + args   (scalar catalogue)
  TAggregateNode      Sum|Count|Avg|Min|Max + inner expression + scope marker
  TConditionalNode    IF / COALESCE (lazy argument slots)
  TParenNode          grouping (parentheses may simply shape the tree)
```

Node ownership: the parser owns every node (owned list or parent-owned children);
the evaluator is a stateless visitor that receives `TExpressionContext` by `const`
and returns a `Variant`; no node retains a context, dataset, bookmark or cache
reference beyond one `Evaluate` call. That property is what makes AST reuse safe
(section 25).

### 24.4 Evaluation entry contract (future)

```pascal
class function TReportExpression.Evaluate(const Expr: string;
  const Context: TExpressionContext): Variant;                     // legacy forever
class function TReportExpression.Evaluate(const Expr: string;
  const Context: TExpressionContext;
  const Mode: TReportExpressionMode): Variant;                     // new, additive
class function TReportExpression.Validate(const Expr: string;
  const Context: TExpressionContext;
  const Mode: TReportExpressionMode): TReportExpressionValidation;  // new, additive
```

## 25. Cache Strategy

### 25.1 Two caches, deliberately separate

| Cache | Key | Value | Owner | Lifetime |
| --- | --- | --- | --- | --- |
| **Parse cache** (new, 4B-2B) | `(ExpressionMode, Expr text)` | immutable AST | engine | one execution; cleared with the existing `ClearExecutionCaches` |
| **Aggregate value cache** (existing, Phase 3) | context key, see 25.2 | evaluated aggregate value | engine (`TAggregateCacheEntry`) | execution- and pass-local; cleared before each pass |

Keeping them separate matters: the parse cache is a pure function of text + mode and
can never be stale; the value cache depends on data and must be invalidated by
execution state.

### 25.2 Can the existing Phase 3 cache safely cache modern results? — **Not as-is**

The Phase 3 key (measured, `TAggregateCacheEntry.Matches`) is:

```text
dataset instance | expression text | group-start bookmark bytes | group-end bookmark bytes
page number | total pages | row number | counting-pass flag
parameters text | variables text | dataset filter text + filtered flag
```

Analysis against the modern evaluator:

| Dependency | Covered today? | Required change |
| --- | --- | --- |
| **Expression language mode** | **no** | **must be added** — identical text can now mean two things; without it a legacy-cached value could be served to a modern expression (or vice versa) |
| expression text | yes | unchanged (text ⇔ AST for a given mode) |
| dataset instance | yes | unchanged |
| group range (bookmarks) | yes | unchanged |
| page / total pages / row | yes | unchanged |
| counting vs rendering pass | yes | unchanged |
| parameters / variables text | yes | unchanged |
| dataset filter state | yes | unchanged |
| **`Context.ReportTitle`** | **no** | **must be added** — flagged in Phase 4A and in the Phase 4B-1 known limitations; modern mode makes it far more likely that a title appears *inside* an aggregate (`SUM(IF([ReportTitle] = 'X', [Amount], 0))`) |
| **`Context.ReportDate`** | **no** | **must be added** (same argument) |
| **script mutation of model/dataset state** | partly | the script host can mutate object properties mid-pass; parameter/variable *text* is keyed, but a mutation of `TReportModel.Title`, a field value, or dataset content is not. Recommendation: (a) add the two metadata fields, and (b) expose an explicit invalidation entry point that mutation paths must call, and/or include a monotonic context-mutation counter bumped by the `Cmd_*` handlers |
| row-scoped inner expressions | correct today | unchanged: the cache stores the aggregate *result*, and the inner expression is evaluated over the whole group, so the row number in the key keeps a row-dependent inner expression from being wrongly reused |

### 25.3 Recommended key (future, additive)

```text
same as today
+ ExpressionMode (or ExpressionLanguageVersion)
+ Context.ReportTitle
+ Context.ReportDate       (stable textual form)
+ context mutation counter (optional; closes the script-mutation hole)
```

All four additions are *conservative*: they can only cause more misses, never a
wrong hit, and none changes the cache's ownership, lifetime or pass-local clearing.
The Phase 3 measurements (one traversal for repeated `SUM([Amount])`) are preserved
for expressions that reference neither title nor date, because the added key fields
are constant within a pass.

### 25.4 AST identity vs text

Text is recommended as the parse-cache key:

* identical text always yields an identical AST for a given mode, so AST identity
  adds hashing complexity and ownership risk without benefit;
* two separately authored identical expressions should share one parsed tree
  (memory win);
* text keys survive serialization round-trips unchanged, exactly as the aggregate
  cache already behaves.

### 25.5 What must *not* be cached

* Field values or row-scoped results in the aggregate cache (the key includes the
  row number today; keep it).
* Anything across an execution (`Prepare` / two-pass boundary) — Phase 3 clears
  before every pass and asserts it.
* Diagnostics: they are per evaluation, not cached, otherwise short-circuiting
  would produce missing or spurious messages.

## 26. Performance Considerations

### 26.1 Where the future evaluator wins

| Activity | Legacy (today) | Modern (proposed) |
| --- | --- | --- |
| Per-row evaluation | re-scans the expression string, rebuilds it with `TStringBuilder`, re-detects the comparison operator, re-scans arithmetic characters | walks an immutable AST; no string allocation, no re-tokenization |
| Parse cost | paid on every evaluation | paid once per (mode, text) with the parse cache |
| Aggregate operands | one dataset scan per aggregate (the cache mitigates repeats) | the same scans, one shared aggregate node, the same cache |
| Diagnostics | silent | collected per evaluation (no allocation when there are none) |

Expected shape: first-row cost ≈ today; steady-state per-row cost lower; memory
cost = one AST per distinct expression (measured: at most 11 distinct `Expression`
values across the entire checked-in corpus).

### 26.2 Recommended caching layers (in order of value)

1. **Aggregate value cache** (exists; must gain the mode key) — the dominant cost in
   row-heavy reports.
2. **Parse cache** per (mode, text), engine-owned — removes tokenizer/parser work
   from every row.
3. **Intra-expression aggregate memoization**: an aggregate node is row-independent,
   so `SUM([Amount]) + SUM([Amount])` needs one scan, not two. The cross-evaluation
   cache achieves this today; intra-expression memoization removes the dependence on
   the cache for the same result.
4. Explicitly **not** recommended: caching field reads (breaks dataset semantics),
   caching per-row results across rows (wrong by definition), or a global
   cross-engine cache (would leak between executions and defeat `Prepare`).

### 26.3 What must be measured in 4B-2B (not assumed)

* Rows/second for a 100-row and a 10 000-row report with 5 expressions (legacy vs
  modern), reusing the `VittixRunner` elapsed-ms observations.
* Aggregate scans per render (Phase 2/3 counters already measure this).
* Parse-cache hit ratio (new counter).
* Memory: distinct-AST count for the 42 fixtures (expected ≤ 20).

No optimization work is in scope for 4B-2B beyond "do not regress"; the modern
evaluator should be faster per row simply because it stops re-parsing strings.

## 27. Security / Safety

### 27.1 Threat model

A `.vrt` file is data supplied by users and partners. It is already parsed as JSON
and interpreted as report layout, and both the standalone designer and the runtime
open files from untrusted places. The expression language must therefore treat
*expression text as untrusted input*.

### 27.2 Controls

| Risk | Control |
| --- | --- |
| Arbitrary code execution | no `EVAL`, no RTTI invocation, no Delphi-code strings, no dynamic method lookup; the evaluator is a closed interpreter over a fixed node set |
| Object access | expressions cannot reference objects, classes, properties or the report model; the only inputs are `TExpressionContext` values (tokens, parameters, variables, dataset fields) |
| Filesystem / registry / network / environment | no functions exist for them, and none may be added (13.3 "Not recommended") |
| Dynamic identifier construction | not expressible: token text comes from the template, never from a computed string |
| Script injection | scripting stays separate (whitelisted `Cmd_*` handlers). Expression evaluation must not be reachable *from* scripts, and scripts must not be reachable *from* expressions |
| Uncontrolled recursion | no user-defined functions ⇒ evaluation is a finite tree walk; parser depth is bounded; no loops |
| Extremely expensive expressions | length limit, node limit, nesting-depth limit, aggregate-count limit, aggregate re-entrancy guard; aggregates stay bounded by the dataset/group range (existing behaviour) |
| Denial of service via aggregates | the aggregate cache (with the corrections in section 25) plus the limits; today's behaviour already scans the range once per distinct aggregate |
| Injection into exports (HTML/PDF/XLSX) | unchanged from today: the evaluator returns text and the existing exporters already escape. The modern language adds no new output channel |
| Information disclosure | no function can read outside the report context; diagnostics may contain token names (template data), never machine paths or environment values |

### 27.3 Non-negotiable invariants

1. The evaluator never executes code or performs I/O.
2. The evaluator never mutates report state, the dataset cursor (except the existing
   aggregate scan, which restores it), the cache, or the context.
3. The evaluator never allocates unbounded memory (all limits are explicit).
4. The evaluator never raises by default, so a malformed file cannot abort a print
   run (legacy contract retained in both modes; modern adds diagnostics).
5. Frozen legacy behaviour remains the default for every existing report.

### 27.4 Limits (concrete defaults)

| Limit | Value | Rationale |
| --- | --- | --- |
| Max expression length | 4 096 characters (hard), warn above 512 | the measured corpus maximum is 22 characters |
| Max parenthesis/nesting depth | 32 default, 128 hard cap | prevents stack exhaustion in the recursive-descent parser |
| Max AST nodes per expression | 512 | prevents pathological trees; the corpus needs < 10 |
| Max function arguments | 16 (variadic functions) | no report needs more |
| Max aggregates per expression | 8 | bounds scans per evaluation |
| Aggregate nesting | 1 (no nesting) | section 16.5 |
| Parser recursion | explicit depth counter, never unbounded | stack safety on the UI thread |
| Diagnostics per evaluation | 64, then suppressed | avoids diagnostic-driven memory growth |
| Parse-cache entries | 1 024 per execution | bounded memory for generated reports |

Exceeding a limit produces `LimitExceeded` (lenient → `Null`), never an exception in
render mode.


## 28. Proposed Test Matrix (Phase 4B-2B)

The matrix below is the acceptance contract for the implementation. Every row must
exist as a test, and every legacy-side expectation must be *measured*, not assumed
(the Phase 4B-1 probe technique is reusable).

```text
A. Lexical
   A1 number literals: integer, decimal, whitespace, '1.' / '.5' rejected
   A2 string literals: empty, doubled quote, embedded operators, no escapes
   A3 keywords/case: AND and and, TRUE/true, SUM/sum
   A4 whitespace: tabs/CRLF between tokens
   A5 bracket tokens: verbatim contents; unterminated '[' = SyntaxError
   A6 length limit: warn above 512, LimitExceeded above 4096

B. Arithmetic
   B1 basic + - * / on integers and doubles
   B2 precedence: 1 + 2 * 3 = 7; 10 - 2 * 3 = 4; 100 / 5 / 2 = 10
   B3 associativity: 2 - 3 - 4 = -5; 10 / 2 * 3 = 15
   B4 unary: -2 * 3 = -6; 2 + -3 = -1; unary on a string = InvalidArgument
   B5 division by zero: NULL + DivisionByZero diagnostic (never exception, never 0)
   B6 parentheses: (1 + 2) * 3 = 9; ((1)) = 1; 2 * (3 + 4) = 14
   B7 nesting depth: 32 ok, 33 diagnosed, 129 LimitExceeded

C. Types and promotion
   C1 1 + 2.5 = 3.5; '10' + 5 = 15; 'a' + 5 = InvalidArgument
   C2 'a' + 'b' = 'ab'; 'a' + 1 = InvalidArgument; 'a' + NULL = NULL
   C3 comparisons: numeric/numeric, string/string, numeric/numeric-string
   C4 1 = '1' True; 1 = 'a' InvalidArgument
   C5 DateTime vs DateTime compares; DateTime vs Number = TypeError
   C6 Currency field passes through as Number; no decimal type exists
   C7 result Variant forms: Double/Integer/Boolean/UnicodeString/Null/Date

D. Comparison and Boolean logic
   D1 all six operators plus != and IS [NOT] NULL
   D2 case-insensitive text compare; 'ALICE' = [Name]
   D3 comparison chaining 1 < 2 < 3 = SyntaxError
   D4 AND/OR/NOT truth tables including the Kleene U rows
   D5 short-circuit: guarded division and guarded aggregate are not evaluated
   D6 precedence: NOT > AND > OR; NOT a = b parses as NOT (a = b)
   D7 truthiness: '0','1','true','false','abc','', numeric strings

E. NULL
   E1 NULL literal is varNull; NULL + 1 = NULL; NULL = NULL = NULL
   E2 IS NULL / IS NOT NULL on a null field, empty string, missing token, parameter
   E3 null field arithmetic/concatenation propagates
   E4 COUNT([nullField]) = 0 while COUNT() = rows
   E5 SUM/AVG/MIN/MAX skip nulls; empty-range results (OD-1 decision)
   E6 IF(NULL, a, b) = b; COALESCE(NULL, x) = x
   E7 consumer boundary: VarToStr(Null) = ''; ConditionVariantToBool(Null) = False

F. Tokens
   F1 field, qualified field, unknown field, null field, repeated field
   F2 parameters (three prefixes, case, missing), variables (case, missing)
   F3 all system tokens with identical legacy values
   F4 [Var.X] alias; [ReportTitle] shadowing documented behaviour
   F5 UserDataSet source resolution (and the OD-11 aggregate decision)

G. Functions
   G1 each catalogue function: valid input, boundary input, NULL input
   G2 unknown function, wrong arity, wrong type → diagnostics + NULL
   G3 lazy IF/COALESCE: untaken branch not evaluated (aggregate + division proof)
   G4 maximum argument count limit

H. Aggregates
   H1 SUM/COUNT/AVG/MIN/MAX over a full dataset and a bookmark group range
   H2 composition: SUM(x)+1, 1+SUM(x), SUM(x)*2, SUM(x)+SUM(y)
   H3 aggregate in a comparison, in IF, inside a scalar function argument
   H4 nested aggregate = SyntaxError; aggregate re-entrancy guard
   H5 empty range; all-null range; mixed null range
   H6 cursor restoration and Eof-safe behaviour (mirrors Phase 1 GAP-001)
   H7 Phase 3 cache: hit/miss counts and one traversal for repeats
   H8 cache separation: a legacy-cached value is not reused for modern text

I. Errors and limits
   I1 each diagnostic code reachable by a test, with a reported position
   I2 lenient mode never raises; strict mode raises with code and position
   I3 limits: length, depth, nodes, arguments, aggregates, diagnostics cap

J. Compatibility
   J1 the full Phase 4A corpus in legacy mode: unchanged (existing tests keep passing)
   J2 the full Phase 4B differential corpus: legacy unchanged
   J3 the 159 fixture values in both modes: only the 2 documented differences
   J4 ExpressionLanguageVersion absent/0/1/>1 behaviour, including the load warning
   J5 two-argument Evaluate never consults the mode (behavioural proof)
   J6 mixed legacy + modern reports in one process
   J7 VittixRunner page counts unchanged for all 42 fixtures in legacy mode
   J8 export/preview parity for a modern report (text/HTML/XLSX)

K. Consumers
   K1 text/memo/field/label ResolveDisplayText
   K2 object PrintWhen, band PrintWhen, conditional colours
   K3 barcode and table PrintWhen paths
   K4 text exporter, HTML export, XLSX export
   K5 aggregate inner expression and summary band
   K6 designer Validate path and preview/print mode agreement
```

## 29. Open Decisions

Each item records the recommendation, the alternative, the observable impact and
what is needed from the project owner. Items marked **[blocking]** must be decided
before implementation starts.

| ID | Decision | Recommendation | Alternatives | Impact if wrong |
| --- | --- | --- | --- | --- |
| **OD-1** [blocking] | Aggregate over an empty or all-null range | `NULL` (SQL) | `0` (legacy-compatible) | blank vs `0` for empty groups; affects every summary band |
| **OD-2** [blocking] | `NULL + 1` | propagate `NULL` | `0` (legacy) / `TypeError` | arithmetic on null fields silently yields a number today |
| **OD-3** [blocking] | `COUNT([x])` with null values | skip nulls (SQL) | count them (legacy measures 3 for 3 null rows) | documented Phase 4A behaviour changes (flagged as a defect there) |
| **OD-4** | `x / 0` | `NULL` + `DivisionByZero` diagnostic | raise / `0` / legacy no-op | guards must stay expressible |
| **OD-5** [blocking] | UNKNOWN condition outcome | not printed (suppressed) | print / per-property setting | decides whether null-driven conditions hide or show content |
| **OD-6** | Bare identifier (`abc`) | `SyntaxError` + diagnostic | treat as a string literal (legacy text semantics) | fixture `PrintWhen` = `abc`: diagnosed vs text (same outcome) |
| **OD-7** | Scalar min/max names | `LEAST` / `GREATEST` | overload `MIN`/`MAX` by arity | function-name space and parser ambiguity |
| **OD-8** [blocking] | Unknown field/token | `NULL` + `UnknownField` | text `'0'` (legacy) / strict error | printed `0` vs blank for missing data — the measured fixture-visible difference |
| **OD-9** [blocking] | Mode carrier | `.vrt` `ExpressionLanguageVersion` + model property; two-arg `Evaluate` permanently legacy | process-global switch (rejected) | decides whether existing reports can ever change meaning |
| **OD-10** | `NOT` precedence | SQL-style: `NOT a = b` → `NOT (a = b)` | Delphi-style: `(NOT a) = b` | author comprehension of negation |
| **OD-11** | Aggregates over `TVittixUserDataSet` | require a `TDataSet`; `UnsupportedDataSet` otherwise | implement forward-cursor traversal | silent literal text today; a fix enables invoice-style aggregates |
| **OD-12** | Qualified aggregates (`SUM([Detail.Amount])`) | not in V1 (diagnostic) | implement with a defined row-synchronisation rule | scope creep; depends on GAP-002 |
| **OD-13** | `CONTAINS`/`STARTSWITH`/`ENDSWITH` case sensitivity | case-insensitive (consistent with comparison) | case-sensitive plus `…I` variants | author expectation vs consistency |
| **OD-14** | Literal `1234,50` | `SyntaxError` (invariant literals) | accepted as a diagnosed locale value | portability vs convenience |
| **OD-15** [blocking] | New public API (`Evaluate(…, Mode)` + `Validate(…)`) | approve as additive overloads | internal-only plumbing | designer validation and CI strictness depend on it |
| **OD-16** [blocking] | Aggregate cache key additions (mode, `ReportTitle`, `ReportDate`, optional mutation counter) | approve all four | approve only the mode | a stale aggregate can print a wrong total |
| **OD-17** | `[Var.X]` explicit alias | add it (optional) | keep only the bare form | minor; removes ambiguity in modern reports |
| **OD-18** | Date literals / date arithmetic | defer (section 19) | add `DATE(...)`/`DAYS()` in 4B-2B | scope; no fixture needs it |

No item on this list requires a change to legacy behaviour: each is an addition, a
modern-mode-only choice, or a cache-key tightening.

## 30. Recommended Phase 4B-2B Implementation Plan

### 30.1 Scope (deliberately small)

In scope: tokenizer, parser, AST, evaluator, the function catalogue in 15.3,
aggregate composition, structured diagnostics, mode plumbing, the `.vrt` key
(read/write), the compatibility analyzer as a *test-only* tool, and tests.

Out of scope: designer UI, migration UX, date features, `CASE`, user functions,
subreport/named-dataset aggregate traversal, performance tuning beyond
"no regression", removing the legacy evaluator.

### 30.2 Stages, each independently reviewable and reversible

| Stage | Deliverable | Exit criteria |
| --- | --- | --- |
| **2B-1 Parser core** | tokenizer + parser + AST + limits, no token evaluation | parser unit tests (matrix A, B2/B3/B6/B7, D6); no production caller yet |
| **2B-2 Evaluator core** | literals, tokens, arithmetic, comparison, Boolean, NULL, parentheses | matrix B, C, D, E1–E3, E7; the legacy differential corpus is unchanged |
| **2B-3 Tokens + functions** | token-resolution parity and catalogue 15.3 | matrix F, G; fixture token values equal legacy for existing tokens |
| **2B-4 Aggregates** | aggregate nodes delegating to the existing traversal, composition, guards | matrix H1–H6; the Phase 3 cache test stays green |
| **2B-5 Diagnostics + limits** | diagnostics object, codes, strictness, counters, `Validate` | matrix I; validation usable from tests without the designer |
| **2B-6 Mode plumbing** | context field, `Evaluate(…, Mode)`, model property, engine propagation | matrix J5, J6; all 564 existing tests pass **unmodified** |
| **2B-7 `.vrt` key** | serializer read/write + load warning; one additive key | matrix J4; serializer round-trip tests green; no existing file modified |
| **2B-8 Cache keying** | mode + `ReportTitle` + `ReportDate` (+ optional mutation counter) in the aggregate cache key | matrix H7/H8; Phase 3 traversal counts unchanged for unaffected expressions |
| **2B-9 Compatibility analyzer + fixtures** | test-only dual evaluator over the 159 fixture values; a modern fixture report **only if approved** | matrix J3: exactly the two documented differences |
| **2B-10 End-to-end verification** | `VittixRunner` legacy run identical to the Phase 4B-1 baseline; one modern smoke report | matrix J7, J8, K |

### 30.3 Hard rules for the implementation phase

1. **No legacy file changes beyond what this design lists**: the context record
   field, engine propagation, cache key, serializer key. The compatibility
   evaluator and its tests stay frozen.
2. **Default off.** Until 2B-6 lands, no production path may reach modern
   evaluation. Until 2B-7 lands, no `.vrt` may declare it.
3. **Every legacy expectation is measured** (probe technique), never reasoned.
4. **The 564-test suite stays green after every stage**, unmodified.
5. **The runner baseline stays identical** for all 42 fixtures in legacy mode.
6. **No optimization** beyond avoiding O(n²) aggregate behaviour.
7. **Documentation**: each stage updates this document with a status note, and
   `docs/Phase4A` only where a behaviour note is genuinely needed.

### 30.4 Estimated size (planning only)

| Component | Rough size |
| --- | --- |
| Tokenizer + parser + AST | ~1 200–1 600 lines |
| Evaluator + type/promotion + NULL | ~700–900 lines |
| Function catalogue (15.3) | ~500–700 lines |
| Diagnostics + limits | ~250–350 lines |
| Mode plumbing (context, engine, serializer, component) | ~200–300 lines |
| Tests (matrix A–K) | ~1 800–2 400 lines |

### 30.5 Recommendation

Proceed to Phase 4B-2B **only after OD-1, OD-2, OD-3, OD-5, OD-8, OD-9, OD-15 and
OD-16 are explicitly decided.** Those eight items determine the language's
observable behaviour and the safety of the compatibility story; the remainder can
be settled during implementation without changing the plan.

## Appendix A — Required Decision Table

| Feature | Legacy | Proposed Modern | Migration Risk | Decision |
| --- | --- | --- | --- | --- |
| Arithmetic precedence | flat left-to-right (`1 + 2 * 3` = 9) | standard precedence, left-associative (`= 7`) | High | **Adopt** in modern mode only; legacy unchanged |
| Parentheses | not parsed (`(1 + 2) * 3` = 0) | conventional grouping, nesting to depth 32 | High | **Adopt** |
| AND | unsupported (`1 = 1 AND 2 = 2` = False) | Kleene conjunction, left-assoc, short-circuit, above `OR` | High | **Adopt** |
| OR | unsupported (`1 = 2 OR 2 = 2` = False) | Kleene disjunction, lowest precedence, short-circuit | High | **Adopt** |
| NOT | unsupported (`NOT (1 = 2)` = False) | Kleene negation, unary right, below comparison (SQL-like) | High | **Adopt** (OD-10 for the precedence choice) |
| `!=` | unsupported (degrades to `=` with a `'x !'` operand) | exact synonym of `<>` | Medium | **Adopt** |
| NULL | no model: literal is text `'NULL'`, null fields become `''`, `NULL + 1` = 0 | real `Null` value, Kleene logic, `IS NULL` / `IS NOT NULL`, propagation in arithmetic, null-skipping aggregates | Very High | **Adopt** in modern mode only (OD-1, OD-2, OD-3) |
| Missing fields | text `'0'` fallback (prints `0`) | `Null` + `UnknownField` diagnostic (prints blank) | High | **Adopt** (OD-8) |
| Strings | single quotes, `''` escape, `"` literal, case-insensitive comparison | unchanged (same literal rules and comparison) | Medium | **Keep as-is** — no reason to change |
| Aggregates | prefix-only, early return (truncates the tail) | first-class function calls: composition, comparison, conditionals, scalar-function arguments | Very High | **Adopt** in modern mode only |
| Errors | silent fallback, no diagnostics | structured diagnostics with positions; lenient at render, strict in tests/CI; never a legacy exception | High | **Adopt** |
| Locale | current-locale numeric parsing (`,` accepted) | invariant literals (`.` only, `,` is the argument separator); locale-tolerant parsing of parameter/variable text; locale-sensitive formatting | Medium | **Adopt** (OD-14 for `1234,50`) |

Supporting decisions (not in the required table but part of the same contract):
function catalogue (15.3), truthiness = the existing `ConditionVariantToBool`
mapping, bracket-token syntax kept verbatim, per-report mode carrier (OD-9), and the
aggregate cache key additions (OD-16).

## Appendix B — Modern Language Examples (future test corpus)

Each row becomes a test with the stated expected result, expected type, and (where
relevant) the expected diagnostic. Dataset for the aggregate rows: three rows with
`Amount` = 10.5 / 20 / 5, `Qty` = 2 / 4 / 10, `Rate` = 3.5 / 1.25 / 2,
`NullText` = null in all rows, `Name` = Alice / Bob / Carol.

### B.1 Arithmetic and grouping

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `1 + 2` | `3` | Number |
| `1 + 2 * 3` | `7` | Number |
| `10 - 2 * 3` | `4` | Number |
| `(1 + 2) * 3` | `9` | Number |
| `1 + (2 * 3)` | `7` | Number |
| `((1 + 2) * 3)` | `9` | Number |
| `10 / 2 * 3` | `15` | Number |
| `2 - 3 - 4` | `-5` | Number |
| `-2 * 3` | `-6` | Number |
| `2 + -3` | `-1` | Number |
| `10 / 0` | `NULL` + `DivisionByZero` | Null |
| `1,5 + 1` | `SyntaxError` | — |

### B.2 Comparison and Boolean

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `1 = 1` | `True` | Boolean |
| `1 <> 2`, `1 != 2` | `True` | Boolean |
| `2 >= 2`, `2 <= 2` | `True` | Boolean |
| `10 = 10.0` | `True` | Boolean |
| `'a' = 'A'` | `True` | Boolean |
| `1 = '1'` | `True` | Boolean |
| `1 = 'a'` | `NULL` + `InvalidArgument` | Null |
| `1 < 2 < 3` | `SyntaxError` | — |
| `1 = 1 AND 2 = 2` | `True` | Boolean |
| `1 = 2 OR 2 = 2` | `True` | Boolean |
| `NOT (1 = 2)` | `True` | Boolean |
| `NOT 1 = 2` | `True` | Boolean |
| `TRUE AND FALSE` | `False` | Boolean |
| `FALSE AND NULL` | `False` | Boolean |
| `TRUE OR NULL` | `True` | Boolean |
| `NOT NULL` | `NULL` | Null |

### B.3 NULL

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `NULL` | `NULL` | Null |
| `NULL + 1` | `NULL` | Null |
| `NULL = NULL` | `NULL` (UNKNOWN) | Null |
| `NULL IS NULL` | `True` | Boolean |
| `NULL IS NOT NULL` | `False` | Boolean |
| `[NullText] IS NULL` | `True` | Boolean |
| `COALESCE([NullText], 0) + 1` | `1` | Number |
| `IF([NullFlag], 'Y', 'N')` (null flag) | `'N'` | String |

### B.4 Fields, parameters, variables

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `[Name]` | `Alice` | String |
| `[Amount]` | `10.5` | Number |
| `[Qty] * [Rate]` | `7` | Number |
| `[MissingField]` | `NULL` + `UnknownField` | Null |
| `[MissingField] + 1` | `NULL` + `UnknownField` | Null |
| `[Param.ReportTitle]` | parameter text | String |
| `[Param.Missing]` | `NULL` + `UnknownParameter` | Null |
| `[CompanyName]` | variable text | String |
| `[Var.CompanyName]` | variable text | String |
| `[PageNo]` | page number (legacy parity) | Number / String |
| `[ReportTitle]` | context title (system token wins) | String |
| `[Detail.Amount]` (no such dataset) | current-row `Amount` + `UnknownDataSet` | Number |

### B.5 Strings

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `'hello'` | `hello` | String |
| `'a''b'` | `a'b` | String |
| `'"hello"'` | `"hello"` | String |
| `'a' + 'b'` | `ab` | String |
| `UPPER('acme')` | `ACME` | String |
| `LOWER('ACME')` | `acme` | String |
| `TRIM('  x ')` | `x` | String |
| `LEN('abcd')` | `4` | Number |
| `SUBSTR('abcdef', 2, 3)` | `bcd` | String |
| `CONTAINS('Acme Corp', 'corp')` | `True` | Boolean |
| `STARTSWITH('Acme', 'AC')` | `True` | Boolean |
| `ENDSWITH('Acme', 'ME')` | `True` | Boolean |

### B.6 Functions and conditionals

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `ABS(-5)` | `5` | Number |
| `ROUND(2.345, 2)` | `2.35` | Number |
| `LEAST(3, 1, 2)` | `1` | Number |
| `GREATEST(3, 1, 2)` | `3` | Number |
| `IF(1 = 1, 'a', 'b')` | `a` | String |
| `IF(1 = 2, 'a', 'b')` | `b` | String |
| `IF([Rate] > 0, [Qty] / [Rate], 0)` | `0.5714…` | Number |
| `COALESCE(NULL, 'x')` | `x` | String |
| `COALESCE([MissingField], 0) + 1` | `1` | Number |
| `UNKNOWNFN(1)` | `NULL` + `UnknownFunction` | Null |
| `ROUND(1, 2, 3)` | `NULL` + `InvalidArgumentCount` | Null |

### B.7 Aggregates

| Expression | Expected result | Expected type |
| --- | --- | --- |
| `SUM([Amount])` | `35.5` | Number |
| `SUM([Amount]) + 1` | `36.5` | Number |
| `1 + SUM([Amount])` | `36.5` | Number |
| `SUM([Amount]) * 2` | `71` | Number |
| `SUM([Qty]) > 100` | `False` | Boolean |
| `SUM([Qty]) > 10` | `True` | Boolean |
| `SUM([Qty] * [Rate])` | `32` | Number |
| `AVG([Amount])` | `11.833…` | Number |
| `MIN([Amount])`, `MAX([Amount])` | `5`, `20` | Number |
| `COUNT()` | `3` | Integer |
| `COUNT([NullText])` | `0` (OD-3) | Integer |
| `ROUND(SUM([Amount]) / 3, 2)` | `11.83` | Number |
| `IF(SUM([Amount]) > 1000, 'High', 'Low')` | `Low` | String |
| `SUM(AVG([Amount]))` | `SyntaxError` | — |
| `SUM([Amount])` with a 2-row group range | `30.5` | Number |
| `SUM([Amount])` over an empty range | `NULL` (OD-1) | Null |

## Appendix C — Repository Evidence Index

Every claim in this document is traceable to one of these sources. Line numbers
were read directly during this phase.

### Production units

| Source | Evidence |
| --- | --- |
| `source/Vittix.Report.Expressions.pas` | the public boundary: `TReportExpression.Evaluate(Expr, Context)` only; the implementation delegates |
| `source/Vittix.Report.Expressions.Compat.pas` | the 9-stage legacy order; `TCompatArithmeticScanner` (optional sign, digits + `.` + `,`, whitespace skipping, `/0` no-op); `TryStrToFloat` with the current locale; ordered comparison operators `<= >= <> = < >`; `IsSingleTokenExpression`; the `'0'` text fallback; the aggregate prefix list |
| `source/Vittix.Report.Aggregates.pas` | `TryEvaluate` parsing (`Pos('(')`, `LastDelimiter(')')`), bookmark scan, cursor restore, cache hit/store calls, `COUNT` counting non-null Variants |
| `source/Vittix.Report.Context.pas` | `TExpressionContext` fields and `IReportRenderHooks` (`GetNamedDataSet`, aggregate cache, subreport model) |
| `source/Vittix.Report.Utils.pas` | `TryGetField`, `SourceActive`, `SafeSourceFieldValue`, `SafeSourceFieldAsString`, `VarIsBlank`, and the Boolean coercion contract (declaration line 97; body 318–356: Null/empty → False, Boolean → itself, numeric ≠ 0, `0/false/no/n/off` → False, `1/true/yes/y/on` → True, numeric string → ≠ 0, other text → False) |
| `source/Vittix.Report.Engine.pas` | `TAggregateCacheEntry` key fields and `Matches` (95–116, 333–358), `ClearExecutionCaches` (511–515), band `PrintWhen` building `Ctx0` (1098–1123), `GetNamedDataSet` (2368–2372), aggregate cache access (2374–2400) |
| `source/Vittix.Report.Objects.pas` | `ShouldPrintObject` (556–589), `ResolveConditionalStyle` (596–612), `ResolveDisplayText` (614–634), expression call sites at 549, 580, 618, 631, 742, 778, 874, 1368 |
| `source/Vittix.Report.Objects.Table.pas` | object-local `ShouldPrintTableObject` (40–68); call at 59 |
| `source/Vittix.Report.Objects.Barcode.pas` | object-local `ShouldPrintBarcodeObject` (217–245); call at 236 |
| `source/Vittix.Report.Export.Text.pas` | `ShouldExportObject` (45–59), `TextObjectValue` (61–74) |
| `source/Vittix.Report.Serializer.pas` | versioning notes (15–17), unknown-object preservation (33–38), `Root.AddPair('Version', 2)` (1100), version read-back (1393–1394), `AVersion` threading through every `LoadProperties` |
| `source/Vittix.Report.Model.pas` | report-level properties: `Objects`, `PageSettings`, `FieldNames`, `DataSetNames`, `Variables` (TStrings with `NameValueSeparator='='`), `Title`, `Author`, `Description` |
| `source/Vittix.Report.Scripting.pas`, `Vittix.Report.ScriptHost.Adapter.pas` | the script execution surface and the whitelisted `Cmd_*` dispatcher (35–83) |
| `source/Vittix.Report.Export.Commands.pas` | `TReportExportDocument`/page/command model used by export verification |
| `source/Vittix.Report.TraversalDiagnostics.pas` | Phase 2/3 diagnostics precedent (process-local counters, no control-flow effect) |

### Tests, documentation, designer and fixtures

| Source | Evidence |
| --- | --- |
| `tests/Test.Vittix.Report.Phase4A.pas` | the executable legacy contract |
| `tests/Test.Vittix.Report.Phase4B.pas` | differential harness, consumer coverage, fixture coverage, cache assertions |
| `tests/Test.Vittix.Report.ExpressionLegacyReference.pas` | frozen predecessor implementation |
| `tests/Test.Vittix.Report.ExpressionAudit.pas` | 31 `_CurrentBehavior` defect tests: precedence, parentheses, `AND`, `!=`, `NULL`, aggregate truncation, UserDataSet aggregates |
| `tests/Test.Vittix.Report.Characterization.pas`, `Test.Vittix.Report.Phase1/2/3.pas` | pagination, memory, cache and fixture-shape baselines |
| `docs/Phase4A-Expression-Compatibility-Contract.md` | `MUST PRESERVE` semantics, consumer matrix, cache interaction notes |
| `docs/Phase4B-Compatibility-Evaluator.md` | replacement record, cache integration, known limitations |
| `docs/Phase4I-20-ExpressionEngineDesign.md` | prior sketch: token kinds (§4.1), node types (§4.2), EBNF grammar (§5), diagnostics (§8), NULL table (§9), parse-cache recommendation (§11), risk table (§15) |
| `vittixdesigner/Frm.ExpressionEditor.pas` | line 39 advertises `IF(<Dataset.Value> < 0, clRed, clBlack)`, unsupported by legacy |
| `vittixdesigner/Frm.ExpressionHelper.pas` | operator buttons + templates (127–131), example list (147–152), property-key buckets (174–189), field insert `'[' + FieldName + ']'` (261), "Check" evaluation (319–346) |
| `reports/*.vrt` (42 files) | all carry `"Version": 2`; no expression-language key exists anywhere |
| fixture scan | 159 string values containing `[...]`; 11 distinct `Expression` values; 10 distinct `PrintWhen` values; maximum expression length 22 characters (mean 10.4) |
| `reports/37_report_variables.vrt` | declares `CompanyName`, `CompanyAddress`, `ReportFooter` as variables (18–21) |
| `reports/45_landscape_summary.vrt` | memo `Text` = `[Companies."CompanyName"]` with band `"DataSetName": "Companies"` — the only qualified token in the corpus |
| `reports/31_runtime_parameter_values.vrt`, `reports/34_reportdata_contract.vrt` | `[Param.ReportTitle]`, `[Param.AmountInWords]`, `[Param.BankText]`, `[Param.FilterSummary]` |
| `reports/22_expression_usage_demo.vrt` (and 25/26/28) | `[RecNo]`, `[Qty] * [Rate]`, `[MissingField] + 1`, `PrintWhen [Qty] > 5`, `PrintWhen [MissingField] >` |
| `reports/20_printwhen_boolean_coercion.vrt` | `PrintWhen` values `0`, `1`, `true`, `false`, `abc` |

### Measured legacy values (Phase 4B-2A probe)

All "legacy result (measured)" columns come from a read-only probe compiled from the
current sources. It builds an in-memory dataset (ID/Amount/Name/Qty/Rate/NullText/
CustomerName/GroupName; three rows), sets two parameters and three variables, then
evaluates ~120 expressions with `TReportExpression.Evaluate`, printing `VarType`
and `VarToStr`. Representative results:

```text
'1 + 2 * 3'                     => varDouble   | 9
'10 - 2 * 3'                    => varDouble   | 24
'(1 + 2) * 3'                   => varDouble   | 0
'(1'                            => varUString  | (1
'2 * (3 + 4)'                   => varDouble   | 2
'1 = 1 AND 2 = 2'               => varBoolean  | False
'1 < 2 AND 3 < 4'               => varBoolean  | True
'1 < 2 < 3'                     => varBoolean  | True
'1 + 2 > 2'                     => varBoolean  | False
'NOT (1 = 2)'                   => varBoolean  | False
'SUM([Amount]) + 1'             => varDouble   | 35.5
'1 + SUM([Amount])'             => varDouble   | 1
'SUM([Qty]) > 100'              => varDouble   | 16
'IF(SUM([Amount]) > 1000, ...)' => varBoolean  | True
'''10'' + 5'                    => varDouble   | 0
'''a'' + ''b'''                 => varUString  | a' + 'b
'1 = ''1'''                     => varBoolean  | True
'NULL'                          => varUString  | NULL
'NULL + 1'                      => varDouble   | 0
'NULL = NULL'                   => varBoolean  | True
'NULL IS NULL'                  => varUString  | NULL IS NULL
'[NullText]'                    => varUString  |
'[NullText] + 1'                => varDouble   | 0
'COUNT([NullText])'             => varInteger  | 3
'[MissingField]'                => varDouble   | 0
'[MissingField] + 1'            => varDouble   | 1
'[MissingField] >'              => varBoolean  | True
'[MissingField] > 0'            => varBoolean  | False
'[MissingField] IS NULL'        => varUString  | 0 IS NULL
'abc'                           => varUString  | abc
'[ReportTitle]'                 => varUString  | Title
'[DataSet.Name]'                => varUString  | Alice
'UPPER(''acme'')'               => varUString  | UPPER('acme')
'IF(1 = 1, ''a'', ''b'')'       => varBoolean  | False
'LEN(TRIM([Remarks])) > 0'      => varBoolean  | True
'[Qty] > 1 AND [Qty] < 5'       => varBoolean  | True
'TRUE AND FALSE'                => varUString  | TRUE AND FALSE
```

## Appendix D — Phase Verification (no production changes)

Method used in this phase:

1. `git status`, `git branch --show-current`, `git rev-parse HEAD` and
   `git diff --stat` were recorded before any analysis (see the final report's
   "Repository Baseline" section).
2. Documentation, units, tests, fixtures and designer sources were reviewed
   read-only.
3. A throwaway console probe was compiled from the *current* sources under the
   gitignored `build/phase4b2a/` directory to measure legacy results. It is not
   part of the repository deliverable, is referenced by no project file, and no
   production source was modified to build it.
4. The existing test suite was executed to confirm no accidental change:
   **564 discovered, 564 passed, 0 failed, 0 errors** — the Phase 4B-1 state.
5. `git status` was re-checked at the end: the only new artifact is this document.

This phase did not: modify a production unit, add a tokenizer/parser/AST, add a
test, add a mode switch, touch the `.vrt` schema, touch the serializer, touch the
designer, touch rendering/print/export, or change any legacy behaviour.

### Explicit answers to the two required questions

> **How can VittixReport support modern semantics without changing the meaning of
> existing reports?**

By making modern semantics *unreachable* without an explicit opt-in that no
existing artifact carries:

* `TReportExpression.Evaluate(Expr, Context)` is permanently legacy — it has no
  mode parameter, so the ~10 consumer call sites can only become mode-aware by an
  explicit code change (Phase 4B-2B, stage 2B-6) that is reviewed as such;
* the mode's zero value is legacy, so every un-initialised context, every
  programmatic `TReportModel`, and every `.vrt` without the new key evaluates
  legacy;
* the mode lives in the template, so migration and rollback are per report;
* the aggregate cache gains the mode in its key, so a legacy value can never be
  served to a modern expression;
* the compatibility evaluator and its frozen reference tests are never removed,
  so legacy semantics remain executable and provable;
* measured evidence: 74 of 75 expressions in the corpus render identically, and
  the two that differ are already-wrong cases surfaced by diagnostics.

> **Can the existing Phase 3 aggregate cache safely cache modern evaluator
> results?**

**Not as-is.** It requires three corrections before modern mode ships: include the
expression mode in the key (otherwise identical text with different semantics can
collide), include `Context.ReportTitle` and `Context.ReportDate` (the Phase 4A
open item, which modern expressions are far more likely to exercise inside
aggregates), and close the script-mutation hole either with an explicit
invalidation hook or a context-mutation counter. All corrections are conservative
(they can only cause more cache misses) and leave ownership, lifetime and
pass-local clearing untouched, so the Phase 3 guarantees and measurements remain
valid.



























