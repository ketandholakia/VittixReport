# VittixReport Demo App

This folder contains a VCL demo application similar to the FastReport sample browser.

## Project
- `VittixReportDemo.dproj`
- `VittixReportDemo.dpr`
- `Frm.DemoMain.pas/.dfm`

## Data
- SQLite DB: `demo/db/vittixreportdemodb.db`
- SQL seed script: `demo/db/vittix_demo_sqlite.sql`

## Report Files
- Put report files in `demo/vrt/`
- File name is mapped from demo key, e.g. `simple_list.vrt`, `charts.vrt`, `xtab_2values.vrt`
- If missing, the app creates a blank report file when you click **Design** or **Preview**

## Buttons
- `Design`: launches `VittixDesigner.exe` and saves JSON output back to selected `.vrt`
- `Preview`: runs selected query, loads selected `.vrt`, and previews through `TVittixReport`
- `Open VRT Folder`: opens Windows Explorer at the selected report file

