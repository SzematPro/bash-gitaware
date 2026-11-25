# bash-gitaware v3: build plan

- Source: [`SPEC.md`](SPEC.md) (scope accepted 2026-11-25)
- Branch: `v3`. All plan state, reports and rulings live in this directory.
- Base: v2.0.1. v3 evolves the v2 module layout (`lib/NN-*.bash` built into
  `new.bashrc`) instead of starting over, so the v2 tests keep guarding
  behavior until a wave replaces them on purpose.

## Conventions

- Each task has an ID (`Tw.n`), the requirement it serves, and acceptance
  criteria (AC) that a test checks. A task is done when its tests pass on the
  whole bash matrix (4.4, 5.0, 5.1, 5.2, 5.3 in `bash:*` containers, running
  as a non-root user) and shellcheck is clean.
- One commit per task, Conventional Commits. Each wave ends with a review
  (at most three lenses), a security review (SR*n*), a rulings pass recorded in
  [`RULINGS.md`](RULINGS.md), and a local tag `v3-wN`. Nothing is pushed until
  the release, except when the owner asks.
- Status values: `todo`, `doing`, `done`, `ruled` (changed by a ruling).

## Wave 0: spine

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T0.1 | R12 | Startup and per-prompt budget harness | `tests/perf.sh` reports the startup and render medians, timed with bash's `time` keyword (the old `date +%s%N` measured 0 under BusyBox); CI fails over budget; budgets live in `tests/budgets.sh` (startup 100 ms, render 40 ms); hosted macOS timing is still unverified | done |
| T0.2 | all | Test sandbox hardening | Each test runs with inherited `_bga_*`/`_BGA_*`/`BASHGITAWARE_*`/`NO_COLOR` cleared (a polluted environment caused 15 failures before the fix, 0 after); the helper that turns a missing tool into a skip is added with its first consumer | done |
| T0.3 | R10 | State-directory primitive | `__bga_state_dir` returns a directory that the user owns with mode 0700, under `XDG_RUNTIME_DIR` or a `mktemp -d` fallback; it refuses a directory owned by someone else or writable by group or others; tests cover a planted symlink and a planted directory | done |
| T0.4 | R10 | Shell-state independence | The prompt renders identically with `extglob`, `nullglob`, `failglob`, `nocaseglob`, `nocasematch`, `globstar`, `dotglob`, `expand_aliases`, `patsub_replacement`, `xpg_echo`, `set -f`, `set -u`, `set -o posix`, `IFS=:` (`tests/shellstate.sh`); `promptvars` off is covered in `tests/security.sh` | done |
| T0.5 | R8 | Plain/agent mode detection | `TERM=dumb`, no tty, `CI`, `AGENT`, `AI_AGENT` or `BASHGITAWARE_MODE=plain` produce a one-line ASCII prompt with no escape sequences; `BASHGITAWARE_MODE=full` overrides the detection | todo |
| T0.6 | R9 | Hook coexistence | Existing `PROMPT_COMMAND` (string or array), `PS0`, DEBUG and EXIT traps keep working; sourcing twice is idempotent; `PROMPT_COMMAND`, `PS0` and `PS1` are not exported | todo |
| T0.7 | R10 | Config loader | `~/.config/bash-gitaware/config` is parsed as `key=value` lines and never sourced; unknown keys produce a warning; values are validated per key | todo |

Exit gate: SR1 (state directory, config parsing, escaping).

## Wave 1: render engine and look

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T1.1 | R1 | Display-width engine | Correct cell widths for ASCII, CJK, combining marks, emoji and invalid UTF-8 (one cell per byte) on glibc and musl; linear time on 10 KB inputs; follows the SPEC section 5 idioms | todo |
| T1.2 | R1 | Segment model | Segments (`path`, `git`, `runtime`, `duration`, `exit`, ...) produce text plus a width; untrusted text is escaped only once, when the segment is built | todo |
| T1.3 | R1 | Right-aligned context | The right block is aligned to `COLUMNS`; it drops or truncates segments when the terminal is narrow, in a stated priority order; a resize is handled on the next prompt | todo |
| T1.4 | R4 | Semantic color tokens and the `Aware` theme | Every color comes from a token; `NO_COLOR` and 16-, 256- and true-color terminals each have a fallback; the theme is one file | todo |
| T1.5 | R2 | Lean layout and command ledger | The default layout matches the mock-up in ADR-0007; previous commands collapse into ledger lines (symbol, command, duration, exit code) | todo |
| T1.6 | R3 | Transient prompt adapted to the ledger | Pressing Enter collapses the prompt to a ledger line; multi-line input and Ctrl-C behave as documented in `tests/MANUAL.md` | todo |
| T1.7 | R1 | ADR-0007: render engine and layout | ADR written and accepted | todo |

Exit gate: SR2 (escape sequences, width engine fed hostile input).

## Wave 2: git within budget

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T2.1 | R5 | Fast path | The cheap git info (branch, hash, state) comes from at most two forks, measured under 20 ms on a repo with 100k files | todo |
| T2.2 | R5 | Background worker | Dirty state and ahead/behind are computed in a worker with a timeout; results go to the state directory from T0.3; no "Done" messages leak to the terminal; stale results are discarded | todo |
| T2.3 | R5 | Timeout helper | Works on bash 4.4 without `timeout(1)`; kills the whole process group; tested with a hung git | todo |
| T2.4 | S3 | Pending indicator (spike first) | A spike decides between redrawing in the background and a static glyph that changes on the next prompt; the result is written down as ADR-0008 before anything is built | todo |
| T2.5 | R5 | ADR-0008: worker and state directory | ADR written and accepted | todo |

Exit gate: SR3 (worker, state files, race conditions).

## Wave 3: `bga` CLI and installer

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T3.1 | R6 | `bga` dispatcher | `bga help`, `bga version`; unknown subcommands exit 2 with usage; works as a shell function and as a script | todo |
| T3.2 | R6 | `bga config` | get, set, unset and list on the config file from T0.7; writes are atomic | todo |
| T3.3 | R6 | `bga theme` | list, preview and set; the preview renders a sample prompt without touching `PS1` | todo |
| T3.4 | R6 | `bga doctor` | Reports the bash version, locale, glyph tier, color depth, terminal OSC support, timings and the state directory; exits non-zero when it finds a problem | todo |
| T3.5 | R7 | Interactive installer | Asks for the mode (replace or append), theme and glyph tier; `--yes` runs without questions; backs up `~/.bashrc`; idempotent | todo |
| T3.6 | R7 | Uninstaller and tamper check | Restores the backup or removes the source line; refuses library files writable by others (files writable by the user's primary group are accepted, ruling L-37) | todo |
| T3.7 | R6 | ADR-0009: CLI surface | ADR written and accepted | todo |

Exit gate: SR4 (installer, file permissions, CLI input).

## Wave 4: themes, docs, release

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T4.1 | S1 | Light and high-contrast themes | Two theme files; their contrast ratios are checked by a script | todo |
| T4.2 | S2 | Powerline variant | Enabled when the glyph tier is `nerd`; without a Nerd Font it falls back cleanly | todo |
| T4.3 | R11 | Bilingual docs | README, configuration guide and FAQ in English and Spanish; a CI check fails when the two diverge in sections or code blocks | todo |
| T4.4 | R11 | Docs lint in CI | markdownlint-cli2 0.24.0 (with MD060 off) and lychee 0.24.2 (`anchor-only` fragments) run in CI | todo |
| T4.5 | S4 | New demo | A vhs tape shows the ledger, the transient prompt and the themes; the GIF is under 400 KB | todo |
| T4.6 | all | Migration guide from v2 | Every v2 `BASHGITAWARE_*` knob is mapped to v3 or listed as removed | todo |
| T4.7 | all | Release 3.0.0 | One release commit, a tag, CHANGELOG; pushed only after the owner confirms | todo |

## Risks

- **Startup budget (R12).** Wave 1 of the lost attempt was already at risk
  from oversized modules and heavy comments (ruling L-46). Measure from T0.1
  on and keep long explanations in ADRs instead of inline comments.
- **Animated indicator (S3).** Writing to the terminal from the background
  while readline owns the line can corrupt the input. The T2.4 spike decides
  whether to build it; downgrading it to a static glyph is an accepted outcome.
- **Width engine (T1.1).** This was the hardest part last time (see SPEC
  section 5). Budget extra review time for it.
