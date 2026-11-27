# ADR-0013: Detailed git status, opt-in

- Status: Accepted
- Date: 2026-11-27

## Context

The prompt shows a single dirty mark (`●`) when anything changed. Users
asked for the usual breakdown: what is staged, what is modified but not
staged, untracked files and conflicts. They also asked for a sign that a
branch's upstream was deleted. The background worker already runs
`git status --porcelain=v2 --branch` (ADR-0008), but it stops reading at
the first entry. That keeps it fast on large dirty trees, because `head`
closes the pipe and git stops early.

## Decision

- **Opt-in** with `git_status = detail`. The default, `compact`, renders
  byte for byte as in 3.1 (tested against the `v3.1.0` build).
- **Counts:** `+N` staged (X field not `.`), `!N` unstaged (Y not `.`),
  `?N` untracked (`?` lines), and `✘N` conflicts (`u` lines; `x` in the
  ascii tier). Each has its own color token in every theme, and the
  contrast check covers them.
- **Bounded:** at most 2000 entries are read. Past that the count shows
  `N+`. The worker's git call keeps its 10 s limit.
- **Linear parse:** the counting runs in a `read` loop at the end of the
  pipe and returns one line of numbers. The first version cut lines off a
  captured string. That copies the rest of the string each time, which is
  quadratic, and took 17.6 s for 2000 entries. The linear loop takes
  0.18 s, and a test guards it.
- **Upstream gone** (both modes): the `branch.upstream` header is present
  but `branch.ab` is missing. It shows as `⇣gone` (`gone` in ascii) in the
  `state` color.
- **Cache:** the worker's file gains a format version and the new fields,
  and the mode is part of the cache key. An old cache, or a result computed
  in compact mode, is treated as a miss and never read as zero counts.

## Alternatives considered

- **Detail by default.** It changes the look of every prompt in a minor
  release, and it costs more on huge dirty trees.
- **Unbounded counts.** A tree with 100k untracked files would make the
  worker parse 100k lines on every refresh.
- **A separate `git diff --cached --quiet` call.** That is another process
  per refresh, for information that porcelain v2 already gives.

## Consequences

- Measured on a 100k-file repository with 5000 modified files: about 7 ms
  per render in both modes, and the detail worker takes 0.18 s.
- Plain mode still shows only `*`.
