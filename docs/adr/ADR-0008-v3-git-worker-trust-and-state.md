# ADR-0008: v3 git worker, trust model and state directory

- Status: Accepted
- Date: 2026-11-25

## Context

The spec gives git a hard 20 ms budget per prompt (R5), with anything slower
moved to a background worker. Since v2.0.1, four security releases showed
that the prompt's git calls are an attack surface. A repository extracted
from an archive ships its own `.git/config` and hooks. Its paths can contain
newlines, and its files can be FIFOs. The worker, its cache and the checks
around them need one recorded design.

## Decision

1. **Fast path: one git call per prompt.** `git rev-parse --git-dir
   --git-common-dir --show-toplevel`, captured with a sentinel. It must
   produce exactly three newline-terminated lines, or the prompt shows no git
   info. Branch, hash and state are then read from files with bounded reads
   of regular files only (`__bga_read_line`). The commit subject is fetched
   only when it is shown, and is capped at 2 KB.
2. **Worker.** `git status --porcelain=v2 --branch` runs in a background
   subshell, in the shell's own directory, and is disowned. Its result goes to
   a cache file in the private state directory. The file is keyed by directory
   and git dir, parsed rather than sourced, and only numeric values are
   accepted. A result for another key is discarded. The prompt shows a static
   pending glyph until a later prompt picks the result up.
3. **Trust model.** Every git call goes through `__bga_git`:
   `--no-optional-locks`, `core.hooksPath=/dev/null`, `core.fsmonitor=false`,
   `log.showSignature=false`, `GIT_NO_LAZY_FETCH=1`, stdin from `/dev/null`,
   and `--ignore-submodules=dirty` for status. Filter drivers defined in the
   repository's config or `config.worktree` are neutralized; git itself
   lists them (`git config --file --no-includes --name-only`). Includes,
   partial clones, odd driver names and configs git cannot parse fail closed:
   the prompt shows the branch only. `BASHGITAWARE_TRUST_REPO_CONFIG=1` turns
   the filter check off.
4. **Trust cache.** The verdict is reused while the config files' content is
   unchanged. The files are read with the `read` builtin: regular files only,
   at most 64 KB, no fork. The cache key also holds the common dir and the
   worktree's git dir. Modification times are not trusted, because `tar xf`
   restores old ones.
5. **Time limits.** Each git call runs under `timeout -s KILL` (or a
   watchdog where `timeout` is missing): 1 s, 3 s for a synchronous status,
   10 s in the worker. The first timeout skips git for the rest of that
   prompt.
6. **State directory** (`lib/16-state.bash`). It is created with `mktemp -d`
   under `$XDG_RUNTIME_DIR`, but only if that is a real directory that the
   user owns and that others cannot write. Otherwise it goes under `$TMPDIR`.
   It is checked to be 0700, owned and not a symlink, and removed at exit.

## Alternatives considered

- **Animated pending indicator (S3), spiked and dropped.** A USR1 trap that
  changes `PS1` and sends `SIGWINCH` to the shell does not redraw the prompt
  while readline waits for input (bash 4.4, 5.2 and 5.3, checked in a pty).
  The other way is to write to the terminal from the background while
  readline owns the line, which corrupts what the user types. Accepted
  outcome: a static glyph, refreshed on the next prompt.
- **Parse `.git/config` in bash**: rejected after review. It disagrees with
  git on case and syntax edge cases (`[Filter.X]`).
- **mtime-based trust cache**: rejected after review, because `tar xf`
  restores mtimes.
- **Reading `.git/commondir` in bash**: rejected. A 256-byte read truncates
  long paths, which made a decoy config possible.

## Consequences

- In a 100k-file repository the prompt costs about 11 ms with the worker
  (`git status` alone is about 70 ms).
- Repositories that rely on local filter drivers (git-crypt,
  `git lfs install --local`) show branch-only information unless the user
  sets `BASHGITAWARE_TRUST_REPO_CONFIG=1`.
- Residual race: bash cannot open a file without blocking. An attacker who
  swaps a config file for a FIFO in the microseconds between the `-f` check
  and the open can block that prompt. That attacker needs live write access
  to the repository while the user is in it, which already allows worse.
- Running git by hand in an untrusted extracted `.git` directory is as
  risky as git itself makes it. These protections cover only the prompt's
  own calls.
