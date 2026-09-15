# GAP-005 / P3 — Print Asymmetry: Audit

Status: **audit complete and P3 implemented (D1 = unify on metafile,
D2 = keep full stretch).**
Tree: branch `main`, HEAD `549e0c4`, no commits.

Predecessors: `docs/GAP-005-Page-Ownership-Audit.md` (§3 P3, §6 Step A),
`docs/Phase6-Output-Coverage.md`, `docs/Phase5-Quality-Benchmark-CI.md`.

Question: **can physical printing use one consistent highest-fidelity page
representation without introducing a new page-ownership architecture?**
Answer: **yes (§4)** — but two decisions must be taken first (§6.1), because the
change alters printed output.

---

## 1. Method

Read-only. All three printer paths were read directly, plus every `Printer.*`
call site in the repository, the DPI handling, and the consumer call chains.

## 2. The three print / print-adjacent paths

| Path | Source drawn | Destination mapping | Entry point |
| --- | --- | --- | --- |
| `TReportRenderer.Print` (Renderer.pas 187–206) | **`FPages[i].Bitmap`** (raster) | `Rect(0,0,Printer.PageWidth,Printer.PageHeight)` — full stretch | `TVittixReport.Print` (Component.pas 690) — the **runtime / embedded** route |
| `TVittixReportPreview.Print` (Preview.pas 529–558) | **metafile preferred**, bitmap fallback | `Rect(0,0,Printer.PageWidth,Printer.PageHeight)` — full stretch | Designer `Frm.Preview.btnPrintClick` (Frm.Preview.pas 299) — the **designer** route |
| `TReportPDFExporter.ExportPages` (Export.PDF.pas 113–176) | **`Pages[i]` metafile** (engine metafiles) | `CalculatePDFDestRect(MF, PW, PH, ScaleMode)`, default `pesFullStretch` | `TVittixReport.ExportToPDF` (Component.pas 703) |

Only these three places use `Vcl.Printers.Printer`. **No `PixelsPerInch` usage
exists anywhere** — there is no explicit DPI handling.

## 3. Findings

**F1 — Representation asymmetry (the P3 target).**
Two of the three paths already print the **metafile** (vector).
`TReportRenderer.Print` is the outlier: it prints the **raster bitmap**. The same
product therefore prints differently depending on the route — the embedded
component prints a rasterisation; the designer prints vector.

**F2 — Double resampling in the raster path.**
`Renderer.Print` draws a bitmap that was itself produced by rasterising the
metafile at the logical page size (96-DPI pixels), then stretched to the printer's
device rectangle (typically 300–600 DPI). That is **two resamples**; the vector
path plays the EMF directly into the printer DC.

**F3 — No shared destination-rect logic.**
Each path independently builds a full-stretch rect. An aspect-preserving,
centred mapping **already exists** — `CalculatePDFDestRect` with
`TPDFExportScaleMode = (pesFullStretch, pesFitPreserveAspectCentered)`
(Export.PDF.pas 58–97) — but it is **private to the PDF unit** (implementation
section), so the renderer and the preview cannot use it.

**F4 — Full stretch is not aspect-preserving.**
All three paths stretch the report page to the printer's page rectangle. When the
report aspect differs from the printer's (A4 report on a Letter printer) the
output is **distorted**. This is pre-existing behaviour, not a P2/P3 regression,
and changing it changes printed output.

**F5 — The PDF path is printer-bound and interactive.**
`ExportToPDF` requires the literal `'Microsoft Print to PDF'` device
(Export.PDF.pas 131–137) and calls `ShowMessage` on a page-size mismatch
(155–159) — a modal dialog that blocks server/headless use. (The *vector* PDF
exporter is a separate path and is unaffected.)

**F6 — P2 changed the equation (why P3 is now tractable).**
Before P2, `Render` produced metafile **and** bitmap, so `Print` inherited a
bitmap whether it wanted one or not. After P2 the bitmap exists **only if
requested**, so the print path's representation is now an explicit choice — the
cleaner experiment the audit anticipated: we can determine what printing needs
instead of inheriting it.

**F7 — Nothing about printing is automatically verified today.**
No automated coverage of any printer path (they require a driver). P2's
`RasterCount` instrumentation now gives a *structural* handle: a vector print
path must leave `RasterCount = 0`.

## 4. Answer to the core question

**Yes — printing can use one representation, and the metafile is the right one**,
because:

1. two of the three paths already do, so the target state is not novel;
2. the metafile is the representation `Render` now retains by default (P2), so
   choosing it removes the last production trigger for rasterisation;
3. it eliminates the double resample (F2) and is the only path that can print
   sharply at high printer DPI.

**But** the destination mapping is a *separate* decision from the source
representation. Unifying the source (metafile) preserves current layout (full
stretch); adopting `pesFitPreserveAspectCentered` would change layout on paper and
must be an explicit, opted-in decision.

## 5. Verifiability — what an automated guard can and cannot prove

| Aspect | Automatable? | Mechanism |
| --- | --- | --- |
| Which source a page is drawn from (metafile vs bitmap) | **Yes** | `TRenderPage.RasterCount` must stay **0** after a print-path draw; a bitmap-sourced draw would increment it |
| Destination rects / scaling maths | **Yes** | extract the mapping as a **pure function** and test it directly (the PDF unit already proves this shape) |
| Page count / page-break sequence | **Yes** | draw into an injected `TCanvas` seam and count pages |
| Actual printed pixels / driver fidelity | **No** | printer-driver dependent → **manual checklist** |
| Preview path | **No** | windowed control (Phase 6 finding) → **manual** |

A recording/mock canvas can prove *what the code asked the printer to draw*. It
**cannot** prove what a driver rendered. Any P3 work must therefore pair an
automated structural guard with a manual fidelity checklist, and claim nothing
more.

## 6. Proposed narrow implementation (NOT started)

### 6.1 Decisions required before coding

- **D1 — May P3 change printed output?** Unifying `Renderer.Print` on the
  metafile makes the runtime route match the designer route (sharper, same
  layout). It is a *visible* change: better fidelity, identical geometry.
- **D2 — Scaling:** keep `pesFullStretch` (current behaviour, no layout change)
  or adopt aspect-preserving? Adopting the aspect mode now would alter every
  printed page.

### 6.2 Scope (when authorised)

1. **Extract a shared, pure print mapping** — generalise the existing
   `CalculatePDFDestRect` logic out of the PDF unit so the renderer, preview and
   PDF exporter all use one implementation. Default mode unchanged.
2. **Unify the source on the metafile** in `TReportRenderer.Print`, matching the
   preview, keeping the bitmap only as a documented fallback when a page has no
   usable metafile (mirroring Preview.pas 546–549).
3. **Introduce a canvas seam** so the print loop can be driven by a
   caller-provided `TCanvas` (`Print` passes `Printer.Canvas`; tests pass an
   off-screen canvas). Prefer an internal/`protected` seam; report any public API
   impact before adding it.
4. **Automated guard** (`tests/Test.Gap005.PrintPath.pas`): assert per page that
   the metafile is chosen (`RasterCount = 0`), that the dest rect equals the
   mapping function's result, the page/`NewPage` sequence, and that the fallback
   engages only when the metafile is unusable — plus direct unit tests of the
   pure mapping (both modes, degenerate inputs).
5. **Manual fidelity checklist** in `TESTING.md`.

### 6.3 Explicitly out of scope

- **P1** (duplicate representations) and **P5** (eviction/streaming).
- Changing the **default scaling** (D2).
- Removing the PDF exporter's dependency on `Microsoft Print to PDF` or its modal
  `ShowMessage` — noted, not fixed here.
- DPI rework, preview redesign, engine changes.
- Any `.vrt`, expression or serializer change.

### 6.4 Acceptance template

1. `tools\ci_gate.ps1` exit 0; DUnitX ≥ 643 + new; `Tests Leaked : 0`.
2. All 42 corpus page counts unchanged (`VittixRunner --strict` exit 0).
3. New structural print-guard tests pass, and — following the P2 pattern — a
   **mutation proof** that reverting the print path to the bitmap makes them fail.
4. Manual printer checklist executed and recorded (or explicitly recorded as NOT
   executable in this environment).
5. `git status reports` clean; 42/42 fixtures byte-untouched.

## 7. Stop conditions

Stop and report if: the canvas seam would require a **public** API break; the
preview cannot be served by the same mapping without redesign; printing from the
metafile turns out to lose content the bitmap path preserved (a finding, not an
assumption); or `PageCount`/pagination semantics shift.

## 8. Verification of this audit

- Read-only: **no production file modified**.
- Baseline unchanged: DUnitX **643/643**, 0 leaked; `tools\ci_gate.ps1` exit 0;
  `VittixRunner --strict` 41 pass / 1 skip / 0 mismatch; packages build with
  0 errors; `reports/` fixtures byte-untouched; HEAD **549e0c4**; no commits.

---

## 9. P3 — implemented

Decisions taken: **D1 = unify on the metafile**, **D2 = keep full stretch**.

### 9.1 Changes

| File | Change |
| --- | --- |
| `source/Vittix.Report.PrintMapping.pas` | **new** — the single pure mapping: `TReportPrintScaleMode` (`prsFullStretch` default, `prsFitPreserveAspectCentered` available) and `CalculatePrintDestRect(...)` |
| `source/Vittix.Report.Renderer.pas` | `Print` now delegates to a new **protected** `DrawPageTo` seam; the source is the **metafile** (bitmap only as a defensive fallback). No public API added. |
| `source/Vittix.Report.Preview.pas` | uses the shared mapping (identical full-stretch rectangle — no behaviour change) |
| `source/Vittix.Report.Export.PDF.pas` | uses the shared mapping; the PDF-unit-private `TPDFExportScaleMode`/`CalculatePDFDestRect` were **deleted** (net −40 lines; its "fit" mode was unreachable dead code — `ScaleMode` was hardcoded to full stretch) |
| `packages/VittixReportRuntime.dpk` | registers the new unit |
| `tests/Test.Gap005.PrintPath.pas` | **new** — 7 tests (see §9.2) |
| `TESTING.md` | new §3.2 manual print-fidelity checklist |

No public API changed: the seam is `protected` and driven by a test descendant.

### 9.2 Tests and mutation proof

```
baseline: 643   new: 7   final: 650   passed: 650   failed: 0   errors: 0   leaked: 0
```

- **Pure mapping:** full stretch reproduces the exact previous rectangle and
  ignores the page size; the aspect mode fits-and-centres and preserves the ratio;
  degenerate/negative inputs never raise.
- **Draw seam:** drawing every page leaves `RasterCount = 0` — i.e. the print
  path is **vector**; a bitmap draw would increment it. Invalid arguments
  (nil canvas, out-of-range index) draw nothing and rasterise nothing.
- **Mutation proof:** forcing `DrawPageTo` back onto the bitmap made **2 tests
  fail** (`Expected [0] but got [3] The print path must draw the metafile, not the
  bitmap (P3)`), then the change was reverted and the suite returned to green.
  The guard therefore detects a raster regression rather than merely observing one.

### 9.3 Evidence and limits

- Corpus unchanged: 42/42 page counts, 0 mismatches; GDI +8 / USER 0 identical to
  before P3.
- **Not verified, not faked:** actual printed pixels and driver fidelity — no
  printer path can run headlessly. `TReportRenderer.Print` itself is never invoked
  by the tests (it would open a device). The manual checklist in `TESTING.md` §3.2
  covers it.
- The preview remains manual-only (windowed control).

### 9.4 Still deferred

- **P1** (duplicate representations) — unchanged.
- **P5** (eviction/streaming) — unchanged.
- The PDF exporter's dependency on `'Microsoft Print to PDF'` and its modal
  `ShowMessage` (finding F5) — noted, not fixed.
- Any change to the **default scaling** (D2) — the aspect mode exists but is not
  wired to any default.
- The designer's `Frm.Preview` still reads `Pages[0].Bitmap` for page dimensions.

