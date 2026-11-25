# Security

## Reporting a vulnerability

If you find a security issue in bash-gitaware, please report it privately
rather than opening a public issue. Email:

**<waldemar@szemat.pro>**

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

- **Shell injection through prompt data.** Branch names, commit subjects,
  directory names, version files (`.python-version`, `.nvmrc`,
  `.node-version`) and virtualenv/conda names are attacker-controlled: any
  cloned repository can set them. `PS1` is decoded for backslash escapes and
  then, with `shopt -s promptvars` (the bash default), expanded again, so
  such text must never reach `PS1` raw. Every untrusted segment goes through
  `__bga_ps1_lit` (`lib/15-escape.bash`), which escapes `\`, `$` and
  backticks for both layers; `tests/security.sh` plants `$(...)` and
  backtick payloads in each source and asserts they are shown, not run.
  Versions up to and including 2.0.0 did not do this; upgrade to 2.0.1.
- **Terminal-escape injection.** Control characters (C0, DEL, and C1 in
  UTF-8 locales) in any untrusted segment are replaced with `?` before they
  reach `PS1` or the OSC 7 cwd report, so a commit subject or directory name
  cannot change the window title, move the cursor or break readline's line
  width accounting.
- **Async cache file.** The background git job writes its result inside a
  private per-shell directory (`$XDG_RUNTIME_DIR` when it is set and owned
  by the user, otherwise a `mktemp -d` directory under `$TMPDIR` or `/tmp`,
  mode 0700), removed at shell exit. The cache is parsed, never sourced, and
  only numeric values are accepted.
- **Hostile `.git` directories.** `git clone` never copies `.git/config`,
  but an archive can ship a whole `.git`. Git settings that name commands
  and hooks could then run on every prompt. bash-gitaware runs git with
  `--no-optional-locks`, `core.hooksPath=/dev/null`, `core.fsmonitor` and
  `log.showSignature` off and no lazy fetching; neutralizes filter drivers
  defined in the repository's own config; does not look inside submodules;
  and shows only the branch when the repository config uses `include` or is
  a partial clone. The user's own
  `~/.gitconfig` is trusted. `BASHGITAWARE_TRUST_REPO_CONFIG=1` turns these
  checks off for users who rely on repository-local filters. Running git
  commands by hand in such a directory is still as risky as git itself
  makes it.
- **Special files.** Version files and `.git` metadata are read only when
  they are regular files, with a size bound, so a symlink to `/dev/zero` or
  a FIFO cannot hang the prompt.
- **Reading from `/proc/1/cgroup`** for container detection. Read-only,
  done once at shell startup, no command execution.
- **`tput` / `dircolors` / `lesspipe`** sub-invocations. Standard system
  utilities, invoked without user input.
- **`git` sub-invocations**. The prompt uses `git rev-parse`, `git status
  --porcelain=v2 --branch`, `git log -1 --pretty=%s`, and `git stash list`.
  All output is parsed line-by-line; no shell-eval of the output.

If you find a path where untrusted input does end up in a shell context,
please report it via the email above.
