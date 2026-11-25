# tests/security.sh -- untrusted text must never be evaluated by the prompt.
#
# Branch names, commit subjects, directory names, version files and env names
# come from repositories the user may have just cloned. Any of them reaching
# PS1 unescaped would run `$(...)`/backticks on every prompt (promptvars) or
# inject terminal control sequences. Each scenario plants a payload, renders
# the prompt through ${PS1@P} (the same expansion the real prompt uses) and
# asserts that no canary file was created and the text is shown literally.
# shellcheck shell=bash disable=SC2016,SC1003  # payloads are literal on purpose

# Payload that creates ./<name> in the render's cwd if it is ever evaluated.
_sec_payload() { printf '$(touch${IFS}%s)' "$1"; }

scenario_security_branch_name() {
    section "security: branch name is not evaluated"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init" \
        && git checkout -qb "x$(_sec_payload PWNED_BR)")
    local out; out="$(bga_render "$d")"
    if [ -e "$d/PWNED_BR" ]; then fail "branch payload executed"; else ok "branch payload not executed"; fi
    assert_contains "$out" 'x$(touch${IFS}PWNED_BR)' "branch shown literally"
    rm -rf "$d"
}

scenario_security_commit_subject() {
    section "security: commit subject is not evaluated"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "s $(_sec_payload PWNED_MSG) \`touch PWNED_BT\` a\\b \\u !x")
    local out; out="$(bga_render "$d")"
    if [ -e "$d/PWNED_MSG" ]; then fail "subject \$() payload executed"; else ok "subject \$() payload not executed"; fi
    if [ -e "$d/PWNED_BT" ];  then fail "subject backtick payload executed"; else ok "subject backtick payload not executed"; fi
    assert_contains "$out" '$(touch${IFS}PWNED_MSG)' "subject \$() shown literally"
    assert_contains "$out" '`touch PWNED_BT`'        "subject backticks shown literally"
    assert_contains "$out" 'a\b \u !x'               "backslashes and ! shown literally"
    rm -rf "$d"
}

scenario_security_directory_name() {
    section "security: directory name is not evaluated"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    local dir; dir="$base/d$(_sec_payload PWNED_DIR)"
    mkdir -p "$dir"
    local out; out="$(bga_render "$dir")"
    if [ -e "$dir/PWNED_DIR" ]; then fail "directory payload executed"; else ok "directory payload not executed"; fi
    assert_contains "$out" 'd$(touch${IFS}PWNED_DIR)' "directory shown literally"
    rm -rf "$base"
}

scenario_security_version_file() {
    section "security: .python-version / .nvmrc content is not evaluated"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    _sec_payload PWNED_PY > "$base/.python-version"
    _sec_payload PWNED_NODE > "$base/.nvmrc"
    printf '{}\n' > "$base/package.json"
    bga_render "$base" >/dev/null
    if [ -e "$base/PWNED_PY" ];   then fail ".python-version payload executed"; else ok ".python-version payload not executed"; fi
    if [ -e "$base/PWNED_NODE" ]; then fail ".nvmrc payload executed"; else ok ".nvmrc payload not executed"; fi
    rm -rf "$base"
}

scenario_security_control_chars() {
    section "security: control characters are neutralized"
    local d; d="$(mktemp_repo)"
    # An OSC 0 (set title) sequence plus BEL hidden in the commit subject.
    (cd "$d" && git commit --allow-empty -qm "$(printf 'ok\033]0;PWNTITLE\007end')")
    local out; out="$(bga_render "$d")"
    assert_lacks    "$out" $'\033]0;PWNTITLE' "no raw OSC from subject"
    assert_contains "$out" 'end'              "rest of subject still shown"
    rm -rf "$d"
}

scenario_security_special_chars() {
    section "security: shell/prompt-special characters shown verbatim"
    local d; d="$(mktemp_repo)"
    # Quotes, & (patsub_replacement in bash 5.2+), ~, %, a trailing backslash.
    (cd "$d" && git commit --allow-empty -qm 'q "dq" '"'sq'"' & ~ %d \')
    local out; out="$(bga_render "$d")"
    assert_contains "$out" 'q "dq" '"'sq'"' & ~ %d \' "special chars verbatim"
    rm -rf "$d"
}

scenario_security_promptvars_off() {
    section "security: literal text with promptvars off"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm 'a\b $HOME !x')
    local out; out="$(bga_render "$d" "BGA_TEST_NOPROMPTVARS=1")"
    assert_contains "$out" 'a\b $HOME !x' "subject literal with promptvars off"
    rm -rf "$d"
}

scenario_security_async_cache_private() {
    section "security: async cache lives in a private directory"
    local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    local out
    # Shared-/tmp fallback (no XDG_RUNTIME_DIR): the cache dir must be fresh,
    # owned by us, mode 0700, and removed when the shell exits.
    out="$(env -u XDG_RUNTIME_DIR TMPDIR="$tmp" bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' BASHGITAWARE_ASYNC=1
        source '$REPO/new.bashrc'
        printf '%s|' \"\$_bga_async_cache\"
        stat -c '%a' \"\$_bga_async_dir\" 2>/dev/null || stat -f '%Lp' \"\$_bga_async_dir\"
    " 2>/dev/null)"
    case "$out" in
        "$tmp"/bga.*/cache\|700) ok "cache in private 0700 dir under TMPDIR" ;;
        *) fail "async cache not private (got: $out)" ;;
    esac
    local left; left="$(find "$tmp" -mindepth 1 2>/dev/null)"
    if [ -z "$left" ]; then ok "cache dir removed at exit"; else fail "cache leftovers: $left"; fi
    rm -rf "$tmp"
}

# Run __bga_state_dir_init in an interactive child with the given env and
# print "<state dir>|<mode>", or REFUSED.
_sec_state_dir() {
    env -u XDG_RUNTIME_DIR "$@" bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM=dumb LANG=C.UTF-8 BASHGITAWARE_ASYNC=0
        source '$REPO/new.bashrc'
        if __bga_state_dir_init; then
            printf '%s|' \"\$_bga_state_dir\"
            stat -c '%a' \"\$_bga_state_dir\" 2>/dev/null || stat -f '%Lp' \"\$_bga_state_dir\"
            __bga_state_dir_cleanup
        else
            printf 'REFUSED'
        fi
    " 2>/dev/null
}

scenario_security_state_dir() {
    section "security: state directory placement"
    local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    local priv="$tmp/xdg" open="$tmp/open" link="$tmp/link" out
    mkdir -m 700 "$priv" "$tmp/t"; mkdir -m 777 "$open"; ln -s "$priv" "$link"

    out="$(_sec_state_dir XDG_RUNTIME_DIR="$priv" TMPDIR="$tmp/t")"
    case "$out" in "$priv"/bga.*\|700) ok "private XDG_RUNTIME_DIR is used" ;; *) fail "private XDG not used (got: $out)" ;; esac

    out="$(_sec_state_dir XDG_RUNTIME_DIR="$open" TMPDIR="$tmp/t")"
    case "$out" in "$tmp/t"/bga.*\|700) ok "world-writable XDG_RUNTIME_DIR is refused" ;; *) fail "open XDG accepted (got: $out)" ;; esac

    out="$(_sec_state_dir XDG_RUNTIME_DIR="$link" TMPDIR="$tmp/t")"
    case "$out" in "$tmp/t"/bga.*\|700) ok "symlinked XDG_RUNTIME_DIR is refused" ;; *) fail "symlinked XDG accepted (got: $out)" ;; esac

    out="$(_sec_state_dir TMPDIR="$tmp/missing")"
    assert_contains "$out" "REFUSED" "no usable base directory -> refused"

    local left; left="$(find "$priv" "$tmp/t" -mindepth 1 2>/dev/null)"
    if [ -z "$left" ]; then ok "state dirs removed by cleanup"; else fail "leftovers: $left"; fi
    rm -rf "$tmp"
}

scenario_async_without_state_dir_falls_back() {
    section "async: no state directory -> synchronous, dirty still shown"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init; : > "$d/f"
    local out; out="$(TMPDIR="$d/missing" XDG_RUNTIME_DIR='' bga_render "$d" BASHGITAWARE_ASYNC=1)"
    assert_contains "$out" "●" "dirty marker shown without async cache"
    assert_lacks    "$out" "…" "no stuck pending indicator"
    rm -rf "$d"
}

# --- SR1 findings (2026-11-25) -----------------------------------------------

scenario_security_special_files() {
    section "security: version files that are devices or FIFOs do not hang the prompt"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    ln -s /dev/zero "$base/.python-version"
    ln -s /dev/zero "$base/.nvmrc"; printf '{}\n' > "$base/package.json"
    local rc=0
    timeout 10 bash -c "$(declare -f bga_render); REPO='$REPO'; bga_render '$base'" >/dev/null 2>&1 || rc=$?
    if [ "$rc" = 124 ]; then fail "prompt hangs on .python-version -> /dev/zero"; else ok "symlink to /dev/zero is skipped"; fi
    rm -rf "$base"
}

scenario_security_window_title() {
    section "security: directory names cannot inject sequences through the title"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-sec-XXXXXX")"
    local dir="$base/t"$'\a'"X"$'\e'"]52;c;aGk="$'\a'
    mkdir -p "$dir"
    local out; out="$(bga_render "$dir")"
    assert_lacks "$out" $'\e]52' "no OSC 52 from a directory name"
    rm -rf "$base"
}

scenario_security_fsmonitor() {
    section "security: core.fsmonitor from a hostile .git/config is never run"
    local d; d="$(mktemp_repo)"
    git -C "$d" config core.fsmonitor "touch '$d/PWNED_FSM'; false"
    bga_render "$d" >/dev/null
    bga_render "$d" BASHGITAWARE_ASYNC=1 >/dev/null
    if [ -e "$d/PWNED_FSM" ]; then fail "core.fsmonitor command ran"; else ok "core.fsmonitor command not run"; fi
    rm -rf "$d"
}

scenario_security_transient_line() {
    section "security: the transient prompt does not echo raw escape sequences"
    local out
    out="$(bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8'
        source '$REPO/new.bashrc'
        _bga_transient_active=1 _bga_transient_lines=1
        READLINE_LINE=\$'echo hi\e]52;c;aGk=\a\tx'
        __bga_transient_collapse
    " 2>/dev/null)"
    assert_lacks    "$out" $'\e]52' "no raw OSC 52 from the typed line"
    assert_contains "$out" "echo hi" "typed text still shown"
}

scenario_security_c1_in_c_locale() {
    section "security: C1 controls are stripped even in the C locale"
    local out
    out="$(LC_ALL=C bash --norc --noprofile -c "
        source '$REPO/lib/15-escape.bash'
        __bga_ps1_lit \$'a\xc2\x9b31mb'; printf '%s' \"\$REPLY\"" 2>/dev/null)"
    assert_lacks "$out" $'\xc2\x9b' "C1 CSI (C2 9B) removed under LC_ALL=C"
}
