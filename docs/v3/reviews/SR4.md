# SR4: security review, wave 3

- Date: 2026-11-25
- Scope: the `bga` CLI (`lib/94-cli.bash`, `bin/bga`), the config loader
  and the `_BGA_CLI` bypass (`lib/00-options.bash`), and `install.sh`.
- Reviewer: an independent reviewer, working on copies with a scratch HOME.

No `bga` input ran code.

| # | Finding | Outcome |
|---|---|---|
| 1 | On a full disk, `config set`/`unset` truncated the config and exited 0 | The new content is built first and written with one `printf` whose status is checked; on failure the old file is kept |
| 2 | A directory at the config path was accepted | Refused unless the path is a regular file |
| 3 | Escape sequences in a config file reached the terminal (`config list`/`get`, loader warnings, `doctor`) | Control characters are replaced with `?` |
| 4 | An exported `_BGA_CLI` made non-interactive scripts that source the file load everything | Only an unexported `_BGA_CLI` counts (`${_BGA_CLI@a}`); `bin/bga` sets it plain |
| 5 | A repository path with `$(...)`, backticks or newlines ran code from the appended `source` line | The line is written with `printf %q` |
| 6 | The tamper check missed ACL write grants and world-writable ancestor directories | Named ACL entries with write are refused (where `getfacl` exists), and every ancestor up to `/` must be non-world-writable unless it is sticky and owned by root or the user |
| 7 | `--uninstall` deleted user lines that mentioned bash-gitaware | Removes only the marked v3 block or the exact v2 lines |
| 8 | `--uninstall` restored a planted backup; `--replace` wrote through a symlinked target | Only backups the user owns and that nobody else can write are restored; a symlinked target is refused |

Regression tests are in `tests/cli.sh` and `tests/install.sh`. One test had
been passing without checking anything: the restore check looked for the
word "original", and `new.bashrc` itself contains it. It now looks for a
unique marker.
