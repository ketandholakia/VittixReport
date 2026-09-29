# Documentation Archive

Superseded development-planning documents. **These are historical records — do
not treat them as current guidance and do not start work from them.**

## Source of truth for development planning

The single source of truth for the development plan is:

**[`VittixReport_FullCodeAnalysis.md`](../development-plan.md)** (repository root; embedded on the site's [development plan page](../development-plan.md))

— the full code-analysis report. Its §5 (Issues by Severity) is the working bug
queue, its §12 (Refactoring Plan) is the backlog of parked/deferred work, and
its §14 lists open questions. Nothing in this archive overrides it.

## What is archived here and why

Everything that used to compete as a "development plan" before the 2026-09-29
full code analysis was adopted as the canonical plan:

- **Root plans & queues** — `BACKLOG_v1.1.md`, `TODO.md`,
  `VittixReport_BugQueue.md`, the per-feature development plans
  (`VectorPDF_DevelopmentPlan.md`, `EmbeddedImage_DevelopmentPlan.md`,
  `TextExpressionEditor_DevelopmentPlan.md`), the Phase 4B-2B closure audit and
  the Phase 4I-20 plan.
- **Modernization programme** — the Phase 1–6 documents, the residual audit and
  the GAP-005 audits (moved from `docs/`).
- **Analyses & reviews** — the architecture analysis, technical evaluation and
  both code reviews (superseded by the full code analysis).
- **Docs-site wrappers** — the `docs/*.md` pages that existed only to embed the
  root documents above into the MkDocs site (`plan-*.md`, `bug-queue.md`,
  `code-review*.md`, `technical-evaluation.md`, `architecture-analysis.md`,
  `phase4b2b-closure-audit.md`). Their snippet includes now point into this
  folder. The one exception is the TODO wrapper, which was deleted outright: it
  contained nothing but a snippet of `TODO.md`, which itself lives here.

Kept **out** of the archive (still current, still in `docs/`): the user and
developer manuals, the testing guide, the events contract (`EVENTS.md`), the
runner CLI reference, regression-fixtures reference, demo documentation, the
designer icon map, branding notes, and the Export-PDF ADR (decision records are
permanent).

## Historical references in code

Some source comments cite these documents by their pre-archive names or path
(e.g. `VectorPDF_DevelopmentPlan.md` in `Vittix.Report.Export.VectorPDF.pas`,
phase labels such as `GAP-005/P2` in `Vittix.Report.Renderer.pas` and the test
units). The phase labels are historical identifiers, not file references. Where
a comment cites a file by name, the pre-archive location is understood to be
this folder (or the repository root for the root-level documents).
