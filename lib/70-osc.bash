
# ---------------------------------------------------------------------------
# OSC integration: OSC 133 (semantic prompt marks) + OSC 7 (cwd reporting).
#
# Modern terminals (WezTerm, Kitty, VS Code, iTerm2, Ghostty, Konsole, Windows
# Terminal, Warp, ...) use these escapes to implement "jump to previous
# prompt", "select last command output", failed-prompt decorations, and
# "new tab inherits cwd". Terminals that don't grok them ignore the bytes.
#
# Lifecycle per prompt cycle:
#   * 133;A and 133;B are embedded in PS1 (wrapped in \[ \] for readline).
#   * 133;C is set via PS0 so it fires exactly once per user command, between
#     Enter and command execution. The DEBUG trap is not used for this: it
#     also fires for commands inside PROMPT_COMMAND, which would emit C at
#     the wrong moments.
#   * 133;D;<exit> and OSC 7 are emitted from PROMPT_COMMAND, before PS1 is
#     assembled, via __bga_osc_prompt_cycle_start.
#
# Disable all OSC emission with BASHGITAWARE_OSC=0.
# See docs/adr/ADR-0003-osc-133-and-osc-7-terminal-integration.md.
# ---------------------------------------------------------------------------

# Build a PS1-safe (escape-wrapped) OSC sequence in REPLY. Used by __bga_prompt
# to embed in the PS1 string for 133;A and 133;B.
# Sets REPLY (no subshell: this runs twice per prompt).
__bga_osc_ps1() {
    REPLY=''
    [ "${BASHGITAWARE_OSC:-1}" = 0 ] && return 0
    printf -v REPLY '\\[\e]%s\a\\]' "$1"
}

# Called from __bga_prompt at the start of each cycle: emit 133;D;<exit> (the
# just-finished command's end) and OSC 7 file://hostname/cwd.
#   $1 = exit code of the just-finished command
__bga_osc_prompt_cycle_start() {
    [ "${BASHGITAWARE_OSC:-1}" = 0 ] && return
    printf '\e]133;D;%s\a' "$1"
    local REPLY; __bga_term_safe "$PWD"
    printf '\e]7;file://%s%s\a' "${HOSTNAME:-localhost}" "$REPLY"
}

# 133;C: command begin. Set via PS0 so it fires exactly once per user command,
# at the right moment (after Enter, before execution). PS0 is expanded like
# PS1 but no \[ \] wrappers are needed (the line has been submitted; readline
# is no longer counting columns).
# The user's own PS0, if any, is kept after the mark; re-sourcing does not
# add the mark twice.
if [ "${BASHGITAWARE_OSC:-1}" != 0 ]; then
    case "${PS0:-}" in
        *$'\e]133;C\a'*) ;;
        *) PS0=$'\e]133;C\a'"${PS0:-}" ;;
    esac
fi

# ---------------------------------------------------------------------------
# OSC 9;4 taskbar progress (3.1, opt-in: progress = 1; ADR-0012). PS0 sets the
# indeterminate state when a command starts; the next prompt clears it, or
# shows the error state for one prompt after a failed command. Off with
# osc = 0, in plain mode, and inside tmux/screen, which do not pass it on.
# ---------------------------------------------------------------------------
# Turned off by a reload: PS0 has already set the busy state for the
# `bga reload` command itself, and no later prompt would clear it.
if [ "${_bga_progress:-0}" = 1 ]; then printf '\e]9;4;0;0\a'; fi
_bga_progress=0
if [ "${BASHGITAWARE_PROGRESS:-0}" = 1 ] && [ "${BASHGITAWARE_OSC:-1}" != 0 ] \
   && [ "${_bga_plain:-0}" != 1 ] && [ -z "${TMUX:-}" ] && [ -z "${STY:-}" ]; then
    _bga_progress=1
fi
# Re-sourcing (bga reload) adds the mark once, and removes it when off.
if [ -n "${PS0:-}" ]; then PS0="${PS0//$'\e]9;4;3;0\a'/}"; fi
if [ "$_bga_progress" = 1 ]; then PS0=$'\e]9;4;3;0\a'"${PS0:-}"; fi

# __bga_osc_progress_end <exit code> <1 if a command ran>
__bga_osc_progress_end() {
    [ "$_bga_progress" = 1 ] || return 0
    if [ "$2" = 1 ] && [ "$1" != 0 ]; then printf '\e]9;4;2;100\a'
    else printf '\e]9;4;0;0\a'; fi
}
