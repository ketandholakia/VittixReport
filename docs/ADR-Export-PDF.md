# ADR: Export PDF Path (Baseline & Decision)

Status: **Proposed — decision pending sign-off**
Date: 2026-09-19
Scope: `E0 — Export Baseline & PDF Decision` (see [Export roadmap](Export-Roadmap.md))
Deciders: project owner

**Update 2026-09-19 (after the baseline):** the blocking defect in §3.3 has
been fixed and the smoke check hardened (§6.1–6.2). Vector PDF now renders:
40 of the 41 corpus PDFs produce ink and extractable text; the remaining one is
an `AllowHTML` rich memo whose content is not captured into export commands (a
pre-existing, documented deferred item — "Rich text PDF export"). The
"Latin-text-only" labels listed in §8 were corrected. §6 items 3–5 (migrate the
default, re-label the capability, glyph subsetting + Indic end-to-end
verification) remain open.

---

## 1. Context

VittixReport ships **two independent PDF paths**, exposed as two separate public
APIs on `TVittixReport`:

| API | Unit / class | Mechanism |
| --- | --- | --- |
| `ExportToPDF` | `Vittix.Report.Export.PDF.pas` → `TReportPDFExporter` (`IReportExporter`) | Prints the rendered `TMetafile` pages to the Windows virtual printer `Microsoft Print to PDF` |
| `ExportToVectorPDF` (file + stream) | `Vittix.Report.Export.VectorPDF.pas` → `TReportVectorPDFExporter` | Writes a PDF directly from the semantic export command document (`TReportExportDocument`) |

The designer exposes both (`Export PDF`, `Export to Vector PDF...`); the vector
action is labelled **Beta**.

The purpose of E0 is to characterise both, identify their feature/Unicode
differences, and decide which one is the supported production path and what
happens to the other.

---

## 2. How each path works (source-verified)

### 2.1 Printer-based (`Export.PDF.pas`)

```
TMetafile pages (TReportEngine.Pages)
        ↓
Printer.PrinterIndex := Printer.Printers.IndexOf('Microsoft Print to PDF')
Printer.Title        := <file name without extension>
Printer.BeginDoc / NewPage / EndDoc
        ↓
Printer.Canvas.StretchDraw(CalculatePrintDestRect(...), Page)
```

Observed properties:

* **Hard environment dependency.** `ExportPages` raises if the named printer is
  absent (`'"Microsoft Print to PDF" printer not found...'`) and there is no
  fallback.
* **The `FileName` argument is not the output path.** It is only used as the
  print-job title; the real destination comes from the printer port. Silent
  writing to a caller-chosen path is not guaranteed (a Save dialog may appear).
* Fidelity is whatever the Windows driver produces from a metafile → typically
  rasterised text/lines, driver-dependent.
* The page-size mismatch diagnostic is non-blocking (`OutputDebugString`); the
  `Vcl.Dialogs` dependency was already removed.
* Output geometry goes through the shared `Vittix.Report.PrintMapping`
  `CalculatePrintDestRect(..., prsFullStretch)`, i.e. the same mapping as print.

### 2.2 Native vector (`VectorPDF.pas`)

```
Engine render pass → TReportExportDocument (TReportExportPage + commands)
        ↓
TReportVectorPDFExporter writes the PDF itself:
  header, page tree, per-page /Resources, content streams, xref, trailer
```

Observed properties:

* **Dependency-free** (RTL/VCL only: `System.ZLib`, GDI; Uniscribe via
  `usp10.dll`) and **deterministic**; stream output overload supports silent /
  server-side export.
* Text is written in **two tiers**:
  * Latin-1 (`SupportsPdfAnsiText`) → the four built-in `Helvetica` variants.
  * Non-Latin-1 → Uniscribe shaping (`ScriptItemize/ScriptShape/ScriptPlace`)
    **and a real embedded TrueType font**: `Type0` / `Identity-H` →
    `CIDFontType2` → `FontDescriptor` `/FontFile2` + `CIDToGIDMap` + `ToUnicode`
    CMap, with a rasterise-to-image fallback and a skip-with-log fallback.
* Images: JPEG (`DCTDecode`) and PNG (Flate, with `/SMask`), as image XObjects.

---

## 3. Baseline evidence (measured on this machine)

### 3.1 Printer path

* `Get-Printer` reports `Microsoft Print to PDF` **present** (driver
  `Microsoft Print To PDF`), so the path is functional here. It is *not*
  guaranteed on other machines (the dependency is the whole risk).

### 3.2 Vector path — Unicode font embedding actually happens

A synthetic document with one Latin-1 command and one Devanagari command was
exported to PDF and the raw bytes inspected:

```
header %PDF-: 1      /Type0: 1        /CIDFontType2: 1
/FontFile2: 1        /ToUnicode: 1    /Identity-H: 1     /Helvetica: 4
```

The Devanagari line is emitted as glyph IDs under the embedded `/UF1` font
(`<010B> Tj`, …) with **no rasterisation** — so font embedding / Unicode text is
implemented in the source, contradicting the "Latin-text-only beta" labels.

### 3.3 Vector path — **output is structurally invalid (blank pages)**

The writer's page object is mis-nested. For a synthetic document *and* for all
41 PDFs produced by the regression runner:

```
page object bracket balance: final depth -1   (one '>>' too many)
/Contents is emitted at depth 0 → it lands OUTSIDE the page dictionary
```

As a consequence the page has no `/Contents`, and renderers produce nothing:

```
41/41 sampled vector PDFs  → MuPDF/pymupdf: page_count ok, dark pixels = 0, get_text() = ''
```

Additional consequence of the same nesting error: the Unicode font resources
(`/UF1 …`) are emitted as siblings of `/Font` **inside `/Resources`** instead of
inside `/Resources /Font` (`get_fonts()` lists only `F1`–`F4`), and `/XObject`
entries are placed one level too shallow.

The root cause is in the page-dictionary assembly
(`Vittix.Report.Export.VectorPDF.pas`, the `<< /Type /Page …` emitter): the
`/Resources /Font` dictionary is closed before the `UF*` entries, and the final
literal emits `' >> /Contents … >>'`, closing the page object before
`/Contents`.

### 3.4 Why this was not caught: the smoke test is string-based

`VittixRunner` reports `Vector PDF OK`, but its check only greps for `%PDF-`,
`xref`, `trailer`, `/Contents`, `/MediaBox` and `%%EOF` as **text**. All of
those markers are present even though `/Contents` is outside the page object, so
the smoke test cannot fail on this class of defect.

---

## 4. Feature / capability comparison (source-inspected, not visually verified)

| Capability | Printer PDF | Vector PDF |
| --- | --- | --- |
| Produces viewable output today | **Yes** (driver-dependent) | **No** — blank pages (§3.3) |
| Environment dependency | `Microsoft Print to PDF` required | None |
| Silent / no-dialog export | Not guaranteed | Yes (stream overload) |
| Server / non-interactive | Fragile (may show Save dialog) | Yes |
| Vector (selectable) text | Driver-dependent, usually raster | Intended yes (blocked by §3.3) |
| Unicode / non-Latin-1 text | Via the print driver | Embedded TrueType (Type0/CIDFontType2) + Uniscribe shaping; raster/skip fallback |
| Multi-page | Yes | Yes (page tree emitted) |
| Images (JPEG/PNG) | Via driver | JPEG/PNG XObjects (+ PNG `/SMask`) |
| EMF/WMF/SVG images | Via driver | Not supported (documented) |
| Font subsetting | n/a | **No** — whole font file embedded (1.5 MB for one short line) |
| Deterministic bytes | No | Yes |
| Test coverage | Print-path/GAP-005 tests | Runner smoke only (structural strings) |

---

## 5. Options considered

* **Option A — Vector PDF is the supported path now.**
  Rejected *as-is*: it cannot be the supported path while it produces blank
  pages. The architecture is right; the writer has a blocking defect.
* **Option B — Printer PDF is the supported path permanently.**
  Rejected as a destination: it keeps a hard environment dependency and cannot
  guarantee silent, path-targeted output — poor for servers/CI.
* **Option C (recommended) — Fix the vector writer, then migrate.**
  Keep the printer path as the supported default *only until* the vector writer
  is repaired and verified; then make vector PDF the default and demote the
  printer path to an optional compatibility fallback. Do not retire the printer
  path in this cycle (the vector path is not yet proven end-to-end).

## 6. Decision (proposed — awaiting sign-off)

**Adopt Option C.**

1. **Immediate (blocking):** fix the vector page object in
   `Vittix.Report.Export.VectorPDF.pas`:
   * emit `/Contents … 0 R` **inside** the page dictionary (remove the extra
     `>>`);
   * emit `UF*` font entries inside `/Resources /Font`;
   * emit `/XObject << … >>` inside `/Resources`.
2. **Immediate (same change):** replace the runner's string-marker vector check
   with a check that **parses** the page object (at minimum: `/Contents` occurs
   inside the page dictionary; ideally render or extract text and require
   non-empty output).
3. **Keep** the printer path as the supported default until (1)+(2) ship and are
   verified on the existing report corpus.
4. **Then** migrate the supported default to Vector PDF and re-label it from
   "Beta / Latin-text-only" to its verified capability set; demote
   `ExportToPDF` to compatibility-only.
5. **Unicode text work (was M5.6):** the embedding pipeline exists; after the
   structural fix, verify it end-to-end (Devanagari/Gujarati sample report,
   text extraction, visual parity vs preview) and decide whether to add glyph
   **subsetting** (files are large) before calling Unicode "supported".

Items owed by the decider: confirm Option C (or choose A/B), and confirm whether
the printer path should ultimately be *compatibility-only* or *deprecated*.

---

## 7. Consequences

* Choosing Option C needs a **small, contained fix** before PDF can be called
  "done" on either path — it does not require an architectural change.
* The `docs/index.md` "Latin-text-only beta" wording and the designer's
  "Full Unicode/font embedding is still pending" message are **stale** and must
  be corrected once (5) is settled (see §8).
* Silent/server PDF export becomes possible without third-party libraries,
  satisfying the dependency policy in the [Export roadmap](Export-Roadmap.md).

## 8. Documentation drift found (to correct)

| Location | Claim | Reality |
| --- | --- | --- |
| `VectorPDF_DevelopmentPlan.md` (M5.5 "Known limitations", M5.6 "Pending") | "No font embedding… non-Latin-1 will not render correctly" | Embedding + shaping implemented (§3.2) |
| `docs/index.md` (Export) | "Latin-text-only beta" | Unicode path implemented (blocked by §3.3, not by font support) |
| `vittixdesigner/Frm.Main.pas` (export message) | "Full Unicode/font embedding is still pending" | Same |
| `docs/Export-Roadmap.md` | "Latin-only text support" | Same |

## 9. Follow-ups (not done in E0)

* Implement §6.1 and §6.2 (vector writer fix + real smoke check) — the smallest
  next change; belongs to E1/E6, not E0.
* Correct the documentation drift in §8.
* Add a Unicode end-to-end test once the writer is fixed.

---

## Appendix — how the baseline was measured

```
# printer availability
Get-Printer | Where-Object Name -eq 'Microsoft Print to PDF'

# vector writer: synthetic doc (Latin + Devanagari) → PDF → byte markers
TReportVectorPDFExporter.ExportDocument(doc, 'probe.pdf')
#   → %PDF- 1, /Type0 1, /CIDFontType2 1, /FontFile2 1, /ToUnicode 1, /Identity-H 1

# page-object structural check (all 41 regression outputs + probe)
#   bracket balance of the `/Type /Page` object → final depth -1, /Contents at depth 0

# render check
VittixRunner --keep-vector-pdf        # then, for each output:
pymupdf.open(pdf)[0].get_text() == '' ; rendered dark pixels == 0
```

All findings above were produced read-only; **no production code was changed**
by E0.
