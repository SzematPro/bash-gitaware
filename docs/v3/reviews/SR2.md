# SR2: security review, wave 1

- Date: 2026-11-25
- Scope: the v3 render engine. Covers `lib/17-width.bash`,
  `lib/19-theme.bash`, `lib/62-lean.bash`, `lib/80-transient.bash`,
  `lib/15-escape.bash` and the new config keys.
- Reviewer: an independent reviewer, with experiments in a scratch directory
  only. Findings were reproduced again before they were fixed.

No attacker-planted text ran a command. Tried in directory names, branches,
subjects, version files, env names and pasted lines, with and without posix
mode. None injected an escape sequence or unbalanced `\[`/`\]`, including
inside the new right block. glibc and musl gave identical results for 20
hostile byte sequences.

| # | Finding | Severity | Verified | Outcome |
|---|---|---|---|---|
| F1 | `BASHGITAWARE_THEME` from the environment was not validated. `${!var}` evaluated an array subscript in it, and theme-table fields reached PS1 and `printf -v` unescaped | Low: needs control of the environment | Yes, with canaries | Fixed: the name must match `[a-z0-9_]`, and every table field is validated |
| F2 | The width engine costs about 50 µs per non-ASCII byte. A hostile path took the prompt to 84-110 ms | Medium (DoS) | By the reviewer's timings | Fixed: above 512 non-ASCII bytes it returns the byte count, an upper bound on the width |
| F3 | The commit subject was fetched in full on every prompt, even with the commit line off. A 9 MB subject took 279 ms | Medium (DoS) | Yes: a test with a 60 KB subject | Fixed: fetched only when shown (off by default in Lean), and capped at 2 KB |
| F4 | Control characters were measured as 0 cells but shown as `?`, so the right block overflowed | Low (screen corruption) | Yes | Fixed: text is measured after sanitizing |
| - | The transient collapse assumed a 2-3 line prompt, so a wrapped line 1 left rows behind | Correctness | Reviewer, in a pty | Fixed: the row count includes the wrap of line 1 |

The first version of the F3 fix used `local -; set -o pipefail`, and bash 4.4
and 5.0 crashed (segmentation fault). The matrix caught it. It was replaced
by `exit "${PIPESTATUS[0]}"` inside the substitution.

Residual: a lone `0x9b` byte (C1 CSI in 8-bit mode, invalid as UTF-8) reaches
the terminal unchanged. It cannot be stripped blindly, because `9b` is also a
valid UTF-8 continuation byte (for example in `ě`, `C4 9B`). Terminals that
decode UTF-8 do not act on it. Revisit if a terminal in use treats it as CSI.

Regression tests are in `tests/security.sh`: theme from the environment,
the bounded subject, and the width of control characters. The width cap
test is in `tests/width.sh`. Each one fails on the code before the fix.
