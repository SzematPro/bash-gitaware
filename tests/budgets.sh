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
# Without timeout(1)/gtimeout (stock macOS) every git call runs under the
# shell watchdog, which costs extra processes; hosted macOS runners measured
# 45-61 ms there. Separate budget so runner noise does not fail CI (R-7).
# tests/perf.sh picks the budget from the helper the library chose; CI runs
# macOS both ways (with and without Homebrew coreutils).
BGA_BUDGET_RENDER_WATCHDOG_MS=90
