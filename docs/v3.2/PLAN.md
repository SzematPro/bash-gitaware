# bash-gitaware 3.2: build plan

- Source: [`SPEC.md`](SPEC.md)
- Branch: `v3.2`. Rulings go in [`../v3/RULINGS.md`](../v3/RULINGS.md)
  (R-9 onward). The conventions are those of [`../v3/PLAN.md`](../v3/PLAN.md).
  Each wave ends with a review, an SR where marked, and a local tag
  `v3.2-wN`.

## Wave 9: CLI (C1, C2)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T9.1 | C1, C2 | Key table | `_bga_config_keys` lists every key with its value pattern; `__bga_config_valid` uses it; `tests/config.sh` unchanged and green | done |
| T9.2 | C1 | `__bga_complete` | Each position in SPEC C1 completes, checked through `compgen`-style calls in `tests/complete.sh` and in a pty run; a user-defined `complete -p bga` is kept | done |
| T9.3 | C2 | `config list --all` | Sources `policy`, `environment`, `config:N` and `default` are each named correctly (policy one uses the root fixtures); values made terminal-safe | done |
| T9.4 | C1, C2 | Docs | README (EN/ES) CLI section, `bga help`, CHANGELOG | done |

## Wave 10: detailed git status (G1)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T10.1 | G1 | Parser | Counts staged/unstaged/untracked/conflicts from porcelain v2 (`1`, `2`, `u`, `?` lines), at most 2000 entries, `N+` when capped; upstream gone when `branch.upstream` is present but `branch.ab` is missing | done |
| T10.2 | G1 | Worker and cache | New cache fields, numeric-only on read; an old-format cache is discarded (test) | done |
| T10.3 | G1 | Render | `git_status = detail` segments with tokens in every theme (contrast checked); `compact` output byte-identical to 3.1 (test); upstream gone in both | done |
| T10.4 | G1 | Budget | 100k-file repository with many changes: render under budget with async on; startup unchanged. Measured: about 7 ms per render in both modes; the detail worker went from 17.6 s (quadratic string cutting, past its 10 s limit) to 0.18 s after a linear rewrite; regression test added | done |
| T10.5 | G1 | ADR-0013 and docs | Why opt-in, the 2000 cap, symbols | done |

## Wave 11: context segments (X1)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T11.1 | X1 | kube | `current-context` from the first kubeconfig file, bounded read, cached by mtime (no reread when unchanged: test); never runs kubectl (stub test) | done |
| T11.2 | X1 | aws, tf | `AWS_PROFILE`/`AWS_VAULT`; `.terraform/environment` through the version-file rules (symlink, NUL, pattern) | done |
| T11.3 | X1 | Layout | Right block after the runtimes, dropped first; tokens in every theme; `contexts` key validated | done |
| T11.4 | X1 | ADR-0014 and docs | README (EN/ES), MIGRATION, CHANGELOG | done |

Exit gate: review and **SR7** (kubeconfig and `.terraform` parsing, cache). Done: SR7 record in reviews/SR7.md.

## Wave 12: release 3.2.0

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T12.1 | all | Release check | SPEC section 3, each criterion recorded here | done |
| T12.2 | all | Release 3.2.0 | Version, CHANGELOG, squash to main, tag, GitHub release, after the owner confirms | done |

## Release check (T12.1, 2026-11-27)

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Completion works in a pty on bash 4.4 to 5.3 | Pass | `tests/complete.sh` pty scenario on every container job, Ubuntu and both macOS jobs (BSD `script` through `pty_run`) |
| 2 | `config list --all` names each of the four sources | Pass | `tests/cli.sh` (config line, environment, default, refused file) and `tests/policy.sh` (policy, root fixtures in CI) |
| 3 | 100k-file repository: render budget holds with `git_status = detail` and async on | Pass | About 7 ms per render; the detail worker takes 0.18 s (W10 review: 129 ms) |
| 4 | Hostile `.terraform/environment` handled like a version file | Pass | SR7, F5 fixed; `tests/context.sh` |
| 5 | CI green on every job; no budget raised | Pass | 17e702c green; budgets unchanged (Linux render 8-13 ms, macOS 53-56 ms against 90 ms) |

