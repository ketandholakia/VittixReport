# VittixReport Demo App

This folder contains a VCL demo application similar to the FastReport sample browser.

## Project
- `VittixReportDemo.dproj`
- `VittixReportDemo.dpr`
- `Frm.DemoMain.pas/.dfm`

## Data
- Demo database: `demo/db/northwind.db` — **not tracked** (large sample DB).
  Download `northwind.db` from https://github.com/jpwhite3/northwind-SQLite3
  and place it here; the app shows this path when the file is missing.
- The database path can be overridden per user in
  `%APPDATA%/VittixReportDemo/settings.ini`:
  ```ini
  [Database]
  NorthwindPath=C:\path\to\northwind.db
  ```
  A configured but missing path is reported explicitly and is not replaced by
  another database automatically.
- GUI acceptance can use a separate canonical-sized copy at
  `demo/db/northwind_acceptance.db`; point `NorthwindPath` at it without
  replacing an existing local `northwind.db`. This acceptance copy was built
  from the documented `jpwhite3/northwind-SQLite3` source at commit
  `4f56e7f5906dfd23b25244c5bfe8fb5da6402efd`, using `src/create.sql`,
  `src/update.sql`, and `src/report.sql` (not `src/populate.py`). Its measured
  core counts are 93 customers, 830 orders, and 2,155 order-detail rows.
  Rebuild a missing copy with `python demo/db/build_northwind_acceptance.py`;
  the script verifies pinned source hashes and refuses to overwrite an existing
  output file.
- Extra sample DB (small, tracked): `demo/db/vittixreportdemodb.db`
- SQL seed script: `demo/db/vittix_demo_sqlite.sql` — regenerates
  `vittixreportdemodb.db`: `sqlite3 demo/db/vittixreportdemodb.db < demo/db/vittix_demo_sqlite.sql`

## Report Files
- Put report files in `demo/vrt/`
- File name is mapped from demo key, e.g. `simple_list.vrt`, `charts.vrt`, `xtab_2values.vrt`
- The report-template folder can be overridden in
  `%APPDATA%/VittixReportDemo/settings.ini`:
  ```ini
  [Reports]
  VrtPath=C:\path\to\demo\vrt
  ```
- The demo also probes portable paths relative to its executable when no
  `VrtPath` is configured. A configured missing folder/template is reported;
  the demo does not silently fall back or create a blank report.

## Buttons
- `Design`: launches `VittixDesigner.exe` and saves JSON output back to selected `.vrt`
- `Preview`: runs selected query, loads selected `.vrt`, and previews through `TVittixReport`
- `Open VRT Folder`: opens Windows Explorer at the selected report file
- `Template Folder...`: displays the current VRT path and selects/persists a
  replacement folder after verifying it contains `.vrt` files.

## GUI Acceptance
- `Acceptance -> GUI Acceptance - Exact Decimal` uses an in-memory `TFDMemTable`
  (`Qty` is `ftInteger`; `Rate` is `ftFMTBCD`, precision 18, scale 3) with three
  signed decimal rows. Preview shows the expected `0.625` and computed `0.725`.
- Run the same demo data/binding/render validation without opening the modal
  preview with `VittixReportDemo.exe --validate-acceptance-fixture`. Exit code 0
  means the exact dataset metadata, values, aggregates, and report switching
  checks passed.

