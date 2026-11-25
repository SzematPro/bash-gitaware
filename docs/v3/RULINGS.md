# bash-gitaware v3: rulings log

Rulings change the plan or the spec once work has started. They are append-only.
Numbering restarts at R-1 for the reconstructed plan. Rulings L-37, L-41, L-42
and L-46 from the lost attempt are carried over through SPEC sections 2 and 4.

| ID | Date | Ruling | Affects |
|---|---|---|---|
| R-1 | 2026-11-25 | The owner chose four Should items (S1 to S4) for 3.0 instead of three, an explicit exception to the scope rule. | SPEC section 3 |
| R-2 | 2026-11-25 | v3 evolves the v2 module layout instead of starting over. | PLAN |
| R-3 | 2026-11-25 | No process substitution or here-strings in shipped code: `< <()` fails to parse and to run in posix mode before bash 5.1, and here-strings write temp files before 5.1. Parse captured output with parameter expansion. | All modules |
| R-4 | 2026-11-25 | The DEBUG trap is installed on the first prompt, from the head of `PROMPT_COMMAND`: bash hides the user's DEBUG trap while a file is sourced and inside functions, so it cannot be chained at source time. | lib/90-hooks.bash |
| R-5 | 2026-11-25 | S3 (animated pending indicator) ships as a static glyph refreshed on the next prompt: the spike showed no safe way to redraw while readline owns the line. | SPEC S3, PLAN T2.4 |
| R-6 | 2026-11-25 | Render budget raised from 40 to 60 ms. The hosted macOS runner measured 45 ms: without timeout(1), each git call runs under the watchdog, which costs extra processes. Linux containers stay at 13-15 ms. | tests/budgets.sh |
| R-7 | 2026-11-25 | Separate render budget of 90 ms when no timeout(1)/gtimeout exists (watchdog path, stock macOS). The hosted macOS runner measured 45-61 ms against the 60 ms budget, and 61 ms failed the 3.0.0 CI once. Hosts with timeout keep 60 ms. | tests/budgets.sh, tests/perf.sh |
| R-8 | 2026-11-25 | The render budget depends on the platform, not on the time-limit helper: 60 ms off macOS, 90 ms on macOS with any helper. The render median now takes 5 runs instead of 3. Hosted macOS runners measured 36-72 ms with coreutils timeout and 36-68 ms with the watchdog, so runner noise, not the helper, sets the figure. Replaces the per-helper budget of R-7. The macOS CI job runs with and without Homebrew coreutils so both helper paths stay tested. | tests/budgets.sh, tests/perf.sh, .github/workflows/ci.yml |
