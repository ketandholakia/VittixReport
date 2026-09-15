# Phase 4B-2B — Closure Audit

## Disposition

**Phase 4B-2B — PASS / COMPLETE.** All five implementation objectives hardened
(cache correctness, memory-safety, modern fixture corpus, end-to-end
verification, granular diagnostics, migration analyzer) are implemented, and
Phase 4A + Phase 4B-1 are reconciled with the modern work. Final measured
result: **DUnitX: 620 found / 620 passed / 0 failed / 0 errored / 0 ignored /
0 leaked / 0 skipped**; VittixRunner 41 passed / 0 failed / 1 skipped by
design (`16_large_preview_warning.vrt`; page counts identical to the Phase 4B-1
baseline). HEAD remains `549e0c4` — no commits
were made for 4B-2B (uncommitted work preserved per instructions — *this* file
is the only new artifact written as the closure checkpoint).

Two pre-existing build gaps are **NOT** part of 4B-2B and are recorded as
separate debt so they don't muddy the phase record (see §10). No Phase 5 work
is started (per reviewer instruction — do not start Phase 5 until this audit
passes).

---

## Axes audited

Verdict legend: PASS = verified against evidence; BLOCK = would stop a merge;
ISSUE-severity = real but acceptable for this phase, tracked as deferred/known.

### 1. Public API surface — PASS
`TReportExpression` in `source/Vittix.Report.Expressions.pas` keeps a single
legacy entry point and adds two strictly-additive overloads:
- `Evaluate(Expr, Context)` — legacy contract, two-argument, never consults mode
  (line 94: `Result := Evaluate(Expr, Context, Context.ExpressionMode)` with the
  context field defaulting to `emLegacy`).
- `Evaluate(Expr, Context, AMode)` — new overload dispatching to
  `TModernExpressionEngine.Evaluate` for `emModern`, else the legacy compat
  evaluator (lines 100–106).
- `Validate(Expr, AMode)` — validation-only entry (lines 108–115).
- `ModeFromLanguageVersion(AVersion, out AMode): Boolean` (lines 119–125):
  `0 → emLegacy`, `1 → emModern`, `other → False` (caller raises the load
  diagnostic).
No second or divergent evaluator entry exists — a repo-wide grep for
`ExpressionLanguageVersion` / `emModern` found call sites only in
Expressions.pas, Context.pas, Engine.pas, Export.Text.pas, Model.pas, and
Serializer.pas (`docs/Phase4B2A-Modern-Expression-Semantics.md` §24.2, §27).
The two-argument legacy `Evaluate` is permanently legacy by construction, so a
struggle against the boundary is impossible.

### 2. Legacy default behavior — PASS
`FExpressionLanguageVersion := 0` in `TReportModel.Create`
(`source/Vittix.Report.Model.pas` line 129); `emLegacy` is the first enum value
of `TExpressionMode = (emLegacy, emModern)`
(`source/Vittix.Report.Expression.Mode.pas` line 21), with an explicit comment
that `Default(TExpressionContext)` and an unversioned file both yield legacy.
Engine `ReportExpressionMode` returns `emModern` only when
`FReport.ExpressionLanguageVersion = 1` and otherwise `emLegacy`
(`source/Vittix.Report.Engine.pas` lines 525–532). The two-argument
`TReportExpression.Evaluate(Expr, Context)` is locked by
`Test_Legacy_TwoArgUnchanged` (line 169) and the differential harness against
the frozen legacy reference — legacy behavior is the contract, not the
default-of-the-day.

### 3. Modern mode selection — PASS
Single approved selector: `"ExpressionLanguageVersion": 1` in the `.vrt`.
Serializer enforces it strictly on load — absent/0/1 accepted, anything else
produces an `UNSUPPORTED_EXPRESSION_LANGUAGE` load diagnostic and exits without
silent upgrade (`source/Vittix.Report.Serializer.pas` lines 1410–1422). Writer
emits the key only when `<> 0`
(lines 1104–1106), so the legacy byte shape is preserved. The frozen legacy
reference (`tests/Test.Vittix.Report.ExpressionLegacyReference.pas`, present
per glob) is never invoked in production and is not wired into the modern
dispatch; the migration analyzer runs on context copies with
`Hooks := nil` (see §7) and never sets an engine mode — confirmed by
`Test_SerializationMode_NoExpressionLanguageVersion` (lines 778–794) which
asserts no checked-in `.vrt` carries the key and that `reports/*.vrt` remain
`Version: 2`.

### 4. `.vrt` serialization — PASS
Writer only emits the key when nonzero, keeping legacy files byte-identical
(`Serializer.pas` 1104: `if R.ExpressionLanguageVersion <> 0 then`). Loader
default is 0 (legacy) and rejects unsupported values with a structured
diagnostic; unknown-key tolerance + `TReportUnknownObject` preservation (the
existing forward-compatibility mechanism) carry the new key through
unloadable-object round-trips unchanged. `Test_SerializationMode_*`
suite (lines 778–794 + `Test_Compatibility_LegacyIsDefault`) locks the round
trip: absent → 0/legacy, 0 → legacy, 1 → modern, other → load error.
`git status reports tests/fixtures/modern` returns `?? tests/fixtures/modern/`
only — the 42 `reports/*.vrt` fixtures are untracked-clean (tracked, no
modifications) and byte-untouched, matching the implementation doc §5 and the
closure requirement of "all 42 legacy fixtures unchanged."

### 5. Cache identity — PASS (with the one documented Phase-4A/4B-1 caveat)
Execution-local cache, cleared per pass via `ClearExecutionCaches` in
`ExecutePass` (`Engine.pas` lines 520–524). `TAggregateCacheEntry.Matches`
includes dataset, expression text, group-start/end bookmarks, page number,
total pages, row number, counting-pass flag, parameters, variables, and
dataset `Filter`/`Filtered` (`Engine.pas` lines 342–367, Capture
369–388) — exactly the set documented in `docs/Phase4A` §"Phase 3 cache
interaction" and `docs/Phase4B-Compatibility-Evaluator.md` §7.
**Mode isolation (OD-15):** the modern aggregate path builds
`CacheKey := CModernCacheKeyPrefix + FExpressionText` (`#1'MODERN'#1`)
before both lookup and store in
`Expression.Evaluator.pas` lines 83, 1154, 1253, with the comment "modern
entries are prefixed so the two modes can never collide"; the legacy path
(`Aggregates.pas` line 72/161) uses the raw expression. `Test_Cache_ModernModeIsolation`
(line 174) asserts `1 + 2 * 3` = 7 modern vs 9 legacy on the same context.
`ReportTitle`/`ReportDate` are **not** cache-key fields — the same pre-existing
gap documented in `docs/Phase4A` §120 and `docs/Phase4B-Compatibility-Evaluator.md`
§7 known limitations, bounded by per-pass clearing and by the statement that
"ReportTitle/ReportDate are immutable during a pass" (`Phase4B2B` doc §2). The
4B2A doc §25.2/25.3 records this as an optional future key broadening; the
hardening decision for 4B-2B was the mode prefix + per-pass clearing, which is
implemented and tested. **No mutation-generation counter** (Option A) —
cache is execution-local and cleared per pass, which is sufficient; mid-pass
row-data mutation is outside the engine execution contract.

### 6. Diagnostics — PASS
New codes are **appended after** the existing enum values with an explicit
comment "Appended AFTER the existing values so the ordinals of all previously
published codes stay stable" (`Expression.Diagnostics.pas` lines 34–44):
`UnexpectedToken, UnexpectedEndOfExpression, InvalidNumber, InvalidString,
InvalidComparison, NonAssociativeComparison, ExpressionTooLong,
ExpressionTooDeep, TooManyNodes`. Pre-existing codes
(`SyntaxError, UnknownField, UnknownDataSet, UnknownParameter, UnknownVariable,
UnknownFunction, InvalidArgumentCount, InvalidArgument, TypeError,
DivisionByZero, NullError, UnsupportedDataSet, LimitExceeded, EvaluationError,
ImplicitConversion, NestedAggregate`) keep their ordinals 0–15.
`TModernExpressionEvaluator.Fail` now tracks and propagates the first-error
**code** into `EVittixExpressionError.Code` (previously always
`EvaluationError`) — verified by the fix for `'1 = ''abc'''` which now
surfaces `InvalidComparison` and by `Test_Modern_DiagnosticCodes` (line 166).
`TExpressionDiagnostics` classifies all new codes as errors (lines 125–136).
Messages at existing call sites are unchanged.

### 7. Migration behavior — PASS
`TExpressionMigrationAnalyzer.Analyze` (`source/.../Expression.Migration.pas`
lines 86–92) is analysis-only: it never writes `.vrt` files, never touches the
serializer, the engine, or the dataset. It evaluates in both modes through the
public `TReportExpression.Evaluate(Expr, Ctx, Mode)` on context **copies with
`Hooks := nil`** for both — `LegacyCtx.Hooks := nil` (line 127) and
`ModernCtx.Hooks := nil` (line 131), so every `Assigned(Context.Hooks)` guard
in both evaluators skips the aggregate cache entirely (zero cache reads, zero
cache writes; OD-15/OD-16 untouched). The caller's context is never mutated —
the analyzers operate on local `LegacyCtx`/`ModernCtx` copies (lines 125/129).
`mdModernOnly`/`mdBothError` are documented unreachable (legacy evaluator is
fail-soft) and kept only for model completeness (doc lines 37–38, source 53–56).
Classification is deterministic over the two results
(`mdSameResult | mdTypeDifference | mdSameResult | mdDifferentResult`,
lines 159–173). Tests:
`Test_Migration_SameResult, _DifferentResult, _TypeDifference, _LegacyOnly,
_ModernErrorCode, _PreservesCallerContext, _AggregateDoesNotTouchCache`
(lines 211–217) — the cache proof is the two-evaluation form (first a miss,
second a hit) rather than a single evaluation.

### 8. Package registration — PASS
`packages/VittixReportRuntime.dpk` contains exactly one 4B-2B addition:
`Vittix.Report.Expression.Migration` in `...(Expression.Migration.pas)`
(dpk line 62), alongside the already-registered
`Vittix.Report.Expression.Language` (line 58) and
`Vittix.Report.Expression.Evaluator` (line 61). No other package-level change
belongs to 4B-2B. `ExpressionDiagnostics` is consumed transitively by the
language unit (used in Language.pas line 19) and does not require its own
contains line.

### 9. Test coverage — PASS
- Baseline before 4B-2B hardening: **564 green** (per `docs/Phase4B-Compatibility-Evaluator.md`
  §10) → 602 (Phase 4B-1) → 610 baseline before hardening (per closure brief).
- New tests added in the Phase 4B2B unit (4 cache + 5 end-to-end modern incl.
  corpus + exporter + §14 + §15 + 1 diagnostic-code + 7 migration analyzer):
  `Test_Modern_DiagnosticCodes`, `Test_EndToEnd_AllModernFixturesRender`,
  `Test_EndToEnd_TextExporterUsesModernMode`, `Test_Migration_*`,
  `Test_Cache_ModernModeIsolation`, etc. (lines 91–217).
- Final DUnitX: **620 found / 620 passed / 0 failed / 0 errored / 0 ignored /
  0 leaked / 0 skipped** — the suite has no `[Ignore]` tests; every discovered
  test executes and passes. VittixRunner: 41 passed / 0 failed / 1 skipped by
  design (`16_large_preview_warning.vrt`). The skip count belongs to the
  headless runner, not to DUnitX.
- Frozen legacy reference (`Test.Vittix.Report.ExpressionLegacyReference.pas`)
  runs the ~180-expression differential corpus unchanged — 0 divergence.
- 42 `reports/*.vrt` load/save/reload + Vector-PDF smoke unchanged;
  `git status` confirms no modification.

### 10. Documentation — PASS
`docs/Phase4B2B-Modern-Expression-Implementation.md` (214 lines, the file read
for this audit) covers: architecture (§1), cache correctness decision + the
mode prefix + why no generation counter (§2), parser error-path memory safety /
`FreeOrphans` ownership model (§3), granular diagnostics + appended ordinals
(§4), the 8-fixture modern corpus with rendered values 7 / 36.5 / True (§5),
end-to-end verification through serializer→model→engine→export (§6), the
read-only migration analyzer with `Hooks := nil` (§7), the test summary
(§8), and the known pre-existing build issues separated out (§9). A per-fixture
README in `tests/fixtures/modern/` records each fixture's proven value.

### 11. Known deferred / external build issues — separated (ISSUE-low, not 4B-2B)
Recorded as two independent debt items so they are not attributed to the
expression engine:
- **`BUILD-GAP-QR-001`** — `packages/VittixReportRuntime.dproj` and
  `packages/VittixReportDesign.dproj` fail to build because the package search
  path resolves `Vittix.Report.Objects.Barcode.pas` against the QR stub
  (`stub_qr`), which lacks `IQrCode`/`TEcc`/`IQrSegment`. `docs/Phase4B-1` §8
  states supplying `DCC_UnitSearchPath` with `source\ThirdParty\QRCodeGenLib\…`
  makes the package build cleanly. Unrelated to expressions; DUnitX test
  project and VittixRunner build cleanly regardless.
- **`BUILD-GAP-SCRIPT-001`** — `build_runtime_dpk.ps1` places `param()` after a
  statement, which is invalid PowerShell and aborts package build invocation.
  Per instructions this was NOT fixed.

### Cross-sub-phase coherence
The four sub-phase documents agree on the boundary and the divergence set:
- **4A** defines the legacy contract + `MUST PRESERVE` list; §"Future evaluator
  boundary" requires a replacement to preserve
  `Evaluate(const Expr; const Context): Variant` — 4B-2B keeps it and adds
  additive overloads.
- **4B-1** installs the compatibility evaluator behind that boundary, frozen
  differentially; 4B-2A/2B reuse its 9-stage ordering for the legacy path and
  its `ConditionVariantToBool` mapping for modern truthiness.
- **4B-2A** designs the modern language + selection mechanism + cache strategy
  (OD-9/OD-15/OD-16) + the test matrix; 4B-2B implements exactly that design.
- **4B-2B** (this implementation) delivers the parser/evaluator, the 8-fixture
  corpus, the analyzer, and the audit-verified cache key.
All four agree on: legacy is the permanent default (4A §97, 4B-1 §7, 4B-2A §2.1,
4B-2B §1); modern requires explicit opt-in `ExpressionLanguageVersion = 1`
(4B-2A §21.2, 4B-2B §3); no automatic migration (4B-2B §3, 4B-2A §23.3); the
two-argument `Evaluate` is legacy-forever (4B-2A §24.4, this audit §1/§2); and
the only semantic divergences from the 42-fixture corpus are the two
documented ones (`[MissingField] + 1`, `[MissingField] >`) that already print
blank/suppressed in legacy via `PrintWhen`.

## Verdict: Phase 4B-2B PASS / COMPLETE. Phase 4B closure audit PASS. Phase 5 NOT started.
