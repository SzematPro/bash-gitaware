# tests/lib.sh -- shared helpers for the bash-gitaware test suite.
#
# Sourced by run.sh; scenarios.sh and perf.sh use the helpers defined here.
# shellcheck shell=bash

# Project root (absolute). Computed from this file's location.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test counters.
_passed=0
_failed=0
_skipped=0
_failures=()

ok()      { _passed=$(( _passed + 1 )); printf '  OK   %s\n' "$1"; }
fail()    { _failed=$(( _failed + 1 )); _failures+=("$1"); printf '  FAIL %s\n' "$1"; }
skip()    { _skipped=$(( _skipped + 1 )); printf '  SKIP %s\n' "$1"; }
section() { printf '\n== %s ==\n' "$1"; }

# Assert a substring is present in $1.
#   assert_contains "<haystack>" "<needle>" "<label>"
assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    case "$haystack" in
        *"$needle"*) ok "$label: contains $(printf '%q' "$needle")" ;;
        *) fail "$label: missing $(printf '%q' "$needle") (got: $(printf '%q' "$haystack"))" ;;
    esac
}

# Assert a substring is absent in $1.
assert_lacks() {
    local haystack="$1" needle="$2" label="$3"
    case "$haystack" in
        *"$needle"*) fail "$label: should NOT contain $(printf '%q' "$needle") (got: $(printf '%q' "$haystack"))" ;;
        *) ok "$label: lacks $(printf '%q' "$needle")" ;;
    esac
}

# Remove prompt state inherited from the developer's own shell (a v2 prompt
# exports some _bga_* variables; BASHGITAWARE_* knobs would change renders).
# Child shells only inherit exported variables, so unsetting them here keeps
# every render in the suite deterministic. NO_COLOR is dropped for the same
# reason, and so is COLORTERM (it selects 24-bit colors); scenarios that need
# them set them explicitly.
sandbox_scrub() {
    local v
    for v in $(compgen -v); do
        case "$v" in _bga_* | _BGA_* | BASHGITAWARE_* | NO_COLOR | COLORTERM) unset "$v" ;; esac
    done
}

# Run a command with a time limit, without timeout(1) (stock macOS has none).
# Returns 124 if it had to be killed, else the command's status.
#   run_bounded <seconds> <cmd> [args...]
run_bounded() {
    local lim="$1" p w rc; shift
    "$@" &
    p=$!
    { sleep "$lim"; kill -KILL "$p"; } >/dev/null 2>&1 &
    w=$!
    wait "$p"; rc=$?
    if kill -0 "$w" 2>/dev/null; then kill "$w" 2>/dev/null; wait "$w" 2>/dev/null; return "$rc"; fi
    return 124
}

# Pseudo-terminal runs through script(1), which comes in two dialects:
# util-linux (`script -qc CMD /dev/null`) and BSD/macOS
# (`script -q /dev/null sh -c CMD`). pty_ok says whether either works;
# pty_run "<shell command>" runs the command on a pty, stdin passed through.
_pty_kind=''
pty_ok() {
    if [ -z "$_pty_kind" ]; then
        _pty_kind=none
        if command -v script >/dev/null 2>&1; then
            if script -qc true /dev/null >/dev/null 2>&1 </dev/null; then _pty_kind=util
            elif script -q /dev/null true >/dev/null 2>&1 </dev/null; then _pty_kind=bsd
            fi
        fi
    fi
    [ "$_pty_kind" != none ]
}
pty_run() {
    pty_ok || return 127
    case "$_pty_kind" in
        util) script -qc "$1" /dev/null ;;
        bsd)  script -q /dev/null sh -c "$1" ;;
    esac
}

# Create a fresh empty git repo in a temp dir. Echoes the dir path.
mktemp_repo() {
    local d; d="$(mktemp -d "${TMPDIR:-/tmp}/bga-test-XXXXXX")"
    git -C "$d" init -q -b main
    git -C "$d" config user.email test@example.com
    git -C "$d" config user.name "BGA Test"
    printf '%s' "$d"
}

# Render bash-gitaware's PS1 in $1 with optional env vars. Stdout is the
# expanded PS1 (with ANSI escapes preserved). Stderr is silenced.
#   bga_render <dir> [VAR=val ...]
#
# Note: defaults BASHGITAWARE_ASYNC=0 unless the caller sets it explicitly.
# Async is a "deferred refresh on the next prompt" path (see ADR-0005); a
# single-render call returns the cheap-only snapshot, which is correct for
# the async-specific tests but defeats the assertions of the sync scenarios
# (dirty marker, ahead/behind counters, ...). Async-specific tests pass
# "BASHGITAWARE_ASYNC=1" explicitly.
bga_render() {
    local dir="$1"; shift
    local kv prelude="" has_async=0
    for kv in "$@"; do
        case "$kv" in BASHGITAWARE_ASYNC=*) has_async=1 ;; esac
        prelude+="export $kv; "
    done
    [ "$has_async" = 0 ] && prelude="export BASHGITAWARE_ASYNC=0; $prelude"
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        $prelude
        cd '$dir' 2>/dev/null
        source '$REPO/new.bashrc'
        if [ -n \"\${BGA_TEST_NOPROMPTVARS:-}\" ]; then shopt -u promptvars; fi
        __bga_prompt
        printf '%s' \"\${PS1@P}\"
    " 2>/dev/null
}

# Sanity test that we can lint each lib/ module on its own (syntax check).
lib_syntax_check() {
    section "lib/ module syntax"
    local f
    for f in "$REPO"/lib/[0-9][0-9]-*.bash; do
        if bash -n "$f" 2>/dev/null; then
            ok "syntax: $(basename "$f")"
        else
            fail "syntax: $(basename "$f")"
        fi
    done
}

# Verify new.bashrc is up to date with lib/.
build_freshness_check() {
    section "build freshness"
    local tmp; tmp="$(mktemp)"
    if bash "$REPO/bin/build.sh" >/dev/null 2>&1 && diff -q "$tmp" "$REPO/new.bashrc" >/dev/null 2>&1; then
        ok "new.bashrc matches build output"
    elif [ -f "$REPO/new.bashrc" ]; then
        # Re-run build into a tmp file directly for a more accurate check.
        local out_tmp; out_tmp="$(mktemp)"
        {
            # shellcheck disable=SC2016
            printf '%s\n' '# Generated by bin/build.sh -- do not edit. Edit lib/*.bash and run `make build`.'
            printf '%s\n' '# shellcheck shell=bash'
            cat "$REPO"/lib/[0-9][0-9]-*.bash
        } > "$out_tmp"
        if diff -q "$out_tmp" "$REPO/new.bashrc" >/dev/null 2>&1; then
            ok "new.bashrc matches build output"
        else
            fail "new.bashrc out of date -- run 'make build' and commit"
        fi
        rm -f "$out_tmp"
    fi
    rm -f "$tmp"
}
