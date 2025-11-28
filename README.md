# Modern Git-Aware Bash Configuration

**Author:** Waldemar Szemat <waldemar@szemat.pro>

This repository contains a modern, colorful, and professional `.bashrc` configuration with enhanced Git integration and visual feedback.

## Features

### Modern Visual Design
- **Colorful prompt** with bright, professional color scheme
- **Git commit message display** in a decorated box above the prompt
- **Real-time Git status** indicators (clean/dirty, ahead/behind)
- **Exit code feedback** (only shown on errors)
- **Terminal width adaptation** for commit message box

### Git Information Display
- **Current branch name** with commit hash
- **Working directory status**: OK (clean) or * (dirty)
- **Remote sync status**: ^ (ahead) and v (behind) with counts
- **Commit message** displayed in a decorative box (full width, no truncation)

### Preserved Functionality
All essential features from the original `actual.bashrc` are preserved:
- History configuration (HISTCONTROL, HISTSIZE, HISTFILESIZE)
- Bash completion support
- Color support for `ls`, `grep`, `fgrep`, `egrep`
- All original aliases (`ll`, `la`, `l`, `alert`)
- PATH configuration for npm-global
- Debian chroot support
- Terminal title setting

### Additional Git Aliases
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
username@hostname:/home/dev/projects/console [main:a1b2c3d] OK
> 
```

### Git Repository - Dirty with Changes
```
+- Commit -----------------------------------------------------------------+
| Implement new feature for user authentication                            |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] *
> 
```

### Git Repository - Ahead of Remote
```
+- Commit ----------------------------------------------------------------+
| Add user dashboard with real-time updates                               |
+-------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] OK ^3
> 
```

### Git Repository - Behind Remote
```
+- Commit -----------------------------------------------------------------+
| Update dependencies                                                      |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] OK v2
> 
```

### After Failed Command
```
+- Commit -----------------------------------------------------------------+
| Refactor code structure                                                  |
+--------------------------------------------------------------------------+
username@hostname:/home/dev/projects/console [main:a1b2c3d] OK [X 1]
> 
```

## Color Scheme

- **Cyan** (`BRIGHT_CYAN`): Username and commit hash
- **Yellow** (`BRIGHT_YELLOW`): Hostname and ahead indicator
- **Blue** (`BRIGHT_BLUE`): Current directory path
- **Green** (`BRIGHT_GREEN`): Git branch, clean status (OK), success prompt (>)
- **Red** (`BRIGHT_RED`): Dirty status (*), error indicator, error prompt (X)
- **Magenta** (`BRIGHT_MAGENTA`): Behind indicator
- **White** (`BRIGHT_WHITE`): Commit message text
- **Gray** (`BRIGHT_BLACK`): Commit message box borders

## Troubleshooting

### Colors Not Showing

If colors don't appear, ensure your terminal supports 256 colors. The configuration automatically detects color support, but you can force it by uncommenting this line in the file:

```bash
force_color_prompt=yes
```

### Git Information Not Appearing

- Ensure you're in a Git repository (`git status` should work)
- Check that Git is installed: `which git`
- Verify Git is working: `git --version`

### Commit Message Box Too Wide/Narrow

The commit message box automatically adapts to your terminal width. If it looks incorrect:
- Resize your terminal window
- Open a new terminal session
- The box uses the `COLUMNS` environment variable

### Performance Issues

If the prompt feels slow:
- The Git status checks run on every command
- In very large repositories, this might be noticeable
- Consider using a faster Git status tool like `gitstatus` if needed

## Customization

### Change Colors

Edit the color definitions in the "COLOR DEFINITIONS" section. For example, to change the username color:

```bash
PROMPT_USER="${BRIGHT_MAGENTA}"  # Change from BRIGHT_CYAN to BRIGHT_MAGENTA
```

### Disable Commit Message Box

If you find the commit message box distracting, you can comment out or remove the commit message display section in the `__prompt_command()` function.

### Adjust History Size

Modify these lines to change history size:

```bash
HISTSIZE=1000        # Number of commands in memory
HISTFILESIZE=2000     # Number of commands in history file
```

## Reverting to Original

If you need to revert to your original configuration:

```bash
cp ~/.bashrc.backup ~/.bashrc
source ~/.bashrc
```

## Files in This Repository

- `new.bashrc` - The new modern configuration (use this one)
- `README.md` - This file

## Requirements

- Bash shell
- Git (for Git features to work)
- Terminal with color support (most modern terminals)
- Linux/Unix-like system (tested on Debian/Ubuntu)

## License

This is a personal configuration file. Use it as you wish!

**Author:** Waldemar Szemat <waldemar@szemat.pro>

