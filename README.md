# Modern Git-Aware Bash Configuration

**Author:** Waldemar Szemat <waldemar@szemat.pro>

A modern, colorful `.bashrc` configuration with real-time Git integration, environment detection, and visual feedback. Designed for developers who live in the terminal.

---

## Table of Contents

- [Installation](#installation)
- [Prompt Anatomy](#prompt-anatomy)
- [Prompt Reference](#prompt-reference)
  - [Commit Message Box](#1-commit-message-box)
  - [Virtual Environment Indicators](#2-virtual-environment-indicators)
  - [Container Indicator](#3-container-indicator)
  - [User and Host](#4-user-and-host)
  - [Current Directory](#5-current-directory)
  - [Git Branch and Hash](#6-git-branch-and-hash)
  - [Git State](#7-git-state)
  - [Dirty / Clean Indicator](#8-dirty--clean-indicator)
  - [Ahead / Behind Remote](#9-ahead--behind-remote)
  - [Stash Count](#10-stash-count)
  - [Exit Code](#11-exit-code)
  - [Command Timer](#12-command-timer)
  - [Prompt Symbol](#13-prompt-symbol)
- [Symbols and Fallback](#symbols-and-fallback)
- [Color Scheme](#color-scheme)
- [Scenarios and Examples](#scenarios-and-examples)
- [Git Aliases](#git-aliases)
- [Customization](#customization)
- [Compatibility](#compatibility)
- [Troubleshooting](#troubleshooting)
- [Performance](#performance)
- [Requirements](#requirements)
- [License](#license)

---

## Installation

### 1. Backup your current configuration

```bash
cp ~/.bashrc ~/.bashrc.backup
```

### 2. Install

**Option A** — Replace entirely (recommended):
```bash
cp new.bashrc ~/.bashrc
```

**Option B** — Merge manually: review `new.bashrc`, then append your custom settings at the end.

### 3. Reload

```bash
source ~/.bashrc
```

Or open a new terminal.

---

## Prompt Anatomy

The prompt is built dynamically after every command. It has up to three sections:

```
╭─ Commit ──────────────────────────────────────────────────────────╮  ┐
│ fix: resolve null pointer in user authentication                  │  ├─ COMMIT BOX
╰───────────────────────────────────────────────────────────────────╯  ┘
(myenv) (conda:ml) (node:v20.11.0) [container] user@host:~/project [main:a1b2c3d|REBASE 3/7] ✗ ↑2 ↓1 ⚑3 [X 1] (14s)
│         │              │               │       │    │   │    │          │  │  │   │   │      │      │
│         │              │               │       │    │   │    │          │  │  │   │   │      │      └─ TIMER
│         │              │               │       │    │   │    │          │  │  │   │   │      └─ EXIT CODE
│         │              │               │       │    │   │    │          │  │  │   │   └─ STASH COUNT
│         │              │               │       │    │   │    │          │  │  │   └─ BEHIND REMOTE
│         │              │               │       │    │   │    │          │  │  └─ AHEAD OF REMOTE
│         │              │               │       │    │   │    │          │  └─ DIRTY/CLEAN
│         │              │               │       │    │   │    │          └─ GIT STATE
│         │              │               │       │    │   │    └─ COMMIT HASH
│         │              │               │       │    │   └─ GIT BRANCH
│         │              │               │       │    └─ WORKING DIRECTORY
│         │              │               │       └─ USER@HOST
│         │              │               └─ CONTAINER
│         │              └─ NODE.JS (NVM)
│         └─ CONDA ENVIRONMENT
└─ PYTHON VIRTUALENV
>  ← PROMPT SYMBOL (green = success, red = failure)
```

**Every element is conditional** — it only appears when relevant. Outside a git repo, only `user@host:path` and the prompt symbol `>` are shown.

---

## Prompt Reference

### 1. Commit Message Box

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ fix: resolve null pointer in user authentication                  │
╰───────────────────────────────────────────────────────────────────╯
```

| Detail | Description |
|---|---|
| **What** | First line of the most recent `git commit` message |
| **When** | Inside a git repository with at least one commit |
| **Box width** | Adapts to terminal width (`$COLUMNS`) |
| **Long messages** | Truncated with `...` if they exceed the available width |
| **Narrow terminal** | If terminal is < 30 columns, the box is replaced with inline: `Commit: message` |
| **Box characters** | Unicode (`╭─│╯`) on UTF-8 terminals, ASCII (`+-\|`) on others |

### 2. Virtual Environment Indicators

```
(myenv) (conda:ml-project) (node:v20.11.0) user@host:~/path
```

Shown **before** `user@host`, following the standard terminal convention.

| Indicator | Source | Example | When shown |
|---|---|---|---|
| `(name)` | Python virtualenv | `(myenv)` | `$VIRTUAL_ENV` is set |
| `(conda:name)` | Conda environment | `(conda:ml)` | `$CONDA_DEFAULT_ENV` is set and is not `base` |
| `(node:version)` | Node.js via NVM | `(node:v20.11.0)` | `$NVM_BIN` is set |

Multiple indicators can appear simultaneously if several environments are active.

### 3. Container Indicator

```
[container] user@host:~/app
```

| Detail | Description |
|---|---|
| **What** | `[container]` prefix |
| **When** | Running inside Docker, Podman, or LXC |
| **Detection** | Checks `/.dockerenv`, `/run/.containerenv`, or `docker`/`lxc`/`containerd` in `/proc/1/cgroup` |
| **Runs** | Once at shell startup (not per prompt) |

### 4. User and Host

```
user@hostname           ← local session
user@hostname           ← SSH session (hostname in bold yellow)
```

| Detail | Description |
|---|---|
| **User** | Current username (cyan) |
| **Host** | Machine hostname (yellow) |
| **SSH detection** | If connected via SSH, the hostname is rendered in **bold yellow** to make remote sessions visually distinct |
| **Detection** | Checks `$SSH_CONNECTION`, `$SSH_TTY`, or `$SSH_CLIENT` (once at startup) |

### 5. Current Directory

```
user@host:~/projects/myapp
```

| Detail | Description |
|---|---|
| **What** | Full working directory path with `~` for home (blue) |
| **Format** | Uses bash's `\w` which abbreviates `$HOME` to `~` |

### 6. Git Branch and Hash

```
[main:a1b2c3d]          ← normal branch
[detached:a1b2c3d]      ← detached HEAD (no branch)
[feature/login:e5f6g7h] ← feature branch
```

| Element | Description |
|---|---|
| `[` `]` | Green brackets delimit the git info section |
| **Branch name** | Current branch (green). Shows `detached:hash` when HEAD is detached |
| `:` | Separator between branch and hash |
| **Commit hash** | First 7 characters of the current commit SHA (cyan) |
| **No commits** | If the repo has no commits yet, the hash is omitted |

### 7. Git State

When git is in the middle of an operation, the state appears after a `|` separator inside the brackets:

```
[main:a1b2c3d|REBASE 3/7]     ← interactive rebase, step 3 of 7
[main:a1b2c3d|MERGING]        ← merge in progress
[main:a1b2c3d|CHERRY-PICK]    ← cherry-pick in progress
[main:a1b2c3d|REVERTING]      ← revert in progress
[main:a1b2c3d|BISECTING]      ← git bisect in progress
[main:a1b2c3d|AM 2/5]         ← git am (apply mailbox), patch 2 of 5
```

| State | Trigger | Progress shown |
|---|---|---|
| `REBASE n/m` | `git rebase` (interactive or non-interactive) | Current step / total steps |
| `AM n/m` | `git am` (applying patches) | Current patch / total patches |
| `MERGING` | `git merge` with conflicts | No |
| `CHERRY-PICK` | `git cherry-pick` with conflicts | No |
| `REVERTING` | `git revert` with conflicts | No |
| `BISECTING` | `git bisect` in progress | No |

Detection is done via **filesystem checks only** (no git subprocesses):
`.git/rebase-merge/`, `.git/rebase-apply/`, `.git/MERGE_HEAD`, `.git/CHERRY_PICK_HEAD`, `.git/REVERT_HEAD`, `.git/BISECT_LOG`.

### 8. Dirty / Clean Indicator

Appears right after the `]` bracket:

```
[main:a1b2c3d] ✓    ← clean: working directory matches HEAD
[main:a1b2c3d] ✗    ← dirty: uncommitted changes exist
```

| Symbol | ASCII fallback | Meaning |
|---|---|---|
| `✓` | `OK` | Working directory is **clean** — no staged, unstaged, or untracked changes |
| `✗` | `*` | Working directory is **dirty** — there are modified, staged, or untracked files |

### 9. Ahead / Behind Remote

Shows how your local branch compares to its upstream tracking branch:

```
[main:a1b2c3d] ✓ ↑3         ← 3 commits ahead (need to push)
[main:a1b2c3d] ✓ ↓2         ← 2 commits behind (need to pull)
[main:a1b2c3d] ✗ ↑5 ↓1      ← diverged: 5 ahead, 1 behind
```

| Symbol | ASCII fallback | Meaning |
|---|---|---|
| `↑N` | `^N` | Local branch is **N commits ahead** of the remote (you have unpushed commits) |
| `↓N` | `vN` | Local branch is **N commits behind** the remote (remote has commits you don't have) |

- Only shown when the count is > 0
- If both appear, the branches have **diverged** and may need rebase or merge
- Not shown if the branch has no upstream tracking branch

### 10. Stash Count

```
[main:a1b2c3d] ✓ ⚑3    ← 3 stashed changesets
```

| Symbol | ASCII fallback | Meaning |
|---|---|---|
| `⚑N` | `SN` | There are **N stashed changesets** saved with `git stash` |

- Only shown when at least one stash exists
- Useful reminder that you have saved work waiting to be applied with `git stash pop`

### 11. Exit Code

```
[main:a1b2c3d] ✓ [X 1]       ← last command failed with exit code 1
[main:a1b2c3d] ✓ [X 127]     ← command not found (exit code 127)
[main:a1b2c3d] ✓ [X 130]     ← interrupted with Ctrl+C (128 + signal 2)
```

| Detail | Description |
|---|---|
| **What** | `[X N]` where N is the exit code of the last command (red) |
| **When** | Only shown when the last command **failed** (exit code != 0) |
| **Hidden** | Not shown after successful commands (exit code 0) |

Common exit codes:
| Code | Meaning |
|---|---|
| `1` | General error |
| `2` | Misuse of command / invalid arguments |
| `126` | Permission denied (not executable) |
| `127` | Command not found |
| `128+N` | Killed by signal N (e.g., 130 = SIGINT / Ctrl+C, 137 = SIGKILL, 143 = SIGTERM) |

### 12. Command Timer

```
[main:a1b2c3d] ✓ (3s)         ← command took 3 seconds
[main:a1b2c3d] ✓ (1m23s)      ← 1 minute 23 seconds
[main:a1b2c3d] ✓ (2h5m)       ← 2 hours 5 minutes
[main:a1b2c3d] ✗ [X 1] (14s)  ← failed after 14 seconds
```

| Detail | Description |
|---|---|
| **What** | `(duration)` in yellow showing how long the last command took |
| **When** | Only shown when the command took **2 seconds or more** |
| **Format** | `Ns` for seconds, `NmNs` for minutes, `NhNm` for hours |
| **Mechanism** | Uses bash `DEBUG` trap to capture start time via `$SECONDS` |

### 13. Prompt Symbol

```
>    ← green: last command succeeded (exit code 0)
>    ← red: last command failed (exit code != 0)
```

The `>` symbol appears on its own line below the info line. Its color provides instant visual feedback about the previous command's success or failure.

---

## Symbols and Fallback

The prompt auto-detects UTF-8 support via `$LANG`, `$LC_ALL`, or `$LC_CTYPE`. On non-UTF-8 terminals, all symbols gracefully fall back to ASCII equivalents:

| Purpose | UTF-8 | ASCII | Color |
|---|---|---|---|
| Clean working directory | `✓` | `OK` | Green |
| Dirty working directory | `✗` | `*` | Red |
| Ahead of remote | `↑` | `^` | Yellow |
| Behind remote | `↓` | `v` | Magenta |
| Stash count | `⚑` | `S` | Cyan |
| Box horizontal | `─` | `-` | Gray |
| Box vertical | `│` | `\|` | Gray |
| Box corners | `╭╮╰╯` | `++++` | Gray |

---

## Color Scheme

Every prompt element uses a semantic color variable, making it easy to retheme:

| Color | Elements |
|---|---|
| **Cyan** | Username, commit hash, stash indicator, "Commit" label |
| **Yellow** | Hostname, ahead indicator, SSH host (bold), timer, container tag |
| **Blue** | Current directory path |
| **Green** | Git branch, brackets, clean indicator (`✓`), success prompt (`>`) |
| **Red** | Dirty indicator (`✗`), exit code, error prompt (`>`), git state |
| **Magenta** | Behind indicator, virtual environment names |
| **White** | Commit message text |
| **Gray** | Commit box borders, chroot indicator |

When `NO_COLOR` environment variable is set (following the [no-color.org](https://no-color.org/) standard), all colors are disabled and the prompt renders in plain text.

---

## Scenarios and Examples

### Outside a Git Repository

Only `user@host:path` and the prompt symbol are shown:

```
user@hostname:~/documents
>
```

### Clean Repository

All changes committed, in sync with remote:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ feat: add user authentication module                              │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [main:a1b2c3d] ✓
>
```

### Dirty Repository with Unpushed Commits

Modified files exist, 3 commits ahead of remote:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ feat: add user authentication module                              │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [main:a1b2c3d] ✗ ↑3
>
```

### Diverged Branch with Stashes

Local and remote have diverged, stashed work exists:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ refactor: extract validation logic                                │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [develop:e5f6a7b] ✗ ↑2 ↓5 ⚑3
>
```

### Interactive Rebase in Progress

Rebase operation at step 3 of 7:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ fix: handle edge case in parser                                   │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [main:a1b2c3d|REBASE 3/7] ✗
>
```

### Merge Conflict

Merge in progress with unresolved conflicts:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ chore: update dependencies                                        │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [main:a1b2c3d|MERGING] ✗
>
```

### Detached HEAD

Checked out a specific commit or tag:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ release: v2.1.0                                                   │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [detached:b8c9d0e] ✓
>
```

### SSH Session with Python Virtualenv

Connected remotely with an active virtual environment:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ fix: correct API response format                                  │
╰───────────────────────────────────────────────────────────────────╯
(venv) user@hostname:~/projects/api [main:a1b2c3d] ✓
>
```

The hostname appears in **bold yellow** over SSH (not visible in this plain text example).

### Docker Container with Conda

Running inside a container with Conda environment active:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ feat: add training pipeline                                       │
╰───────────────────────────────────────────────────────────────────╯
(conda:torch-env) [container] user@hostname:~/ml-project [main:f1e2d3c] ✓
>
```

### Failed Long-Running Command

Command failed after 14 seconds:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ test: add integration tests                                       │
╰───────────────────────────────────────────────────────────────────╯
user@hostname:~/projects/myapp [main:a1b2c3d] ✓ [X 1] (14s)
>
```

### Everything at Once

All indicators active simultaneously:

```
╭─ Commit ──────────────────────────────────────────────────────────╮
│ wip: experimental feature                                         │
╰───────────────────────────────────────────────────────────────────╯
(venv) (node:v20.11.0) [container] user@hostname:~/project [feat:c3d4e5f|REBASE 2/5] ✗ ↑1 ↓3 ⚑2 [X 130] (1m5s)
>
```

Reading left to right:
1. `(venv)` — Python virtualenv is active
2. `(node:v20.11.0)` — Node.js v20.11.0 via NVM
3. `[container]` — Running inside Docker
4. `user@hostname` — Current user and machine
5. `:~/project` — Working directory
6. `[feat:c3d4e5f|REBASE 2/5]` — On branch `feat`, commit `c3d4e5f`, rebasing (step 2 of 5)
7. `✗` — Working directory has uncommitted changes
8. `↑1` — 1 commit ahead of remote
9. `↓3` — 3 commits behind remote
10. `⚑2` — 2 stashed changesets
11. `[X 130]` — Last command was interrupted (Ctrl+C)
12. `(1m5s)` — Last command ran for 1 minute 5 seconds

---

## Git Aliases

Included shortcuts for common git operations:

| Alias | Command | Description |
|---|---|---|
| `gs` | `git status` | Show working tree status |
| `ga` | `git add` | Stage files |
| `gc` | `git commit` | Create a commit |
| `gp` | `git push` | Push to remote |
| `gl` | `git log --oneline --graph --decorate --all` | Visual log of all branches |
| `gd` | `git diff` | Show unstaged changes |
| `gb` | `git branch` | List or create branches |
| `gco` | `git checkout` | Switch branches or restore files |
| `gst` | `git stash` | Stash current changes |
| `gsp` | `git stash pop` | Apply and remove last stash |

---

## Customization

### Change Colors

Edit the semantic color mappings in the `COLOR DEFINITIONS` section of `new.bashrc`:

```bash
PROMPT_USER="${BRIGHT_MAGENTA}"     # Change username color
PROMPT_GIT_BRANCH="${BRIGHT_CYAN}"  # Change branch color
PROMPT_TIMER="${BRIGHT_RED}"        # Change timer color
```

All available mappings: `PROMPT_USER`, `PROMPT_HOST`, `PROMPT_PATH`, `PROMPT_GIT_BRANCH`, `PROMPT_GIT_DIRTY`, `PROMPT_GIT_CLEAN`, `PROMPT_GIT_AHEAD`, `PROMPT_GIT_BEHIND`, `PROMPT_GIT_COMMIT`, `PROMPT_GIT_MESSAGE`, `PROMPT_GIT_STASH`, `PROMPT_GIT_STATE`, `PROMPT_MESSAGE_BOX`, `PROMPT_SUCCESS`, `PROMPT_ERROR`, `PROMPT_VENV`, `PROMPT_TIMER`, `PROMPT_SSH_HOST`, `PROMPT_CONTAINER`.

### Change Symbols

Edit the `SYMBOL DEFINITIONS` section:

```bash
SYM_CLEAN="ok"     # Replace ✓
SYM_DIRTY="!!"     # Replace ✗
SYM_STASH="@"      # Replace ⚑
```

### Disable Commit Message Box

Comment out the commit box section inside `__prompt_command()` (the block starting with `# === Commit message box ===`).

### Disable Command Timer

Remove or comment out:
```bash
trap '__timer_start' DEBUG
```

### Adjust History Size

```bash
HISTSIZE=1000        # Number of commands in memory (default: 10000)
HISTFILESIZE=2000    # Number of commands in history file (default: 20000)
```

---

## Compatibility

| Requirement | Minimum |
|---|---|
| Bash | 4.x or 5.x |
| Git | 2.11+ (for `--porcelain=v2`) |
| OS | Linux, macOS, WSL |
| Terminal | Any (graceful degradation without color/Unicode) |
| Locale | UTF-8 or ASCII (auto-detected) |
| Standard | Respects [NO_COLOR](https://no-color.org/) |

---

## Troubleshooting

### Colors not showing
- Ensure your terminal supports 256 colors
- Uncomment `force_color_prompt=yes` in the file to force colors
- Make sure `NO_COLOR` is not set: `unset NO_COLOR`

### Git information not appearing
- Verify you are inside a git repository: `git status`
- Check git version is 2.11+: `git --version`

### Unicode symbols showing as garbled text
- Check your locale: `echo $LANG` (should contain `UTF-8`)
- The prompt automatically falls back to ASCII on non-UTF-8 locales

### Commit box looks wrong
- The box adapts to `$COLUMNS`. Resize the terminal or open a new one
- Terminals narrower than 30 columns show an inline format instead

---

## Performance

| Metric | Value |
|---|---|
| Git subprocesses per prompt | 3-4 (down from 7) |
| Environment detection | Once at shell startup |
| Git state detection | Filesystem checks only (0 subprocesses) |
| Dirty detection | Early-exit on first dirty file |
| Box rendering | Mostly pure bash (`printf -v`), `wc -L` for display width |

---

## Requirements

- Bash 4.x or 5.x
- Git 2.11+
- Terminal emulator (any modern terminal works)
- Linux/Unix-like system

## Files

| File | Description |
|---|---|
| `new.bashrc` | The configuration file (copy to `~/.bashrc`) |
| `README.md` | This manual |
| `LICENSE` | MIT License |

## Reverting

```bash
cp ~/.bashrc.backup ~/.bashrc
source ~/.bashrc
```

## License

MIT License - See [LICENSE](LICENSE) for details.

**Author:** Waldemar Szemat <waldemar@szemat.pro>
