# GAP-005 — Page Ownership & Retention: Architecture Audit

Status: **audit complete; Step 0 (guard widening, test-only) implemented.**
P1–P5 remain unimplemented and are still not proposed for implementation.
Tree state: branch `main`, HEAD `549e0c4`, no commits.

Predecessors: `docs/Phase6-Output-Coverage.md`,
`docs/Phase5-Quality-Benchmark-CI.md`.

Question this audit answers: **is GAP-005 one problem, or several smaller
problems?** Answer: **several** (§3), coupled through three consumers with a
hard observability split (§4/§5).

---

## 1. Method

Read-only. Every claim is code-referenced. Consumers were traced outward from the
page-producing code through the component, the exporters and the preview.

## 2. Verified ownership / lifetime map

| Artifact | Created | Owned / freed by | Consumed by | Lifetime |
| --- | --- | --- | --- | --- |
| Engine page metafile | `StartNewPage` (Engine 561) | `FPages: TObjectList<TMetafile>` owns (427/489); added in `EndCurrentPage` (655) | `ExportToPDF` → `TReportPDFExporter.ExportToFile(Engine.Pages,…)` (Component 716); `ExportWith` → `IReportExporter.ExportPages(Engine.Pages,…)` (Component 923, Interfaces 36); `TReportRenderer.Render` (Renderer 111) | one `Prepare`; cleared at pass start (`BeginPass` 774, `Prepare` 1560) |
| Engine current page + canvas | `StartNewPage` (561/566) | engine; canvas freed in `EndCurrentPage` (649), page moved into `FPages` | (transient) | one page |
| **Renderer metafile copy** | `Renderer.Render` (Renderer 111, `Page.Metafile.Assign`) | `TReportRenderer.FPages` owns (74/82) | **E-mail**: `EmailClick` → `TReportEmailExporter` (Component 520–524); **preview**: `LoadFromRenderer` copies it again (Preview 185) | renderer lifetime |
| **Renderer bitmap** | `Renderer.Render` (Renderer 108/112, `StretchDraw`) | same `TRenderPage` (54–68) | **`TReportRenderer.Print`** (Renderer 133, `StretchDraw` on the bitmap) | renderer lifetime |
| Preview metafile copy | `LoadFromRenderer` (Preview 184–186) | `TVittixReportPreview.FMetafilePages` (137/144) | `Paint` (459) and `Print` (547), preferred over the bitmap | preview lifetime |
| Preview bitmap copy | `LoadFromRenderer` (Preview 178–182, pixel-perfect `Draw`) | `TVittixReportPreview.FPages` (136/145) | `Paint`/`Print` **fallback only** when the metafile is missing (460, 549) | preview lifetime |
| Export command document | `TReportExportDocument` | component (`ExportDoc.Free`) | VectorPDF / HTML / XLSX / Text | one export call |

**Two structural facts that drive everything below:**

1. **The engine is freed immediately after rendering** in the main flows —
   `Execute` frees the engine right after `Renderer.Render` (Component 566–571),
   and `Print` does the same (684–689). The *renderer's* pages, not the engine's,
   are what survive to be consumed.
2. **The renderer drives the engine**: `TReportRenderer.Render` assigns
   parameters, sets `TwoPassRendering`, calls `AEngine.Prepare`, then copies
   every engine page (Renderer 102–118).

Per page, four artifacts therefore coexist at peak: engine metafile → renderer
metafile copy + renderer bitmap → preview metafile copy + preview bitmap. That is
the GAP-005 cost.

---

## 3. Is GAP-005 one problem or several?

**Several.** They share a symptom (memory / print quality) but differ in risk,
observability and blast radius.

### P1 — Duplicate page representations
Three copies of the same content live at once (engine metafile; renderer metafile
+ bitmap; preview metafile + bitmap). Each has a *real* consumer, so none is dead
weight — but the renderer's metafile copy exists only to be re-copied by the
preview and handed to the e-mail exporter, and the preview's bitmap copy is only
ever a **fallback** (the metafile is preferred in both `Paint` and `Print`).

### P2 — Eager rasterization
`Renderer.Render` rasterizes **every** page to a bitmap unconditionally
(Renderer 112), although the bitmap is needed only by `TReportRenderer.Print` and
by the preview's fallback. Bitmaps dominate memory (width × height × 4 bytes per
page). A lazily-produced raster would remove the dominant cost in the common
preview path.

### P3 — Print-fidelity asymmetry
Two print paths in one product behave differently:
`TReportRenderer.Print` rasters the bitmap through `StretchDraw` (Renderer 133),
while `TVittixReportPreview.Print` **prefers the metafile** (Preview 547).
Unifying on metafile playback improves sharpness and is the prerequisite for
dropping the renderer bitmap from the print path — but the print path is not
automatable here (§4).

### P4 — `PageCount` is a counter, not a collection size
`TReportEngine.PageCount` reads `FPageNumber` (Engine 274) — the current page
counter, not `FPages.Count`. Phase 1 and Phase 6 tests assert
`Engine.PageCount = Renderer.Pages.Count`, which holds only because every page is
currently retained. **Any eviction/streaming design must preserve `PageCount`
semantics**, or `[TotalPages]`-style output and those tests break silently.

### P5 — No eviction or streaming exists
`FPages` accumulates for the whole pass and is cleared only at *pass* start
(`BeginPass` 774, `Prepare` 1560; `ExecutePass` calls `ClearExecutionCaches`
first, 1512). Two-pass rendering builds pages twice, but only the final pass's
pages are retained. There is no page-cache policy, no eviction and no
re-render seam. This is net-new architecture, not a tweak.

**Verdict:** P1–P3 are memory/quality; P4 is a contract hazard constraining all
of them; P5 is a new subsystem. Treating GAP-005 as one task would mix a
refactor, a quality change and new architecture.

---

## 4. The decisive constraint: an observability split

| Path | Automatable today? | Evidence |
| --- | --- | --- |
| Engine page counts / pagination | **Yes** | 42-report corpus, `reports/regression_baselines.json`, `VittixRunner --strict` |
| Vector PDF / HTML / XLSX / Text | **Yes** | corpus export smoke + export test units |
| `TReportRenderer` page shape | **Yes** | added headlessly in Phase 6 (`Test_Coverage_RendererPageDimensions`) |
| Plugin seam `ExportPages(Engine.Pages)` | **Yes** | `Test.Vittix.Runner.ExportVerification`, export tests |
| **`TVittixReportPreview`** | **No** | windowed `TCustomControl`; fails with "has no parent window" (Phase 6, confirmed) |
| **Physical print** (both paths) | **No** | printer-driver dependent (Phase 1 manual procedure) |
| Pixel / visual fidelity | **No** | no comparator exists (GAP-006) |

The renderer — where the eager bitmap and the print rasterization live — **is**
headlessly testable, while the preview and the printer are not. This is the same
trap that sank the GAP-004 index: a change in a path the gate cannot see.

## 5. Coupling map (why P1–P3 cannot be a small isolated change)

```
Engine metafile ──► ExportToPDF (Component 716)
                 ├─► IReportExporter.ExportPages (923)
                 └─► Renderer.Render ──► renderer metafile copy ──► E-mail (520-524)
                                     │                         └─► Preview.LoadFromRenderer (185)
                                     └─► renderer bitmap ──► Renderer.Print (133, StretchDraw)
                                                          └─► preview bitmap copy (fallback only)
```

Removing the renderer metafile copy requires rerouting the e-mail exporter;
switching print to metafile playback changes printed output; dropping the preview
bitmap touches a non-automatable path. **Every P1–P3 simplification is coupled to
at least one consumer that is either manual-only or a public seam.**

---

## 6. Recommended decomposition and sequencing (Phase 7+)

> **Superseded in part (post P2 + P3).** Step 0, P2 and P3 are now **complete**.
> The residual review (`docs/GAP-005-Residual-Review.md`) measured what
> duplication actually remains and concluded that **P1 (Steps B/C) is not worth
> pursuing as an ownership redesign**; only the narrow preview Step D remains,
> and it is not authorised. The sequencing below is kept as the historical record.

Do **not** implement in this phase. When Phase 7 is authorised:

**Step 0 — widen the guard first (test-only, low risk).**
Extend headless coverage over the artifacts P1–P3 would change: renderer page
representation (metafile presence/shape, bitmap presence/shape), the
`ExportPages(Engine.Pages)` seam, and the e-mail/PDF metafile consumption. This
is the GAP-006 direction from the Phase 6 ranking applied narrowly to the
renderer/export boundary rather than to pixels. Without it every later step is
unverifiable — exactly the GAP-004 failure mode.

**Step A — P2 + P3 in the renderer (gate-covered), print verified manually.**
Make the raster lazy and unify print on metafile playback. Both live in
`TReportRenderer`, which is headlessly testable. Printed output is a *quality*
change, so it needs the Phase 1 manual print procedure (TESTING.md §3.1/§9) and a
deliberate note in the Phase 1 characterization record.

**Step B — P1 + P4 in the engine (gate-covered).**
Only after Step 0/A: consider page retention, preserving `PageCount` semantics
(P4) and proving it with corpus page counts. Start with the *cheap* removal — the
renderer metafile copy, rerouting the e-mail exporter to the retained
representation — rather than introducing eviction.

**Step C — P5 (eviction/streaming)** only if measurements justify it. Net-new
architecture; a phase of its own, not part of a memory cleanup.

**Step D — preview lifetime (`LoadFromRenderer` copies) last.** The only part
with no automatable verification today; changing it before a windowed harness
exists would be unverifiable. **Leaving the copies in place is a defensible end
state.**

### Explicit non-goals for the next phase

- No eviction/streaming before Steps 0–B.
- No preview change without a windowed harness (or an explicit decision to verify
  it manually).
- No change to `PageCount` / `[TotalPages]` semantics.
- No `.vrt`, expression, or serializer change.

---

## 7. Acceptance template (per future step)

1. `tools\ci_gate.ps1` exit 0; DUnitX count strictly ≥ 630 + new;
   `Tests Leaked : 0`.
2. All 42 corpus page counts unchanged (`VittixRunner --strict` exit 0).
3. Step-specific structural assertion (e.g. "raster produced only on demand"
   proven by a counter or by object presence before/after a paint/print call).
4. Manual print/preview checklist executed and recorded (Steps A and D), because
   neither is automatable.
5. Process resource deltas recorded via the runner; memory claimed only when
   measured, never assumed.

---

## 8. Verification of this audit

- Read-only: **no production file was modified** to produce it.
- Baseline unchanged and reproducible: DUnitX **630/630**, 0 leaked;
  `tools\ci_gate.ps1` exit 0; `VittixRunner --strict` 41 pass / 1 skip; packages
  build with 0 errors; `reports/` fixtures byte-untouched; HEAD **549e0c4**; no
  commits.

---

## 9. Step 0 — implemented (test-only)

`tests\Test.Gap005.OutputGuard.pas` (+7 tests → DUnitX 637) establishes the
renderer/export safety net required before Steps A/B.

**What it guards:** one `TRenderGuardSummary` per render (logical page count,
retained pages, renderer pages, page dimensions, metafile presence, bitmap
presence, first rendered text sample) and a `GuardViolations` comparison that
classifies changes as `page-count` / `page-dimension` / `page-presence` /
`output-text`.

**Detection is proven, not assumed.** Four tests inject one deliberate change
each into a synthetic summary and assert the guard reports exactly that class
(and not another) — so the guard has been observed failing for each change type
it claims to catch:

| Injected change | Expected class |
| --- | --- |
| logical / retained / renderer page count | `page-count` |
| page width or height | `page-dimension` |
| metafile or bitmap missing | `page-presence` |
| rendered text | `output-text` |

**Real-render assertions:** a 120-row fixture must produce >1 page;
`Engine.PageCount = Engine.Pages.Count = Renderer.Pages.Count`; every engine page
carries a metafile; every renderer page currently carries both a bitmap and a
metafile; the first rendered text sample is non-empty; and the real summary
compared with itself yields zero violations.

**P4 contract locked:** `Test_Guard_PageCountTracksRetainedPages` asserts the
logical page count equals the retained page count under the current design. Any
future eviction/retention change must update this test **deliberately** rather
than break it by accident — the constraint requested for the implementation plan.

**Stated limitation (no fake verification):** the real PDF exporter (printer
driver) and e-mail exporter (MAPI) are **not** invoked. The export seam is
guarded through its `IReportExporter.ExportPages` contract using an in-process
recording exporter; the preview and both print paths remain manual-only (audit
§4).

**No production file was modified by Step 0.**

---

## 10. P2 — lazy rasterisation: implemented

Scope: **P2 only** (P1, P3, P5 remain deferred, §6).

### 10.1 Consumer inventory (established before any change)

Every repository consumer of a renderer page bitmap was enumerated:

| Consumer | Location | Needs bitmap? |
| --- | --- | --- |
| `TReportRenderer.Render` | Renderer.pas (old line 112) | **No** — this was the eager rasterisation being removed |
| `TReportRenderer.Print` | Renderer.pas (line 133) | Yes, but only when `Print` is called (on demand) |
| `TVittixReportPreview.LoadFromRenderer` | Preview.pas (line 178) | Yes, at load (the bitmap copy is a paint/print **fallback**; the metafile is preferred) |
| `Frm.Preview` (designer) | `vittixdesigner/Frm.Preview.pas` 143–144 | Only for **page dimensions** (could read the metafile instead) |
| `ExportToPDF` | Component.pas 716 | **No** — uses `Engine.Pages` metafiles |
| `ExportWith` / `IReportExporter.ExportPages` | Component.pas 923 | **No** — metafiles |
| E-mail export | Component.pas 520–524 | **No** — uses `Renderer.Pages[i].Metafile` |
| VectorPDF / HTML / XLSX / Text | component export paths | **No** — export document / model |

**Conclusion: no production consumer requires a bitmap immediately after
`Render`.** The bitmap is needed only by explicit demand (print, preview load,
designer page-size query).

### 10.2 Design

```
Render:
    metafile retained (vector)           <- primary representation
    bitmap NOT created                   <- the P2 change

Bitmap access (page.Bitmap):
    first access  -> materialise from the metafile, cache, RasterCount := 1
    later access  -> return the cached instance (no re-rasterisation)
```

- The rasterisation path is **centralised** in `TRenderPage.GetBitmap`
  (one place, `Renderer.pas`) and reproduces the previous sequence exactly
  (white fill, then `StretchDraw` of the metafile at the page dimensions), so
  visual output is unchanged.
- `TRenderPage.RasterCount` is read-only instrumentation (0 or 1) so laziness is
  **measured**, never inferred from a nil bitmap.
- **Public API note:** `TRenderPage.Bitmap` and `.Metafile` changed from public
  *fields* to read-only *properties*. This is **source-compatible**: every
  consumer read them, and no writer exists anywhere in the repository (verified
  by search). No caller has to change.
- **Ownership:** the page owns both artefacts; `Destroy` frees whichever exist,
  so a materialised bitmap cannot outlive its metafile.
- **Threading:** the renderer is used from the owning VCL thread; no
  synchronisation was added and none is needed under the supported usage.

### 10.3 Guard adaptation (contract split, not weakening)

The Step 0 guard's single "bitmap present" expectation was **split**:

| After | Required |
| --- | --- |
| `Render` | metafile present and valid for every page; **`EagerRasterisations = 0`** |
| bitmap demand | a bitmap materialises, with the page width/height |

The mutation tests were extended with a **P2 regression detector**: injecting
`EagerRasterisations = 1` must raise a `page-presence` violation. No existing
detection was weakened.

### 10.4 Evidence

- **Mutation proof.** Temporarily reintroducing eager rasterisation in `Render`
  (one line: touching `Page.Bitmap`) made **6 tests fail** — `Test_A`–`Test_E`
  plus the Step 0 guard — with messages such as
  `Expected [0] but got [3] Render must not rasterise any page eagerly`.
  The change was then reverted and the suite returned to green. The guard
  therefore provably detects the regression rather than merely checking for nil.
- **Structural before/after.** The multi-page fixture renders **3 pages**:
  before P2 → **3** rasterisations immediately after `Render`; after P2 → **0**.
  At scale (1000 rows, >10 pages) after P2 → **0** rasterisations.
- **Corpus unchanged.** All 42 page counts unchanged (`VittixRunner --strict`,
  0 mismatches); GDI delta 8 and USER delta 0 identical to the pre-P2 baseline.

### 10.5 Deferred / unchanged by P2

- **P1** (duplicate representations) — deferred. The renderer still retains a
  metafile copy alongside the engine's; the preview still copies both.
- **P3** (print asymmetry) — deferred. `TReportRenderer.Print` still rasterises
  via `StretchDraw` on the (now lazily materialised) bitmap; `Preview.Print`
  still prefers the metafile. No print behaviour was changed.
- **P5** (eviction/streaming) — deferred.
- **Preview** — unchanged; it still copies the bitmap at load, which now
  materialises on demand. Making it metafile-first is Step D.
- **Designer follow-up (not changed):** `vittixdesigner/Frm.Preview.pas`
  reads `Pages[0].Bitmap.Width/Height` only to size the large-preview warning;
  it could read `Metafile.Width/Height` and avoid one raster. Behaviour is
  identical today, so this is left as a follow-up.

