# bash-gitaware 3.1: build plan

- Source: [`SPEC.md`](SPEC.md)
- Branch: `v3.1` from `main` (b378023). All plan state lives in this
  directory. Rulings are appended to [`../v3/RULINGS.md`](../v3/RULINGS.md),
  starting at R-8.
- Conventions: as in [`../v3/PLAN.md`](../v3/PLAN.md). One commit per task,
  tests on the bash 4.4-5.3 container matrix as a non-root user, shellcheck
  clean. Each wave ends with a review (at most three lenses), a security
  review where marked, a rulings pass, and a local tag `v3.1-wN`.

## Wave 5: maintenance and shell defaults (M1, M3)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T5.1 | M3 | macOS CI with a real timeout helper | The `macos-tests` job runs as a matrix (`watchdog`, `coreutils` with `brew install coreutils`); `tests/perf.sh` reports the platform and the helper the library picked, and `BGA_EXPECT_TMO` fails a job on the wrong helper; budget per platform (60 ms, macOS 90 ms) and a 5-run median (ruling R-8, after macOS measured 36-72 ms with either helper); green 3 runs in a row on 8fee844 (macOS render 27-54 ms with timeout, 32-53 ms with the watchdog) | done |
| T5.2 | M3 | `tests/MANUAL.md` for 3.x | No v2 milestone sections or `/tmp/bga-$$.cache` paths; checks for Lean, ledger, transient, right block on a narrow terminal, themes, plain mode, `bga doctor`, state directory; each check names the command to run | done |
| T5.3 | M1 | `shell_defaults` key | Loader accepts `shell_defaults = 0 \| 1` and `BASHGITAWARE_SHELL_DEFAULTS`; 0: no aliases, `HISTCONTROL`/`HISTSIZE` untouched, no `dircolors`/`lesspipe` eval, no completion or `~/.bash_aliases` sourced; 1 or unset: current behavior (`tests/config.sh`, new `tests/shell.sh`) | done |
| T5.4 | M1 | Drop the `PATH` entry | `new.bashrc` never changes `PATH` with any setting (test compares `PATH` before and after sourcing) | done |
| T5.5 | M1 | Installer writes the key | Interactive installer asks (default 0 for append, 1 for replace); `--yes` writes the mode's default; re-running keeps an existing value; `--uninstall` unchanged (`tests/install.sh`, interactive path through `script`) | done |
| T5.6 | M1 | Doctor notice | `bga doctor` prints a notice (exit 0) when `shell_defaults` is unset, with the `bga config set` line to fix it; no notice once set (`tests/cli.sh`) | done |
| T5.7 | M1 | Startup budget check | Startup median with the module off is not higher than with it on; both under 100 ms on the matrix (`tests/perf.sh` measures both) | done |
| T5.8 | M1 | ADR-0010: shell defaults | `docs/adr/ADR-0010-shell-defaults-module.md`: what is in the module, why off, the migration rule, the 4.0 flip, the `PATH` removal | todo |
| T5.9 | M1 | Docs | README (EN/ES) "Shell defaults" section with the alias list; `docs/MIGRATION.md` 3.0 to 3.1 section; CHANGELOG `[Unreleased]`; parity check green | todo |

Exit gate: review (correctness, compatibility, docs). No SR: the module adds
no new input surface.

## Wave 6: policy file (M2)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T6.1 | M2 | ADR-0011: policy file (first) | Path, format, precedence, locking, trust rules, threat model (not a boundary against the account owner), test seam, rejected options (`XDG_CONFIG_DIRS`, sourcing a file, per-repo policy) | todo |
| T6.2 | M2 | Trust check | `__bga_policy_trusted` accepts a file whose owner and ancestor owners are uid 0 with no group/other write and no ACL grant; accepts a root-owned `/etc` symlink; refuses a symlink to a non-root file, a FIFO or device, a file owned by a user; never blocks on a FIFO (tests create root-owned fixtures before dropping to `bgauser`, as the CI containers already do) | todo |
| T6.3 | M2 | Loader layering | Policy parsed with the config parser before env and user config; locked keys recorded in `_bga_policy_locked`; env and user config values for locked keys ignored, with one warning for the user config; invalid policy lines warned by line number (`tests/config.sh`) | todo |
| T6.4 | M2 | CLI respects locks | `bga config set`/`unset` on a locked key exits 1 and names the policy file; `bga config list` marks locked keys; `bga theme set` goes through the same check (`tests/cli.sh`) | todo |
| T6.5 | M2 | Doctor | Shows the policy path, its state (absent, applied, refused and why) and the locked keys; a refused policy makes `doctor` exit 1 | todo |
| T6.6 | M2 | Test seam | The policy path can be changed only for the test suite, and only a uid-0-owned file is accepted there too; documented in ADR-0011; no user-facing variable can point the loader to a user-owned policy (test) | todo |
| T6.7 | M2 | Docs for admins | README (EN/ES) "For administrators" section with an example policy; CHANGELOG | todo |

Exit gate: review (security, correctness, compatibility) and **SR5** (policy
trust check, parser, lock bypass through env, `bga`, `bga reload` and
re-sourcing).

## Wave 7: prompt and CLI extras (S5 to S8)

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T7.1 | S5 | vi-mode indicator | With `set -o vi`, `bind -v` shows `show-mode-in-prompt on` and mode strings built from theme tokens inside `\1 \2`; user-set mode strings are not touched; `vi_mode = 0`, plain mode and emacs mode set nothing; pty run on bash 4.4/5.2/5.3: switching mode redraws the indicator, transient collapse still correct | todo |
| T7.2 | S6 | Ruby, Deno, Bun, Java | Detected from the files in SPEC S6; versions read with `__bga_read_line` and escaped once; no new process per prompt or per directory change (test counts forks with a `PATH` of stubs); hostile version files covered in `tests/security.sh` | todo |
| T7.3 | S6 | `runtimes` key | `runtimes = py,node` shows only those; unknown names warned by line number; `runtime = 0` still wins (`tests/config.sh`, `tests/lean.sh`) | todo |
| T7.4 | S7 | OSC 9;4 progress | With `progress = 1`: `PS0` carries `9;4;3`, the next prompt emits `9;4;0`, a failed command gives `9;4;2` then `9;4;0` on the next prompt; nothing with `osc = 0`, in plain mode, or with `TMUX`/`STY` set; the user's `PS0` is kept (`tests/hooks.sh`, `tests/plain.sh`) | todo |
| T7.5 | S8 | `bga config edit` | Edits a 0600 copy in the state dir; valid: atomic save, comments kept; invalid: warnings and a choice to edit again or discard; editor exits non-zero: original untouched; symlinked config refused; no tty: exit 2 (`tests/cli.sh` with a scripted editor) | todo |
| T7.6 | S5, S7 | ADR-0012: vi-mode and OSC 9;4 | Why readline mode strings instead of a segment, why progress is opt-in, terminals that ignore OSC 9;4 | todo |
| T7.7 | all | Docs | README (EN/ES) config table gains `vi_mode`, `runtimes`, `progress`; `bga config edit` in the CLI section; `docs/MIGRATION.md`; parity green | todo |

Exit gate: review (correctness, escaping, compatibility) and **SR6** (mode
strings and OSC output fed hostile theme values, version files, editor
temp-file handling).

## Wave 8: release 3.1.0

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T8.1 | all | Release check | Each criterion in SPEC section 5 checked and recorded here; budgets re-measured and the comment in `tests/budgets.sh` updated | todo |
| T8.2 | all | Release 3.1.0 | `_bga_version='3.1.0'`, CHANGELOG `[3.1.0]`, one release commit and tag `v3.1.0`; pushed only after the owner confirms | todo |

## Risks

- **Migration surprise (M1).** Users who update with `git pull` must keep
  their aliases. That is why an unset key means on until 4.0. T5.3 tests that
  case explicitly.
- **Policy trust on macOS (M2).** `/etc` is a symlink and `stat` flags differ.
  T6.2 must run on both macOS jobs, not only on Linux.
- **Root-owned fixtures (M2).** Tests need a uid-0 file. The containers start
  as root before `su bgauser`. On macOS CI, use `sudo` in a setup step. A
  developer running the suite locally gets a skip, not a failure (SPEC v3
  section 5, capability probes).
- **vi-mode width (S5).** readline counts mode strings as part of the prompt.
  Escapes outside `\1 \2` would break the cursor position. The pty run in
  T7.1 is the guard.
- **Scope.** Wave 7 has four independent items. If the release date slips,
  S7 and S8 are the first to move to 3.2. That needs a ruling.
