
# ---------------------------------------------------------------------------
# Command timer (via the DEBUG trap)
# ---------------------------------------------------------------------------
_bga_timer_start=''
_bga_last_duration=''

__bga_timer_start() { _bga_timer_start="${_bga_timer_start:-$SECONDS}"; }
trap '__bga_timer_start' DEBUG

# ---------------------------------------------------------------------------
# Async (M5): initialise the cache path + install the cleanup EXIT trap.
# A no-op when BASHGITAWARE_ASYNC=0 or in a non-interactive shell.
# ---------------------------------------------------------------------------
__bga_async_init

# ---------------------------------------------------------------------------
# Wire the prompt assembler
# ---------------------------------------------------------------------------
PROMPT_COMMAND=__bga_prompt
