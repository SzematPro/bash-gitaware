# tests/complete.sh -- bash completion for bga (3.2, C1).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# COMPREPLY for the words given, as "[a] [b] ".
_cp_run() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' BASHGITAWARE_MODE=full
        source '$REPO/new.bashrc'
        t() { COMP_WORDS=(\"\$@\"); COMP_CWORD=\$(( \$# - 1 )); __bga_complete; printf '[%s] ' \"\${COMPREPLY[@]}\"; echo; }
        $1
    " 2>/dev/null
}

scenario_complete_positions() {
    section "completion: every position of bga"
    local out
    out="$(_cp_run 't bga ""')";                  assert_contains "$out" "[config] [theme] [doctor] [reload] [version] [help]" "subcommands"
    out="$(_cp_run 't bga config ""')";           assert_contains "$out" "[path] [list] [get] [set] [unset] [edit]" "config subcommands"
    out="$(_cp_run 't bga theme s')";             assert_contains "$out" "[set]" "theme subcommand prefix"
    out="$(_cp_run 't bga config get sh')";       assert_contains "$out" "[show_host] [shell_defaults]" "keys from the key table"
    out="$(_cp_run 't bga config set style ""')"; assert_contains "$out" "[lean] [classic]" "enum values"
    out="$(_cp_run 't bga config set clock ""')"; assert_contains "$out" "[0] [1]" "bool values"
    out="$(_cp_run 't bga config set theme ""')"; assert_contains "$out" "[aware] [contrast] [light]" "theme names"
    out="$(_cp_run 't bga config set runtimes py,r')"; assert_contains "$out" "[py,rust] [py,ruby]" "list item after the last comma"
    out="$(_cp_run 't bga config set path_maxdepth ""')"
    if [ "$out" = '[] ' ]; then ok "numbers: no candidates"; else fail "numbers: got '$out'"; fi
    out="$(_cp_run 't bga config list -')";       assert_contains "$out" "[--all]" "list --all"
    # A completion the user set is kept; plain mode registers none.
    out="$(bash --norc --noprofile -i -c "export HOME='$HOME' BASHGITAWARE_MODE=full; complete -W mine bga; source '$REPO/new.bashrc'; complete -p bga" 2>/dev/null)"
    assert_contains "$out" "complete -W 'mine' bga" "user's completion for bga kept"
    out="$(bash --norc --noprofile -i -c "export HOME='$HOME' BASHGITAWARE_MODE=plain; source '$REPO/new.bashrc'; complete -p bga || echo none" 2>/dev/null)"
    assert_contains "$out" "none" "plain mode: no completion registered"
}

scenario_complete_pty() {
    section "completion: TAB in a real line editor (pty)"
    if ! pty_ok; then skip "completion pty run (needs script(1))"; return; fi
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-cp-XXXXXX")"
    printf 'export BASHGITAWARE_MODE=full BASHGITAWARE_ASYNC=0 TERM=xterm-256color\nsource %q\n' "$REPO/new.bashrc" > "$d/rc"
    out="$( { sleep 1; printf 'bga conf\t'; sleep 0.5; printf 'pa\t'; sleep 0.5; printf '\r'; sleep 0.5; printf 'exit\r'; sleep 0.5; } \
        | HOME="$d" pty_run "bash --rcfile '$d/rc' -i" 2>&1)"
    assert_contains "$out" "bga config path" "TAB completes subcommand and config subcommand"
    rm -rf "$d"
}
