# VittixReport Bug Queue

## Critical
- [x] BUG-C1 NamedDS not passed to renderer - fixed in `0d49ea9`
- [x] BUG-C2 Print invokes wrong method - fixed in `4e412d7`
- [x] BUG-C4 Static reports fail without MasterData - fixed in `8cbab36`

## Significant
- [x] BUG-S2 AutoSize mutates bounds - fixed in `911b466`
- [x] BUG-S6 Margin overlay hidden - fixed in `99ab2a4`

## Minor

- [x] BUG-M1 GDI handle growth in regression runs (+8: 16 -> 24). CLOSED 2026-09-28 after a dedicated audit: expected one-time VCL/GDI cache initialization, **not a leak**, no production fix. Evidence: deterministic 16 -> 24 across 3 suite runs with USER handles and memory flat; no accumulation when the full suite runs twice in one process (GDI stays at 24); the delta decomposes into first-use `Vcl.Graphics` global caches created during `Engine.Prepare` (first report +5, first barcode report +2, first displayformat-values report +1) that persist for process lifetime and are reused; Vector PDF export adds zero persistent handles; the identical +8 reproduces at pre-M5.5 commit `0bd2087` (2026-05-25), exonerating M5.5/M5.6/M5.7/M8. The image-heavy suspects (`07_imagepath_test`, `27_object_event_image_cases`) cost 0.

## Refactor

Always work top-down:

Critical
Significant
Minor
Refactor
