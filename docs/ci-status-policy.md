# CI status policy

This page is the single source of truth for what the GitHub Actions checks on
this repository mean, how Delphi validation is recorded without a CI runner,
and what must happen before a self-hosted runner may be registered again.

Two independent validation axes exist:

1. **Automated hosted checks** — licensing-independent repository hygiene,
   consistency and documentation checks that run automatically on GitHub-hosted
   runners.
2. **Manual Delphi gate** — the full build/test/regression gate that requires
   RAD Studio and is therefore run only by dispatch or locally on a licensed
   machine. Its results are **evidence**, not GitHub CI status.

## Automated hosted checks

`.github/workflows/repo-hygiene.yml` runs three jobs on GitHub-hosted
`ubuntu-latest` runners. They need no Delphi, no secrets and no Windows
dependencies:

| Check | What it verifies |
|---|---|
| `Hygiene (conflict markers, BOM policy, secrets, scratch paths)` | merge-conflict markers, the Pascal UTF-8 BOM policy, secret-regression scan, scratch-path regression |
| `Consistency (dpr registrations, baselines JSON, YAML config)` | test-project unit registrations resolve to files, `reports/regression_baselines.json` parses, workflow and `mkdocs.yml` YAML parses |
| `Documentation (mkdocs build)` | the MkDocs documentation site builds |

**Merge dependency:** the hosted workflow lands on `main` through **PR #10**.
Until PR #10 merges, no automatic checks exist on `main` and PRs will not show
the three checks above.

**These checks are not required by branch protection.** As of 2026-11-13 the
`main` branch protection has no required status checks (the `gate` requirement
was removed by owner decision on 2026-10-25, see
[the release status record](Release-Status-Record-2026-10-25.md)). Whether the
three hosted checks are configured as required checks is a separate owner
decision; if it is taken, this page must be updated.

## Manual Delphi gate (Build and Test)

`.github/workflows/build-and-test.yml` is **dispatch-only** since 2026-11
(push/pull_request triggers were removed). There is no registered self-hosted
runner on the repository and Delphi unattended/build-server licensing is
unresolved, so automatic Delphi CI is impossible and must not be faked. See the
trigger-policy comment in the workflow file itself.

Dispatch it from the CLI or the Actions tab:

```powershell
gh workflow run "Build and Test" --ref <branch>
```

The workflow runs `tools\ci_gate.ps1 -IncludePackages` on a
`[self-hosted, windows, delphi]` runner — exactly the same gate as the local
command below:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\ci_gate.ps1 -IncludePackages
```

### What a dispatch run is — and is not

- A dispatch run is a separate `workflow_dispatch` event. It is **not** a pull
  request status check: GitHub will not show it in the PR merge box, and its
  result never gates merging.
- **Verify the run's commit SHA.** A validation result applies only to the
  exact SHA that was tested. Check the run's `head_sha` in the run URL/UI and
  record it. Any later commit invalidates the previous exact-head validation.
- Record the run URL and the exact SHA in the pull request description or the
  dated release-status record, so the evidence is auditable.

### Delphi validation record

Every Delphi validation (dispatched or local) should be recorded with at least
these fields — either in the PR description or in a dated release-status
record document:

- Repository and branch.
- Exact commit SHA (the validated tree).
- Workflow run URL, if dispatched.
- Delphi/RAD Studio version (e.g. RAD Studio 23.0 / Delphi 12.x).
- Command executed (e.g. `tools\ci_gate.ps1 -IncludePackages`).
- DUnitX found/passed/failed/errored counts.
- Leak count (`Tests Leaked : 0`).
- `VittixRunner --strict` results (reports discovered, matched, mismatched,
  skipped, exit code).
- USER and GDI handle deltas (limits: USER 0, GDI 16 by default).
- Runtime package / design package build results.
- Designer and demo build results.
- Firebird integration results (see the caveat below).
- Gate exit code.
- Log/artifact locations (`build\gate\`, `tests\dunitx-results.xml`,
  `build\phase5-benchmark-timings.txt`).
- Operator and validation date.

### Firebird integration caveat (unresolved prerequisite)

The Firebird integration tests in the DUnitX suite are opt-in through
environment variables (`VITTIX_FB_DATABASE` pointing at a new disposable
database, `VITTIX_FB_DISPOSABLE=YES`, optional `VITTIX_FB_CLIENT`/user/password,
`VITTIX_FB_KEEP=1` to retain the database). The current CI gate invocation
(`tools\ci_gate.ps1 -IncludePackages`) does **not** set these variables, so a
dispatched run does not exercise Firebird integration. Whether the
runner/service-account environment will provide them — or whether the gate
should configure them — is an unresolved prerequisite for future runner
qualification. **Never record Firebird integration as passing unless the
fixture demonstrably executed** (it prints its own diagnostic output; the
release records show `12/12` only where it ran with environment configured).

## Change-class policy

| Change class | Validation expectation |
|---|---|
| Routine pull request | Hosted checks green; manual Delphi evidence (dispatch run and/or exact-head local gate record) per owner policy |
| Pagination/engine-sensitive pull request | Full exact-head Delphi gate record (DUnitX + strict runner + packages) plus owner review of pagination baselines |
| Release candidate | Full gate, owner GUI acceptance, dated release-status record (the established PR #3 / v1.0.1 pattern) |
| Main merge | Hosted checks; optional post-merge Delphi validation dispatched on the exact `main` SHA |

**Enforcement reality:** GitHub does not automatically enforce the manual
Delphi evidence. There is no required status check for the Delphi gate, so the
enforcement mechanisms are the branch-protection settings that remain in place
(required conversation resolution, admin enforcement) plus owner review
discipline and this documented policy. This changes only when a licensed
runner exists and `gate` is restored as a required check.

## Future runner restoration — prerequisites

Do not register, install or activate any runner until **all** of the following
are satisfied:

- **Written Embarcadero licensing confirmation** covering unattended/build-server
  execution of RAD Studio / Delphi on the intended machine or VM. A present
  `.slip` file proves activation only — it is not proof of unattended/build-server
  rights.
- **External contributor approval restrictions** tightened (workflow runs from
  external contributors require approval) before any code from PRs can execute
  on the runner.
- **Dedicated least-privilege service account** for the runner (pattern:
  `RL\VittixCI`), with its password rotated immediately before registration.
- **Repository-scoped runner** — registration tokens generated per
  installation, never stored as repository secrets; runner runs only in a
  dedicated workspace directory.
- **Workflow security review** of everything the runner executes: action
  references (SHA-pinned), scripts, and the commands a PR-head checkout can
  influence.
- **Disposable workspace and Firebird database** — per-job workspace cleanup of
  build outputs, and the Firebird fixture's disposable-database contract
  (environment variables set, `VITTIX_FB_KEEP` unset).
- **Cleanup and decommission procedure** documented: how to remove the runner,
  revoke the registration, and retire the service account.

After a runner is qualified, the documented sequence is: restore automatic
push/pull_request triggers (or keep dispatch plus a runner-availability probe),
re-register the runner with labels `self-hosted`, `windows`, `delphi`, and
restore `gate` as a required status check. Update this page as part of that
work.

## Related documentation

- [VittixRunner CLI](runner-cli.md) — the regression runner the gate executes.
- [Testing](testing.md) — the automated gate and manual checklists.
- [Release status record 2026-10-25](Release-Status-Record-2026-10-25.md) —
  the owner-authorized removal of the required `gate` check and the
  licensing-prerequisite statement.
- [Phase 5 - quality, benchmarking and CI](archive/Phase5-Quality-Benchmark-CI.md)
  — the gate contract (archived, historical).
