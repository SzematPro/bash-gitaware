# bash-gitaware v3: reconstructed spec (draft)

- Status: Draft, pending owner confirmation of section 3
- Date: 2026-11-25
- Supersedes: the v3 design and contract 1.2.x from 2026-11-12/13. Those lived
  outside the repository and were lost in a host reboot on 2026-11-15. This
  document rebuilds them from the recorded decisions. Everything v3 lives in
  this branch from now on.

## 1. Why v3

v2 (12 modules in `lib/` built into `new.bashrc`, non-interactive
`install.sh`) works, but users say its starship-like look is not premium. v3 is
a redesign of the look, the configuration experience and the robustness
guarantees. It keeps the project identity and the v2 tags.

## 2. Locked decisions (recovered, do not reopen)

| Area | Decision |
|---|---|
| Name | Keep `bash-gitaware`; command-line tool is `bga`. v2 tags stay. |
| Floor | bash 4.4 or newer. Pure bash, no runtime dependencies beyond git. |
| License | MIT, `Copyright (c) 2024-2026 Waldemar Szemat (SzematPro)`. |
| Default style | Lean: a command ledger, a transient prompt, context aligned right. |
| Signature theme | `Aware`. |
| Git budget | 20 ms hard limit per prompt for git work. Anything slower moves to a background worker. |
| Shell defaults | Optional module, off by default. Deferred to 3.1. |
| Plain/agent mode | Uses only generic signals: `TERM=dumb`, no tty, `CI`, `AGENT`, `AI_AGENT`, `BASHGITAWARE_MODE=plain`. No product names in code or docs. |
| Docs | User-facing docs in English and Spanish, with a CI check that they match. ADRs, architecture, CHANGELOG and the test manual are English only. |
| Attribution | No AI attribution anywhere. Never commit `CLAUDE.md`. |
| Release | One release commit plus tag. Normal push only after the owner confirms. |
| 3.0 scope rule | Every Must item, plus three Should items with high visual impact. All other Should items, including the shell-defaults module and a policy file, go to 3.1 and are not mentioned in 3.0 docs. |
| Reviews | At most three review lenses per wave, a second reviewer for high-risk tasks, and four security reviews (SR1 to SR4). |

## 3. 3.0 scope (reconstructed: OWNER MUST CONFIRM)

The original MoSCoW list was lost. The items below are inferred from the locked
decisions and the wave-0/1 review findings. The owner should mark each one
Must, Should or 3.1, and name the three Should items.

| ID | Item | Proposed | Evidence |
|---|---|---|---|
| R1 | New render engine: segments, a display-width engine that handles UTF-8 correctly, right-aligned context | Must | "Lean ... right-aligned context"; width-engine lessons |
| R2 | Lean default style with a command ledger (previous commands collapsed into compact lines) | Must | Locked default style |
| R3 | Transient prompt carried over from v2, adapted to the ledger | Must | Locked default style |
| R4 | `Aware` theme plus a theme mechanism based on semantic color tokens | Must | Signature theme |
| R5 | Git info within a 20 ms budget, with a background worker and a private state directory | Must | Locked budget; wave-1 blocker on state directory ownership |
| R6 | `bga` CLI: `bga config`, `bga theme`, `bga doctor`, `bga version` (exact set TBC) | Must | Locked CLI name |
| R7 | Interactive installer and uninstaller with a check that the library files have not been tampered with | Must | v2 installer was non-interactive; ruling L-37 on the tamper check |
| R8 | Plain/agent mode | Must | Locked |
| R9 | Hook installation that coexists with existing `PROMPT_COMMAND`, `PS0`, DEBUG and EXIT traps, and unexports `PROMPT_COMMAND`/`PS0`/`PS1` | Must | Ruling L-42 |
| R10 | Security invariants of section 4, with tests | Must | v2.0.1 advisory GHSA-596h-h6gh-q2w6 |
| R11 | Bilingual docs with a parity check, markdownlint and lychee in CI | Must | Locked; task T1.16 |
| R12 | Startup-time budget (AC11), with CI enforcement | Must | Ruling L-46 |
| S1-S3 | Three high-visual-impact Should items: OWNER TO NAME (candidates: extra themes, a Nerd Font powerline variant, an animated pending-git indicator, a richer demo) | Should | Scope rule |

## 4. Non-functional requirements

- **Security** (carried over from v2.0.1, enforced by tests): untrusted text
  (refs, subjects, paths, version files, env names) reaches `PS1` only through
  one escaping function. Control characters are replaced. Nothing read from
  disk is sourced. State and cache files live in a directory owned by the user
  with mode 0700, and that ownership is checked before use. The code never
  depends on `promptvars` being on or off.
- **Performance:** at most 20 ms of git work per prompt; a startup budget
  (AC11) measured in CI; no quadratic string idioms (section 5).
- **Compatibility:** bash 4.4, 5.0, 5.1, 5.2 and 5.3 on glibc and musl, plus
  macOS with Homebrew bash. The code must not depend on the caller's `shopt`
  state (`extglob`, `expand_aliases`, `patsub_replacement`, `promptvars`).
- **Lint:** shellcheck clean. The only allowed disables are SC2016, SC2317,
  SC1090 and SC1091. No integer attribute (`declare -i`) in shipped code
  (ruling L-41).

## 5. Technical lessons to keep (from waves 0-1)

- `printf '%.1s'` and `'%.2s'` cut bytes, not characters, on bash 4.4 to 5.3
  (glibc and musl).
- `printf '%d' "'c"` goes through `mbtowc`, whose hidden state is corrupted
  by a truncated UTF-8 sequence on glibc. Do not use it on untrusted input.
- glibc decodes 4- to 6-byte forms beyond U+10FFFF as one character and musl
  refuses them. Treat overlong forms and anything beyond U+10FFFF as one
  cell per byte.
- `${s:i:1}` is linear per call in multibyte locales. Skip runs of printable
  ASCII with `${s%%[!\ -~]*}`. `${s##*[!\ -~]}` is quadratic; use
  `${s%[!\ -~]*}` instead.
- Mixing pattern cuts with character indexing in a UTF-8 locale can loop
  forever. The width engine must use one model consistently.
- `arr=($s)` is the only fast split that needs no fork, but it triggers
  SC2206. The lint-clean loop is 4 to 8 times slower; decide this per hot path.
- A `bash -i` reading from a pipe echoes the typed commands, so tests must not
  assert on names that appear in those commands.
- The test sandbox must clear inherited `_bga_*`/`_BGA_*` variables, because
  the developer's v2 prompt exports some.
- Capability probes must turn "tool missing" into a skip, not a failure.

## 6. Process lessons

- Keep all state in the repository (this branch), never in `/tmp`.
- Agents never run commands in the main checkout. They work in worktrees.
- Never message a running workflow agent. Answer it through files.
- Every wave ends with a final rulings pass, then a checkpoint, then a tag
  (`v3-wN`).
- Keep waves small, about 10 tasks, each with its own acceptance criteria and
  tests.

## 7. Next steps

1. Owner confirms section 3: Must, Should or 3.1 for each item, and names
   S1 to S3.
2. Write `docs/v3/PLAN.md`: waves, tasks and acceptance criteria per task.
3. ADRs for the render engine, the worker and state directory, and the CLI.
4. Wave 0 (spine): module layout, build, test sandbox, CI matrix, escaping
   and state-directory primitives.
