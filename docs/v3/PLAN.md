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
| T0.5 | R8 | Plain/agent mode detection | `TERM=dumb`, no tty, `CI`, `AGENT`, `AI_AGENT` or `BASHGITAWARE_MODE=plain` produce `<path> (<branch>[ *])[ [exit N]] $ `: one ASCII line, no escape sequences, untrusted text escaped; `BASHGITAWARE_MODE=full` overrides (`tests/plain.sh`, plus a pty run); user docs pending in T4.3 | done |
| T0.6 | R9 | Hook coexistence | Existing `PROMPT_COMMAND` (string or array), `PS0`, DEBUG and EXIT traps keep working and the exit status reaches the user's hooks; bash-preexec gets the timer through `preexec_functions`; sourcing twice is idempotent; `PROMPT_COMMAND`, `PS0` and `PS1` are unexported (`tests/hooks.sh`, plus a pty run: `took 3s`, user DEBUG trap chained) | done |
| T0.7 | R10 | Config loader | `${BASHGITAWARE_CONFIG:-${XDG_CONFIG_HOME:-~/.config}/bash-gitaware/config}` is parsed as `key = value` lines and never sourced; per-key validation; unknown keys, bad values and malformed lines are reported with line numbers; environment > file > preset; a file that others own or can write is refused (`tests/config.sh`) | done |

Exit gate: SR1 (state directory, config parsing, escaping).

## Wave 1: render engine and look

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T1.1 | R1 | Display-width engine | `lib/17-width.bash` (table from `bin/gen-width.py`, Unicode 15, 469 ranges): 18 known cases (ASCII, accents, combining, CJK, fullwidth, emoji, ZWJ, VS16, controls, invalid, truncated, overlong, surrogate, > U+10FFFF) pass on glibc and musl; linear (10 KB vs 20 KB about 2x) on bash 4.4 to 5.3 (`tests/width.sh`) | done |
| T1.2 | R1 | Segment model | Lean pieces are added with `__bga_lean_add <token> <raw text>`: escaped once by `__bga_ps1_lit`, colored by a token, raw text kept for `__bga_width`; runtimes come from `_bga_rt_items` (raw labels) (`lib/62-lean.bash`) | done |
| T1.3 | R1 | Right-aligned context | Right block (runtimes, optional clock) drawn inside `\[ \]` with `ESC 7`, `ESC [ col G`, `ESC 8`, at `COLUMNS - width + 1`; dropped from the end (clock, then runtimes) when it does not fit; the left side falls back to the last path component; `COLUMNS` read per prompt (`tests/lean.sh`, pty check) | done |
| T1.4 | R4 | Semantic color tokens and the `Aware` theme | `lib/19-theme.bash`: themes are token tables (hex, xterm-256, 16-color, bold) resolved for 24-bit (`COLORTERM`), 256, 16 or no color; Aware palette; `BASHGITAWARE_THEME` / `theme =`; no literal SGR escapes outside the theme module; the transient line now honors `NO_COLOR` (`tests/theme.sh`) | done |
| T1.5 | R2 | Lean layout and command ledger | Default style (`BASHGITAWARE_STYLE=classic` keeps v2): line 1 path + git left, context right; line 2 symbol; result line `  ✘N · 3s` before the next prompt only for failed or slow commands (`tests/lean.sh`; pty runs on bash 4.4-5.3) | done |
| T1.6 | R3 | Transient prompt adapted to the ledger | Collapse now moves up, clears and swaps PS1; readline redraws `❯ <command>` itself. Before, the line was printed twice on every bash 4.4-5.3 (also in v2). The DEBUG trap ignores PROMPT_COMMAND entries and the bind -x function, so an empty Enter adds no result line (pty runs on bash 4.4-5.3); `tests/MANUAL.md` updated | done |
| T1.7 | R1 | ADR-0007: render engine and layout | `docs/adr/ADR-0007-v3-render-engine-and-lean-layout.md`: Lean mock-up, segments, width engine, right block drawn with cursor moves inside `\[ \]` so width errors fail soft, narrow-terminal drop order; layout open to owner feedback | done |

Exit gate: SR2 (escape sequences, width engine fed hostile input).

## Wave 2: git within budget

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T2.1 | R5 | Fast path | One git call per prompt (`rev-parse`); the trust check's `git config` reruns only when a config file is newer than a marker in the state dir; OSC and path helpers return through REPLY instead of subshells. 100k-file repo: 18 ms to 13 ms per prompt with async (sync status alone is ~77 ms, which is why it runs in the worker) | done |
| T2.2 | R5 | Background worker | Existing async job (lib/85-async.bash) meets it: 10 s timeout per git call, results in the private state dir, `disown` (no job messages in pty runs), results keyed by directory and git dir; a test shows another repo's result is discarded | done |
| T2.3 | R5 | Timeout helper | `__bga_gitrun` (v2.0.4): `timeout -s KILL`, gtimeout, or a watchdog on stock macOS; tested with FIFOs that hang git, on Linux and macOS CI; the first timeout skips the rest of the prompt. git children are not a concern: hooks, fsmonitor and lazy fetch are off | done |
| T2.4 | S3 | Pending indicator (spike first) | Spike in a pty (bash 4.4/5.2/5.3): a USR1 trap plus SIGWINCH does not redraw the prompt while readline waits, and writing from the background corrupts input. Accepted outcome per this plan: static pending glyph refreshed on the next prompt (ADR-0008) | ruled |
| T2.5 | R5 | ADR-0008: worker and state directory | `docs/adr/ADR-0008-v3-git-worker-trust-and-state.md` (worker, trust model, content-validated cache, time limits, state dir, rejected alternatives) | done |

Exit gate: SR3 (worker, state files, race conditions).

## Wave 3: `bga` CLI and installer

| ID | Req | Task | Acceptance criteria | Status |
|---|---|---|---|---|
| T3.1 | R6 | `bga` dispatcher | `lib/94-cli.bash` defines `bga` in interactive shells; `bin/bga` runs it as a script (`_BGA_CLI=1` loads settings without hooks); `help`, `version`; unknown commands exit 2 with usage (`tests/cli.sh`) | done |
| T3.2 | R6 | `bga config` | `path`, `list`, `get`, `set`, `unset`; values validated with the loader's rules; atomic write (temp file plus `mv`, 0600), comments and order kept; a symlinked config is not replaced | done |
| T3.3 | R6 | `bga theme` | `list`, `preview` (sample Lean prompt printed with the theme's raw tokens, PS1 untouched), `set` (stored through `bga config`) | done |
| T3.4 | R6 | `bga doctor` | Reports bash, git, locale, glyph tier, color depth, style and theme, plain mode, timeout helper, state dir, config file (with loader warnings); exits 1 on a problem (old bash/git, invalid config) | done |
| T3.5 | R7 | Interactive installer | On a terminal with no mode flag, `install.sh` asks for the mode (append or replace), theme and glyphs (stored with `bin/bga config set`); `--yes` asks nothing; backup before replace; idempotent append (`tests/install.sh`, interactive path driven through `script`) | done |
| T3.6 | R7 | Uninstaller and tamper check | `--uninstall` removes the appended block or restores the newest backup, and is a no-op the second time; the installer refuses a `new.bashrc` or directory that others can write or that someone else owns, and accepts one writable by the user's primary group (L-37) | done |
| T3.7 | R6 | ADR-0009: CLI surface | `docs/adr/ADR-0009-v3-cli-surface.md` | done |

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
