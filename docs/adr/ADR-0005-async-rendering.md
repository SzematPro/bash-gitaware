# ADR-0005: Async / non-blocking rendering

- Status: Accepted
- Date: 2026-05-13

## Context

A rich prompt does work each cycle. On a small repo with warm caches the work
is invisible; on a large repo or with cold caches it is not:

- `git status --porcelain=v2` traverses the work tree. On a monorepo with
  100k+ tracked files it routinely takes 100–500 ms.
- Runtime version commands (`node --version`, `python --version`) cost
  30–80 ms each on a cold cache, or substantially more when wrapped by a
  version manager (nvm shim, pyenv, asdf) that re-evaluates init scripts on
  every invocation.

If the prompt waits for these synchronously, every `cd` and every command
feels laggy. The Powerlevel10k "instant prompt" idea (render with cached
cheap info immediately, fill in slow parts asynchronously) is the cure.

Doing this in bash fights readline. Readline owns the cursor while the user
is typing; there is no public API to redraw the prompt mid-edit without
disturbing what the user has typed so far. Anything that touches the cursor
during user input races readline's own redraw and corrupts the line.

## Decision

Split prompt work into **cheap** (always synchronous) and **expensive**
(async), and accept "deferred refresh on the next prompt" as the honest
deliverable:

**Cheap (sync, always):**

- `git rev-parse --git-dir --show-toplevel` (a few ms; tells us if we are in
  a repo at all and the repo name).
- Filesystem-only state checks: `.git/MERGE_HEAD`, `.git/CHERRY_PICK_HEAD`,
  `.git/REBASE_HEAD`, `.git/rebase-merge/`, `.git/rebase-apply/`,
  `.git/BISECT_LOG`. No git subprocess for these.
- Cached runtime version (per `(PWD, VIRTUAL_ENV, CONDA_DEFAULT_ENV)`). The
  first prompt in a directory may have a cold cache; subsequent prompts hit
  it.

**Expensive (async, when needed):**

- Full `git status --porcelain=v2 --branch`: produces the dirty bit, ahead /
  behind counts, stash count signal.
- Cold-cache runtime version commands when no version file is present.

**Lifecycle (as implemented):**

1. Each prompt cycle renders immediately with the cheap info plus a subtle
   placeholder (a faint ellipsis `…`, or `...` on the ascii tier) where the
   expensive info will be.
2. A background subshell (`( … ) &`) computes the expensive info and
   atomically writes it to a per-shell cache file
   (`${XDG_RUNTIME_DIR:-/tmp}/bga-${$}.cache`) via a sibling tmpfile + rename.
3. On the next prompt cycle, the cache file is parsed defensively (no
   `source` of file content; only four well-known keys are accepted) and the
   prompt re-renders with full info. If the user types and submits a command
   before the background job finishes, the missed result is overwritten on
   the next dispatch and the prompt for the next command picks up whichever
   cache landed first.
4. A still-running previous job is sent `SIGTERM` before a new one is
   dispatched (at most one in flight per shell).
5. The `EXIT` trap kills any survivor job and removes the cache file.

**What was *not* shipped, and why:**

- **No `SIGUSR1`-based "completion ping"**. The earlier sketch in this ADR
  mentioned best-effort signalling to wake the foreground shell. In
  practice, signal handlers that run while readline holds the cursor can
  fire mid-keystroke; trying to re-render from inside one races readline's
  own redraw and corrupts whatever the user is typing. The deferred-on-
  next-prompt path is the honest deliverable: the slow work is never on the
  critical path of *showing* the prompt, and the user sees the full info
  the next time they hit Enter -- which is the same UX result without the
  fragility.
- **No async path for runtime version commands.** The existing per-
  `(PWD, VIRTUAL_ENV, CONDA_DEFAULT_ENV)` cache in `lib/50-runtime.bash`
  already amortises the cold-cache cost across a directory's lifetime:
  the first prompt after a `cd` pays the ~30-80 ms version command once,
  every subsequent prompt in the same directory hits the cache and pays
  nothing. The expensive case async would help with -- the very first
  prompt after `cd` -- is small enough that the added complexity of
  async-ifying runtime is not worth it. Documented here so a future
  contributor does not reopen the question.

Disable with `BASHGITAWARE_ASYNC=0` → fully synchronous, no background job,
no temp file, no `EXIT` trap. Useful in scripts, CI shells, or for anyone
who prefers predictable timing over snappiness.

## Alternatives considered

- **True in-place refresh** via `bind -x`, save cursor, redraw the prompt
  while the user is typing, restore cursor. Considered and rejected: races
  with readline's own redraw, breaks completion menus mid-input, corrupts
  the line on terminal resize. The complexity-vs-payoff is bad.
- **`SIGUSR1`-based "wake the shell when finished".** Considered and
  rejected for the same reason as above: signal handlers can fire while
  readline owns the cursor, and any re-render from inside one corrupts the
  current line. Deferred refresh on the next prompt cycle delivers the
  same end-state without that fragility.
- **Long-lived coprocess** (`coproc`) instead of a single-shot subshell per
  prompt. Lower per-prompt overhead, but adds a stateful component to clean
  up on shell exit, to detect when the worker crashes, and to keep in sync
  across `cd`. Single-shot fork-and-write is simpler and the fork cost
  (~5 ms in modern bash) is negligible against the 100–500 ms work it
  enables. Single-shot wins on simplicity.
- **Drop async entirely; rely on cheap-only info.** Means dirty / ahead /
  behind counters never appear on large repos, defeating the prompt's main
  job. Rejected.
- **Async runtime version commands.** The existing per-directory cache in
  `lib/50-runtime.bash` already amortises cold-cache version commands; the
  one prompt that pays the cost is the first prompt after a `cd`, and the
  per-prompt cost cap there (~80 ms) is acceptable. Async-ifying runtime
  would double the moving parts for marginal payoff. Rejected.

## Consequences

- Perceived prompt latency is independent of repo size.
- **Honest limitation, surfaced in the README**: the refresh happens **on
  the next prompt**, not in place on the line the user is currently editing.
  In practice this means: the first prompt after a `cd` into a slow repo
  shows a placeholder for ~100 ms (the cheap info); the prompt for the next
  command shows full info. The slow work is never on the critical path of
  *showing* the prompt.
- The async machinery is the most complex module; tests cover (a) the
  cheap-only render path, (b) the cache is read on the next cycle, (c) no
  orphan background jobs survive `exit`.
- One extra knob (`BASHGITAWARE_ASYNC=0`) for the fully-synchronous path.
- Background-job lifecycle: at most one in flight per shell at a time; a new
  prompt sends `SIGTERM` to a still-running previous job before starting a
  new one. Temp files are cleaned in the `EXIT` trap.
