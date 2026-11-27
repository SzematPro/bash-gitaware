# demo/demo.tape -- the README GIF, recorded with vhs (https://github.com/charmbracelet/vhs).
#
#   vhs demo/demo.tape     # from the repository root; writes demo/demo.gif
#
# Shows the Lean prompt, the dirty mark and the detailed git status, the
# result line, a context segment on the right, bga completion with TAB and a
# theme switch. The setup runs hidden in a throwaway repository under /tmp.
Output demo/demo.gif
Set Shell bash
Set FontSize 16
Set Width 1280
Set Height 640
Set Padding 28
Set TypingSpeed 50ms
Set Framerate 12

Hide
Type `BGA_REPO="$PWD"; export LANG=en_US.UTF-8 BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0 BASHGITAWARE_CONFIG=/tmp/bga-demo.cfg AWS_PROFILE=staging; rm -f /tmp/bga-demo.cfg`
Enter
Type "cd /tmp && rm -rf demo-app && git init -q -b main demo-app && cd demo-app"
Enter
Type "git config user.email demo@example.com && git config user.name Demo && printf '{}\n' > package.json && printf '20.11.1\n' > .nvmrc"
Enter
Type "git add -A && git commit -qm 'feat: first version' && git commit --allow-empty -qm 'feat: second'"
Enter
Type `source "$BGA_REPO/new.bashrc" && clear`
Enter
Sleep 600ms
Show

Sleep 1200ms
Type "echo 'todo' > notes.txt && git add notes.txt && echo '{ }' > package.json"
Enter
Sleep 1500ms
Type "bga config set git_status detail && bga config set contexts aws && bga reload"
Enter
Sleep 2000ms
Type "sleep 3; false"
Enter
Sleep 4500ms
Type "bga th"
Sleep 400ms
Tab
Sleep 600ms
Type "s"
Sleep 400ms
Tab
Sleep 600ms
Type "contrast"
Enter
Sleep 800ms
Type "bga reload"
Enter
Sleep 3000ms
