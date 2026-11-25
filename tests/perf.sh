# tests/perf.sh -- performance budgets.
#
# Two budgets, both stored in tests/budgets.sh:
#   * startup: extra time `source new.bashrc` adds to an interactive bash;
#   * render:  time per synchronous __bga_prompt in a small repo.
# Timing uses bash's own `time` keyword (TIMEFORMAT=%3R, milliseconds), which
# works on every supported bash and platform. `date +%s%N` does not: BusyBox
# and BSD date have no %N, which made the old check measure zero.
# Each figure is the median of several runs to absorb scheduler noise.
# shellcheck shell=bash source-path=SCRIPTDIR

# shellcheck source=budgets.sh
source "$REPO/tests/budgets.sh"

# Milliseconds taken by one run of the bash -c script in $1.
_perf_once_ms() {
    local TIMEFORMAT=%3R t
    t="$( { time bash --norc --noprofile -i -c "$1" >/dev/null 2>&1; } 2>&1 )"
    t="${t//[!0-9]/}"        # 0.123 -> 0123
    printf '%d' "$(( 10#$t ))"
}

# Median, in ms, of $1 runs of script $2.
_perf_median_ms() {
    local n="$1" i v; local -a s=()
    for (( i = 0; i < n; i++ )); do v="$(_perf_once_ms "$2")"; s+=("$v"); done
    # Insertion sort: n is tiny.
    local j k
    for (( j = 1; j < n; j++ )); do
        k="${s[j]}"; i=$(( j - 1 ))
        while [ "$i" -ge 0 ] && [ "${s[i]}" -gt "$k" ]; do s[i+1]="${s[i]}"; i=$(( i - 1 )); done
        s[i+1]="$k"
    done
    printf '%d' "${s[n/2]}"
}

scenario_perf_budget() {
    section "performance budgets"
    local d; d="$(mktemp_repo)"
    git -C "$d" commit --allow-empty -qm "init" >/dev/null 2>&1
    local env="export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120 BASHGITAWARE_ASYNC=0; cd '$d'"

    # Startup: sourcing cost over a bare interactive bash.
    local base src startup
    base="$(_perf_median_ms 5 "$env")"
    src="$(_perf_median_ms 5 "$env; source '$REPO/new.bashrc'")"
    startup=$(( src - base )); [ "$startup" -lt 0 ] && startup=0
    if [ "$src" -le 0 ]; then
        fail "perf: timer returned 0 ms (measurement broken)"
    elif [ "$startup" -le "$BGA_BUDGET_STARTUP_MS" ]; then
        ok "perf: startup ${startup}ms (budget ${BGA_BUDGET_STARTUP_MS}ms)"
    else
        fail "perf: startup ${startup}ms exceeds budget ${BGA_BUDGET_STARTUP_MS}ms"
    fi

    # Render: per-prompt cost, amortized over n renders in one shell.
    local n=50 total per
    total="$(_perf_median_ms 3 "$env; source '$REPO/new.bashrc'; i=0; while [ \$i -lt $n ]; do __bga_prompt; i=\$(( i + 1 )); done")"
    per=$(( (total - src) / n )); [ "$per" -lt 0 ] && per=0
    if [ "$per" -le "$BGA_BUDGET_RENDER_MS" ]; then
        ok "perf: ${per}ms/render across $n renders (budget ${BGA_BUDGET_RENDER_MS}ms)"
    else
        fail "perf: ${per}ms/render exceeds budget ${BGA_BUDGET_RENDER_MS}ms"
    fi

    rm -rf "$d"
}
