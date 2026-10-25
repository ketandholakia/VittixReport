# Release Status Record — PR #3 Merge (2026-10-25)

> PR #3 merged after owner-authorized removal of the unavailable self-hosted
> `gate` requirement. Release approval is based on the exact-head local
> authoritative gate and owner GUI acceptance. GitHub self-hosted CI was not
> used for this merge.

> The change from required CI to manual/local validation was an explicit owner
> policy decision, not a bypass of a failing product test.

## Merge facts

- PR #3 head (validated release candidate): `64e87299b3617a7831b5f02f3ac1207bf47f6e3b`
- Base at merge: `main` = `3de4da24245667f2efa27c57bd0fe38b18e55485`
- Merge strategy: **merge commit** (no squash, no rebase)
- Merge commit: `5ebbaa95047a4522ab1eb3feeab18d2925931ed7`
- Parents: `3de4da2` (previous main) + `64e8729` (PR head)
- New `main`: `5ebbaa95047a4522ab1eb3feeab18d2925931ed7`
- Merged at: `2026-10-25T09:05:09Z` (UTC)
- Merge tree: `96ed92745b7c959fc5406fcec83855d9b13af2d2` — **identical** to the
  validated PR head tree; zero unexpected merge content.

## Branch protection change (owner-authorized)

- Before: `required_status_checks: [gate]` (strict up-to-date enabled).
- After: `required_status_checks: null`.
- Unchanged and preserved: admin enforcement (enabled), required conversation
  resolution (enabled), force pushes (disabled), branch deletion (disabled),
  required signatures (off), linear history (off), restrictions (none),
  lock branch (off), block creations (off), fork syncing (off).
- Queued GitHub Actions run `40072137546` was cancelled **by GitHub
  automatically** after the merge; it was not deleted manually.

## Validation basis (release authorization)

- Exact PR #3 head `64e8729` under dedicated least-privilege `RL\VittixCI`:
  - DUnitX: 865/865 (0 failed, 0 errored, 0 skipped, 0 leaked)
  - Firebird integration: 12/12 (fixture executed, embedded 32-bit client,
    disposable CI DB created then deleted)
  - Strict runner: 41 passed / 0 failed / 1 intentional skip
  - Runtime/design packages, designer, demo: PASS
  - USER handle delta: 0; GDI handle delta: +8 (limit 16); exit code 0
- Owner GUI acceptance: PASS (PR tree unchanged from the accepted candidate).

## Remaining known risks

- Historical Firebird TIMESTAMP/BOOLEAN Prepare AV root cause remains unknown.
- Recovery/restore acceptance not performed.
- Separate-database isolation acceptance not performed.
- Cross-machine Firebird validation not performed.

## Outstanding prerequisite for future self-hosted CI

Delphi unattended/build-server licensing is **UNRESOLVED**. Do not register the
GitHub runner until written licensing confirmation is obtained. Post-licensing
sequence: tighten external-PR approval → rotate `VittixCI` password → register
runner (`self-hosted`, `windows`, `delphi`) → restore `gate` as a required
check.
