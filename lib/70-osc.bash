
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

# Emit a PS1-safe (escape-wrapped) OSC sequence on stdout. Used by __bga_prompt
# to embed in the PS1 string for 133;A and 133;B.
__bga_osc_ps1() {
    [ "${BASHGITAWARE_OSC:-1}" = 0 ] && return
    printf '\\[\e]%s\a\\]' "$1"
}

# Called from __bga_prompt at the start of each cycle: emit 133;D;<exit> (the
# just-finished command's end) and OSC 7 file://hostname/cwd.
#   $1 = exit code of the just-finished command
__bga_osc_prompt_cycle_start() {
    [ "${BASHGITAWARE_OSC:-1}" = 0 ] && return
    printf '\e]133;D;%s\a' "$1"
    printf '\e]7;file://%s%s\a' "${HOSTNAME:-localhost}" "$PWD"
}

# 133;C: command begin. Set via PS0 so it fires exactly once per user command,
# at the right moment (after Enter, before execution). PS0 is expanded like
# PS1 but no \[ \] wrappers are needed (the line has been submitted; readline
# is no longer counting columns).
if [ "${BASHGITAWARE_OSC:-1}" != 0 ]; then
    PS0=$'\e]133;C\a'
fi
