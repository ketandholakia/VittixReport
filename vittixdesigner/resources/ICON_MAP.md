# VittixReport Designer Icon Map

## Purpose
This document maps designer actions, tools, panels, and report objects to SVG files in `vittixdesigner/resources/`.

- Icons are currently SVG files.
- Use existing files only unless a missing icon is explicitly added.
- Keep names stable so Delphi image collection/icon wiring does not break.

## Naming rules
- Use lowercase snake_case filenames.
- Prefer simple names like `save.svg`, `undo.svg`, `text_object.svg`.
- Avoid long Material download names.
- Do not rename icons after they are wired into the designer unless code/DFM references are updated.
- Object icons should end with `_object.svg` where appropriate.

## Icon colour standard
- Toolbar and designer icons are dark grey (`#4A4A4A`, some newer ones `#1E1E1E`) so they stay readable on the light `clBtnFace` UI.
- Keep new SVG sources dark; the designer does not recolour icons at runtime.

## How the icons reach the UI (current)

The designer does **not** use any SVG component and does **not** use the DELPHI
`TImageCollection`/`TVirtualImageList` pair for the toolbar. Icons are plain PNGs
embedded as resources and loaded at startup:

1. `resources/*.svg` - the source icon set (98 files).
2. `resources/convert_fitz.py` - renders each SVG to a transparent **24x24** PNG
   in `resources/png/<name>.png`.
3. `resources/gen_png_rc.py` - writes `resources/vittix_png_icons.rc`
   (`PNG_<NAME> RCDATA "png/<name>.png"`).
4. `brcc32 -fo vittix_png_icons.RES vittix_png_icons.rc` - compiles the resource.
5. `Frm.Main.pas` (`{$R resources\vittix_png_icons.res}`) loads every entry into
   `ImageList1` at startup with `ImageList1.Add`.

`ImageList1` is configured as `cd32Bit`, `dsTransparent`, **24x24** - it must stay
the same size as the generated PNGs.

### Pitfall: the legacy bitmap stored in the DFM

`Frm.Main.dfm` still contains an old 16x16 placeholder bitmap for `ImageList1`.
`TCustomImageList.SetWidth/SetHeight` only clears the list when the handle is
already allocated, so without an explicit `ImageList1.Clear` (see
`TfrmMain.FormCreate`) those stale images stay at index 0 and every runtime image
is appended **after** them. That shifts every `ImageIndex` referenced by the
toolbar and the structure tree and the wrong (or blank) icons are drawn.

Do not remove the `ImageList1.Clear` call, and keep `ImageList1` size in sync with
the generated PNG size.

## File / report actions
| Action | Icon file | Notes |
|---|---|---|
| New Report | `new_file.svg` | create new report |
| Open Report | `file_open.svg` | open report file |
| Open Folder / Browse | `folder_open.svg` | browse/open folder |
| Save | `save.svg` | save current report |
| Save As | `save_as.svg` | save with new name |
| Export PDF | `picture_as_pdf.svg` | PDF export |
| Print | `print.svg` | print report |
| Preview | `preview.svg` | report preview |
| Download / Export | `download.svg` | generic export/download |
| Page Setup | `page_setting.svg` | page settings |
| Report Properties | `info.svg` | title/author/description |
| About | `about.svg` | about dialog |
| OK / Apply | `check.svg` | confirm/apply |
| Cancel / Close | `close.svg` | close/cancel |

## Edit actions
| Action | Icon file | Notes |
|---|---|---|
| Undo | `undo.svg` | undo action |
| Redo | `redo.svg` | redo action |
| Cut | `cut.svg` | cut selection |
| Copy | `copy.svg` | copy selection |
| Paste | `paste.svg` | paste selection |
| Delete | `delete.svg` | delete selection |
| Select All | `select_all.svg` | select all |

## Report object tools
| Action | Icon file | Notes |
|---|---|---|
| Text Object | `text_object.svg` | text object tool |
| Label Object | `label_object.svg` | label object tool |
| Data Field Object | `datafield_object.svg` | bound field object |
| Memo Object | `memo_object.svg` | memo object tool |
| Image Object | `image_object.svg` | image object tool |
| Barcode Object | `barcode_object.svg` | barcode object tool |
| Shape Object | `shapes_object.svg` | shape object tool |
| Line Object | `line_object.svg` | line object tool |
| SubReport Object | `subreport_object.svg` | subreport object tool |
| Table Object | `table_object.svg` | table object tool |

## Bands / structure
| Action | Icon file | Notes |
|---|---|---|
| Structure Tree | `account_tree.svg` | Missing - add from Google Material Icons before wiring. |
| Band Manager | `bands.svg` | band manager |
| Generic Band | `table_rows.svg` | generic band marker |
| Bands List | `view_agenda.svg` | band list |
| Page Header | `view_headline.svg` | page header band |
| Detail / Master Data | `segment.svg` | detail/master data band |
| Header/Footer marker | `subtitles.svg` | header/footer marker |
| Layers / Object Order | `layers.svg` | Missing - add from Google Material Icons before wiring. |

## Alignment and layout
| Action | Icon file | Notes |
|---|---|---|
| Align Left | `align_horizontal_left.svg` | align left |
| Align Center | `align_center.svg` | align center |
| Align Right | `align_horizontal_right.svg` | align right |
| Align Top | `align_vertical_top.svg` | align top |
| Align Bottom | `align_vertical_bottom.svg` | align bottom |
| Align Text Left | `format_align_left.svg` | text alignment |
| Align Text Center | `format_align_center.svg` | text alignment |
| Align Text Right | `format_align_right.svg` | text alignment |
| Justify Text | `format_align_justify.svg` | text alignment |
| Same Width | `width.svg` | same width |
| Same Height | `height.svg` | same height |
| Move Object | `open_with.svg` | move object |
| Resize Object | `aspect_ratio.svg` | resize object |
| Drag Handle | `drag_indicator.svg` | drag handle |
| Align Vertical Center | `align_vertical_center.svg` | vertical center alignment |

## Z-order / arrange
| Action | Icon file | Notes |
|---|---|---|
| Bring To Front | `flip_to_front.svg` | bring forward |
| Send To Back | `flip_to_back.svg` | send backward |

## Data / connection
| Action | Icon file | Notes |
|---|---|---|
| Database | `storage.svg` | database |
| Dataset | `dataset.svg` | dataset |
| Table / Data Table | `table_chart.svg` | data table |
| Fields List | `view_list.svg` | fields list |
| Reload Sample Dataset | `sync.svg` | reload sample data |
| Live Database Connection | `cloud_sync.svg` | live connection |
| Connection | `link.svg` | connection/link |
| Data Schema | `schema.svg` | schema |

## Expression helper
| Action | Icon file | Notes |
|---|---|---|
| Expression | `functions.svg` | expression editor |
| Check Expression | `calculate.svg` | validate expression |
| Insert Field | `playlist_add.svg` | insert field token |
| Condition | `rule.svg` | conditional expression |
| Recent Expressions | `history.svg` | recent expression list |
| Formula / Code | `code.svg` | formula/code |
| Expression Help | `help.svg` | expression help |

## Regression / diagnostics
| Action | Icon file | Notes |
|---|---|---|
| Regression Tests | `fact_check.svg` | regression tests |
| Test / Lab | `science.svg` | test/lab |
| Diagnostics / Debug | `bug_report.svg` | diagnostics/debug |
| Stress Test | `speed.svg` | stress test |
| Memory Test | `memory.svg` | memory test |
| Analytics / Results | `analytics.svg` | results/analytics |
| Pass | `check_circle.svg` | pass/success |
| Error / Fail | `error.svg` | failure/error |
| Warning | `warning.svg` | warning |

## Help / documentation
| Action | Icon file | Notes |
|---|---|---|
| Help | `help.svg` | help |
| Keyboard Shortcuts | `keyboard.svg` | shortcuts |
| Documentation | `menu_book.svg` | docs |
| Tips | `tips_and_updates.svg` | tips |
| Info | `info.svg` | info |
| About | `about.svg` | about |

## Zoom / preview
| Action | Icon file | Notes |
|---|---|---|
| Zoom In | `zoom_in.svg` | zoom in |
| Zoom Out | `zoom_out.svg` | zoom out |
| Fit Page | `zoom_fit_to_page.svg` | fit page |
| Fit Width | `zoom_fit_width.svg` | fit width |
| Preview | `preview.svg` | preview |

## Missing recommended icons
- `account_tree.svg`
- `layers.svg`
- `crop_square.svg`
- `horizontal_rule.svg`
- `visibility.svg`
- `pageview.svg`

Only add these if needed by the final toolbar/tree/menu design.

## Future wiring notes
- Icons are plain PNGs loaded into `ImageList1` (24x24); there is no SVG component dependency.
- Keep toolbar icons at 24x24 and keep them in sync with `ImageList1.Width/Height`.
- Keep the `ImageList1` load order below stable; toolbar and structure-tree `ImageIndex` values in the DFM depend on it. New icons must be appended, never inserted.
- `label_object` was appended after `table_object`, so indices 0..31 keep their historical meaning.

## ImageList1 index map
This is the load order used by `TfrmMain.FormCreate`
(`PNGNames`) and the mapping consumed by `ToolBar1.Images = ImageList1` plus the
structure tree. Indices 0..20 are toolbar buttons, 21..31 are structure-tree
nodes, 32 is toolbox-only.

| Index | Icon file | Usage |
|---|---|---|
| 0 | `file_open.svg` | Open Report (`btnOpen`) |
| 1 | `save.svg` | Save (`btnSave`) |
| 2 | `new_file.svg` | New Report (`btnNew`) |
| 3 | `undo.svg` | Undo (`btnUndo`) |
| 4 | `redo.svg` | Redo (`btnRedo`) |
| 5 | `align_horizontal_left.svg` | Align Left (`btnAlignLeft`) |
| 6 | `align_horizontal_right.svg` | Align Right (`btnAlignRight`) |
| 7 | `preview.svg` | Preview (`btnPreview`) |
| 8 | `delete.svg` | Delete (`btnDelete`) |
| 9 | `copy.svg` | Copy (`btnCopy`) |
| 10 | `paste.svg` | Paste (`btnPaste`) |
| 11 | `align_vertical_top.svg` | Align Top (`btnAlignTop`) |
| 12 | `align_vertical_bottom.svg` | Align Bottom (`btnAlignBottom`) |
| 13 | `width.svg` | Same Width (`btnSameW`) / Distribute H (`btnDistH`) |
| 14 | `height.svg` | Same Height (`btnSameH`) / Distribute V (`btnDistV`) |
| 15 | `align_center.svg` | Center Horizontally (`btnCenterH`) |
| 16 | `align_vertical_center.svg` | Center Vertically (`btnCenterV`) |
| 17 | `flip_to_front.svg` | Bring To Front (`btnFront`) |
| 18 | `flip_to_back.svg` | Send To Back (`btnBack`) |
| 19 | `zoom_in.svg` | Zoom In (`btnZoomIn`) |
| 20 | `zoom_out.svg` | Zoom Out (`btnZoomOut`) |
| 21 | `description.svg` | structure tree: report root / fallback |
| 22 | `table_rows.svg` | structure tree: band |
| 23 | `text_object.svg` | structure tree: text object |
| 24 | `datafield_object.svg` | structure tree: data field |
| 25 | `memo_object.svg` | structure tree: memo |
| 26 | `image_object.svg` | structure tree: image |
| 27 | `barcode_object.svg` | structure tree: barcode |
| 28 | `shapes_object.svg` | structure tree: shape |
| 29 | `line_object.svg` | structure tree: line |
| 30 | `subreport_object.svg` | structure tree: sub report |
| 31 | `table_object.svg` | structure tree: table |
| 32 | `label_object.svg` | object toolbox: label tool |
| 33 | `save_as.svg` | toolbar: Save As (`btnSaveAs`) |
| 34 | `picture_as_pdf.svg` | toolbar: Export PDF (`btnExportPDF`) |
| 35 | `cut.svg` | toolbar: Cut (`btnCut`) |
| 36 | `zoom_fit_width.svg` | toolbar: Fit page width (`btnFitWidth`) |
| 37 | `grid.svg` | toolbar toggle: show grid (`btnToggleGrid`) |
| 38 | `snap_to_grid.svg` | toolbar toggle: snap to grid (`btnToggleSnap`) |
| 39 | `show_ruler.svg` | toolbar toggle: rulers (`btnToggleRuler`) |
| 40 | `border.svg` | toolbar toggle: margin guides (`btnToggleMargin`) |

Notes:
- `btnDistH` / `btnDistV` deliberately reuse the width/height icons.
- `Save As`, `Export PDF`, `Cut`, `Select All`, `Page Setup` and `Report
  Properties` are mapped in this document but are not toolbar buttons in the
  current DFM layout.
- Which toolbox tools appear is driven by `GetRegisteredReportObjects`; every
  registered class resolves a name through `ToolImageNameForClass` and falls
  back to `description`.

## Toolbar image mapping (ImageList1)
The main toolbar uses `ToolBar1.Images = ImageList1` and resolves icons by
`ImageIndex`. The `ImageName` values stored in the DFM are inert for a plain
`TImageList` (it has no name support); the numeric `ImageIndex` is authoritative.
Order below is the load order used by `TfrmMain.FormCreate`.

| Button | Action | SVG file | Image name / Index | Notes |
|---|---|---|---|---|
| `btnNew` | New Report | `new_file.svg` | `new_file` / `2` | wired |
| `btnOpen` | Open Report | `file_open.svg` | `file_open` / `0` | wired |
| `btnSave` | Save | `save.svg` | `save` / `1` | wired |
| `btnSaveAs` | Save As | `save_as.svg` | `save_as` / `33` | wired |
| `btnExportPDF` | Export to PDF | `picture_as_pdf.svg` | `picture_as_pdf` / `34` | wired |
| `btnUndo` | Undo | `undo.svg` | `undo` / `3` | wired |
| `btnRedo` | Redo | `redo.svg` | `redo` / `4` | wired |
| `btnDelete` | Delete | `delete.svg` | `delete` / `8` | wired |
| `btnCut` | Cut | `cut.svg` | `cut` / `35` | wired |
| `btnCopy` | Copy | `copy.svg` | `copy` / `9` | wired |
| `btnPaste` | Paste | `paste.svg` | `paste` / `10` | wired |
| `btnAlignLeft` | Align Left | `align_horizontal_left.svg` | `align_horizontal_left` / `5` | wired |
| `btnAlignRight` | Align Right | `align_horizontal_right.svg` | `align_horizontal_right` / `6` | wired |
| `btnAlignTop` | Align Top | `align_vertical_top.svg` | `align_vertical_top` / `11` | wired |
| `btnAlignBottom` | Align Bottom | `align_vertical_bottom.svg` | `align_vertical_bottom` / `12` | wired |
| `btnSameW` | Same Width | `width.svg` | `width` / `13` | wired |
| `btnSameH` | Same Height | `height.svg` | `height` / `14` | wired |
| `btnCenterH` | Center Horizontally | `align_center.svg` | `align_center` / `15` | wired |
| `btnCenterV` | Center Vertically | `align_vertical_center.svg` | `align_vertical_center` / `16` | wired |
| `btnDistH` | Distribute Horizontally | `width.svg` | `width` / `13` | wired (fallback icon) |
| `btnDistV` | Distribute Vertically | `height.svg` | `height` / `14` | wired (fallback icon) |
| `btnFront` | Bring To Front | `flip_to_front.svg` | `flip_to_front` / `17` | wired |
| `btnBack` | Send To Back | `flip_to_back.svg` | `flip_to_back` / `18` | wired |
| `btnZoomIn` | Zoom In | `zoom_in.svg` | `zoom_in` / `19` | wired |
| `btnZoomOut` | Zoom Out | `zoom_out.svg` | `zoom_out` / `20` | wired |
| `btnFitWidth` | Fit page width | `zoom_fit_width.svg` | `zoom_fit_width` / `36` | wired |
| `btnToggleGrid` | Toggle grid | `grid.svg` | `grid` / `37` | `tbsCheck`, mirrors View > Show Grid |
| `btnToggleSnap` | Toggle snap | `snap_to_grid.svg` | `snap_to_grid` / `38` | `tbsCheck`, mirrors View > Snap to Grid |
| `btnToggleRuler` | Toggle rulers | `show_ruler.svg` | `show_ruler` / `39` | `tbsCheck`, mirrors View > Show Rulers |
| `btnToggleMargin` | Toggle margins | `border.svg` | `border` / `40` | `tbsCheck`, mirrors View > Show Margins |
| `btnPreview` | Preview | `preview.svg` | `preview` / `7` | wired |


## Structure tree image mapping
Structure tree uses `FTreeStructure.Images = ImageList1` and node `ImageIndex`/`SelectedIndex` (indices 21..31, see `TREE_ICON_*` in `Frm.Main.pas`).

| Node type | Icon file | Image index/name | Notes |
|---|---|---|---|
| Report root | `description.svg` | `21` / `description` | fallback/default icon |
| Band node | `table_rows.svg` | `22` / `table_rows` | all `TReportBand` types |
| Text object | `text_object.svg` | `23` / `text_object` | `TReportTextObject` |
| Data field object | `datafield_object.svg` | `24` / `datafield_object` | `TReportFieldObject` |
| Memo object | `memo_object.svg` | `25` / `memo_object` | `TReportMemoObject` |
| Image object | `image_object.svg` | `26` / `image_object` | `TReportImageObject` |
| Barcode object | `barcode_object.svg` | `27` / `barcode_object` | `TReportBarcodeObject` |
| Shape object | `shapes_object.svg` | `28` / `shapes_object` | `TReportShapeObject` |
| Line object | `line_object.svg` | `29` / `line_object` | `TReportLineObject` |
| SubReport object | `subreport_object.svg` | `30` / `subreport_object` | `TReportSubReportObject` |
| Table object | `table_object.svg` | `31` / `table_object` | `TReportTableObject` |
| Unknown/fallback object | `description.svg` | `21` / `description` | fallback mapping |

## Object toolbox image mapping
Object toolbox (`TVittixReportToolbox`) uses owner-draw rows and resolves icon
indexes from `ToolImages` **by image name** (`GetIndexByName`).

Important: a plain `Vcl.ImgList.TImageList` does not implement image names -
`IsImageNameAvailable` returns `False` and `GetIndexByName` always returns `-1`,
so the toolbox would silently draw text only. The designer therefore assigns the
toolbox a name-aware `TVirtualImageList` (backed by a `TImageCollection` filled
from the same PNG resources), created in `TfrmMain.FormCreate`. The toolbar and
the structure tree keep using the plain `ImageList1` because DFM streaming of
`ImageIndex`/`ImageName` is only stable on a list without name support.

| Object tool | Icon file | Image index/name | Notes |
|---|---|---|---|
| Text | `text_object.svg` | `text_object` | `TReportTextObject` |
| Label | `label_object.svg` | `label_object` | `TReportLabelObject` |
| Data Field | `datafield_object.svg` | `datafield_object` | `TReportFieldObject` |
| Memo | `memo_object.svg` | `memo_object` | `TReportMemoObject` |
| Image | `image_object.svg` | `image_object` | `TReportImageObject` |
| Barcode | `barcode_object.svg` | `barcode_object` | `TReportBarcodeObject` |
| Shape | `shapes_object.svg` | `shapes_object` | `TReportShapeObject` |
| Line | `line_object.svg` | `line_object` | `TReportLineObject` |
| SubReport | `subreport_object.svg` | `subreport_object` | `TReportSubReportObject` |
| Table | `table_object.svg` | `table_object` | `TReportTableObject` |
| Fallback | `description.svg` | `description` | text-only fallback if image name not found |



