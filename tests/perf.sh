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

    # Startup with the shell-defaults module off (ADR-0010): within budget
    # everywhere. "Not slower than on" is only checked where the module loads
    # bash-completion, the one heavy part: elsewhere (macOS, Alpine) both runs
    # do the same work and the two medians differ by noise alone (macOS CI
    # measured 19 ms off against 11 ms on). The slack absorbs timer noise.
    local src_off startup_off slack=5 heavy=0
    src_off="$(_perf_median_ms 5 "$env; export BASHGITAWARE_SHELL_DEFAULTS=0; source '$REPO/new.bashrc'")"
    startup_off=$(( src_off - base )); [ "$startup_off" -lt 0 ] && startup_off=0
    { [ -f /usr/share/bash-completion/bash_completion ] || [ -f /etc/bash_completion ]; } && heavy=1
    if [ "$startup_off" -gt "$BGA_BUDGET_STARTUP_MS" ]; then
        fail "perf: startup ${startup_off}ms with shell_defaults=0 exceeds budget ${BGA_BUDGET_STARTUP_MS}ms"
    elif [ "$heavy" = 1 ] && [ "$startup_off" -gt $(( startup + slack )) ]; then
        fail "perf: startup ${startup_off}ms with shell_defaults=0 is slower than on (${startup}ms)"
    else
        ok "perf: startup ${startup_off}ms with shell_defaults=0 (on: ${startup}ms)"
    fi

    # Render: per-prompt cost, amortized over n renders in one shell.
    local n=50 total per
    # Median of 5: hosted runners are noisy (ruling R-8).
    total="$(_perf_median_ms 5 "$env; source '$REPO/new.bashrc'; i=0; while [ \$i -lt $n ]; do __bga_prompt; i=\$(( i + 1 )); done")"
    per=$(( (total - src) / n )); [ "$per" -lt 0 ] && per=0
    # The budget depends on the platform (R-8). The time-limit helper the
    # library picked at load (lib/30-git.bash: timeout, gtimeout, or '' for
    # the watchdog) is only reported, and checked when CI pins it.
    local how budget plat
    how="$(bash --norc --noprofile -i -c "$env; source '$REPO/new.bashrc' >/dev/null 2>&1; printf '%s' \"\${_bga_tmo:-watchdog}\"" 2>/dev/null)"
    case "$how" in timeout | gtimeout) ;; *) how=watchdog ;; esac
    plat="$(uname -s 2>/dev/null)"
    case "$plat" in
        Darwin) budget="$BGA_BUDGET_RENDER_MACOS_MS" ;;
        *)      budget="$BGA_BUDGET_RENDER_MS" ;;
    esac
    # CI pins the path each job must exercise, so a runner image change cannot
    # silently move a job to the other one. "coreutils" accepts either name:
    # Homebrew's coreutils puts an unprefixed timeout on PATH.
    if [ -n "${BGA_EXPECT_TMO:-}" ]; then
        local want="$BGA_EXPECT_TMO"
        [ "$want" = coreutils ] && case "$how" in timeout | gtimeout) want="$how" ;; esac
        if [ "$how" = "$want" ]; then
            ok "perf: time-limit helper is $how (expected $BGA_EXPECT_TMO)"
        else
            fail "perf: time-limit helper is $how, expected $BGA_EXPECT_TMO"
        fi
    fi
    if [ "$per" -le "$budget" ]; then
        ok "perf: ${per}ms/render across $n renders (budget ${budget}ms, ${plat:-?}, $how)"
    else
        fail "perf: ${per}ms/render exceeds budget ${budget}ms (${plat:-?}, $how)"
    fi

    rm -rf "$d"
}
