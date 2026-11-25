# SR5: administrator policy file

- Date: 2026-11-25
- Scope: `v3.1-w5..HEAD` policy loader, trust check, CLI locks
  (`lib/00-options.bash`, `lib/94-cli.bash`), threat model in ADR-0011
- Method: an independent reviewer with shell and Docker access. It used
  root-owned fixtures and a second unprivileged user as the attacker. Each
  finding was reproduced with a PoC, and every PoC was run again on the
  fixed code.

| ID | Severity | Finding | Fix | Re-test |
|---|---|---|---|---|
| F1 | Medium | The trust check resolved the path with `cd -P` and checked the physical path, but the parser read the logical path again. A symlink in the middle that another user owns (for example `/etc/bash-gitaware -> /home/eve/lnk -> /opt/real`) could be swapped between the check and the read. 49 of 200 shells applied the attacker's file, including a locked `trust_repo_config = 1`, and swapping in a FIFO hung 11 of 60 shells | The parser reads `_bga_policy_real`, the physical path that was checked. Every component of that path is owned by root and not writable by others | Same race: 0 of 200 shells applied the attacker's content; 0 of 100 hung |
| F2 | Low | The check counted the lines of `find -print`, so a directory name containing a newline made the count come out right while a component failed. A root-owned policy in a mode 777 directory named `a<LF>b` was applied | `find` prints only the paths that fail, and any output or a non-zero exit refuses the policy. A path with a newline is refused. The trailing newline of `pwd -P` is kept | Refused with "has a newline in its path"; the race applied nothing |
| F3 | Low | `${k^^}` and `${k,,}` follow the locale. Under `tr_TR.UTF-8`, `i` becomes a dotted capital I, so `printf -v` fails ("not a valid identifier"). Any key containing `i` did not apply, while `doctor` still listed it as locked. This was also present in the 3.0 user config parser | Key case folding runs in `LC_ALL=C` (`__bga_key_lc`, `__bga_key_uc`), only for the conversion. The warnings keep the user's locale, so UTF-8 C1 controls are still stripped | Ubuntu image, `tr_TR.UTF-8`: same result as `C.UTF-8`. A test runs where the locale is installed |

Blocked correctly (no change needed):
- `_BGA_POLICY` exported, set with `declare -x` or `declare -rx`, or passed through `bin/bga`;
- a policy that is a symlink, FIFO, `/dev/null` or `/dev/zero`;
- files owned by other users or with group/other write;
- a link pointing into a user's directory;
- named ACL write entries;
- escape sequences in the path, in warnings and in `doctor`;
- code execution through keys or values;
- `/proc/self/root` paths.

Accepted: a huge root-owned policy is slow to parse. Only root can create
one.
