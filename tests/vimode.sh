# tests/vimode.sh -- vi-mode indicator (3.1, S5; ADR-0012).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# readline variables after sourcing; $1 = set-up before sourcing, $2 = after.
# No `set -o vi` here: in `bash -i -c` without a tty, bash 4.4 to 5.2 crash
# after it (a bash bug, fixed in 5.3; real terminals are fine). The setup does
# not depend on the editing mode, and the pty test below runs real vi mode.
_vm_bind() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_MODE=full
        $1
        source '$REPO/new.bashrc'
        $2
        bind -v | grep -E 'show-mode-in-prompt|mode-string'
    " 2>/dev/null | sed -e $'s/\x1b/<E>/g' -e $'s/\x01/<1>/g' -e $'s/\x02/<2>/g'
}

scenario_vimode_setup() {
    section "vi-mode: readline mode strings"
    local out
    out="$(_vm_bind '' '')"
    assert_contains "$out" "show-mode-in-prompt on" "indicator turned on"
    assert_contains "$out" "vi-cmd-mode-string <1><E>[" "command-mode marker colored inside \\1 \\2"
    assert_contains "$out" "N<1><E>[0m<2> " "command-mode marker resets its color"
    assert_contains "$out" "emacs-mode-string "$'\n' "emacs string emptied (emacs mode unchanged)"

    out="$(_vm_bind "bind 'set show-mode-in-prompt on'" '')"
    assert_contains "$out" "vi-cmd-mode-string (cmd)" "user's show-mode-in-prompt: left alone"
    out="$(_vm_bind "bind 'set vi-cmd-mode-string \"[N]\"'" '')"
    assert_contains "$out" "vi-cmd-mode-string [N]" "user's own mode string: left alone"
    assert_contains "$out" "show-mode-in-prompt off" "user's own mode string: indicator not forced on"
    out="$(_vm_bind 'export BASHGITAWARE_VI_MODE=0' '')"
    assert_contains "$out" "show-mode-in-prompt off" "vi_mode = 0: nothing set"
    out="$(_vm_bind 'export BASHGITAWARE_MODE=plain' '')"
    assert_contains "$out" "show-mode-in-prompt off" "plain mode: nothing set"
    out="$(_vm_bind '' "export BASHGITAWARE_VI_MODE=0; source '$REPO/new.bashrc'")"
    assert_contains "$out" "show-mode-in-prompt off" "re-sourced with vi_mode = 0: defaults back"
    assert_contains "$out" "vi-cmd-mode-string (cmd)" "re-sourced with vi_mode = 0: default string back"
    # Strings the user changes after the first load survive a reload.
    out="$(_vm_bind '' "bind 'set vi-ins-mode-string \"[I]\"'; source '$REPO/new.bashrc'")"
    assert_contains "$out" "vi-ins-mode-string [I]" "user's later change kept across a reload"
}

scenario_vimode_pty() {
    section "vi-mode: readline draws the marker on a mode switch (pty)"
    if ! pty_ok; then
        skip "vi-mode pty run (needs script(1))"; return
    fi
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-vm-XXXXXX")"
    printf 'export BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0 TERM=xterm-256color\nset -o vi\nsource %q\n' "$REPO/new.bashrc" > "$d/rc"
    # ESC needs a pause after it, or readline reads ESC + i as Meta-i.
    out="$( { sleep 1; printf 'echo one'; sleep 0.3; printf '\033'; sleep 1; printf 'A two\r'; sleep 0.5; printf 'exit\r'; sleep 0.5; } \
        | HOME="$d" pty_run "bash --rcfile '$d/rc' -i" 2>&1)"
    case "$out" in *$'\e['*'mN'$'\e[0m '*) ok "command mode: colored N drawn by readline" ;;
                   *) fail "command mode: no marker in the pty output" ;; esac
    assert_contains "$out" "one two" "editing still works (ESC, A, typed text)"
    # The transient prompt still collapses the line after a vi-mode edit.
    # Without escapes, the edited line shows twice: as typed, and again when
    # the transient prompt collapses it (once if the collapse did not run).
    local plain n
    plain="$(printf '%s' "$out" | sed -E $'s/\x1b\\[[0-9;?]*[A-Za-z]//g; s/\x1b\\][^\a]*\a//g; s/\x1b[78]//g')"
    n="$(printf '%s' "$plain" | grep -oE '(❯|>) echo one two' | wc -l | tr -d ' ')"
    if [ "${n:-0}" -ge 2 ]; then ok "transient collapse after a vi-mode edit"; else fail "no transient collapse after a vi-mode edit ($n)"; fi
    rm -rf "$d"
}
