# Vittix Report Engine - Follow-up Tracker
**Derived from the May 2026 review**

---

## Purpose

This document is a working tracker for the next review cycle. It is not a second full code review.

Verified fixed items were re-tested with `VittixRunner.exe` on the current tree:

- `30 Passed`
- `0 Failed`
- `7 Skipped`

---

## Status Legend

- `Verified fixed` - source confirms the issue is resolved.
- `Doc-only` - keep as historical context; no code change needed.
- `Open` - still needs code work or source verification.
- `Needs re-test` - likely fixed, but should be exercised in the current tree.

---

## Open Items

| Item | Status | Next Action |
|---|---|---|
| `BUG-M3` | Needs re-test | Confirm controls are always re-enabled after `First`. |
| `BUG-M7` | Needs re-test | Confirm line objects still honor `ShouldPrintObject`. |
| `R1` | Open | Decide whether to remove global render state now or defer. |
| `R2` | Open | Decide whether to unify preview rendering with configured engine. |
| `R3` | Open | If undo churn matters, cache RTTI context. |
| `R4` | Open | Consider typing designer mode directly. |
| `R5` | Open | Decide whether to collapse the `Core.*` alias units. |
| `R6` | Open | Replace the script host `if-else` chain when ready. |
| `R7` | Open | Move the preview form to a standalone unit if customization is needed. |
| `R8` | Open | Document the limited HTML subset more clearly. |
| `R9` | Open | Add serializer registration if custom object types need it. |
| `MF1` | Open | Decide if single-pass rendering is worth keeping as a supported mode. |
| `MF3` | Open | Add object-level page-break support only if a real layout need appears. |
| `MF4` | Open | Replace the Microsoft Print to PDF dependency with a native exporter. |
| `MF5` | Open | Add other exporters only if export scope expands. |
| `MF6` | Open | Wire `TVittixUserDataSet` through the engine if that API must be supported. |
| `MF7` | Open | Add a reliable row counter to the expression context if needed. |
| `MF8` | Open | Add band-level conditional formatting only if required by report layouts. |
| `MF10` | Open | Add band insertion UI only if the designer workflow depends on it. |
| `MF11` | Open | Add thumbnails/page navigator only if preview navigation remains a pain point. |
| `MF12` | Open | Add runtime report parameters if the product needs user input at run time. |
| `MF13` | Open | Treat barcode encoding as approximation until a real encoder is integrated. |
| `MF14` | Open | Add cross-band lines only if invoice-style layouts require it. |

---

## Recommended Next Pass

### Phase 1

1. Re-test all `Verified fixed` items against the current source tree.
2. Re-run demo reports and check preview, print, export, save, and reload.
3. Confirm no stale global state or serializer regression remains.

### Phase 2

1. Resolve any remaining `Needs re-test` items.
2. Turn any newly discovered regressions into new tracker entries.
3. Keep changes small and isolated.

### Phase 3

1. Only pick one or two open refactors if they directly support a bug fix.
2. Leave broad cleanup until the bug backlog is smaller.
3. Do not reopen `Verified fixed` items unless a source regression is found.

---

## Test Checklist

- Open existing demo reports.
- Render preview pages.
- Print a report.
- Export to PDF.
- Save and reload a report.
- Verify round-trip on the reloaded report.
- Test an empty dataset report.
- Test a larger dataset report.
- Test long text wrapping and can-grow behavior.
- Test image rendering.
- Confirm there are no obvious memory or GDI leaks.

---

## Output Format for the Next Review

Keep the next review short and operational:

1. Brief summary of what changed since the first review.
2. Table of items still open.
3. Table of items verified fixed.
4. Small implementation order list.
5. Test checklist tied to the remaining work.
