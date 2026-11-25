# SR1: security review, wave 0

- Date: 2026-11-25
- Scope: `git diff 1e57f89..v3 -- lib/` (v2.0.1 fixes plus wave 0)
- Reviewer: an independent reviewer with no prior context and read-only
  access. Every finding was then reproduced or refuted by running it, before
  any fix.

| # | Finding | Reviewer severity | Verified | Outcome |
|---|---|---|---|---|
| 1 | A version file or `.git` file that is a symlink to `/dev/zero`, `/dev/tty` or a FIFO hangs every prompt | High | Yes: `timeout` reported rc 124 | Fixed: `__bga_read_line` accepts regular files only and reads at most 256 bytes; also replaces 4 `cat` forks |
| 2 | The window title used `\w`, which passes control characters through, so a directory name could inject OSC 52 | Medium | Partly: the reviewer had the version range reversed. Bash 4.4 to 5.1 pass control characters raw; 5.2 and later print them as `^[` | Fixed: the title uses the escaped path. `debian_chroot` is escaped too |
| 3 | The transient prompt echoed `READLINE_LINE` raw, so a pasted hidden ESC reached the terminal | Medium | Yes | Fixed: `__bga_term_safe` (tabs become spaces) |
| 4 | C1 controls (C2 80-9F) pass through in the C locale | Low | Yes | Fixed: `__bga_strip_c1`, matching bytes under `LC_ALL=C`, only when a C2 byte is present |
| 5 | Async jobs shared `cache.tmp.$$`, and `wait` ran on a disowned PID | Low | By reading the code | Fixed: `$BASHPID`; `wait` removed |
| 6 | The runtime cache key ignored the `promptvars` state | Low | By reading the code | Fixed: `promptvars` is part of the key |
| 7 | `core.fsmonitor` from a hostile `.git/config` (extracted archive) runs on every prompt | Low, as "pre-existing class" | Yes: the canary ran. This is command execution on `cd`, so it is high in practice | Fixed: `git -c core.fsmonitor=false status`. Residual risk: clean/smudge filters from such a config can still run during `git status`, the same as running `git status` by hand there. To be documented in SECURITY.md |
| 8 | Only the config file was checked, not its directory (swap between check and read) | Low | By reading the code | Fixed: the parent directory is checked too |
| 9 | A `PROMPT_COMMAND` ending in `# comment` or `&` broke `__bga_prompt` | Correctness | Yes: the prompt was never built, or a syntax error | Fixed: entries are joined with newlines |
| 10 | A newline in `PWD` broke the line-based async cache key | Correctness | By reading the code | Fixed: newlines in the key become `?` |

Regression tests: `tests/security.sh` (special files, window title,
fsmonitor, transient line, C1 in the C locale) and `tests/hooks.sh` (comment
and `&`). Each one was checked against the code before the fix:
numbers 1, 3, 4, 7 and 9 fail there, and #2 fails on bash 4.4.

Backport: #1, #2, #3 and #7 also affect the released v2.0.1.

## Follow-up: hostile `.git/config` (automated review, same day)

The fsmonitor fix was incomplete. Each of these was reproduced with a canary:

- clean/process filter drivers ran on stale stat data;
- `gpg.program` ran for a forged signed commit when `log.showSignature` was set;
- a filter in a submodule's config ran.

Fix: `__bga_git_status_safe` (lib/30-git.bash). Every git call passes
`log.showSignature=false`. `git status` adds `core.fsmonitor=false` and
`--ignore-submodules=dirty`, and neutralizes every filter driver that the
repository config or `config.worktree` defines. Git itself lists those
drivers with `git config --file --no-includes --name-only`. A first version
parsed the config in bash, and a second automated review showed that git
normalizes names differently (`[Filter.X]`). Includes, odd driver names and
configs that git cannot parse all fail closed: the prompt skips `git status`.
`BASHGITAWARE_TRUST_REPO_CONFIG=1` opts out. Tests: `tests/gitconfig.sh`.
