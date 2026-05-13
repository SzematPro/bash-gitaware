
# ---------------------------------------------------------------------------
# Command timer (via the DEBUG trap)
# ---------------------------------------------------------------------------
_bga_timer_start=''
_bga_last_duration=''

__bga_timer_start() { _bga_timer_start="${_bga_timer_start:-$SECONDS}"; }
trap '__bga_timer_start' DEBUG

# ---------------------------------------------------------------------------
# Wire the prompt assembler
# ---------------------------------------------------------------------------
PROMPT_COMMAND=__bga_prompt
