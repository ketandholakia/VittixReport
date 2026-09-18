# VittixReport User Manual

## Overview
VittixReport provides a visual report designer and runtime engine for Delphi VCL applications. It enables users to design, preview, and export reports with bands, data fields, images, tables, barcodes, and more.

## Launching the Designer
- Open `vittixdesigner/VittixDesigner.dproj` in Delphi 12.2 and run the application.

## Main Window Layout
- **Objects Toolbox**: Drag objects (Label, Field, Image, Table, Barcode, etc.) onto the canvas.
- **Designer Canvas**: Arrange bands and objects visually.
- **Properties Panel**: Edit properties of the selected object.
- **Menus/Toolbar**: File, Edit, Insert, Align, View, Report, Preview, Export.

## Basic Operations
- **New/Open/Save**: Create or load `.vrt` report files.
- **Export to PDF**: Export the current report to PDF (requires Windows 10+).
- **Undo/Redo**: Unlimited undo/redo for all actions.
- **Insert Bands**: Add report sections (title, header, footer, master data, summary).
- **Insert Objects**: Place visual elements in bands.
- **Align/Distribute**: Align and space objects with toolbar buttons.
- **Zoom/View**: Zoom in/out, toggle grid/rulers/margins.

## Keyboard Shortcuts
| Action | Shortcut |
|--------|----------|
| New report | Ctrl+N |
| Open | Ctrl+O |
| Save | Ctrl+S |
| Undo/Redo | Ctrl+Z / Ctrl+Y |
| Cut/Copy/Paste | Ctrl+X/C/V |
| Delete | Del |
| Select All | Ctrl+A |
| Nudge | Arrow keys |
| Preview | F5 |

## Report File Format
- Reports are saved as JSON (`.vrt`).
- Example:
```json
{
  "Version": 2,
  "Title": "Sales Report",
  "Objects": [ ... ]
}
```

## Printing and Exporting
- Use the Preview window to review pages.
- Print directly or export to PDF.

## Expressions and Events
- Text objects can embed field and variable references such as `[Name]`.
- Common uses are conditional formatting, `DisplayFormat`/`EditMask` on fields, `PrintWhen` visibility rules, and `SUM()` aggregates in group footers.
- Runtime `OnBeforePrint` / `OnAfterPrint` callbacks are assigned by the host application in Delphi code; the designer does not execute persisted event text.
- See the demo templates and the report events reference for working examples.

## Troubleshooting
- Ensure all required bands and objects are placed.
- For PDF export, "Microsoft Print to PDF" must be available (Windows 10+).

## More Help
- See the README for project structure and integration.
- For advanced usage, see the Developer Manual.
- For event scripting rules, see the report events reference.
- For ready-made examples, see the demo templates.
