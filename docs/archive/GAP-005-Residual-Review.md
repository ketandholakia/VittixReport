# GAP-005 — Residual Duplication Review (post P2 + P3)

Status: **read-only review — no production code changed.** It supersedes the
P1 recommendation in `docs/GAP-005-Page-Ownership-Audit.md` §6.
Tree: branch `main`, HEAD `549e0c4`, no commits.

Predecessors: `docs/GAP-005-Page-Ownership-Audit.md`,
`docs/GAP-005-P3-Print-Audit.md`.

Question: **after P2 (lazy rasterisation) and P3 (vector printing), how much
duplication actually remains, and is P1 still worth its risk?**

Answer: **the duplication has moved — it is now confined to the preview, and it
is a Step D concern rather than a P1 (ownership redesign) concern.** P1's
remaining benefit no longer justifies its cost (§5).

---

## 1. Method

Read-only. The representation map was re-derived from the post-P2/P3 source, and
the residual volume was quantified from the checked-in corpus page counts
(`reports/regression_baselines.json`) using the project's own bitmap-size formula
(`vittixdesigner/Frm.Preview.pas`: `pages x width x height x 4`).

**Caveat on the numbers:** the page counts are exact (read from the baseline
file), but the byte figures assume the representative A4 page (793x1122) for
every page. Reports in the corpus do not all share one page size, so the totals
in §3 are **estimates of the right order, not per-report measurements**. A truly
measured figure would need an instrumented run, which this review deliberately
did not add.

## 2. Representation map after P2 + P3

| Consumer path | Metafiles retained | Bitmaps materialised | Evidence |
| --- | --- | --- | --- |
| Export to Vector PDF / HTML / XLSX / Text | engine only (freed with the engine) | **0** | no renderer involved; export document/model |
| `ExportToPDF` (printer path) | engine only | **0** | Component.pas 716 → `ExportToFile(Engine.Pages, …)` |
| `ExportWith` / `IReportExporter.ExportPages` | engine only | **0** | Component.pas 923 |
| E-mail export | renderer metafile copies | **0** | Component.pas 520–524 uses `.Metafile` |
| **`TVittixReport.Print`** (runtime print) | renderer metafile copies | **0** | P3: `DrawPageTo` draws the metafile; `RasterCount` stays 0 |
| **`TVittixReport.Execute`** (runtime modal preview) | renderer + preview copies | **2 per page** | `LoadFromRenderer` Preview.pas 179–187 |
| **Designer preview** (`Frm.Preview`) | renderer + preview copies | **2 per page** (+1 for the dimension probe) | Frm.Preview.pas 143–144 reads `Pages[0].Bitmap`; then `LoadFromRenderer` |

**P2 removed the eager rasterisation from `Render`; P3 removed it from printing.
The only remaining bitmap production is the preview loading path.**

## 3. Quantified residual

Page geometry (A4 at 96 DPI, the project default): `793 x 1122 = 889,746 px`;
at 4 bytes/px that is **3,558,984 B ≈ 3.39 MiB per bitmap**.

Corpus total (41 baseline reports): **432 pages**.

| Scenario | Bitmaps after P2/P3 | Bitmap footprint (estimated) |
| --- | ---: | ---: |
| Pre-P2: full preview of the corpus | 432 renderer + 432 preview copies = **864** | ≈ **2.86 GiB** |
| Export / print / e-mail (any report) | **0** | 0 |
| **Preview of the corpus today** | 432 x 2 = **864** | ≈ **2.86 GiB** |
| **Preview of `41_twopass_totalpages.vrt`** (75 pages) | 75 x 2 = **150** | ≈ **508 MiB** |

So P2/P3 removed **all** rasterisation from the export, print and e-mail paths —
but the preview path is **unchanged** and still dominates what remains.

## 4. The decisive detail: the preview bitmap is (effectively) unreachable

`TVittixReportPreview` keeps the bitmap **only as a fallback**, and the metafile
is preferred at every use:

| Use | Code | Preference |
| --- | --- | --- |
| `PageWidth` / `PageHeight` | Preview.pas 225–242 | metafile, else bitmap |
| `Paint` | Preview.pas 458–461 | metafile, else bitmap |
| `Print` | Preview.pas 546–549 | metafile, else bitmap |

`LoadFromRenderer` copies the metafile unconditionally (185–187), and after P2/P3
`Render` always produces a valid metafile — so `MetaCopy.Width > 0` in every
normal case and the bitmap branch never executes. **The preview's bitmap copy
exists solely to satisfy a fallback that cannot trigger**, and reading
`ARenderer.Pages[i].Bitmap` (line 179) is what *forces* the renderer to
rasterise every page again — undoing P2 for the preview path.

This is a **self-contained preview problem**, not a page-ownership problem.

## 5. Is P1 still worth it? — assessed, and not at this level

The original audit defined P1 as removing duplicate representations across
engine/renderer/preview. Reassessed against the map in §2:

| Element of P1 | Residual benefit after P2/P3 | Risk |
| --- | --- | --- |
| Renderer metafile copy | small (vector; unmeasured, structurally far below a bitmap) | public/consumer rerouting (e-mail) |
| Preview metafile copy | small (same) | preview is windowed → **not gate-coverable** |
| **Preview bitmap copy + forced rasterisation** | **the entire remaining bitmap cost (§3)** | **not gate-coverable** |
| Engine metafile lifetime | none (freed with the engine in every flow) | ownership change, high blast radius |

**Conclusion:** the only *material* residual is the preview bitmap path, which is
a **Step D** item and is verifiable **only manually**. The remaining metafile
duplication is structurally the smaller term and touches ownership and public
consumers for little measurable gain. Therefore:

> **P1 is not worth pursuing as an ownership redesign.** It is deferred, and at
> most a narrow, self-contained Step D on the preview should be considered — and
> only if the preview's memory is an observed problem in practice.

## 6. Step D — scoped but NOT authorised

Recorded for a future decision; **not implemented here.**

1. `LoadFromRenderer`: stop reading `ARenderer.Pages[i].Bitmap` and stop creating
   the preview bitmap copy; retain metafiles only. (Keeps the preview's
   lifetime-independence property for the metafiles — the reason copies exist.)
2. Make the bitmap fallback **explicit and on demand** rather than pre-copied: if
   a page's metafile is unusable, materialise from the renderer at that point —
   or simply document that the fallback is unreachable after P2/P3.
3. `Frm.Preview`: read `Pages[0].Metafile.Width/Height` for the size probe
   instead of `Pages[0].Bitmap`, removing one more raster.

**Acceptance (all manual):** the preview paints and prints correctly, page
count/dimensions unchanged, no visible regression — recorded in `TESTING.md`
§3.2, because the preview cannot be instantiated headlessly. **The automated gate
cannot protect this change, so it must never be presented as gate-verified.**

## 7. Out of scope

- P5 (eviction/streaming) — still deferred.
- Changing the preview's object model beyond Step D.
- Any engine/renderer ownership unification (P1).
- Any `.vrt`, expression, serializer or pagination change.

## 8. Verification of this review

- Read-only: **no production file modified**.
- Baseline unchanged: DUnitX **650/650**, 0 leaked; `tools\ci_gate.ps1` exit 0;
  `VittixRunner --strict` 41 pass / 1 skip / 0 mismatch; runtime and design
  packages plus the designer build with 0 errors; `reports/` fixtures
  byte-untouched; HEAD **549e0c4**; no commits.
