# Vittix Designer - UI/UX Improvement Roadmap

Status: proposal (analysis only, no code changed by this document)
Scope: `vittixdesigner/` (the standalone `VittixDesigner.exe` app)
Related: `vittixdesigner/README.md`, `vittixdesigner/resources/ICON_MAP.md`

> **Progress:**
> - *Batch 1* (items 1-3): toolbar checkbox strip removed, Save As / Export PDF /
>   Cut / Fit-width added, four `tbsCheck` view toggles, state-driven status bar.
> - *Batch 2*: property inspector got a live filter box (item 6, first part) and the
>   status bar was split into four panels so the file state and the property hint no
>   longer overwrite each other.
> - *Batch 3*: property groups are now collapsible (click a `[Group]` header, or press
>   Enter/Space on it); each header shows its member count and whether it is folded.
>   Item 6's "real editors per type" turned out to be **already implemented**
>   (`Frm.Main.PropertyEditorHelpers` supplies pick lists and ellipsis editors), so that
>   bullet was dropped from the open list.
> - *Batch 4*: the left dock is now a single chain of four **collapsible sections**
>   (Objects / Report Structure / Variables / Dataset Fields) with uniform header bars.
>   Clicking a header folds that section to its header bar; the leftover height always
>   goes to the bottom-most open section, and the folded state plus per-section heights
>   are persisted. The "double-click a band node to zoom the canvas" bullet from item 7
>   is still open.
> - *Batch 5*: added a **Problems panel** as a fifth dock section (between Variables and
>   Dataset Fields). It lists loader diagnostics (previously discarded, including on the
>   command-line open path) plus live report checks - unknown DataField against the
>   report schema or connected dataset, unbound field objects, zero-size objects, bands
>   with no height, images with neither picture nor DataField. The header shows the count
>   and double-clicking an entry selects the offending object.
> - *Batch 6*: **reveal-in-canvas**. Double-clicking a structure-tree node - and a
>   Problems entry - now scrolls the designer viewport so the band/object is visible.
>   This needed one additive public member on the designer control,
>   `TVittixReportDesigner.ObjectClientRect`, because the layout geometry was private.
>   That closes item 7.
> - *Batch 7*: **drag read-out overlay** (part of item 8). While moving, resizing or
>   re-sizing a band the canvas shows a small amber badge next to the pointer with the
>   live position (`X n   Y n`), size (`W x H`) or band height (`H n`). Audit for item 8
>   also found that smart alignment guides are **already implemented** (they snap within
>   5 px and draw as guide lines).
> - *Batch 8*: **insert affordance** (closes item 8). Hovering a band separator draws a
>   blue insertion line across the page plus a `+ Band` badge; clicking the separator (a
>   click, not a resize drag) raises the new `OnBandInsertRequest` event and the host
>   pops its band-type menu, inserting the chosen band directly after that separator.
> - *Batch 9*: **dead-code triage** (item 4). Removed all eleven never-used private
>   symbols in the designer plus two in the library; the solution builds with no H2219
>   warnings.
> - *Batch 10*: **guided empty state + template gallery** (item 10). An empty report now
>   draws a short three-step guide on the canvas, and File > New from Template lists the
>   reports found in the templates folder (`reports/` by default) and loads the chosen one.
> - *Batch 11*: **command palette** (item 13). `Ctrl+Shift+P` (or View > Command Palette)
>   opens a filterable list of every enabled menu command - 111 entries in the current
>   build - and runs the chosen one.
> - *Batch 12*: **chrome theme palette** (part of item 11). `Frm.Main.Theme.pas` is now
>   the single documented source for the designer's chrome colours, with three presets
>   (Classic = today's look, Soft, Dark), applied to the dock sections, panels, splitters,
>   lists, status bar and the designer canvas surface. View > Theme switches it and the
>   choice is persisted. The canvas *internals* (grid, margin guides, band header strips,
>   selection handles) and a VCL style remain open - see item 11.
> - *Batch 13*: **accessibility baseline** (item 16). Hints added to the remaining
>   interactive controls (report title/author, zoom box and preset combo, property filter
>   and grid, canvas viewport, object toolbox, dock splitters, Apply buttons). Audit: of 57
>   interactive controls every one now carries a Hint except four text buttons whose
>   captions are self-describing, and every focusable control has a TabOrder with none
>   disabled - nothing is unreachable by keyboard.
> - Item 5 was re-checked and is **already implemented** (`Frm.Main.SelectionSync`);
>   it is removed from the open list.
> - Items 4, 7-16 remain open.

---

## 1. Where the UI stands today

Inventory taken from `Frm.Main.dfm` / `Frm.Main.pas`:

| Region | Current implementation |
|---|---|
| Menu bar | File / Edit / Insert / Align / View / Report / Help |
| Toolbar | 22 icon buttons + 9 separators + zoom combo, then a 320 px `TCheckListBox` "quick view toggle strip" (Grid/Snap/Ruler/Margin), then Preview |
| Status bar | 3 panels: selection details, file, `Zoom: n%` (`Frm.Main.ViewHelpers.UpdateStatusBar`) |
| Left dock | One column, 3 splitters: **Objects** (owner-draw toolbox) / **Report Structure** (tree) / **Variables** (tree) / **Dataset Fields** (filter + list) |
| Canvas | `TVittixReportDesigner` inside a `TScrollBox`, 1200×1600 logical surface |
| Right dock | Report title/author edits, `TValueListEditor` property grid, Apply, Font..., Bring Front, Send Back, Preview |
| Dialogs | Band Manager, Page Setup, Report Properties, Designer Options, Script Editor, Expression Helper, Preview, Image Editor |

Strong points worth keeping: unlimited undo/redo, named alignment commands, grid/snap/rulers/margin guides,
`FitPageWidthZoom`, persisted preferences (`TDesignerPreferencesService`), drag-and-drop of fields and
variables onto the canvas, per-property hint text in the status bar.

---

## 2. Quick wins (≈half a day each, low risk)

*Items 1-3 below are implemented; see the progress note at the top.*

These are contained edits that do not touch the report engine or public component APIs.

1. **Replace the toolbar `CheckListBox1` toggle strip with icon toggle buttons.**
   `CheckListBox1` (`Frm.Main.dfm:300`) is a 320 px `TCheckListBox` embedded in `ToolBar1`, so the toolbar
   mixes checkboxes with flat icon buttons. Four `TToolButton`s with `Style = tbsCheck` bound to
   `Grid / Snap / Ruler / Margin` (icons `grid.svg`, `snap_to_grid.svg`, `show_ruler.svg`, `border.svg`
   are already generated) make it consistent, free ~250 px of toolbar, and remove a control whose
   `Columns = 4` layout breaks under DPI scaling.
   Touches: `Frm.Main.dfm`, `Frm.Main.ViewHelpers.pas` (`ConfigureViewToggleStrip`), `CheckListBox1ClickCheck`.

2. **Finish the toolbar action set.** Icons already exist for `save_as`, `picture_as_pdf`, `print`,
   `cut`, `select_all`, `zoom_fit_to_page`, `zoom_fit_width`, and the commands are already implemented as
   menu handlers. Adding Save As / Export PDF / Print / Fit-width / Fit-page removes trips to the menu bar.
   Note `FitPageWidthZoom` already exists (`Frm.Main.pas:4603`).

3. **Make the status bar carry state, not just coordinates.** Add a modified (`*`) indicator, show the
   full file path on hover instead of `ExtractFileName`, and surface the active panel/list mode.
   Touches: `Frm.Main.ViewHelpers.UpdateStatusBar`.

4. **Triage the dead helpers.** *Delivered in batch 9.* Every private symbol the compiler
   flagged as declared-but-never-used in `Frm.Main.pas` was removed - `SamePropertyValue`,
   `BuildChangedPropertyBatch`, `SelectedObjectsSpanBands`,
   `CanInsertVariableIntoCurrentProperty`, `FindStructureNodeByData`, `ShortNodePreview`,
   `IsControlWithinParent`, `IsFontDialogRowKey`, `FindRecentFilesMenu`,
   `RunRegressionTestReports` (the dead wrapper; the live
   `RunRegressionTestReportsAction` lives in `Frm.Main.ReportActions`) - plus the unused
   `FDisablePreviewShortcut` field and two library privates
   (`TVittixReportDesigner.FPageTop`, `TExpressionTokenizer.CurrentChar`).
   The solution now builds with **zero H2219 warnings**.
   Left alone on purpose: the H2164 "local variable declared but never used" hints in the
   library (ScriptHost adapter, expression evaluator, barcode encoder, `DrawRulers`) -
   harmless, and a few may be deliberate scaffolding.
   Note: `SamePropertyValue` / `BuildChangedPropertyBatch` were the scaffolding for
   multi-select batch apply; the remaining item-6 work (mixed-value display) would need
   them rebuilt. They are recoverable from git history.

5. **~~Selection feedback in the structure tree.~~** - already implemented via
   `Frm.Main.SelectionSync` (`SyncReportStructureSelection`, `StructureTreeChange`,
   `StructureTreeDblClick`); the canvas and the tree already stay in sync.

---

## 3. Mid-term (≈1-3 days each)

6. **Property inspector usability.** *Filter box and collapsible groups delivered in
   batches 2-3.* `edtPropFilter` (above the grid) hides non-matching rows live,
   Esc clears and Enter jumps into the grid; clicking a `[Group]` header (or Enter/Space
   on it) folds that group, and the header shows `(n)` / `(n collapsed)`. Type-aware
   editors already exist in `Frm.Main.PropertyEditorHelpers` (enum and boolean pick
   lists, field pick list, ellipsis editors for text/colour/font/expression/script).
   Still open:
   - explicit "N objects selected / mixed values" state for multi-select,
   - "reset to default" per row.

7. **Left dock information architecture.** *Collapsible sections delivered in batch 4.*
   The dock is one vertical chain - Objects, Report Structure, Variables, Dataset Fields -
   where each header folds its section down to an 18 px bar (`+` marker when folded,
   `-` when open). The bottom-most open section absorbs the leftover height, so folding
   never leaves a gap, and the fold state plus the per-section heights are persisted in
   `TDesignerPreferencesService` (`ObjectsPanelHeight`, `StructurePanelHeight`,
   `VariablesPanelHeight` and the four `*Collapsed` flags).
   Also delivered in batch 6: double-clicking a node in the tree scrolls the canvas so
   that band/object is visible (`ScrollObjectIntoView` over the new
   `ObjectClientRect`), which completes this item.

8. **Direct manipulation on canvas.** *Delivered.*
   Already present before this work: band height by dragging the separator, object resize
   handles, rubber-band selection, and smart alignment guides that **snap** (within 5 px)
   as well as draw.
   Batch 7 added the drag read-out overlay (`DrawDragReadout`) - live `X/Y` while moving,
   `W x H` while resizing, `H n` while resizing a band.
   Batch 8 added the insertion affordance: hovering a band separator draws an insertion
   line and a `+ Band` badge, and clicking it raises `OnBandInsertRequest` so the host can
   insert a band at that point (`Frm.Main` pops a six-entry band-type menu and
   `InsertBandAfter` places the new band directly after the clicked one). Dragging the same
   separator still resizes the band; only a click with no drag requests an insert.

9. **Problems / diagnostics panel.** *Delivered in batch 5.* A fifth dock section lists
   loader diagnostics plus live checks (DataField not in the report schema or connected
   dataset, unbound field objects, zero-size objects, bands with no height, images with
   neither picture nor DataField). The header shows the entry count and a double-click
   selects the object a problem refers to. Possible follow-ups: per-severity colour,
   a "refresh" command, and checks for expressions that fail to parse.

10. **Guided empty state.** *Delivered in batch 10.* A report with no bands now draws a
    short guide on the canvas (`DrawEmptyReportHint`):
    "Empty report - get started:", "1. Insert > Add Band", "2. Drag a field from the
    Dataset Fields list onto the band", "3. Click Preview to see the rendered result".
    It is suppressed while insert mode is active, since that already shows its own hint.
    `File > New from Template` lists the `.vrt` files found in the first existing
    templates folder - `<exe>\templates`, `<exe>\..\templates`, `<exe>\reports`,
    `<exe>\..\reports` (the repo's 42-file `reports/` folder is picked up today),
    `<exe>\..\demo\vrt` - and loads the chosen report against the sample dataset.
    Possible follow-ups: thumbnails in the menu, a "Start from a blank report" entry, and
    persisting a user-chosen templates folder in the preferences service.

---

## 4. Larger investments (weeks, higher risk - needs discussion first)

11. **Theming / visual refresh.** *Partly delivered in batch 12.*
    `vittixdesigner/Frm.Main.Theme.pas` holds the palette the designer chrome uses -
    the colours used to sit inline at each call site (dock header bars, splitters,
    overlays). Three presets ship: **Classic** (the previous look, so existing
    installations see no change), **Soft** (warm-neutral surfaces, slate header bar, blue
    accent) and **Dark**. `View > Theme` switches between them, `ApplyTheme` pushes the
    palette onto the dock sections, panels, splitters, lists, status bar, the canvas
    surface and (for non-Classic themes) the designer's canvas colour, and the choice is
    persisted as `Theme=` in the settings file. The Classic theme deliberately leaves the
    canvas colour to Designer Options so that setting is not clobbered.
    Still open, and needing a decision rather than just code:
    - **Canvas internals.** Grid lines, margin guides, band header strips, selection
      handles, smart guides and the drag/insert/hint overlays are painted inside
      `Vittix.Report.DesignerControl` with system colours (`clWindowText`, `clGray`,
      `clFuchsia`, ...) which adapt to the OS theme. Making them palette-driven means a
      change inside the reusable control and a visual pass on the result.
    - **A VCL style** (`TStyleManager.TrySetStyle`) would refresh every form at once, but
      it repaints controls the designer's custom-drawn chrome does not expect, and the
      result cannot be validated from here - it needs someone to look at it.
    - Consistent paddings across the docks, and a matching accent for the property grid
      and toolbox selection.
12. **Icon sizes at DPI.** `ImageList1` is a single 24×24 list; PerMonitorV2 setups would look better with
    16/24/32 px variants selected per DPI. Requires extending the icon pipeline in
    `resources/ICON_MAP.md` (one PNG per size, one `TImageList` per size).
13. **Command palette.** *Delivered in batch 11.* `Ctrl+Shift+P` (also View > Command
    Palette) opens a modal palette: type to filter, Up/Down to move, Enter to run,
    Esc to dismiss.
    The entries come from the **menu tree**, not from `TCommandDispatcher` - the
    dispatcher is the undo/redo stack for model actions, so it has no notion of UI
    commands. Walking the menu instead means the palette stays in sync automatically and
    also picks up the runtime-built menus (recent files, templates, the Insert menus).
    Captions are rendered as `Menu > Item    (Shortcut)`.
    The chosen command runs *after* the palette closes, so dialogs it opens nest under the
    main window rather than under the palette.
    Possible follow-ups: a scoring/fuzzy match rather than a substring filter, remembering
    the last command, and adding non-menu commands (e.g. designer options) as entries.
14. **Undo history panel** exposing `TCommandManager` entries with names and jump-to-state.
15. **Non-blocking report preparation.** `AGENTS.md` already calls for avoiding a blocked UI during long
    preparation; add a cancellable progress surface for prepare/preview/export of large reports.
16. **Accessibility baseline.** *Delivered in batch 13.*
    - Hints: an audit over the form found the interactive controls that had none - the
      report title/author edits, the zoom box and preset combo, the property filter and
      the property grid, the canvas viewport, the object toolbox, the dock splitters and
      the Apply buttons - and they now all carry one. 57 interactive controls were
      checked; the only ones left without a Hint are four text buttons whose captions
      already say what they do (Font..., Bring Front, Send Back, Preview).
    - Toolbar and menu commands already had hints/captions from earlier batches.
    - Tab order: every focusable control has an explicit TabOrder and none is
      TabStop=False, so nothing is unreachable by keyboard.
    - Still open if wanted: real screen-reader names (VCL exposes Caption/Hint to MSAA;
      a UIA provider for the custom-drawn canvas would be a separate piece of work), and
      a keyboard-shortcut cheat sheet review.

---

## 5. Guardrails

- No rewrite of the component library; designer-only changes stay in `vittixdesigner/`.
- Do not rename or remove public classes, units, or properties (`AGENTS.md`).
- Changes to `Frm.Main.dfm` must keep the existing `ImageIndex` contract - see
  `resources/ICON_MAP.md` ("ImageList1 index map") before adding/removing toolbar buttons.
- Every UI change needs a manual pass: open a demo report, check preview/print/export parity, and verify
  no new GDI/memory growth (the designer creates many temporary bitmaps).

## 6. Suggested first batch

Items 1, 2 and 3 together: they are contained, use assets and commands that already exist, and visibly
change the toolbar and status bar without touching the report engine. Item 4 should be triaged at the same
time (wire or delete the dead helpers) to stop the codebase drifting.
