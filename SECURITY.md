# Security

## Reporting a vulnerability

If you find a security issue in bash-gitaware, please report it privately
rather than opening a public issue. Email:

**waldemar@szemat.pro**

Please include:

- A clear description of the issue.
- Steps to reproduce.
- The bash and OS versions, and the terminal emulator if relevant.

Reports are acknowledged within a week. Confirmed issues are addressed in a
patch release and credited (with your permission) in the changelog.

## Threat model

bash-gitaware is a shell prompt: it runs on every interactive prompt cycle,
inherits the shell user's privileges, and renders data that flows in from
the filesystem (git repo contents, branch names, commit subjects, paths) and
from environment variables (`BASHGITAWARE_*`, `TERM`, `LANG`, the various
runtime-manager variables).

The relevant risks and how we treat them:

- **Shell injection through prompt data.** Branch names, commit subjects and
  filenames are treated as data: they are inserted into `PS1` as strings,
  never re-evaluated. The prompt uses `${var}` expansion and `printf`, never
  `eval` of user-controlled content. A branch named `$(touch /tmp/x)` does
  not execute.
- **Terminal-escape injection.** Commit subjects and branch names are
  inserted into a prompt that emits ANSI/OSC escapes around them. A subject
  that itself contains escape sequences could affect terminal state. This is
  a known trade-off of any prompt that displays git data; mitigation is the
  responsibility of the terminal emulator (modern terminals filter or
  sanitize escapes in scrollback). bash-gitaware does not actively sanitize
  the commit subject; users who clone untrusted repositories should be aware
  of this trade-off.
- **Reading from `/proc/1/cgroup`** for container detection. Read-only,
  done once at shell startup, no command execution.
- **`tput` / `dircolors` / `lesspipe`** sub-invocations. Standard system
  utilities, invoked without user input.
- **`git` sub-invocations**. The prompt uses `git rev-parse`, `git status
  --porcelain=v2 --branch`, `git log -1 --pretty=%s`, and `git stash list`.
  All output is parsed line-by-line; no shell-eval of the output.

If you find a path where untrusted input does end up in a shell context,
please report it via the email above.
