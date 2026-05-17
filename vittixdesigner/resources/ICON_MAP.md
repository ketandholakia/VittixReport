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
| Align Vertical Center | `vertical_align_center.svg` | Missing - add from Google Material Icons before wiring. |

## Z-order / arrange
| Action | Icon file | Notes |
|---|---|---|
| Bring To Front | `flip_to_front.svg` | bring forward |
| Send To Back | `flip_to_back.svg` | Missing - add from Google Material Icons before wiring. |

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
- `flip_to_back.svg`
- `vertical_align_center.svg`
- `crop_square.svg`
- `horizontal_rule.svg`
- `visibility.svg`
- `pageview.svg`

Only add these if needed by the final toolbar/tree/menu design.

## Future wiring notes
- Prefer loading SVGs into a central SVG image collection if available.
- Keep toolbar icons around 24x24.
- Keep tree icons around 16x16.
- Do not rely on raw ImageIndex numbers without documenting the mapping.
- If using ImageList indexes, add an "ImageList index map" section later.
