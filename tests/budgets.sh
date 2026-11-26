# tests/budgets.sh -- performance budgets, in milliseconds (one place to tune).
#
# Measured on 2026-11-26 in CI (medians, 3.1 code): startup 12-22 ms and
# render 8-13 ms on Linux (ubuntu runner and bash:4.4-5.3 containers);
# startup 13-15 ms and render 34-38 ms on hosted macOS (earlier runs went up
# to 72 ms, which is why macOS has its own budget). The shell-defaults module
# costs about 12 ms where bash-completion is installed. Lower the budgets as
# the code tightens; never raise one without a ruling in docs/v3/RULINGS.md
# (render: 40 -> 60 ms, R-6; macOS 90 ms, R-7 then R-8).
# shellcheck shell=bash disable=SC2034  # consumed by tests/perf.sh

BGA_BUDGET_STARTUP_MS=100
BGA_BUDGET_RENDER_MS=60
# macOS (uname Darwin) gets its own render budget whatever the time-limit
# helper. Hosted macOS runners measured 36-72 ms with coreutils timeout and
# 36-68 ms with the shell watchdog: runner noise, not the helper, sets the
# figure (ruling R-8, which replaces the per-helper budget of R-7).
BGA_BUDGET_RENDER_MACOS_MS=90
