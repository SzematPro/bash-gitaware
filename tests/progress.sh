# tests/progress.sh -- OSC 9;4 taskbar progress (3.1, S7; ADR-0012).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Interactive bash with the full prompt; $1 = set-up, $2 = commands after
# sourcing. Output is made visible: ESC -> '<E>', BEL -> '<B>'.
_pg_run() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0
        unset TMUX STY
        $1
        source '$REPO/new.bashrc'
        $2
    " 2>/dev/null | sed -e $'s/\x1b/<E>/g' -e $'s/\a/<B>/g'
}

scenario_progress_osc94() {
    section "progress: OSC 9;4 while a command runs (opt-in)"
    local on='export BASHGITAWARE_PROGRESS=1' out
    out="$(_pg_run "$on; PS0='USER-PS0'" 'printf "ps0=%s\n" "$PS0"')"
    assert_contains "$out" "ps0=<E>]9;4;3;0<B>" "PS0 starts the indeterminate state"
    assert_contains "$out" "USER-PS0" "the user's PS0 is kept"

    out="$(_pg_run "$on" '_bga_timer_start=$SECONDS; false; __bga_prompt; echo; _bga_timer_start=$SECONDS; true; __bga_prompt; echo; __bga_prompt' )"
    assert_contains "$out" "<E>]9;4;2;100<B>" "a failed command shows the error state"
    case "$out" in *'<E>]9;4;2;100<B>'*'<E>]9;4;0;0<B>'*'<E>]9;4;0;0<B>'*) ok "success and an empty Enter clear it" ;;
                   *) fail "progress not cleared after success / empty Enter" ;; esac

    out="$(_pg_run "$on" 'false; __bga_prompt')"
    assert_lacks "$out" "9;4;2" "no error state when no command ran (empty Enter after a failure)"

    # Re-sourcing with progress off removes the mark from PS0.
    out="$(_pg_run "$on" "unset BASHGITAWARE_PROGRESS; source '$REPO/new.bashrc'; printf 'ps0=[%s]\\n' \"\${PS0:-}\"" | sed 's/<E>]133;C<B>//')"
    assert_contains "$out" "ps0=[]" "re-sourced with progress off: mark removed"

    # Turning progress off with a reload clears the busy state that PS0 set
    # for the reload command itself.
    out="$(_pg_run "$on" "unset BASHGITAWARE_PROGRESS; source '$REPO/new.bashrc'")"
    assert_contains "$out" "<E>]9;4;0;0<B>" "reload that turns progress off clears the taskbar"
    local c
    for c in '' 'export BASHGITAWARE_OSC=0' 'export BASHGITAWARE_MODE=plain' 'export TMUX=/tmp/tmux-1/default,1,0' 'export STY=1.pts-0'; do
        out="$(_pg_run "${c:+$c; }${c:+$on}${c:-}" '_bga_timer_start=$SECONDS; false; __bga_prompt; printf "ps0=%s\n" "${PS0:-}"')"
        assert_lacks "$out" "9;4" "no OSC 9;4 with: ${c:-progress unset}"
    done
}
