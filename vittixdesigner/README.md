# Vittix Report Designer — Application

A full-featured, standalone report designer application built on the Vittix
Report framework. Written in Delphi 12.2 (VCL, Win32/Win64).

---

## Project Structure

```
VittixReportDesignerApp/
├── VittixDesigner.dpr        Main application project
├── VittixDesigner.dproj      Project options (Delphi 12.2)
│
├── Frm.Main.pas / .dfm       ★ Main designer window
├── Frm.BandManager.pas/.dfm  Band Manager dialog
├── Frm.PageSettings.pas/.dfm Page Setup dialog
├── Frm.Preview.pas / .dfm    Print Preview window
│
└── (the Vittix.Report.* units live in the parent folder ../)
```

---

## How to Open in Delphi 12.2

1. Place this `VittixReportDesignerApp` folder **inside** your existing
   Vittix.Report source tree so the `..\..\` relative paths in the `.dpr`
   resolve correctly, or adjust the paths in `VittixDesigner.dpr` to
   match your layout.

2. Open **VittixDesigner.dproj** in Delphi 12.2.

3. Build → Run (F9).

---

## Main Window Layout

```
┌──────────────────────────────────────────────────────────────────┐
│ File  Edit  Insert  Align  View  Report                  (menu)  │
│ [New][Open][Save] | [Undo][Redo] | [Align tools] | [Zoom][Prev] │
├────────────┬──────────────────────────────────┬──────────────────┤
│            │                                  │                  │
│  Objects   │       Designer Canvas            │   Properties     │
│  ────────  │   (TVittixReportDesigner         │  ────────────    │
│  Label     │    inside a TScrollBox)          │  Report Title    │
│  Field     │                                  │  Author          │
│  Image     │  Bands + objects drawn here.     │  Zoom %          │
│  Table     │  Click to select, drag to move,  │  ────────────    │
│  Barcode   │  rubber-band for multi-select,   │  [ValueListEditor│
│  Line      │  double-click to edit text       │   shows published│
│  Shape     │                                  │   props of the   │
│  RichText  │                                  │   selected obj]  │
│            │                                  │  [Apply Props]   │
└────────────┴──────────────────────────────────┴──────────────────┘
│ Status: 2 objects selected  at (120, 40)  160 × 20              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Features

### File Operations
| Action | Shortcut |
|--------|----------|
| New report | Ctrl+N |
| Open `.vrt` file | Ctrl+O |
| Save | Ctrl+S |
| Save As | — |
| Export to PDF | — |

### Edit
| Action | Shortcut |
|--------|----------|
| Undo (unlimited) | Ctrl+Z |
| Redo | Ctrl+Y |
| Cut / Copy / Paste | Ctrl+X/C/V |
| Delete | Del |
| Select All | Ctrl+A |

### Insert Bands
Via **Insert** menu or Band Manager:
- Report Title
- Page Header
- Master Data  ← attach a TDataSet to the engine at runtime
- Page Footer
- Report Summary

### Insert Objects
Click an object type in the **Objects** toolbox on the left, then click
inside a band on the canvas to place it. Pressing Esc cancels insert mode.

Registered object types (from ObjectRegistry):
- Label, FieldLabel, Image, Line, Shape, RichText
- Table (`Vittix.Report.Objects.Table`)
- Barcode (`Vittix.Report.Objects.Barcode`)

### Alignment Toolbar
All alignment operations are **fully undoable** (Ctrl+Z):
- Align Left / Right / Top / Bottom
- Same Width / Same Height
- Center Horizontal / Center Vertical
- Distribute Horizontally / Vertically  *(requires ≥ 3 objects)*
- Bring to Front / Send to Back

### View
- Zoom In (+) / Zoom Out (−) / Reset to 100% — or type a % in the zoom box
- Toggle: Grid, Snap-to-Grid, Rulers, Margin guides

### Property Inspector
Selecting any object loads its **published properties** into the
`TValueListEditor` panel on the right. Edit a value and press Enter or
click **Apply Properties** to commit the change back to the object via
`TReportPropertyBridge`.

### Band Manager  (`Report → Band Manager…`)
- Lists all bands in the report
- Add / Delete bands
- Edit each band's: Type, Height, GroupField, GroupLevel,
  CanGrow, CanShrink, StartNewPage, BackColor

### Page Setup  (`Report → Page Setup…`)
- Paper size: A4, Letter, Legal, A3, Custom
- Orientation: Portrait / Landscape
- Margins (in pixels @ 96 DPI)
- Live dimension preview

### Print Preview  (`Report → Preview…`  or F5)
- Renders the report via `TReportRenderer + TReportEngine`
  against a *nil* dataset (design-time preview with no live data)
- First / Prev / Next / Last navigation
- Zoom In / Out / Fit Width
- Print button (uses system printer via `TVittixReportPreview.Print`)

---

## Wiring a Live DataSet at Runtime

The designer itself uses `nil` for the dataset. In your own host application
you can embed `TVittixReportDesigner` and drive the engine like this:

```delphi
uses
  Vittix.Report.Engine,
  Vittix.Report.Serializer,
  Vittix.Report.Export.PDF;

var
  Report : TReportModel;
  Engine : TReportEngine;
begin
  Report := TReportSerializer.LoadFromFile('MyReport.vrt');
  Engine := TReportEngine.Create(Report, MyADOQuery);
  try
    Engine.Prepare;
    // Engine.Pages contains TMetafile pages
    TReportPDFExporter.ExportToFile(Engine.Pages, 'output.pdf');
  finally
    Engine.Free;
    Report.Free;
  end;
end;
```

---

## Keyboard Shortcuts in the Designer Canvas

| Key | Action |
|-----|--------|
| Arrow keys | Nudge selected object(s) by 1 px (Shift = grid size) |
| Del | Delete selected |
| Ctrl+A | Select all objects in active band |
| Ctrl+Z / Y | Undo / Redo |
| Esc | Cancel insert mode |

---

## Report File Format

Reports are saved as **JSON** (`.vrt` extension). The format is
fully documented in `Vittix.Report.Serializer`. A minimal example:

```json
{
  "Version": 2,
  "Title": "Sales Report",
  "Author": "Ketan",
  "PageSettings": { "PaperSize": 0, "Orientation": 0, ... },
  "Objects": [
    { "Type": "TReportBand",  "BandType": 2, "Height": 40 },
    { "Type": "TReportLabel", "Bounds": [10,8,200,20],
      "Text": "Hello [Name]", "FontSize": 10 }
  ]
}
```

---

## Dependencies

All from the **Vittix.Report.*** units in the parent folder:
`Model, Objects, Bands, PageSettings, Serializer, Undo, DesignerControl,
Toolbox, PropertyBridge, Engine, Renderer, Preview, Interfaces, Utils,
Aggregates, Expressions, Context, DataSources, Scripting,
Objects.Barcode, Objects.Table, Export.PDF`

No third-party libraries required beyond standard Delphi RTL + VCL.

---

## Bug Fixes Applied (vs. Original Units)

The four critical bugs noted in code review have been fixed in the units
delivered alongside this application:

1. **Alignment not undoable** — `AlignLeft/Right/Top/Bottom`, `SameWidth/Height`,
   `CenterH/V` now issue `TMultiMoveCommand` so Ctrl+Z works.

2. **Keyboard nudge not undoable** — Arrow keys in `KeyDown` now use the
   same `TMultiMoveCommand` pattern.

3. **DistributeH/V wrong order** — Both functions now sort a copy of the
   selection by position (Left for H, Top for V) before distributing.

4. **Insert X offset wrong** — `SnapV(PP.X - BAND_LBL_W)` → `SnapV(PP.X)`.
   Objects no longer appear 68 px to the left of where you click.

5. **CloneReport temp file** — Now uses `Root.ToJSON` / `ParseJSONValue`
   entirely in memory.
