# Phase 4I-20: Expression Engine Replacement — Design Document

## 1. Executive Summary

Replace the heuristic string-replacement evaluator in `Vittix.Report.Expressions.pas` with a proper lexer/tokenizer → recursive-descent parser → AST → evaluator pipeline, while preserving the `TReportExpression.Evaluate` class-function signature. A new `Vittix.Report.ExpressionParser.pas` unit houses the lexer, parser, AST types, evaluator, and diagnostics. `Vittix.Report.Aggregates.pas` is refactored to use the new AST evaluator internally, breaking its circular dependency on `Vittix.Report.Expressions`.

---

## 2. Unit/File Layout

| File | Purpose |
|------|---------|
| `source/Vittix.Report.Expressions.pas` | **Unchanged public API.** `TReportExpression.Evaluate` preserved verbatim. Internally delegates to `TExpressionParser.Evaluate`. Removes all heuristic code (EvalSimpleMath, ResolveFieldTokens heuristic, etc.) after delegate is wired. |
| `source/Vittix.Report.ExpressionParser.pas` | **NEW.** Lexer (`TExpressionLexer`), AST node types (`TExpressionNode` descendants), RecursiveDescentParser (`TExpressionParser`), Evaluator (`TExpressionEvaluator`), Diagnostics (`TExpressionDiagnostics`). |
| `source/Vittix.Report.Aggregates.pas` | **REFACTORED.** `TReportAggregates.TryEvaluate` no longer calls `TReportExpression.Evaluate` (breaking circular dep). Instead calls `TExpressionParser.EvaluateAggregate` or constructs AST for the inner expression and evaluates it via `TExpressionEvaluator` with aggregate iteration context. |
| `tests/Test.Vittix.Report.Expressions.pas` | **UPDATED.** Characterization tests that assert known-wrong results are replaced with correct-behavior assertions. No new test fixture class. |
| `tests/Test.Vittix.Report.ExpressionAudit.pas` | **UPDATED OR REPLACED.** All 29 audit tests that assert defective behavior are rewritten to assert correct behavior, OR a new `Test.Vittix.Report.ExpressionEngine` fixture replaces them with proper unit tests. |

### Dependency Graph (after)

```
Vittix.Report.ExpressionParser.pas
  uses: System.SysUtils, System.Variants, System.Classes, Data.DB, Vittix.Report.Context, Vittix.Report.Utils

Vittix.Report.Expressions.pas
  uses: Vittix.Report.ExpressionParser, Vittix.Report.Aggregates  (unchanged external)

Vittix.Report.Aggregates.pas
  uses: System.SysUtils, System.Variants, Data.DB, Vittix.Report.Context, Vittix.Report.ExpressionParser
  (NO longer uses Vittix.Report.Expressions — circular dep eliminated)

All other units (Engine, Bands, Objects, Export.Text, etc.)
  unchanged — still use Vittix.Report.Expressions only
```

---

## 3. TReportExpression.Evaluate Compatibility

The **exact** public signature is preserved:

```delphi
class function Evaluate(const Expr: string; const Context: TExpressionContext): Variant;
```

**Implementation after Phase 4I-20:**

```delphi
class function TReportExpression.Evaluate(
  const Expr: string;
  const Context: TExpressionContext): Variant;
var
  P: TExpressionParser;
begin
  if Trim(Expr) = '' then Exit('');
  P := TExpressionParser.Create(Expr, Context);
  try
    Result := P.Evaluate;
  finally
    P.Free;
  end;
end;
```

The old heuristic code (ResolveFieldTokens, EvalSimpleMath, FindComparisonOperator, TryEvalComparison, IsSingleTokenExpression) is removed. All characterizations of the old behavior are superseded by the new parser's documented behavior.

---

## 4. Type/Signature Definitions (Vittix.Report.ExpressionParser.pas)

### 4.1 Token Types

```delphi
type
  TExpressionTokenKind = (
    tkNumber,           // 42, 3.14, -7 (signed number literal)
    tkString,           // 'hello', 'a=b'
    tkIdentifier,       // Name, Amount, PageNo, SUM, COUNT — unquoted word
    tkFieldRef,         // [FieldName] — already resolved token reference
    tkParamRef,         // [Param.Name] — parameter reference
    tkVariableRef,      // [VarName] — variable reference
    tkTrue,             // TRUE
    tkFalse,            // FALSE
    tkNull,             // NULL
    tkAdd,              // +
    tkSubtract,         // -
    tkMultiply,         // *
    tkDivide,           // /
    tkEqual,            // =
    tkNotEqual,         // <>
    tkLess,             // <
    tkGreater,          // >
    tkLessOrEqual,      // <=
    tkGreaterOrEqual,   // >=
    tkAnd,              // AND
    tkOr,               // OR
    tkNot,              // NOT
    tkLParen,           // (
    tkRParen,           // )
    tkComma,            // , (function args)
    tkEOF
  );

  TExpressionSourcePos = record
    Line: Integer;
    Col: Integer;
    Index: Integer;  // 0-based offset into source expression
  end;

  TExpressionToken = record
    Kind: TExpressionTokenKind;
    Text: string;       // raw text (e.g. 'SUM', '(', '[Amount]', '3.14')
    Value: Variant;     // pre-resolved value where applicable (numbers, booleans, strings)
    Pos: TExpressionSourcePos;
  end;
```

### 4.2 AST Node Types

```delphi
type
  TExpressionNode = class abstract
  private
    FSourcePos: TExpressionSourcePos;
  public
    property SourcePos: TExpressionSourcePos read FSourcePos;
    constructor Create(ASourcePos: TExpressionSourcePos); virtual;
    function Evaluate(const Ctx: TExpressionContext): Variant; virtual; abstract;
    function ToString: string; override; virtual; // for debugging
  end;

  TExpressionLiteralNode = class(TExpressionNode)
  private
    FLiteralType: TExpressionTokenKind; // tkNumber, tkString, tkTrue, tkFalse, tkNull
    FLiteralValue: Variant;
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
  end;

  TExpressionFieldRefNode = class(TExpressionNode)
  private
    FOriginalText: string;  // '[FieldName]' or '[Param.X]' etc.
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
  end;

  TExpressionIdentifierNode = class(TExpressionNode)
  private
    FName: string;  // unquoted identifier (for function names or variable refs)
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
  end;

  TExpressionUnaryNode = class(TExpressionNode)
  private
    FOp: TExpressionTokenKind; // tkNot, tkSubtract, tkAdd
    FOperand: TExpressionNode;
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
  end;

  TExpressionBinaryNode = class(TExpressionNode)
  private
    FOp: TExpressionTokenKind;
    FLeft: TExpressionNode;
    FRight: TExpressionNode;
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
  end;

  TExpressionFunctionNode = class(TExpressionNode)
  private
    FName: string;
    FArgs: TList<TExpressionNode>;
  public
    function Evaluate(const Ctx: TExpressionContext): Variant; override;
    function ArgCount: Integer;
  end;
```

### 4.3 Parser and Evaluator Signatures

```delphi
type
  TExpressionDiagnostics = class
  private
    FMessages: TStringList;
    FErrorCount: Integer;
    FWarningCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddError(ASourcePos: TExpressionSourcePos; const AMessage: string);
    procedure AddWarning(ASourcePos: TExpressionSourcePos; const AMessage: string);
    property ErrorCount: Integer read FErrorCount;
    property WarningCount: Integer read FWarningCount;
    property Messages: TStrings read FMessages;
  end;

  TExpressionParser = class
  private
    FLexer: TExpressionLexer;
    FDiagnostics: TExpressionDiagnostics;
    FContext: TExpressionContext;
  public
    constructor Create(const AExpr: string; const AContext: TExpressionContext);
    destructor Destroy; override;
    function Evaluate: Variant;
    function EvaluateAggregate: Variant;  // for TReportAggregates alternative entry
    property Diagnostics: TExpressionDiagnostics read FDiagnostics;
    property HasErrors: Boolean read (FDiagnostics.ErrorCount > 0);
  end;

  TExpressionEvaluator = class
  private
    FContext: TExpressionContext;
    FGroupStart: TBookmark;
    FGroupEnd: TBookmark;
    FAggregateCaller: TFunc<string, Variant>; // for aggregate function delegation
  public
    constructor Create(const AContext: TExpressionContext);
    function EvaluateNode(Node: TExpressionNode): Variant;
    function EvaluateAggregate(
      const FuncName: string;
      const InnerExpr: string;
      const Context: TExpressionContext): Variant;
  end;
```

### 4.4 Lexer Signature

```delphi
type
  TExpressionLexer = class
  private
    FSource: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FTokens: TList<TExpressionToken>;
    FCurrentIndex: Integer;
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;
    procedure Tokenize;
    function NextToken: TExpressionToken;
    function PeekToken: TExpressionToken;
    function CurrentToken: TExpressionToken;
    property TokenCount: Integer read FTokens.Count;
    property Tokens[Index: Integer]: TExpressionToken read;
  end;
```

---

## 5. Grammar (EBNF)

```
expression      := or_expression ;
or_expression   := and_expression ( 'OR' and_expression )* ;
and_expression  := not_expression ( 'AND' not_expression )* ;
not_expression  := 'NOT' not_expression
                  | comparison ;
comparison      := arithmetic ( comparison_op arithmetic )? ;
comparison_op   := '=' | '<>' | '<' | '>' | '<=' | '>=' ;
arithmetic      := term ( ('+' | '-') term )* ;
term            := factor ( ('*' | '/') factor )* ;
factor          := unary ;
unary           := '+' factor
                  | '-' factor
                  | 'NOT' factor
                  | primary ;
primary         := '(' expression ')'
                  | function_call
                  | literal
                  | field_or_var_ref ;
function_call   := identifier '(' [ argument ( ',' argument )* ] ')' ;
argument        := expression ;
literal         := NUMBER
                  | STRING
                  | TRUE
                  | FALSE
                  | NULL ;
field_or_var_ref := '[' ( 'Param.' identifier
                        | 'Parameter.' identifier
                        | 'Parameters.' identifier
                        | identifier ( '.' identifier )? ) ']' ;
```

### Grammar Notes

1. **Precedence (low to high):** OR < AND < NOT < comparison < arithmetic (+,-) < arithmetic (*,/) < unary < primary
2. **Comparison** is binary and only occurs at comparison level; no comparison chains (e.g., `a < b < c` parses as `(a < b) < c` which is then evaluated as boolean compare).
3. **Function calls** are parsed at primary level, meaning `SUM(1+2)` parses as `SUM((1+2))` — arguments are full expressions.
4. **Field/Param/Variable references** are at primary level and are distinguished in the lexer by the `[` prefix.
5. **Parentheses** at primary level give explicit grouping.
6. **NOT** is at the unary level (lower precedence than comparison, higher than arithmetic), so `NOT a = b` parses as `NOT (a = b)`.

---

## 6. Ownership/Lifetime Strategy

### 6.1 AST Node Ownership

- `TExpressionParser` owns all AST nodes created during parsing.
- Nodes are stored in a `TList<TExpressionNode>` (or owned directly by parent nodes in the tree).
- `TExpressionParser.Destroy` frees all nodes.
- `TExpressionFunctionNode` owns its `FArgs` list and all argument nodes.
- `TExpressionBinaryNode` and `TExpressionUnaryNode` own their child nodes.
- **No AST node holds a reference to a mutable context.** The evaluator receives `TExpressionContext` (a record) by `const` at each `Evaluate` call.

### 6.2 Context Lifetime

- `TExpressionContext` is a record passed by const reference. It contains borrowed references (bookmarks, TStrings, TDataSet). The parser and evaluator do NOT store the context beyond a single `Evaluate` call.
- The `TExpressionParser` stores `FContext` as a record field for the duration of `Evaluate` but does not retain it after.

### 6.3 Diagnostics

- `TExpressionDiagnostics` is owned by `TExpressionParser` and freed in its destructor.
- Diagnostics are accumulated during parsing AND evaluation.

### 6.4 TExpressionParser Lifetime

- Created per expression in `TReportExpression.Evaluate`.
- Freed immediately after evaluation (try/finally).
- No caching by default (see Section 11 for cache recommendation).

---

## 7. Aggregate Iteration Strategy

### 7.1 TDataSet Aggregates

When a `SUM/COUNT/AVG/MIN/MAX` function is evaluated over a `TDataSet`:

```
1. Save current bookmark (SaveBM)
2. DisableControls
3. If Context.GroupStart <> nil: GotoBookmark(GroupStart); else: First
4. Iterate while not Eof and not at GroupEnd:
   a. Evaluate inner expression for current row via EvaluateNode
   b. Accumulate per aggregate function
   c. Next
5. Restore bookmark (SaveBM), FreeBookmark(SaveBM), EnableControls
```

This mirrors the current `TReportAggregates.TryEvaluate` logic but:
- Uses `EvaluateNode` instead of `TReportExpression.Evaluate` (eliminating circular dep).
- The inner expression is parsed once into an AST, then `EvaluateNode` is called per row.
- Bookmark leak is prevented by try/finally.

### 7.2 TVittixUserDataSet Aggregates

When `Context.UserDataSet` is assigned (and `Context.DataSet` is nil or inactive):

```
1. Call UserDataSet.First
2. Iterate while not UserDataSet.Eof:
   a. For each field reference in the AST, call UserDataSet.GetValue(fieldName)
   b. Evaluate inner expression via EvaluateNode (which uses UserDataSet for field refs)
   c. Accumulate per aggregate function
3. No bookmark save/restore (UserDataSet may not support bookmarks)
```

**Key design decision:** `TExpressionNode.Evaluate` for `TExpressionFieldRefNode` checks `Context.UserDataSet` first via `SafeSourceFieldValue` (from `Vittix.Report.Utils`), then falls back to `Context.DataSet`. This is the same resolution order used by the current heuristic but moved to the AST evaluator.

### 7.3 Aggregate Function Resolution

Aggregate functions are handled by `TExpressionFunctionNode.Evaluate`:

```delphi
function TExpressionFunctionNode.Evaluate(const Ctx: TExpressionContext): Variant;
begin
  if FName in ['SUM','COUNT','AVG','MIN','MAX'] then
    Result := TExpressionEvaluator.EvaluateAggregate(FName, Self, Ctx)
  else
    Result := Null; // unknown function — safe fallback
end;
```

`TExpressionEvaluator.EvaluateAggregate` performs the iteration described in 7.1/7.2, calling `EvaluateNode` on each argument node for each row.

### 7.4 Breaking the Circular Dependency

Current: `Expressions.pas` → `Aggregates.pas` → `Expressions.pas` (circular).

After: `Aggregates.pas` → `ExpressionParser.pas` → `Expressions.pas` (no cycle; ExpressionParser is new and lower in the dependency graph). `Expressions.pas` calls `ExpressionParser` but `ExpressionParser` does NOT call `Expressions.pas` — it calls `Utils` and `Context` only.

---

## 8. Diagnostic/Default-Result Policy

### 8.1 Safe No-Exception Behavior

Every evaluation path that could fail returns a safe default:

| Failure Mode | Default Result | Diagnostic |
|---|---|---|
| Empty expression `''` | `''` (empty string) | None |
| Unknown token/field | `0` (numeric) or `''` (string context) | Warning (DEBUG only) |
| Nil dataset | `0` for field ref | Warning |
| Inactive dataset | `0` for field ref | Warning |
| Field not found | `0` for field ref | Warning |
| Division by zero | `0` | Warning |
| Unknown function `Foo(...)` | `Null` | Warning |
| Malformed expression (unbalanced parens, trailing op, etc.) | `0` or `''` depending on context | Error |
| Non-numeric value in arithmetic | `0` | Warning |
| NULL in arithmetic | `0` (NULL + 1 = 0) | None (NULL semantics) |
| NULL in comparison | `Null = Null` → `Null` (NOT True, NOT False) | None |

### 8.2 Diagnostics Object

- `TExpressionDiagnostics` collects errors and warnings with source positions.
- In normal (non-DEBUG) builds, diagnostics are populated but not surfaced externally (callers can check `HasErrors` and `Diagnostics.ErrorCount`).
- In DEBUG builds, diagnostics are also output via `OutputDebugString`.
- The diagnostics object is accessible via `TExpressionParser.Diagnostics` for testing.

### 8.3 Expression-Level Error Policy

When the parser encounters a syntax error:
- It does NOT raise an exception.
- It records an error in diagnostics.
- It attempts to produce a best-effort AST (skipping the malformed token).
- The evaluator returns a safe default for the malformed portion.

---

## 9. Explicit NULL Semantics

| Operation | NULL Behavior |
|---|---|
| `NULL` literal | Variant `Null` |
| `NULL + N` | `0` (NULL absorbs arithmetic; result is NULL→0 for variant coercion) |
| `N + NULL` | `0` |
| `NULL = NULL` | `Null` (unknown — not True, not False) |
| `NULL <> NULL` | `Null` |
| `N = NULL` | `Null` |
| `N > NULL` | `Null` |
| `NULL AND True` | `Null` |
| `NULL OR True` | `True` (OR with True wins) |
| `NOT NULL` | `Null` |
| `COUNT([Field])` with NULL values | Counts only non-NULL values |
| `SUM([Field])` with NULL values | Skips NULLs in sum |
| `AVG([Field])` with NULL values | Sum / Count (non-NULL only) |
| `MIN/MAX([Field])` with NULL values | Ignores NULLs |
| String context: `NULL` rendered | `''` (empty string) via VarToStr |
| `[NullField]` (dataset field is NULL) | `Null` variant; arithmetic → 0; string → `''` |

### Implementation

All arithmetic and comparison operations in AST nodes check `VarIsNull` on operands before operating. When either operand is NULL, the result is `Null` (for comparisons) or `0` (for arithmetic, matching existing variant coercion behavior for downstream consumers). COUNT explicitly skips NULLs.

---

## 10. Source Positions

### 10.1 Source Position Tracking

Every AST node stores its `TExpressionSourcePos` (Line, Col, Index in source string).

### 10.2 Token Source Positions

The lexer records the position at the START of each token. When a token is created:
- `Line` and `Col` are updated as the lexer scans.
- Line numbers are 1-based; columns are 1-based.
- Index is 0-based into the source string.

### 10.3 Diagnostic Source Positions

Every diagnostic message includes the `TExpressionSourcePos` of the offending token, enabling precise error reporting (e.g., "Unexpected ')' at line 1, col 12").

### 10.4 Practical Use

Currently `TExpressionContext` is a record passed around by callers (engine, designer). Source positions in AST nodes are primarily for:
- Diagnostic messages
- Future debugging/logging
- Designer expression validation (highlighting errors in the expression editor)

The `TExpressionSourcePos` record does NOT store the source expression string itself (nodes store only the position; the caller can map position back to the original expression text).

---

## 11. Parse-Cache Recommendation

### NOT RECOMMENDED for Phase 4I-20

Rationale:
- `TReportExpression.Evaluate` is typically called per-row during rendering. For a report with N rows, each expression is evaluated N times. However, expression strings are typically small and parsing is fast (microseconds).
- Caching introduces mutable state (cache invalidation when context changes for field values but not expression text).
- The existing codebase has no precedent for expression-level caching.
- Memory pressure from caching could be significant for reports with many unique expressions.

### RECOMMENDED for Future Phase (4I-30)

If profiling shows parsing is a bottleneck:
- **Cache key:** `(Expr: string)` only — the expression text.
- **Cache value:** Parsed `TExpressionNode` tree (or a serializable form).
- **Cache scope:** Per-`TReportEngine` instance (lives for one report render).
- **Invalidation:** Never needed for expression text. AST nodes re-evaluate against fresh `TExpressionContext` each call.
- **Implementation:** `TDictionary<string, TExpressionNode>` owned by `TReportEngine`, freed in destructor.
- **Thread safety:** Not required (engine is single-threaded).
- **This is an optimization only and does not affect correctness.**

---

## 12. Compatibility/Coercion Decisions

### 12.1 TReportExpression.Evaluate Return Type

**UNCHANGED.** Returns `Variant`. The new evaluator produces the same Variant types as the old heuristic for all currently supported expressions:

| Expression | Old Result | New Result | Match? |
|---|---|---|---|
| `''` | `''` | `''` | Yes |
| `[PageNo]` (value=1) | `1` (Double) | `1` (Double) | Yes |
| `[Name]` (value='Alice') | `'Alice'` (string) | `'Alice'` (string) | Yes |
| `[Param.CompanyName]` | `'Acme Corp'` | `'Acme Corp'` | Yes |
| `'hello'` | `'hello'` | `'hello'` | Yes |
| `true` | `True` | `True` | Yes |
| `false` | `False` | `False` | Yes |
| `NULL` | `'NULL'` | `Null` (Variant) | **CHANGE** — see below |
| `1 + 2` | `3` (Double) | `3` (Double) | Yes |
| `200 > 100` | `True` | `True` | Yes |
| `SUM([Amount])` | `350` (Double) | `350` (Double) | Yes |

### 12.2 NULL Literal Change

**This is the one behavioral change for expressions the new parser handles.** Currently `NULL` returns the string `'NULL'`. After Phase 4I-20, `NULL` returns the Variant `Null`. This is intentional — it enables proper NULL semantics in arithmetic and comparisons.

**Impact:** Tests that assert `VarToStr(TReportExpression.Evaluate('NULL', ...))` = `'NULL'` must be updated to check `VarIsNull(...)`. This is documented and expected.

### 12.3 Operator `!=` → `<>`

**NEW SUPPORT:** `!=` is now supported as a synonym for `<>`. This is an addition, not a change. Existing behavior (which treated `!=` incorrectly) is replaced.

### 12.4 AND/OR/NOT Support

**NEW SUPPORT.** Currently AND/OR are treated as string text. After Phase 4I-20, they are boolean operators with proper short-circuit evaluation:
- `A AND B`: evaluate A; if False, return False; else evaluate B.
- `A OR B`: evaluate A; if True, return True; else evaluate B.
- `NOT A`: evaluate A; return boolean negation (with NULL handling → Null).

### 12.5 Comparison Precedence Over Arithmetic

**FIX.** Currently comparisons are evaluated AFTER arithmetic tokenization, leading to text comparison of arithmetic expressions. After Phase 4I-20, the grammar ensures arithmetic is evaluated before comparison:
- `[ID] > 1` correctly evaluates `ID > 1` numerically.
- `1 + 2 > 2` correctly evaluates `3 > 2` → `True`.

### 12.6 Aggregate Composition

**FIX.** Currently `SUM([Amount]) + 1` returns `350` (aggregate shortcut discards `+ 1`). After Phase 4I-20, the aggregate is just a function node in the AST, so the full expression evaluates correctly: `SUM([Amount]) + 1 = 351`.

### 12.7 Precedence Fix

**FIX.** `2 + 3 * 4` now correctly evaluates to `14` (not `20`). `10 - 2 * 3` = `4` (not `24`). `10 / 2 * 3` = `15` (unchanged — left-to-right is correct for same-precedence).

### 12.8 Parentheses

**FIX.** `(1 + 2) * 3` now evaluates to `9` (not `0`). Parentheses are first-class in the grammar.

### 12.9 Quoted String with Double Quotes

**BEHAVIOR CHANGE.** Currently only single quotes are stripped. After Phase 4I-20, double-quoted strings are not recognized as string literals (they remain as identifiers/text). This matches the current test expectation (`'"hello"'` → `'"hello"'`). No change here — documented for clarity.

---

## 13. Parse Cache Recommendation (Summary)

See Section 11. **Do not implement a parse cache in Phase 4I-20.** Create each `TExpressionParser` per call, free it after evaluation.

---

## 14. Test Plan

### 14.1 Update Existing Tests

#### Test.Vittix.Report.Expressions.pas

Update the following tests to assert CORRECT behavior (not characterization):

| Test | Current Expected | New Expected | Reason |
|---|---|---|---|
| `Test_Arithmetic_Precedence_CurrentBehavior` | `20.0` | `14.0` | Operator precedence |
| `Test_Arithmetic_LeftToRight_CurrentBehavior` | `24.0` | `4.0` | Operator precedence |
| All comparison tests | Current text-compare results | Numeric compare results | Correct comparison |
| `Test_Aggregate_SUM_WithDataSet` | `350.0` | `350.0` | No change (was already correct) |
| `Test_Aggregate_SUM_WithUserDataSetNil_NotConfirmed` | `'SUM(0)'` | Depends on aggregate impl | See below |
| `Test_Comparison_AndNotSupported` | `True` (text) | `True` (proper AND) | New AND support |

Remove all `_CurrentBehavior` suffixes from test names after updating.

#### Test.Vittix.Report.ExpressionAudit.pas

**Option A (Recommended):** Delete this entire fixture. Its 29 tests all assert known-defective behavior that the new parser fixes. Maintaining it provides no value after the fix.

**Option B:** Rename to `TestExpressionEngineCorrectness` and flip every assertion to correct values with clear documentation comments.

### 14.2 New Tests (Test.Vittix.Report.Expressions.pas additions)

Add a new test fixture `TTestExpressionEngineFixed` (or extend existing) with:

#### A. Lexer Tests
- `Test_Lexer_Number` — verify `42` → tkNumber, `3.14` → tkNumber, `-7` → tkNumber
- `Test_Lexer_String` — verify `'hello'` → tkString, `'a=b'` → tkString
- `Test_Lexer_Identifier` — verify `SUM` → tkIdentifier, `Name` → tkIdentifier
- `Test_Lexer_FieldRef` — verify `[Amount]` → tkFieldRef, `[Param.X]` → tkFieldRef
- `Test_Lexer_Operators` — verify all operators tokenize correctly
- `Test_Lexer_BooleansAndNull` — verify `TRUE`, `FALSE`, `NULL` tokens

#### B. Parser/AST Tests
- `Test_Parser_Precedence` — `2 + 3 * 4` → AST with `*` deeper than `+`
- `Test_Parser_Parentheses` — `(1 + 2) * 3` → AST with `(1+2)` as inner group
- `Test_Parser_Unary` — `-5 + +3` → unary nodes
- `Test_Parser_AndOr` — `a AND b OR c` → correct tree shape
- `Test_Parser_Not` — `NOT a` → unary NOT node
- `Test_Parser_FunctionCall` — `SUM([Amount])` → function node with 1 arg
- `Test_Parser_NestedFunctions` — `SUM(AVG([X]) + 1)` → correct nesting
- `Test_Parser_Malformed_TrailingOp` — `1 +` → no exception, safe default
- `Test_Parser_Malformed_UnbalancedParen` — `(1 + 2` → no exception, safe default
- `Test_Parser_Malformed_UnknownFunction` — `Foo(1)` → no exception, Null result

#### C. Evaluator Tests
- `Test_Evaluator_Number` — `42` → `42.0` (Double)
- `Test_Evaluator_String` — `'hello'` → `'hello'`
- `Test_Evaluator_Boolean` — `TRUE` → `True`, `FALSE` → `False`
- `Test_Evaluator_NULL` — `NULL` → `Null` (variant)
- `Test_Evaluator_NULL_Add_Number` — `NULL + 1` → `0`
- `Test_Evaluator_NULL_Compare` — `NULL = NULL` → `Null`
- `Test_Evaluator_Comparison_Numeric` — `5 > 3` → `True`
- `Test_Evaluator_Comparison_String` — `'a' < 'b'` → `True`
- `Test_Evaluator_AndShortCircuit` — `False AND [ErroringField]` → `False` (no field access needed)
- `Test_Evaluator_OrShortCircuit` — `True OR [ErroringField]` → `True`
- `Test_Evaluator_Not` — `NOT TRUE` → `False`, `NOT NULL` → `Null`

#### D. Field/Parameter/Variable Reference Tests
- `Test_Evaluator_FieldRef` — `[Name]` → field value
- `Test_Evaluator_FieldRef_NilDataset` — `[Name]` with nil DataSet → `0`
- `Test_Evaluator_ParamRef` — `[Param.X]` → parameter value
- `Test_Evaluator_VariableRef` — `[VarName]` → variable value
- `Test_Evaluator_UserDataSetField` — `[Amount]` with UserDataSet → value

#### E. Aggregate Tests
- `Test_Aggregate_SUM` — `SUM([X])` over 3 rows → sum
- `Test_Aggregate_COUNT` — `COUNT([X])` → row count (non-NULL)
- `Test_Aggregate_COUNT_NullSkipping` — `COUNT([X])` where some X are NULL → count non-NULL
- `Test_Aggregate_AVG` — `AVG([X])` → sum/count
- `Test_Aggregate_MIN` — `MIN([X])` → minimum
- `Test_Aggregate_MAX` — `MAX([X])` → maximum
- `Test_Aggregate_EMPTY` — `SUM([X])` on empty dataset → `0`
- `Test_Aggregate_TDataSet` — aggregate over TDataSet with GroupStart/GroupEnd bookmarks
- `Test_Aggregate_UserDataSet` — aggregate over TVittixUserDataSet (FIXES BUG-005)
- `Test_Aggregate_Composition` — `SUM([X]) + 1` → sum + 1 (no truncation)
- `Test_Aggregate_DoubleAggregate` — `SUM([X]) + SUM([Y])` → both evaluated

#### F. AST Immutability Tests
- `Test_AST_NoMutableContext` — evaluate same AST with different contexts, verify independent results

#### G. Diagnostics Tests
- `Test_Diagnostics_Malformed` — malformed expression increments ErrorCount
- `Test_Diagnostics_NoErrors` — valid expression has ErrorCount = 0

### 14.3 Regression Tests

- All existing demo reports must still open and render identically.
- All existing PDF/export outputs must match previous output (visual diff).
- Empty dataset reports must still produce 1 page.
- Large dataset reports must still render without error.
- Long text wrapping must still work.
- Images must still render correctly.
- Print path must still work.

---

## 15. Risks

### HIGH RISK

| # | Risk | Mitigation |
|---|---|---|
| R1 | **Behavior change on NULL literal.** `NULL` changes from string `'NULL'` to variant `Null`. Downstream code checking `VarToStr(Result) = 'NULL'` will break. | Document clearly. All tests using `VarToStr` on NULL must be updated. Add a migration note in CHANGELOG. |
| R2 | **Aggregate composition behavior change.** `SUM([X]) + 1` changes from `350` to `351`. Any test or report that relied on the truncation bug will break. | Document as bug fix. Audit all test assertions for aggregate composition. |
| R3 | **Comparison precedence change.** `1 + 2 > 2` changes from `False` (text compare) to `True` (numeric compare). Any PrintWhen conditions using arithmetic in comparisons will change behavior. | Document as bug fix. Audit all PrintWhen conditions in existing reports. |
| R4 | **Precedence change.** `2 + 3 * 4` changes from `20` to `14`. Existing reports relying on left-to-right evaluation will produce different results. | Document as bug fix. Test coverage will catch regressions. |

### MEDIUM RISK

| # | Risk | Mitigation |
|---|---|---|
| R5 | **Circular dependency not fully eliminated.** If `ExpressionParser.pas` accidentally uses `Expressions.pas`, package build fails. | Strict dependency review. CI build verification. |
| R6 | **TVittixUserDataSet aggregate iteration differs from TDataSet.** UserDataSet has no bookmark support; group boundary detection must use field value comparison instead. | Implement group-end detection by comparing current row field values to GroupEnd key. Document limitations. |
| R7 | **NOT operator binding.** `NOT a = b` could parse as `NOT (a = b)` or `(NOT a) = b`. Grammar specifies `NOT` at unary level → `NOT (a = b)`. This differs from some SQL dialects. | Document explicitly. Align with Delphi `not` precedence. |
| R8 | **`!=` vs `<>` conflict.** Both map to `tkNotEqual`. If someone writes `a != b <> c`, the lexer produces two `tkNotEqual` tokens. This is malformed and handled by error policy. | Acceptable — `!=` is a synonym, not a replacement. |

### LOW RISK

| # | Risk | Mitigation |
|---|---|---|
| R9 | **Double-quote string literals still unsupported.** `'hello'` works; `"hello"` does not. Existing code relying on this quirk is unaffected. | Document as known limitation. |
| R10 | **Empty parens `()` in function calls.** `SUM()` would parse but produce `0` for SUM. No exception raised. | Acceptable — matches safe-fallback policy. |
| R11 | **Variant coercion differences.** Some edge cases in Double/Integer/Decimal variant coercion may differ between old and new code paths. | Run comprehensive variant coercion tests. |
| R12 | **GDI/memory leak in bookmark handling.** Aggregate iteration saves/restores bookmarks; new code must follow try/finally pattern exactly. | Code review + test with `ReportMemoryManager` on Win32. |

---

## 16. Unavoidable API Changes

The following API changes are **unavoidable** given the requirements:

| Change | Why Unavoidable | Impact |
|---|---|---|
| **`TReportExpression.Evaluate` for `NULL` literal returns `Null` instead of `'NULL'`** | Explicit NULL semantics require a null variant. String `'NULL'` is indistinguishable from a field literally containing the text "NULL". | All callers/tests checking `VarToStr(Result) = 'NULL'` must update. |
| **`Vittix.Report.Aggregates.pas` no longer uses `Vittix.Report.Expressions`** | Circular dependency must be broken. Aggregates now uses `Vittix.Report.ExpressionParser` directly. | Internal only — no public API change on `TReportAggregates.TryEvaluate` signature. |
| **`Vittix.Report.Aggregates.pas` removes circular unit reference** | The new `ExpressionParser` breaks the cycle. `Aggregates` loses its `Expressions` in-uses clause. | Build-order dependent; `ExpressionParser` must compile before `Aggregates` is removed from `Expressions`'s interface uses if any. (Not applicable since `Expressions` still imports `Aggregates` for the aggregate shortcut in `Evaluate`.) |
| **Behavioral changes in evaluation results** (precedence, comparison, aggregate composition) | Required to correctly implement the specified grammar/semantics. Heuristic cannot produce correct results for these cases. | Existing test assertions must be updated. Report outputs may differ for expressions using these patterns. |

The following are **NOT** API changes (implementation details):
- Internal class additions in `ExpressionParser.pas` — no existing code imports this unit yet.
- AST node types — purely internal.
- Diagnostics object — new public type, but not imported by existing code.

---

## 17. Implementation Sequence

1. **Create `Vittix.Report.ExpressionParser.pas`** with lexer, AST, parser, evaluator, diagnostics.
2. **Refactor `Vittix.Report.Aggregates.pas`** to use `TExpressionEvaluator.EvaluateAggregate` instead of `TReportExpression.Evaluate`.
3. **Update `Vittix.Report.Expressions.pas`** — replace heuristic internals with delegate to `TExpressionParser.Evaluate`.
4. **Update tests** — fix all characterization/audit assertions, add new tests.
5. **Build and run all tests** — verify no regressions.
6. **Run demo reports** — verify visual correctness.

---

## 18. Circular Dependency Resolution

**Current cycle:**
```
Expressions.pas uses Aggregates.pas (for SUM/COUNT/AVG/MIN/MAX in Evaluate)
Aggregates.pas uses Expressions.pas (for TReportExpression.Evaluate in aggregate iteration)
```

**After Phase 4I-20:**
```
Expressions.pas uses ExpressionParser.pas (new — no cycle)
ExpressionParser.pas uses Context, Utils (no cycle)
Aggregates.pas uses ExpressionParser.pas (new — no cycle)
ExpressionParser.pas does NOT use Expressions.pas or Aggregates.pas
```

`Expressions.pas` still uses `Aggregates.pas` for the aggregate shortcut (top-level `SUM(...)` detection before full parse). This is retained for backward compatibility — if `TReportAggregates.TryEvaluate` returns True, we use its result directly. But `Aggregates.pas` no longer calls back to `Expressions.pas`.

Wait — this still creates a cycle: `Expressions → Aggregates → ExpressionParser`. But `ExpressionParser` does not use `Expressions`, so there is no cycle. `Expressions` uses both `Aggregates` and `ExpressionParser`, but neither of those uses `Expressions` back.

Actually, after the refactor, we can simplify: `Expressions.Evaluate` can skip the `TReportAggregates.TryEvaluate` shortcut and let the parser handle aggregates natively via `TExpressionFunctionNode`. This eliminates the `Expressions → Aggregates` dependency too, leaving:

```
ExpressionParser.pas — no VittixReport dependencies beyond Context/Utils
Expressions.pas — uses ExpressionParser (only)
Aggregates.pas — uses ExpressionParser (only)
```

But this requires `TReportAggregates.TryEvaluate` to be kept for backward compatibility even though it's no longer called internally. Keep it as a legacy class function that delegates to `TExpressionEvaluator.EvaluateAggregate`.

**Final dependency graph:**
```
Context.pas — no VittixReport deps (leaf)
Utils.pas — uses UserDataSet (one-way)
ExpressionParser.pas — uses Context, Utils (leaf-level)
Expressions.pas — uses ExpressionParser, Aggregates (Aggregates kept for legacy API)
Aggregates.pas — uses ExpressionParser (cycle eliminated)
All other units — use Expressions (unchanged)
```

If we want to also eliminate `Expressions → Aggregates`, we make `TReportAggregates.TryEvaluate` a thin wrapper that delegates to the new evaluator, and remove it from `Expressions.pas` in-uses. The `Expressions.pas` class function handles aggregates natively. This is the cleaner end state.
