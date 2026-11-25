# demo/demo.tape -- vhs script for demo/demo.gif (v3, Lean style).
# Regenerate with `make demo` (needs vhs, ttyd and ffmpeg).
#
# Shows: the Lean prompt, the dirty mark and ahead count, a runtime in the
# right block, the transient collapse, a result line for a slow failing
# command, and switching themes with bga.

Output demo/demo.gif
Set Shell bash
Set FontSize 16
Set Width 1280
Set Height 640
Set Padding 28
Set TypingSpeed 50ms
Set Framerate 12

Hide
Type `BGA_REPO="$PWD"; export LANG=en_US.UTF-8 BASHGITAWARE_MODE=full BASHGITAWARE_CONFIG=/tmp/bga-demo.cfg; rm -f /tmp/bga-demo.cfg`
Enter
Type "cd /tmp && rm -rf demo-app && git init -q -b main demo-app && cd demo-app"
Enter
Type "git config user.email demo@example.com && git config user.name Demo && printf '{}\n' > package.json"
Enter
Type "git add -A && git commit -qm 'feat: first version' && git commit --allow-empty -qm 'feat: second'"
Enter
Type `source "$BGA_REPO/new.bashrc" && clear`
Enter
Sleep 600ms
Show

Sleep 1200ms
Type "echo 'todo' > notes.txt"
Enter
Sleep 1200ms
Type "git status --short"
Enter
Sleep 1500ms
Type "sleep 3; false"
Enter
Sleep 4500ms
Type "bga theme set contrast && bga reload"
Enter
Sleep 2000ms
Type "ls"
Enter
Sleep 2500ms
