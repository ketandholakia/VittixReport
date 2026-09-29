# v1.1 Backlog — parked at v1.0 freeze (2026-09-28)

Nothing here blocks v1.0. Do not work on these until v1.0.0 ships.

Entries below were moved here from `TODO.md` and from the v1.0 scope triage of the
existing development plans (see the `V1.0 Scope Triage` section in each plan).
Source references are preserved so each entry can be picked up with full context later.

| Idea | Source | Notes |
|------|--------|-------|
| Named dataset tree in the text/expression editor (plan M7) | `TextExpressionEditor_DevelopmentPlan.md` M7 | Intentionally deferred even before the freeze: the model has no per-dataset field metadata and `Dataset.FieldName` expression syntax is unsupported. Prerequisites (per-dataset field metadata, dataset-qualified syntax) must land first. |
| Syntax highlighting, autocomplete, line-number gutter in the editor | `TextExpressionEditor_DevelopmentPlan.md` M8 (deferred list) | Usability polish only; no correctness need. |
| `IF(...)` expression function and designer snippet | `TextExpressionEditor_DevelopmentPlan.md` M6 (deferred) | Blocked on evaluator support; do not add the snippet before the function exists. |
| Embedded image clear/replace workflow + "Embedded/None" status indication | `EmbeddedImage_DevelopmentPlan.md` M3 (pending) | Load/replace via `Load Embedded Image...` already works (M2); M3 is polish plus explicit clear. |
| Embedded-image regression report fixture | `EmbeddedImage_DevelopmentPlan.md` M4 (pending) | `[test]`-class work — may be pulled forward during the freeze only if embedded-image behavior needs a characterization test. No corpus report currently uses `PictureData`. |
| ~~Vector PDF export of embedded PNG/JPEG images~~ done pre-freeze (`874ebbd`) | `EmbeddedImage_DevelopmentPlan.md` M5 (completed) | No backlog work remains: embedded (non-file) pictures are re-captured as a registered temporary PNG and exported as image XObjects, verified end-to-end (PictureData serialize/reload to Vector PDF) by `Test_EmbeddedPicture_PictureData_VectorPDF_ContainsImageXObject`. The former "dropped by the default PDF export" note was stale and is removed. Extended embedded formats stay deferred - see the M7 row below. |
| Extended embedded image formats: BMP→PNG conversion, WMF/EMF vector preservation, SVG import/rendering | `EmbeddedImage_DevelopmentPlan.md` M7 (deferred) | Format-specific loaders and PDF rendering decisions; no current application need. |
| Phase 4I-20: replace heuristic expression evaluator with AST parser/evaluator | `Phase4I-20-plan.md` (whole plan) | Deferred wholesale at the freeze. Not started (no `Vittix.Report.Expression.Parser.pas` exists). Legacy evaluation is default and characterized by tests; the modern opt-in engine from Phase 4B-2B already exists. Soak-time expression bugs get `[fix]`ed inside the existing evaluator instead. |
| Vector PDF: full SVG support | `VectorPDF_DevelopmentPlan.md` § Deferred | Requires licensing/deployment/thread-safety review before any runtime dependency. |
| Vector PDF: EMF/WMF vector parsing into PDF commands | `VectorPDF_DevelopmentPlan.md` § Deferred | EMF/WMF currently fail gracefully (skip with logged warning) in vector output. |
| Vector PDF: PDF/A compliance | `VectorPDF_DevelopmentPlan.md` § Deferred | No current requirement. |
| Vector PDF: cluster-level Indic text extraction (current `/ToUnicode` is glyph-level) and `hmtx`/`cmap` trimming in glyph subsetting | `VectorPDF_DevelopmentPlan.md` M5.6 "Still open" | Visual output is correct; only text-extraction fidelity and subset size are affected. |
| Vector PDF: progressive/CMYK JPEG distinction, PNG alpha channel, mid-word split for over-wide single words | `VectorPDF_DevelopmentPlan.md` M5.5 known limitations | Documented decisions, not silent gaps. |
| Designer refactor residuals: drag-gesture extraction (roadmap step 2), mouse-event migration to the interaction controller (step 3) | `TODO.md` Refactor Roadmap notes | Refactors not attached to a bug are forbidden during the freeze. |
| IF-expression dependent designer affordances and any new expression syntax surfaced in the editor | `TextExpressionEditor_DevelopmentPlan.md` | Keep the editor aligned with what the evaluator actually supports; never insert tokens the renderer cannot resolve. |
