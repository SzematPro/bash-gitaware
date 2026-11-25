# tests/plain.sh -- plain mode for dumb terminals, CI and automated agents.
#
# Generic signals only (TERM=dumb, no tty, CI, AGENT, AI_AGENT, or
# BASHGITAWARE_MODE=plain) switch to a one-line ASCII prompt with no escape
# sequences; BASHGITAWARE_MODE=full overrides the detection. run.sh exports
# BASHGITAWARE_MODE=full for every other test, so each case here unsets it.
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Render with BASHGITAWARE_MODE removed; extra VAR=val pairs are exported.
_pl_render() {
    local dir="$1"; shift
    env -u BASHGITAWARE_MODE bash -c "$(declare -f bga_render); REPO='$REPO'; bga_render \"\$@\"" _ "$dir" "$@"
}

_pl_assert_plain() {
    local out="$1" label="$2"
    case "$out" in *$'\e'*) fail "$label: has escape sequences ($(printf '%q' "$out"))"; return ;; esac
    case "$out" in *$'\n'*) fail "$label: more than one line ($(printf '%q' "$out"))"; return ;; esac
    case "$out" in *'$ ' | *'# ') ok "$label: one ASCII line ending in the prompt symbol" ;;
                   *) fail "$label: unexpected form ($(printf '%q' "$out"))" ;; esac
}

scenario_plain_mode() {
    section "plain mode: detection and output"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init; : > "$d/dirty"
    local name; name="$(basename "$d")"
    local out

    out="$(_pl_render "$d")"                       # tests run without a tty
    _pl_assert_plain "$out" "no tty"
    assert_contains "$out" "$name (main *)"        "plain shows repo, branch and dirty mark"

    out="$(_pl_render "$d" BASHGITAWARE_MODE=plain)"
    _pl_assert_plain "$out" "BASHGITAWARE_MODE=plain"

    out="$(_pl_render "$d" TERM=dumb BASHGITAWARE_MODE=auto)"
    _pl_assert_plain "$out" "TERM=dumb"

    out="$(_pl_render "$d" CI=true BASHGITAWARE_MODE=full)"
    case "$out" in *$'\e'*) ok "BASHGITAWARE_MODE=full overrides detection" ;;
                   *) fail "MODE=full still plain ($(printf '%q' "$out"))" ;; esac

    rm -rf "$d"
}

scenario_plain_mode_escaping() {
    section "plain mode: untrusted text"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init
    git -C "$d" checkout -qb 'b$(touch${IFS}PWNED_PLAIN)'
    local out
    out="$(env -u BASHGITAWARE_MODE bash -c "
        $(declare -f bga_render); REPO='$REPO'
        bga_render '$d' BASHGITAWARE_MODE=plain" )"
    if [ -e "$d/PWNED_PLAIN" ]; then fail "plain: branch payload executed"; else ok "plain: branch payload not executed"; fi
    assert_contains "$out" 'b$(touch${IFS}PWNED_PLAIN)' "plain: branch shown literally"
    rm -rf "$d"
}
