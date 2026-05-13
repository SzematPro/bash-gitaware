# bash-gitaware demo for v2.0.0.
#
# Regenerate with `make demo` from the repo root. Requires:
#   - vhs    (charmbracelet/vhs, https://github.com/charmbracelet/vhs)
#   - ttyd   (apt: sudo apt install ttyd)
#   - ffmpeg (apt: sudo apt install ffmpeg)
#
# vhs reads this file and writes demo/demo.svg.

Output demo/demo.gif

Set Shell bash
Set FontSize 16
Set Width 1280
Set Height 720
Set Padding 32
Set TypingSpeed 55ms
Set Framerate 12

# Hidden setup: export the env knobs that keep the demo deterministic
# (transient collapse off so each multi-line prompt is visible in the
# recording; async deferred-refresh off so the dirty marker appears
# immediately -- both are documented features of the actual install,
# this just suppresses them inside the recording). Capture the repo
# root, build a throwaway demo repo, source bash-gitaware on top, clear
# the screen.
Hide
Type "export BASHGITAWARE_TRANSIENT=0 BASHGITAWARE_ASYNC=0 LANG=en_US.UTF-8"
Enter
Type `BGA_REPO="$PWD"`
Enter
Type "cd /tmp && rm -rf bga-demo && git init -q -b main bga-demo && cd bga-demo"
Enter
Type "git config user.email demo@example.com && git config user.name Demo"
Enter
Type "git commit --allow-empty -qm 'feat(install): add install.sh with --replace / --append modes'"
Enter
Type `source "$BGA_REPO/new.bashrc"`
Enter
Type "clear"
Enter
Sleep 600ms
Show

# Clean repo state.
Sleep 800ms
Type "ls"
Enter
Sleep 800ms

# Make a change -> dirty marker appears.
Type "echo wip > note.txt"
Enter
Sleep 700ms

Type "git status --short"
Enter
Sleep 1500ms

# Stash -> stash count appears.
Type "git stash"
Enter
Sleep 1700ms

# Slow command -> timer.
Type "sleep 3"
Enter
Sleep 3500ms

# Failure -> red prompt + exit code.
Type "false"
Enter
Sleep 1500ms

# Leave the repo -> simple prompt.
Type "cd /tmp"
Enter
Sleep 1700ms

Type "exit"
Enter
Sleep 500ms
