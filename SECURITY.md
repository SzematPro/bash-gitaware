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

## Supported versions

| Version | Supported |
|---|---|
| 3.2.x | Yes |
| 3.0.x to 3.1.x | No: upgrade to 3.2.x |
| 2.x and older | No: upgrade to 3.2.x (no backports) |

## Published advisories

| Advisory | Summary | Fixed in |
|---|---|---|
| [GHSA-596h-h6gh-q2w6](https://github.com/SzematPro/bash-gitaware/security/advisories/GHSA-596h-h6gh-q2w6) | Command execution via branch names, commit subjects and paths shown in the prompt | 2.0.1 |
| [GHSA-988m-62g2-c378](https://github.com/SzematPro/bash-gitaware/security/advisories/GHSA-988m-62g2-c378) | Commands from an extracted `.git` directory run by the prompt's git calls; prompt hang and escape injection | 2.0.4 |
| [GHSA-x6pc-gm52-6fwv](https://github.com/SzematPro/bash-gitaware/security/advisories/GHSA-x6pc-gm52-6fwv) | Version files in a cloned repository can freeze the prompt or show files outside it | 3.1.0 |
| [GHSA-vfpf-4w24-2xhf](https://github.com/SzematPro/bash-gitaware/security/advisories/GHSA-vfpf-4w24-2xhf) | Private state directory can be hijacked after it is deleted; bidi controls pass the escaper | 3.2.0 |

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
- **Terminal-escape injection.** Control characters are replaced with `?`
  in any untrusted segment before it reaches `PS1` or the OSC 7 cwd report.
  That covers C0, DEL, C1 (in UTF-8, and as lone bytes outside UTF-8
  locales) and bidi/format controls (U+200E/F, U+202A-E, U+2066-9). A commit
  subject or directory name cannot change the window title, move the
  cursor, reorder text on screen or break readline's width accounting.
- **State directory and cache.** The background git job writes its result
  inside a private per-shell directory, removed at shell exit. The directory
  is under `$XDG_RUNTIME_DIR` when that is set and owned by the user, and
  otherwise is a `mktemp -d` directory under `$TMPDIR` or `/tmp`, mode 0700.
  Before every write it is checked again to be a real directory the user
  owns, because a cleaner may delete it while the shell runs (3.2.0). The
  cache is parsed, never sourced, carries a format version, and only numeric
  values are accepted.
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
- **Version and workspace files** (`.python-version`, `.nvmrc`,
  `.ruby-version`, `.java-version`, `.sdkmanrc`, `.terraform/environment`).
  They are read only when they are regular files, with a size bound and a
  read that a NUL byte ends, so a FIFO, `/dev/zero` or a file of NULs cannot
  hang the prompt. A symlink is followed only to a file inside the
  repository. Only a version-like value is shown (first word, at most 32
  characters of `[A-Za-z0-9._+@/:-]`). No runtime tool is ever run to find a
  version for Ruby, Deno, Bun or Java.
- **Settings files.** The user config and the administrator policy
  (`/etc/bash-gitaware/policy`) are parsed as data, never sourced, and every
  key and value is validated. The user config is refused when other users
  can write it. The policy is used only when it, and every directory on its
  physical path, is owned by root and not writable by group or others (no
  macOS ACL grants), and the path that was checked is the one read.
  `bga config set`/`edit` refuse to write into a directory other users can
  write.
- **Context segments** (opt-in). The kubeconfig is read as data with one
  bounded read; `kubectl`, `aws` and `terraform` are never run. Labels are
  escaped like any other untrusted text.
- **Reading from `/proc/1/cgroup`** for container detection. Read-only,
  done once at shell startup, no command execution.
- **`tput` / `dircolors` / `lesspipe`** sub-invocations. Standard system
  utilities, invoked without user input.
- **`git` sub-invocations**. The prompt uses `git rev-parse`, `git status
  --porcelain=v2 --branch`, `git log -1 --pretty=%s`, and `git stash list`.
  All output is parsed line-by-line; no shell-eval of the output.

If you find a path where untrusted input does end up in a shell context,
please report it via the email above.
