# tests/shellstate.sh -- the prompt must not depend on the user's shell options.
#
# Users source bash-gitaware into shells with all sorts of shopt/set state.
# Each scenario renders the same repo with one option flipped (before and
# after sourcing) and compares it with a baseline render.
# shellcheck shell=bash

# Render with a prelude run before sourcing and a postlude run after it.
# stderr is kept (an option that breaks the prompt usually prints an error);
# only the job-control notices of a tty-less bash -i are dropped.
#   _ss_render <dir> <prelude> <postlude>
_ss_render() {
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_ASYNC=0
        cd '$1' || exit 1
        $2
        source '$REPO/new.bashrc'
        $3
        __bga_prompt
        printf '%s' \"\${PS1@P}\"
    " 2>&1 | grep -av -e 'cannot set terminal process group' -e 'no job control in this shell'
}

scenario_shell_state_independence() {
    section "shell options do not change the prompt"
    local d; d="$(mktemp_repo)"
    mkdir -p "$d/src/deep"; : > "$d/src/deep/x.txt"
    git -C "$d" add -A; git -C "$d" commit -qm 'feat: a * b ? [c] & d'
    : > "$d/untracked"
    local base; base="$(_ss_render "$d/src/deep" '' '')"
    # The baseline must be a real render, or every comparison is vacuous.
    assert_contains "$base" "main"       "baseline shows the branch"
    assert_contains "$base" "●"          "baseline shows the dirty marker"
    assert_contains "$base" "src/deep"   "baseline shows the repo path"
    assert_lacks    "$base" "bash:"      "baseline has no shell errors"
    local opt out
    for opt in extglob nullglob failglob nocaseglob nocasematch globstar dotglob \
               expand_aliases patsub_replacement xpg_echo; do
        if ! bash -c "shopt -s $opt" >/dev/null 2>&1; then skip "shopt $opt (not in this bash)"; continue; fi
        out="$(_ss_render "$d/src/deep" "shopt -s $opt" "shopt -s $opt")"
        if [ "$out" = "$base" ]; then ok "shopt -s $opt"; else fail "shopt -s $opt changes the prompt: $(printf '%q' "$out")"; fi
    done
    for opt in 'set -f' 'set -u' 'set -o posix' 'IFS=:' 'LC_ALL=C.UTF-8'; do
        out="$(_ss_render "$d/src/deep" "$opt" "$opt")"
        if [ "$out" = "$base" ]; then ok "$opt"; else fail "'$opt' changes the prompt: $(printf '%q' "$out")"; fi
    done
    rm -rf "$d"
}

scenario_shellstate_failglob_exit() {
    section "shell state: no error at exit with failglob"
    local out
    out="$(bash --norc --noprofile -i -c "export HOME='$HOME' PATH='$PATH' BASHGITAWARE_MODE=full; shopt -s failglob; source '$REPO/new.bashrc'; __bga_prompt >/dev/null; exit" 2>&1)"
    assert_lacks "$out" "no match" "state directory cleanup does not glob"
}

