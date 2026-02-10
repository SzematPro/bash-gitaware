# Modern Git-Aware Bash Configuration

**Author:** Waldemar Szemat <waldemar@szemat.pro>

This repository contains a modern, colorful, and professional `.bashrc` configuration with enhanced Git integration and visual feedback.

## Features

### Modern Visual Design
- **Colorful prompt** with bright, professional color scheme
- **Git commit message display** in a decorated box above the prompt
- **Real-time Git status** indicators (clean/dirty, ahead/behind, stash)
- **Exit code feedback** (only shown on errors)
- **Command execution timer** (shown when command takes >= 2 seconds)
- **Terminal width adaptation** for commit message box with smart truncation
- **Unicode symbols** with automatic ASCII fallback (`✓/OK`, `✗/*`, `↑/^`, `↓/v`, `⚑/S`)

### Git Information Display
- **Current branch name** with commit hash
- **Working directory status**: ✓ (clean) or ✗ (dirty)
- **Remote sync status**: ↑ (ahead) and ↓ (behind) with counts
- **Stash count**: ⚑N when stashes exist
- **Git state detection**: REBASE (with progress), MERGING, CHERRY-PICK, REVERTING, BISECTING, AM
- **Commit message** displayed in a decorative box (truncated with `...` for long messages)
- **Detached HEAD** display with hash

### Environment Detection
- **SSH sessions**: hostname displayed in bold yellow when connected via SSH
- **Containers**: `[container]` prefix when running inside Docker or other containers
- **Virtual environments**: Python venv, Conda, and Node.js (NVM) indicators before user@host
- **NO_COLOR support**: respects the [NO_COLOR](https://no-color.org/) standard

### Performance
- **Optimized git subprocess usage**: 2-3 git calls per prompt (down from 7 in previous version)
- **Single `git status --porcelain=v2 --branch`** provides branch, hash, ahead/behind, and dirty status
- **Early-exit parsing**: stops reading git output as soon as dirty state is detected
- **No subprocesses** for git state detection (filesystem checks only)
- **Environment detection** runs once at shell startup, not every prompt

### Preserved Functionality
All essential features from the original configuration are preserved:
- History configuration (HISTCONTROL, HISTSIZE, HISTFILESIZE)
- Bash completion support
- Color support for `ls`, `grep`, `fgrep`, `egrep`
- All original aliases (`ll`, `la`, `l`, `alert`)
- PATH configuration for npm-global
- Debian chroot support
- Terminal title setting

### Git Aliases
- `gs` - git status
- `ga` - git add
- `gc` - git commit
- `gp` - git push
- `gl` - git log (oneline graph)
- `gd` - git diff
- `gb` - git branch
- `gco` - git checkout
- `gst` - git stash
- `gsp` - git stash pop

## Installation

### Step 1: Backup Your Current Configuration

Before making any changes, **backup your existing `.bashrc` file**:

```bash
cp ~/.bashrc ~/.bashrc.backup
```

### Step 2: Copy the New Configuration

You have two options:

#### Option A: Replace Entire `.bashrc` (Recommended)

```bash
cp new.bashrc ~/.bashrc
```

#### Option B: Merge with Existing Configuration

If you have custom configurations in your current `.bashrc` that you want to keep:

1. Review `new.bashrc` to understand what it contains
2. Manually merge any custom settings you have
3. Or append your custom settings to the end of `new.bashrc` before copying

### Step 3: Reload Your Configuration

After copying the file, reload your bash configuration:

```bash
source ~/.bashrc
```

Or simply open a new terminal window/tab.

## Visual Examples

### Normal Directory (No Git)
```
username@hostname:/home/dev/projects
>
```

### Git Repository - Clean
```
+- Commit ------------------------------------------------------------------+
| Fix bug in login                                                          |
+---------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] ✓
>
```

### Git Repository - Dirty with Ahead/Behind
```
+- Commit -----------------------------------------------------------------+
| Implement new feature for user authentication                            |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] ✗ ↑3 ↓1
>
```

### Git Repository - With Stash and State
```
+- Commit -----------------------------------------------------------------+
| Add user dashboard                                                       |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d|REBASE 3/7] ✗ ⚑2
>
```

### SSH Session with Virtual Environment
```
+- Commit -----------------------------------------------------------------+
| Update API endpoints                                                     |
+--------------------------------------------------------------------------+
(myenv) username@hostname:/home/dev/projects [main:a1b2c3d] ✓
>
```

### After Failed Long-Running Command
```
+- Commit -----------------------------------------------------------------+
| Refactor code structure                                                  |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] ✓ [X 1] (5s)
>
```

### Container Environment
```
[container] username@hostname:/app [main:a1b2c3d] ✓
>
```

## Compatibility

- **Bash**: 4.x and 5.x
- **OS**: Linux (all distros), macOS, WSL
- **Git**: 2.11+ (required for `--porcelain=v2`)
- **Terminals**: with and without color support (graceful degradation)
- **Locales**: UTF-8 and ASCII (automatic detection with fallback)
- **Standards**: respects [NO_COLOR](https://no-color.org/)

## Color Scheme

- **Cyan** (`BRIGHT_CYAN`): Username, commit hash, stash indicator
- **Yellow** (`BRIGHT_YELLOW`): Hostname, ahead indicator, SSH host, timer, container
- **Blue** (`BRIGHT_BLUE`): Current directory path
- **Green** (`BRIGHT_GREEN`): Git branch, clean status (✓), success prompt (>)
- **Red** (`BRIGHT_RED`): Dirty status (✗), error indicator, error prompt (>), git state
- **Magenta** (`BRIGHT_MAGENTA`): Behind indicator, virtual environment names
- **White** (`BRIGHT_WHITE`): Commit message text
- **Gray** (`BRIGHT_BLACK`): Commit message box borders

## Troubleshooting

### Colors Not Showing

If colors don't appear, ensure your terminal supports 256 colors. The configuration automatically detects color support, but you can force it by uncommenting this line in the file:

```bash
force_color_prompt=yes
```

Make sure `NO_COLOR` environment variable is not set.

### Git Information Not Appearing

- Ensure you're in a Git repository (`git status` should work)
- Check that Git is installed: `which git`
- Verify Git version is 2.11+: `git --version`

### Unicode Symbols Not Showing

If you see garbled characters instead of ✓, ✗, ↑, ↓, ⚑:
- Check your locale supports UTF-8: `echo $LANG`
- The prompt automatically falls back to ASCII symbols (OK, *, ^, v, S) for non-UTF-8 locales

### Commit Message Box Too Wide/Narrow

The commit message box automatically adapts to your terminal width. Long messages are truncated with `...`. If the terminal is narrower than 30 columns, the box is replaced with an inline display.

### Performance Issues

The prompt uses 2-3 git subprocesses per command (down from 7 in the previous version). If the prompt still feels slow in very large repositories, consider using a faster Git status tool like `gitstatus`.

## Customization

### Change Colors

Edit the semantic color mappings in the "COLOR DEFINITIONS" section:

```bash
PROMPT_USER="${BRIGHT_MAGENTA}"  # Change from BRIGHT_CYAN to BRIGHT_MAGENTA
```

### Change Symbols

Edit the "SYMBOL DEFINITIONS" section to use custom symbols:

```bash
SYM_CLEAN="ok"
SYM_DIRTY="!!"
```

### Disable Commit Message Box

Comment out or remove the commit message display section in the `__prompt_command()` function.

### Disable Command Timer

Remove or comment out the `trap '__timer_start' DEBUG` line and the timer section in `__prompt_command()`.

### Adjust History Size

```bash
HISTSIZE=1000        # Number of commands in memory
HISTFILESIZE=2000    # Number of commands in history file
```

## Reverting to Original

```bash
cp ~/.bashrc.backup ~/.bashrc
source ~/.bashrc
```

## Files in This Repository

- `new.bashrc` - The modern configuration (use this one)
- `README.md` - This file
- `LICENSE` - MIT License

## Requirements

- Bash 4.x or 5.x
- Git 2.11+ (for `--porcelain=v2` support)
- Terminal with color support (most modern terminals; graceful fallback without)
- Linux/Unix-like system

## License

MIT License - See [LICENSE](LICENSE) for details.

**Author:** Waldemar Szemat <waldemar@szemat.pro>
