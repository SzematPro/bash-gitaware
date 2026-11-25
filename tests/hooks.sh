# tests/hooks.sh -- bash-gitaware must coexist with the user's own hooks.
#
# Real ~/.bashrc files already have PROMPT_COMMAND entries (history -a, direnv,
# VTE), DEBUG/EXIT traps and sometimes PS0. Sourcing bash-gitaware must keep
# them working, be idempotent, and leave PROMPT_COMMAND/PS0/PS1 unexported.
# shellcheck shell=bash disable=SC2016  # child-shell scripts are single-quoted on purpose

# Run a script in an interactive child: $1 runs before sourcing, $2 after.
_hk_run() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_ASYNC=0
        $1
        source '$REPO/new.bashrc'
        $2
    " 2>&1 | grep -av -e 'cannot set terminal process group' -e 'no job control in this shell'
}

scenario_hooks_prompt_command_string() {
    section "hooks: existing PROMPT_COMMAND string is kept"
    local out
    out="$(_hk_run "_uh() { _seen=\$?; }; PROMPT_COMMAND='_uh; history -a;'" '
        (exit 3); eval "$PROMPT_COMMAND"
        printf "seen=%s\n" "$_seen"
        printf "pc=%s\n" "${PROMPT_COMMAND//$'"'"'\n'"'"'/ | }"
        case "$PS1" in *133\;A*) echo "ps1=built" ;; esac')"
    assert_contains "$out" "seen=3"        "user hook still sees the command's exit status"
    assert_contains "$out" "ps1=built"     "bash-gitaware prompt still built"
    assert_contains "$out" 'pc=_bga_exit=$? _bga_in_pc=1 | __bga_pre "${_bga_dbg_done-$(trap -p DEBUG)}" | _uh; history -a; | __bga_prompt' "order: ours, user hooks, prompt"
}

scenario_hooks_prompt_command_comment() {
    section "hooks: a trailing comment or & in PROMPT_COMMAND does not break the prompt"
    local out pc
    for pc in 'history -a # keep history' 'true &'; do
        out="$(_hk_run "PROMPT_COMMAND='$pc'" 'PS1=unset; eval "$PROMPT_COMMAND" 2>&1; case "$PS1" in unset) echo "prompt=missing" ;; *) echo "prompt=built" ;; esac')"
        assert_contains "$out" "prompt=built" "PROMPT_COMMAND='$pc'"
        assert_lacks    "$out" "syntax error" "PROMPT_COMMAND='$pc': no syntax error"
    done
}

scenario_hooks_prompt_command_array() {
    section "hooks: existing PROMPT_COMMAND array is kept (bash 5.1+)"
    if ! bash -c 'PROMPT_COMMAND=(a b); [ "${BASH_VERSINFO[0]}${BASH_VERSINFO[1]}" -ge 51 ]' 2>/dev/null; then
        skip "PROMPT_COMMAND arrays need bash 5.1"; return
    fi
    local out
    out="$(_hk_run "PROMPT_COMMAND=('history -a' '_x=1')" 'printf "<%s>" "${PROMPT_COMMAND[@]}"')"
    assert_contains "$out" '<__bga_pre "${_bga_dbg_done-$(trap -p DEBUG)}"><history -a><_x=1><__bga_prompt>' "array order: ours, user hooks, prompt"
}

scenario_hooks_idempotent() {
    section "hooks: sourcing twice changes nothing"
    local out
    out="$(_hk_run "PROMPT_COMMAND='history -a'; trap 'echo user-dbg >/dev/null' DEBUG" '
        eval "$PROMPT_COMMAND"
        a="$PROMPT_COMMAND|$(trap -p DEBUG)|$(trap -p EXIT)|$PS0"
        source "'"$REPO"'/new.bashrc"
        eval "$PROMPT_COMMAND"
        b="$PROMPT_COMMAND|$(trap -p DEBUG)|$(trap -p EXIT)|$PS0"
        [ "$a" = "$b" ] && echo same || printf "differs:\n%s\n%s\n" "$a" "$b"')"
    assert_contains "$out" "same" "second source is a no-op"
}

scenario_hooks_traps_chained() {
    section "hooks: existing DEBUG / EXIT traps are kept"
    local out
    out="$(_hk_run "trap 'echo user-debug >/dev/null' DEBUG; trap 'echo user-exit' EXIT" 'eval "$PROMPT_COMMAND"; trap -p DEBUG; echo bye' )"
    assert_contains "$out" "__bga_timer_start" "DEBUG trap has the timer"
    assert_contains "$out" "user-debug"        "DEBUG trap keeps the user's command"
    assert_contains "$out" "user-exit"         "user's EXIT trap still runs"
}

scenario_hooks_bash_preexec() {
    section "hooks: with bash-preexec, the timer uses preexec_functions"
    local out
    out="$(_hk_run "declare -a preexec_functions=(user_fn); trap 'bp_debug' DEBUG" '
        eval "$PROMPT_COMMAND"; source "'"$REPO"'/new.bashrc"; eval "$PROMPT_COMMAND"
        printf "<%s>" "${preexec_functions[@]}"; echo; trap -p DEBUG')"
    assert_contains "$out" "<user_fn><__bga_timer_start>" "timer added once to preexec_functions"
    assert_contains "$out" "trap -- 'bp_debug' DEBUG"     "bash-preexec's DEBUG trap untouched"
}

scenario_hooks_async_exit_chained() {
    section "hooks: async EXIT cleanup chains with the user's EXIT trap"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_ASYNC=1
        trap 'echo user-exit' EXIT
        source '$REPO/new.bashrc'
        trap -p EXIT
    " 2>/dev/null)"
    assert_contains "$out" "__bga_async_cleanup" "EXIT trap has the async cleanup"
    assert_contains "$out" "user-exit"           "EXIT trap keeps the user's command"
}

scenario_hooks_ps0_and_exports() {
    section "hooks: PS0 kept, PROMPT_COMMAND/PS0/PS1 not exported"
    local out
    out="$(_hk_run "export PS0='[user-ps0]' PS1='x' PROMPT_COMMAND='history -a'" '
        printf "ps0=%q\n" "$PS0"
        bash --norc --noprofile -c '"'"'echo "child:${PROMPT_COMMAND-unset}:${PS0-unset}:${PS1-unset}"'"'"'')"
    assert_contains "$out" "[user-ps0]"                  "user's PS0 kept"
    assert_contains "$out" "133;C"                       "OSC 133;C added to PS0"
    assert_contains "$out" "child:unset:unset:unset"     "child shells do not inherit them"
}
