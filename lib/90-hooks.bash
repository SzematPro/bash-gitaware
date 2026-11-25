# ---------------------------------------------------------------------------
# Hooks. bash-gitaware shares the shell with the user's own hooks (history -a,
# direnv, VTE, bash-preexec, ...), so it adds itself without replacing them:
#   * PROMPT_COMMAND: our head first (saves the exit status and hands it on),
#     the user's hooks next, __bga_prompt last (so it sees their effects and
#     resets the timer after the DEBUG trap has fired for all of them);
#   * DEBUG / EXIT traps: our command first, then the existing one;
#   * with bash-preexec loaded, the timer goes into preexec_functions instead
#     of the DEBUG trap, which bash-preexec owns;
#   * PROMPT_COMMAND, PS0 and PS1 are unexported (ruling L-42): child shells
#     do not have our functions.
# Every step is idempotent, so sourcing the file twice changes nothing.
#
# Why the DEBUG trap is installed on the first prompt and not here: while a
# file is being sourced (and inside any function) bash hides the user's DEBUG
# trap, so `trap -p DEBUG` cannot see it. The head of PROMPT_COMMAND runs at
# top level, where it is visible; ${_bga_dbg_done-...} makes that one-time
# read cost a fork only on the first prompt.
# ---------------------------------------------------------------------------

# Add $1 in front of the trap for signal $2, keeping the old command. $3 is
# the output of `trap -p <sig>`, read by the caller where the trap is visible.
__bga_trap_add() {
    local cmd="$1" sig="$2" raw="${3-}" prev=''
    local -a t=()
    # trap -p prints shell-quoted output (trap -- '<cmd>' SIG): safe to eval.
    [ -n "$raw" ] && eval "t=( $raw )"
    [ "${#t[@]}" -ge 3 ] && prev="${t[2]}"
    [ "$prev" = - ] && prev=''        # posix mode prints "trap -- - SIG" for none
    case "$prev" in "$cmd" | "$cmd; "*) return 0 ;; esac
    # shellcheck disable=SC2064  # expand now: the trap holds both commands
    trap "$cmd${prev:+; $prev}" "$sig"
}

# Second entry of PROMPT_COMMAND. $1 is `trap -p DEBUG` on the first prompt
# only. Returns the saved exit status so the user's hooks still see it.
__bga_pre() {
    if [ -z "${_bga_dbg_done:-}" ]; then
        _bga_dbg_done=1
        if [[ "$(declare -p preexec_functions 2>/dev/null)" == "declare -a"* ]]; then
            case " ${preexec_functions[*]} " in
                *" __bga_timer_start "*) ;;
                *) preexec_functions+=(__bga_timer_start) ;;
            esac
        else
            __bga_trap_add __bga_timer_start DEBUG "${1-}"
        fi
    fi
    return "${_bga_exit:-0}"
}

# The two entries that open PROMPT_COMMAND. The first must be a plain
# assignment so it sees the command's status before anything else runs.
# shellcheck disable=SC2016  # expanded when PROMPT_COMMAND runs, not here
_bga_pc_save='_bga_exit=$?'
# shellcheck disable=SC2016,SC2089  # shell code for PROMPT_COMMAND, not argv
_bga_pc_pre='__bga_pre "${_bga_dbg_done-$(trap -p DEBUG)}"'

# Strip our own entries and stray separators from a PROMPT_COMMAND string.
__bga_pc_strip() {
    local s="$1" ws=$' \t\n'
    s="${s#"$_bga_pc_save; $_bga_pc_pre;"}"; s="${s%; __bga_prompt}"
    [ "$s" = __bga_prompt ] && s=''
    while :; do
        case "$s" in
            ["$ws"]* | \;*) s="${s#?}" ;;
            *["$ws"] | *\;) s="${s%?}" ;;
            *) break ;;
        esac
    done
    REPLY="$s"
}

__bga_hooks_install() {
    local REPLY
    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        local -a keep=() ; local e
        for e in "${PROMPT_COMMAND[@]}"; do
            case "$e" in "$_bga_pc_save" | "$_bga_pc_pre" | __bga_prompt) ;; *) keep+=("$e") ;; esac
        done
        PROMPT_COMMAND=("$_bga_pc_save" "$_bga_pc_pre" "${keep[@]}" __bga_prompt)
    else
        __bga_pc_strip "${PROMPT_COMMAND:-}"
        # shellcheck disable=SC2178  # string branch: PROMPT_COMMAND is not an array here
        PROMPT_COMMAND="$_bga_pc_save; $_bga_pc_pre; ${REPLY:+$REPLY; }__bga_prompt"
    fi
    # shellcheck disable=SC2090  # only the export flag changes
    export -n PROMPT_COMMAND PS0 PS1 2>/dev/null
}

# ---------------------------------------------------------------------------
# Command timer (DEBUG trap, or preexec_functions under bash-preexec)
# ---------------------------------------------------------------------------
_bga_timer_start="${_bga_timer_start:-}"
_bga_last_duration=''
_bga_exit=''

__bga_timer_start() { _bga_timer_start="${_bga_timer_start:-$SECONDS}"; }

# ---------------------------------------------------------------------------
# Async (M5): initialise the cache path + install the cleanup EXIT trap.
# A no-op when BASHGITAWARE_ASYNC=0 or in a non-interactive shell.
# ---------------------------------------------------------------------------
__bga_async_init

__bga_hooks_install
