# VittixRunner CLI

`VittixRunner` is the console regression runner. It executes the `.vrt`
fixtures in `reports/`, reconciles rendered page counts against
`reports/regression_baselines.json`, and reports resource-handle deltas.
It is a console application built from `VittixRunner.dpr`; the regression
gate builds it from `VittixRunner.dproj` into
`bin\<platform>\<config>\VittixRunner.exe` (gate step 3/4).

The runner discovers the `.vrt` fixtures in the reports directory
(42 in the current inventory, of which `16_large_preview_warning.vrt` is
skipped by design) and drives them with the same sample data the visual
designer uses (`reports/sample_data.json` unless overridden).

## Usage

```text
Usage: VittixRunner [options] [reportfile.vrt]
```

(The usage text above is the runner's own `--help` output.)

## Options

| Option | Description |
|---|---|
| `--reports <dir>` | Use `<dir>` as the reports directory (no probing). |
| `--baseline <file>` | Use `<file>` as the pagination baseline. |
| `--sample-data <f>` | Use `<f>` as the sample data file. |
| `--output <dir>` | Root directory for retained/export artifacts. |
| `--filter <report>` | Run only `<report>` (also: `--filter=<report>`). A positional `reportfile.vrt` means the same thing; the two forms cannot be combined. |
| `--scripts` | Run only script-bearing regression reports. |
| `--script-trace` | Print script trace diagnostics without pagination checks. |
| `--keep-vector-pdf` | Keep vector PDF smoke outputs under `build\vector-pdf-smoke`. |
| `--strict` (†) | Reconcile every report against the baseline; read-only, exit nonzero on any mismatch. |
| `--format text\|json` (†) | Output format. JSON mode prints exactly one JSON document to stdout. |
| `-pause` | Keep console open after completion. |
| `-h, --help` | Show the help text and exit 0. |

(†) `--strict` and `--format` are accepted by the option parser but are not
listed in the `--help` output. There is no `--update-baseline` switch; the
parser sources state explicitly that it does not exist yet.

## Invalid combinations

The parser rejects these with an error message (see exit codes):

| Combination | Error |
|---|---|
| `--strict` with `--filter` or a positional report name | `--strict cannot be combined with --filter` |
| `--strict` with `--scripts` | `--strict cannot be combined with --scripts` |
| `--strict` with `--script-trace` | `--strict cannot be combined with --script-trace` |
| `--format json` with `--script-trace` | `--format json cannot be combined with --script-trace` |
| `--format json` with `-pause` | `--format json cannot be combined with -pause` |

Strict mode needs the complete report set, so anything that skips reports is
rejected. JSON mode needs machine-readable stdout, so anything that would
corrupt that stream is rejected.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (`--help`, clean run, clean strict reconciliation). |
| `1` | Run failure: CLI parse failure (non-strict), missing reports directory or `--sample-data` file, strict reconciliation or execution failure, any failed report in a non-strict run, JSON formatter failure. |
| `2` | Strict configuration error: CLI validation failure under `--strict`, or a missing, empty, malformed or invalid baseline. No reports are executed in this case. |

## Defaults

| Item | Default |
|---|---|
| Reports directory | Probed relative to the executable: `..\reports`, then `..\..\reports`, then `..\..\..\reports` (covers `bin\<platform>\<config>\`). |
| Baseline file | `<reports>/regression_baselines.json` unless `--baseline` is given. |
| Sample data | `<reports>/sample_data.json` unless `--sample-data` is given; loaded only if the file exists (an explicit `--sample-data` file must exist). |

## Strict versus default runs

- `--strict` is structurally read-only: it uses the validated baseline loader,
  never writes a baseline, and a broken baseline exits 2 before any report runs.
- A default (non-strict) run may auto-register new reports into the legacy
  baseline file it maintains. That auto-registration never turns the run into
  a failure by itself.
- Resource thresholds are enforced by the gate on the runner's output:
  USER handle delta must be 0, GDI handle delta is bounded (gate limit 16).

## Examples

```powershell
# Full strict gate run (what CI-equivalent verification uses)
VittixRunner --strict

# Keep vector PDF smoke outputs for manual inspection
VittixRunner --strict --keep-vector-pdf --output build\gate

# Focus on script-bearing reports (not combinable with --strict)
VittixRunner --scripts
VittixRunner --script-trace

# Single report while developing object event handling
VittixRunner 24_object_event_before_after_masterdata.vrt

# Machine-readable summary
VittixRunner --format json > result.json
```

## CI usage

`.github/workflows/build-and-test.yml` runs `tools\ci_gate.ps1
-IncludePackages` on a self-hosted Windows + Delphi runner. Gate step 4/4 runs
the freshly built executable as `VittixRunner --strict --keep-vector-pdf
--output <gate-dir>` and requires exit 0, then applies the USER/GDI handle
thresholds to the output.

## Related documentation

- [Testing](testing.md) — the automated gate and the manual checklists that use these commands.
- [Regression fixtures](regression-fixtures.md) — the 42 fixtures and the baseline file this tool checks.
- [Phase 5 - quality, benchmarking & CI](Phase5-Quality-Benchmark-CI.md) — the gate contract this tool implements.
