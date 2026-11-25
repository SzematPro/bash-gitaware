# SR3: security review, wave 2

- Date: 2026-11-25
- Scope: the git worker, the trust cache added in wave 2, and the state
  directory (`lib/30-git.bash`, `lib/85-async.bash`, `lib/16-state.bash`).
- Reviewer: an independent reviewer, with experiments in a scratch directory.
  Automated commit reviews also ran while the wave was in progress.

| # | Finding | Source | Verified | Outcome |
|---|---|---|---|---|
| A1 | The trust cache trusted modification times, but `tar xf` restores old ones | Automated | Yes: the test fails on the earlier code | Fixed: the cache is validated by content |
| A2 | Worktrees that share a common dir shared one verdict | Automated | By test | Fixed: the worktree git dir is part of the key |
| A3 | The verdict could be cached for content that changed during the scan | Automated | Race, not reproduced | Fixed: the files are re-read after the scan, and the verdict is cached only if they did not change |
| A4 | A config swapped for a FIFO between the checks blocks the read | Automated | Race | Mitigated: `-f` check before each read, plus `read -t 1`. Residual: the open itself can block; it needs live write access to the repository (ADR-0008) |
| F1 | High. In a UTF-8 locale, `read -N` and `${#var}` count invalid multibyte sequences differently. A config of 280 KB passed as smaller than 64 KB, so its unread tail could be changed and the cached "safe" verdict reused | SR3 | Yes: canary on glibc bash 5.2 | Fixed: `__bga_read_whole` reads with byte semantics and reads one extra byte to prove EOF. A larger file is never cached |
| F2 | The async result was never refreshed while the shell stayed in a directory (also in v2) | SR3 | Yes: by test | Fixed: on a cache hit after a command, a refresh runs in the background while the cached values stay on screen |

Checked and closed by SR3: NUL bytes in configs, symlinked configs, repos
that produce the same key, other config sources (`core.worktree`,
`includeIf` in all its forms, `GIT_CONFIG_*`), the job running in the wrong
directory after a `cd`, cancelled jobs overwriting the cache, tmp naming and
atomic rename, and state-dir cleanup.

Regression tests: in `tests/gitconfig.sh`, `trust_cache` and
`trust_cache_multibyte`; in `tests/scenarios.sh`,
`async_stale_result_discarded` and `async_refreshes_after_command`.
