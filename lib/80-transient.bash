
# ---------------------------------------------------------------------------
# Transient prompt -- collapse the previous prompt to a one-line form on submit.
#
# Strategy: bind -x to an auxiliary chord (\C-x\C-t) runs the collapse function;
# then remap Enter (\C-m) to a readline macro "\C-x\C-t\C-j": collapse, then
# accept-line via \C-j (default-bound to accept-line, distinct from \C-m so
# we do not recurse into our own remap).
#
# At submit time the cursor is on the last line of the just-shown prompt.
# We move the cursor up to the start of the prompt, clear to end of screen,
# then reprint "<symbol> <typed-command>" colored by the previous exit code.
# accept-line then echoes \n and the command runs as usual; the modern terminal
# (via OSC 133;C from PS0) still gets the command-start mark in the right place.
#
# The reprinted form includes READLINE_LINE so scrollback stays useful: each
# collapsed prompt is "❯ <command>", not just "❯" -- matches Powerlevel10k.
# (This refines ADR-0004 step 2: the original 'minimal form ("❯ only")' was
# directional; in practice the typed command must remain visible in scrollback.)
#
# Knob: BASHGITAWARE_TRANSIENT=0 disables. Honored at source time (the bind is
# not installed) and at call time (the function short-circuits if the var was
# set after sourcing).
#
# Edge cases (per ADR-0004; see also tests/MANUAL.md):
#   - First prompt: _bga_transient_active starts 0; __bga_prompt sets it to 1
#     after the first render. Until then the collapse is a no-op.
#   - Empty submit (Enter on empty buffer): READLINE_LINE is empty; transient
#     reads "❯ ".
#   - Ctrl-C at the prompt: readline discards the line, our bind does not fire,
#     the full prompt stays on screen until the next prompt redraws.
#   - clear: collapse fires, then `clear` wipes the screen; final state clean.
#   - Multi-line typed input (\<Enter> continuation) or terminal resize between
#     render and submit: the recorded line count can be stale; acceptable
#     misalignment, the next prompt re-syncs.
#
# See docs/adr/ADR-0004-transient-prompt.md.
# ---------------------------------------------------------------------------

_bga_transient_lines=0
_bga_transient_exit=0
_bga_transient_active=0

__bga_transient_collapse() {
    [ "${BASHGITAWARE_TRANSIENT:-1}" = 0 ] && return 0
    [ "${_bga_transient_active:-0}" = 1 ] || return 0

    local up=$(( ${_bga_transient_lines:-1} - 1 ))
    [ "$up" -lt 0 ] && up=0

    local color reset
    reset=$'\e[0m'
    if [ "${_bga_transient_exit:-0}" -eq 0 ]; then
        color=$'\e[1;32m'
    else
        color=$'\e[1;31m'
    fi

    local sym="${_g_sym:-❯}"

    if [ "$up" -gt 0 ]; then
        printf '\r\e[%dA\e[J%s%s%s %s' "$up" "$color" "$sym" "$reset" "${READLINE_LINE:-}"
    else
        printf '\r\e[J%s%s%s %s' "$color" "$sym" "$reset" "${READLINE_LINE:-}"
    fi
}

# Install the Enter remap once at source time, only in interactive shells.
# The auxiliary chord \C-x\C-t carries our function; \C-m runs it then \C-j
# (default-bound to accept-line) submits the line.
if [ "${BASHGITAWARE_TRANSIENT:-1}" != 0 ] && [[ $- == *i* ]]; then
    bind -x '"\C-x\C-t": __bga_transient_collapse' 2>/dev/null
    bind '"\C-m": "\C-x\C-t\C-j"' 2>/dev/null
fi
