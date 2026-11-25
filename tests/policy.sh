# tests/policy.sh -- the administrator policy file (ADR-0011).
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose
#
# Trust tests need root-owned files: tests/policy-fixtures.sh creates them
# under /etc/bga-policy-test (CI runs it as root). Without them those tests
# are skipped.

_PF=/etc/bga-policy-test

# Interactive bash: $1 = policy path (set unexported, the test seam), $2 =
# set-up before sourcing, $3 = commands after. stderr is kept.
_pol_run() {
    local h; h="$(mktemp -d "${TMPDIR:-/tmp}/bga-pol-XXXXXX")"; chmod 700 "$h"
    bash --norc --noprofile -i -c "
        export HOME='$h' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_MODE=full
        export BASHGITAWARE_CONFIG='$h/config'
        ${1:+_BGA_POLICY='$1'}
        $2
        source '$REPO/new.bashrc'
        $3
    " 2>&1 | grep -av -e 'cannot set terminal process group' -e 'no job control in this shell'
    rm -rf "$h"
}

_pol_have_fixtures() {
    [ -f "$_PF/ok/policy" ] && [ -n "$(find "$_PF/ok/policy" -maxdepth 0 -user 0 2>/dev/null)" ]
}

scenario_policy_untrusted_user_file() {
    section "policy: a file the user owns is never used (no root needed)"
    local d out; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-pol-XXXXXX")"
    printf 'theme = contrast\n' > "$d/policy"; chmod 644 "$d/policy"
    out="$(_pol_run "$d/policy" '' 'echo "theme=${BASHGITAWARE_THEME:-unset} state=$_bga_policy_state"')"
    assert_contains "$out" "theme=unset state=refused" "user-owned policy refused"
    assert_contains "$out" "policy ignored" "refusal warned"
    # The seam only works unexported: an exported path is ignored entirely.
    out="$(_pol_run '' "export _BGA_POLICY='$d/policy'" 'echo "state=$_bga_policy_state path=$_bga_policy_path"')"
    assert_contains "$out" "state=absent path=/etc/bash-gitaware/policy" "exported _BGA_POLICY ignored"
    rm -rf "$d"
    # Nothing at the default path: no cost beyond a test, doctor says none.
    out="$(_pol_run '' '' 'bga doctor')"
    if [ -e /etc/bash-gitaware/policy ]; then
        skip "doctor without a policy (/etc/bash-gitaware/policy exists here)"
    else
        assert_contains "$out" "info policy         none" "doctor: no policy"
    fi
}

scenario_policy_applied() {
    section "policy: locks keys above environment and user config"
    if ! _pol_have_fixtures; then skip "policy fixtures missing (run tests/policy-fixtures.sh as root)"; return; fi
    local out rc
    out="$(_pol_run "$_PF/ok/policy" 'export BASHGITAWARE_THEME=aware' \
        'echo "theme=$BASHGITAWARE_THEME glyphs=$BASHGITAWARE_GLYPHS locked=[$_bga_policy_locked]"')"
    assert_contains "$out" "theme=contrast glyphs=ascii locked=[ theme glyphs ]" "policy wins over the environment"
    assert_lacks    "$out" "bash-gitaware:" "clean policy: no warnings"

    out="$(_pol_run "$_PF/ok/policy" "printf 'theme = light\nclock = 1\n' > \"\$HOME/config\"; chmod 600 \"\$HOME/config\"" \
        'echo "theme=$BASHGITAWARE_THEME clock=$BASHGITAWARE_CLOCK"')"
    assert_contains "$out" "theme=contrast clock=1" "user config: locked key ignored, others applied"
    assert_lacks    "$out" "bash-gitaware:" "locked user line skipped silently at startup"

    out="$(_pol_run "$_PF/ok/policy" "printf 'theme = light\n' > \"\$HOME/config\"; chmod 600 \"\$HOME/config\"" \
        'bga config set theme aware; echo "rc=$?"; bga config unset glyphs; echo "rc=$?"; bga theme set light; echo "rc=$?"; bga config set clock 1; echo "rc=$?"; bga config list; bga doctor; echo "doctor=$?"')"
    assert_contains "$out" "'theme' is set by the administrator policy ($_PF/ok/policy)" "config set on a locked key names the policy"
    rc="$(printf '%s\n' "$out" | grep -c '^rc=1$')"
    if [ "$rc" = 3 ]; then ok "set, unset and theme set on locked keys exit 1"; else fail "locked writes: $rc of 3 exited 1"; fi
    assert_contains "$out" "rc=0" "an unlocked key can still be set"
    assert_contains "$out" "theme = light   (ignored: locked by policy)" "config list marks the locked line"
    assert_contains "$out" "ok   policy         $_PF/ok/policy (locks: theme, glyphs)" "doctor lists locked keys"
    assert_contains "$out" "your config sets theme; the policy wins" "doctor points at the shadowed line"
    assert_contains "$out" "doctor=0" "doctor exits 0 with an applied policy"

    # A root-owned symlinked directory on the path is fine (macOS /etc).
    out="$(_pol_run "$_PF/alias/policy" '' 'echo "theme=$BASHGITAWARE_THEME state=$_bga_policy_state real=$_bga_policy_real"')"
    assert_contains "$out" "theme=contrast state=applied" "root-owned directory symlink accepted"
    # SR5 F1: the file read is the physical path that was checked, so a
    # symlink on the way cannot be swapped between check and read.
    local phys; phys="$(cd -P "$_PF/ok" && pwd -P)"   # /private/etc on macOS
    assert_contains "$out" "real=$phys/policy" "the checked physical path is the one read"

    out="$(_pol_run "$_PF/badlines/policy" '' 'echo "theme=$BASHGITAWARE_THEME glyphs=${BASHGITAWARE_GLYPHS:-unset}"')"
    assert_contains "$out" "policy:3: unknown key 'bogus'" "bad policy line warned with its number"
    assert_contains "$out" "policy:4: invalid value for 'glyphs'" "invalid policy value warned"
    assert_contains "$out" "policy:5: expected key = value" "malformed policy line warned"
    assert_contains "$out" "theme=contrast glyphs=unset" "valid lines applied, invalid ones not locked"

    # bga reload keeps the policy on top.
    out="$(_pol_run "$_PF/ok/policy" '' 'export BASHGITAWARE_THEME=light; bga reload >/dev/null 2>&1; echo "theme=$BASHGITAWARE_THEME"')"
    assert_contains "$out" "theme=contrast" "policy still wins after bga reload"
    # A policy that no longer applies on reload leaves nothing behind: the
    # user config takes over again (the seam path stands in for a removal).
    out="$(_pol_run "$_PF/ok/policy" "printf 'theme = light\n' > \"\$HOME/config\"; chmod 600 \"\$HOME/config\"" \
        '_BGA_POLICY=/nonexistent/policy; bga reload >/dev/null 2>&1; echo "theme=$BASHGITAWARE_THEME glyphs=${BASHGITAWARE_GLYPHS:-unset} state=$_bga_policy_state"')"
    assert_contains "$out" "theme=light glyphs=unset state=absent" "removed policy: its values are gone after bga reload"
}

scenario_policy_refused() {
    section "policy: refused when anyone but root could change it"
    if ! _pol_have_fixtures; then skip "policy fixtures missing (run tests/policy-fixtures.sh as root)"; return; fi
    local c out rc
    # SR5 F2: a newline in a path name must not fool the check.
    out="$(_pol_run "$_PF/nl"$'\n'"x/policy" '' 'echo "theme=${BASHGITAWARE_THEME:-unset} state=$_bga_policy_state"')"
    assert_contains "$out" "theme=unset state=refused" "newline in a directory name: refused"
    for c in gw dirw link fifo unreadable acl; do
        if [ "$c" = acl ] && [ ! -e "$_PF/acl/policy" ]; then skip "policy acl: no ACL support here"; continue; fi
        out="$(run_bounded 10 _pol_run "$_PF/$c/policy" '' 'echo "theme=${BASHGITAWARE_THEME:-unset} state=$_bga_policy_state"; bga doctor >/dev/null 2>&1; echo "doctor=$?"')"; rc=$?
        if [ "$rc" = 124 ]; then fail "policy $c: shell hung"; continue; fi
        assert_contains "$out" "theme=unset state=refused" "policy $c: refused, nothing applied"
        assert_contains "$out" "policy ignored" "policy $c: warned"
        assert_contains "$out" "doctor=1" "policy $c: doctor exits 1"
    done
}
