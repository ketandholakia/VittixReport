# Vittix brand assets

Two marks, one per product:

| File | Product | Mark |
|---|---|---|
| `vittix-designer-logo.png` / `vittix-designer.ico` | **Vittix Report Designer** (the app) | V/D monogram |
| `vittix-report-logo.png` / `vittix-report.ico` | **VittixReport** (the component library) | V/R monogram |

- `*-logo.png` — wide transparent logo at 1024 px, for documents, README headers,
  package listings and anywhere a horizontal mark is wanted.
- `*.ico` — the same mark squared off with padding, at
  16/20/24/32/40/48/64/128/256 px, for Windows window, taskbar and shortcut icons.
- `source/*-master.png` — the artwork as supplied. Edit these, not the outputs.
- `_preview-*.png` — a 3× check strip showing the icon at 16/32/48/64 px.

## Colours

Sampled from the artwork, for use in docs, packaging and any future UI work:

| Role | Value |
|---|---|
| Brand blue | `#027CFB` |
| Brand slate | `#384150` |

These sit comfortably next to the designer's existing chrome palette
(`Frm.Main.Theme.pas`), whose Soft preset accent is `#0066CC`.

## Regenerating

```bash
python branding/build_brand_assets.py
```

Requires Pillow. It rewrites the PNG/ICO files and then regenerates

```
vittixdesigner/resources/vittix_app_icon.res
```

which contains `MAINICON` (the designer icon for the executable) and
`VITTIX_LOGO` (the RCDATA PNG the About dialog displays). That `.res` is
committed, so a normal build never needs this script.

### Why the .res is generated here

Neither of the obvious routes works with this toolchain:

- `brcc32` (5.40, from 1999) cannot read modern `.ico` files — it fails with
  `Allocate failed` on anything Pillow writes.
- `{$R 'file.ico'}` is not supported by `dcc32`; the linker reports
  `Unsupported 16bit resource`.

So the resource file is written directly. Two details matter, both learned the
hard way:

1. The file must start with the **null resource entry** `brcc32` normally emits.
2. That entry's type and name must be the ordinal-form fields (`FF FF 00 00`),
   not raw zero bytes — otherwise `ilink32` rejects the whole file with
   `Unsupported 16bit resource`.
