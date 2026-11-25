# tests/lean.sh -- the Lean layout (default style, ADR-0007).
# run.sh exports BASHGITAWARE_STYLE=classic for the v2 scenarios; these unset it.
# shellcheck shell=bash disable=SC2016  # payloads are literal on purpose

# Render dir $1 in Lean style; extra VAR=val pairs after it. $LEAN_PRE runs
# before __bga_prompt (e.g. to simulate a finished command).
_ln_render() {
    local dir="$1"; shift
    local kv prelude=''
    for kv in "$@"; do prelude+="export $kv; "; done
    env -u BASHGITAWARE_STYLE bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=80 BASHGITAWARE_ASYNC=0
        $prelude
        cd '$dir' 2>/dev/null
        source '$REPO/new.bashrc'
        ${LEAN_PRE:-}
        __bga_prompt
        printf '%s' \"\${PS1@P}\"
    " 2>/dev/null
}

# Strip escapes and readline markers to see what the user sees.
_ln_visible() {
    local s="${1//[$'\001\002']/}"
    s="$(printf '%s' "$s" | sed $'s/\e\\][^\a]*\a//g; s/\e\\[[0-9;]*[A-Za-z]//g; s/\e[78]//g')"
    printf '%s' "$s"
}

scenario_lean_layout() {
    section "lean: two lines, git on the left, symbol below"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init; : > "$d/dirty"
    local out vis; out="$(_ln_render "$d")"; vis="$(_ln_visible "$out")"
    assert_contains "$vis" "$(basename "$d")  main ●" "path, branch and dirty mark on line 1"
    assert_lacks    "$vis" " on "                     "no classic 'on' connector"
    assert_lacks    "$vis" "init"                     "commit subject off by default"
    local lines="${vis//[!$'\n']/}"
    if [ "${#lines}" = 1 ]; then ok "two lines"; else fail "expected 2 lines, got $(( ${#lines} + 1 ))"; fi
    case "$vis" in *$'\n❯ ') ok "symbol line" ;; *) fail "no symbol line ($(printf '%q' "$vis"))" ;; esac
    rm -rf "$d"
}

scenario_lean_right_block() {
    section "lean: right block aligned with cursor moves, dropped when narrow"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-ln-XXXXXX")"
    mkdir -p "$base/bin"; printf '{}\n' > "$base/package.json"
    printf '#!/bin/sh\necho v20.1.0\n' > "$base/bin/node"; chmod +x "$base/bin/node"
    local out
    out="$(PATH="$base/bin:$PATH" _ln_render "$base")"
    # "node 20.1.0" is 11 cells: column 80 - 11 + 1 = 70.
    assert_contains "$out" $'\e7\e[70G' "right block at column 70 of 80"
    assert_contains "$out" "node 20.1.0" "runtime in the right block"
    assert_contains "$out" $'\e8'       "cursor restored after the right block"
    out="$(PATH="$base/bin:$PATH" _ln_render "$base" COLUMNS=20)"
    assert_lacks    "$out" "node 20.1.0" "right block dropped on a narrow terminal"
    out="$(PATH="$base/bin:$PATH" _ln_render "$base" BASHGITAWARE_CLOCK=1)"
    case "$(_ln_visible "$out")" in *node\ 20.1.0\ ·\ [0-2][0-9]:[0-5][0-9]*) ok "clock after the runtime" ;;
        *) fail "clock missing ($(printf '%q' "$(_ln_visible "$out")"))" ;; esac
    rm -rf "$base"
}

scenario_lean_wide_path() {
    section "lean: right column uses display width, not string length"
    local base; base="$(mktemp -d "${TMPDIR:-/tmp}/bga-ln-XXXXXX")"
    mkdir -p "$base/bin" "$base/日本語"; printf '{}\n' > "$base/日本語/package.json"
    printf '#!/bin/sh\necho v20.1.0\n' > "$base/bin/node"; chmod +x "$base/bin/node"
    # 70 columns leave room for the wide left side even with a [container]
    # tag; the right block sits at 70 - 11 + 1 = 60 whatever the left holds.
    local out; out="$(PATH="$base/bin:$PATH" _ln_render "$base/日本語" COLUMNS=70)"
    assert_contains "$out" $'\e7\e[60G' "right block column independent of left text"
    rm -rf "$base"
}

scenario_lean_result_line() {
    section "lean: result line for failed or slow commands only"
    local out
    out="$(LEAN_PRE='_bga_timer_start=$(( SECONDS - 5 )); (exit 3)' _ln_render /tmp)"
    case "$(_ln_visible "$out")" in "  ✘3 · 5s"$'\n'*) ok "failed and slow: '  ✘3 · 5s' before the prompt" ;;
        *) fail "result line missing ($(printf '%q' "$(_ln_visible "$out")"))" ;; esac
    out="$(LEAN_PRE='(exit 3)' _ln_render /tmp)"
    assert_lacks "$out" "✘3" "no result line when nothing ran (empty Enter)"
    out="$(LEAN_PRE='_bga_timer_start=$SECONDS' _ln_render /tmp)"
    assert_lacks "$out" "✘" "no result line for a fast successful command"
    out="$(LEAN_PRE='_bga_timer_start=$SECONDS; (exit 2)' _ln_render /tmp BASHGITAWARE_GLYPHS=ascii)"
    assert_contains "$(_ln_visible "$out")" "  exit 2" "ascii glyphs: 'exit N'"
}

scenario_lean_untrusted() {
    section "lean: untrusted text is escaped"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init
    git -C "$d" checkout -qb 'b$(touch${IFS}PWNED_LEAN)'
    local out; out="$(_ln_render "$d")"
    if [ -e "$d/PWNED_LEAN" ]; then fail "lean: branch payload executed"; else ok "lean: branch payload not executed"; fi
    assert_contains "$out" 'b$(touch${IFS}PWNED_LEAN)' "lean: branch shown literally"
    rm -rf "$d"
}

scenario_lean_powerline() {
    section "lean: powerline separators only with Nerd Font glyphs"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm init
    local out
    out="$(_ln_render "$d" BASHGITAWARE_GLYPHS=nerd)"
    assert_contains "$out" $'' "nerd: thin separator between path and git"
    out="$(_ln_render "$d" BASHGITAWARE_GLYPHS=nerd BASHGITAWARE_POWERLINE=0)"
    assert_lacks    "$out" $'' "BASHGITAWARE_POWERLINE=0 turns it off"
    out="$(_ln_render "$d" BASHGITAWARE_GLYPHS=unicode)"
    assert_lacks    "$out" $'' "no Nerd Font: no powerline glyphs"
    rm -rf "$d"
}
