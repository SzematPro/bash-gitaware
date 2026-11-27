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
| T11.1 | X1 | kube | `current-context` from the first kubeconfig file, bounded read, cached by mtime (no reread when unchanged: test); never runs kubectl (stub test) | todo |
| T11.2 | X1 | aws, tf | `AWS_PROFILE`/`AWS_VAULT`; `.terraform/environment` through the version-file rules (symlink, NUL, pattern) | todo |
| T11.3 | X1 | Layout | Right block after the runtimes, dropped first; tokens in every theme; `contexts` key validated | todo |
| T11.4 | X1 | ADR-0014 and docs | README (EN/ES), MIGRATION, CHANGELOG | todo |

Exit gate: review and **SR7** (kubeconfig and `.terraform` parsing, cache).

## Wave 12: release 3.2.0

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T12.1 | all | Release check | SPEC section 3, each criterion recorded here | todo |
| T12.2 | all | Release 3.2.0 | Version, CHANGELOG, squash to main, tag, GitHub release, after the owner confirms | todo |
