# SR6: wave 7 (runtimes, vi mode, OSC 9;4, config edit)

- Date: 2026-11-25
- Scope: `lib/50-runtime.bash` (new version files), `lib/15-escape.bash`,
  `lib/82-vimode.bash`, `lib/70-osc.bash`, and `bga config edit` in
  `lib/94-cli.bash`
- Method: an independent reviewer with shell and Docker access, using a
  second local user as the attacker and hostile repository files. Each
  finding was reproduced with a PoC. The fixes have regression tests.

No finding lets a repository run code.

| ID | Severity | Finding | Fix |
|---|---|---|---|
| F1 | Medium | `bga config edit` wrote its temp copy in the config directory without checking it. In a directory other users can write (not sticky), one of them replaced the copy with a symlink to the victim's `~/.bashrc` while the editor was open, and `chmod` and `mv` then overwrote it. `config set` had the same pattern, with a tiny window | f4a3f5e: `config set`/`edit` apply the loader's rule (no group/other-writable directory unless sticky; the file must be ours), and check that the copy is still a regular file of ours before `chmod` and `mv` |
| F2 | Medium | bash's `read -n` does not count NUL bytes, so a version file of NULs was read to the end on every prompt: 11 s for 1 GB, which a cloned repository ships at about 1 MB compressed. Ctrl-C did not stop it. This was already true for `.python-version` and `.nvmrc` | a9fec7c: `read -d ''`, so a NUL ends the read; `.sdkmanrc` is read in one bounded 12 KB read |
| F3 | Low | A version file symlinked to `~/.git-credentials` showed the token in the prompt (on the user's own screen only) | a9fec7c: symlinks are followed only to files inside the repository (a monorepo `.nvmrc -> ../.nvmrc` still works); the value must look like a version: its first word, at most 32 characters of `[A-Za-z0-9._+@/:-]` |
| F4 | Low | Lone bytes 0x80-0x9F passed the escaper. In a non-UTF-8 locale with an 8-bit terminal, 0x9B is CSI. This predates 3.1 (branch names take the same path) | a9fec7c: replaced outside UTF-8 locales. In UTF-8 they are continuation bytes of normal characters and are kept |
| F5 | Low | Ctrl-C or a hangup during the editor left the 0600 temp copy behind | f4a3f5e: the edit runs in a subshell whose traps remove the copy |

Unconfirmed, covered by the F3 fix: a version file symlinked to a regular
file that blocks (`/proc/kmsg`, readable by root only).

Blocked correctly: `$(...)`, backticks, prompt escapes and terminal
sequences in version files; `/dev/zero`, `/dev/tty`, FIFOs and directories
in place of version files; `.sdkmanrc` lines after line 50; `runtimes`
values. Only theme SGR codes (digits) reach the vi-mode `bind` string, and
its `\1 \2` wrapping is correct on bash 4.4 to 5.3. OSC 9;4 uses fixed bytes
and keeps the user's `PS0`. The temp path reaches `sh -c` as `$1`, never as
code.
