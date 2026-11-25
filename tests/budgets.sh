# tests/budgets.sh -- performance budgets, in milliseconds (one place to tune).
#
# Measured on 2026-11-25 (medians): startup 2-4 ms in the bash:4.4-5.3
# containers and about 14 ms on a Linux laptop (system bash-completion);
# render 9-11 ms everywhere. Hosted macOS runners fork more slowly and are not
# measured yet, hence the wide headroom. Lower the budgets as v3 tightens the
# code; never raise one without a ruling in docs/v3/RULINGS.md (render:
# 40 -> 60 ms, ruling R-6).
# shellcheck shell=bash disable=SC2034  # consumed by tests/perf.sh

BGA_BUDGET_STARTUP_MS=100
BGA_BUDGET_RENDER_MS=60
# macOS (uname Darwin) gets its own render budget whatever the time-limit
# helper. Hosted macOS runners measured 36-72 ms with coreutils timeout and
# 36-68 ms with the shell watchdog: runner noise, not the helper, sets the
# figure (ruling R-8, which replaces the per-helper budget of R-7).
BGA_BUDGET_RENDER_MACOS_MS=90
