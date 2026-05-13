# tests/perf.sh -- performance budget.
#
# Asserts that synchronous render time is well under a person-perceptible delay.
# The budget is generous on CI (which is slower than a developer laptop). Async
# rendering (M5) makes the *perceived* time independent of repo size; this test
# covers the synchronous path.
# shellcheck shell=bash

scenario_perf_budget() {
    section "performance budget"
    local d; d="$(mktemp_repo)"
    (cd "$d" && git commit --allow-empty -qm "init") >/dev/null 2>&1

    local n=50
    local t0 t1 elapsed_ms per_ms
    t0="$(date +%s%N)"
    bash --norc --noprofile -i -c "
        export HOME='$HOME' PATH='$PATH' TERM='xterm-256color' LANG='C.UTF-8' COLUMNS=120
        cd '$d'
        source '$REPO/new.bashrc'
        i=0; while [ \$i -lt $n ]; do __bga_prompt; i=\$(( i + 1 )); done
    " >/dev/null 2>&1
    t1="$(date +%s%N)"

    elapsed_ms=$(( (t1 - t0) / 1000000 ))
    per_ms=$(( elapsed_ms / n ))

    # The budget includes bash startup overhead (one fork per scenario), so the
    # per-render figure is a generous upper bound. Tighten as the project
    # matures.
    local budget=80
    if [ "$per_ms" -le "$budget" ]; then
        ok "perf: ${per_ms}ms/render across $n renders (budget ${budget}ms)"
    else
        fail "perf: ${per_ms}ms/render exceeds budget ${budget}ms"
    fi

    rm -rf "$d"
}
