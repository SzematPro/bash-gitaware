# bash-gitaware v2 — Build Plan

This breaks the work in [`SPEC.md`](SPEC.md) into milestones. Each milestone is a
coherent slice that ends in a buildable, testable state; commits within a
milestone are atomic and follow Conventional Commits. Tags:
`v2.0.0-{alpha|beta.N|rc.N}` at milestone checkpoints, `v2.0.0` at the end. The
single-file `new.bashrc` is regenerated (`make build`) and committed in every
milestone that touches `lib/`.

## Target layout

```
lib/00-options.bash    read & normalize BASHGITAWARE_* knobs; apply presets
lib/10-detect.bash     ssh / container / utf8 / title / root / color capability (once)
lib/20-palette.bash    color palette + tiered glyph sets
lib/30-git.bash        __bga_git_info / __bga_git_state (cheap vs full parts, for async)
lib/40-path.bash       __bga_path (repo-relative; trimming)
lib/50-runtime.bash    __bga_runtime (node/python/rust/go; per-directory cache)
lib/60-render.bash     __bga_render (assemble PS1 from parts) + powerline-preset render
lib/70-osc.bash        OSC 133 (A/B/C/D) + OSC 7 + OSC 0/2 title
lib/80-transient.bash  transient-prompt machinery
lib/85-async.bash      async / deferred-refresh machinery
lib/90-hooks.bash      wire PROMPT_COMMAND, the DEBUG/preexec hook, signal handlers
lib/95-shell.bash      the non-prompt .bashrc bits (history, ls colors, aliases, completion, PATH)
bin/build.sh           cat lib/[0-9][0-9]-*.bash (+ header) -> new.bashrc
new.bashrc             GENERATED single-file artifact (committed; CI checks it is current)
Makefile               build / test / lint / demo
tests/                 run.sh, scenarios.sh, perf.sh, lib.sh, MANUAL.md
.github/workflows/ci.yml
demo/demo.tape         vhs script ; demo/demo.svg generated
install.sh
docs/SPEC.md docs/PLAN.md docs/adr/ docs/diagrams/
CHANGELOG.md CONTRIBUTING.md SECURITY.md .editorconfig LICENSE README.md
```

## Milestones

### M0 — Spec, ADRs, plan, diagrams (docs only; lowest risk)

- `docs/SPEC.md` (done), `docs/PLAN.md` (this file).
- `docs/adr/README.md` (index) + `docs/adr/template.md`.
- ADR-0001 module architecture & the build pipeline (`lib/` + `build.sh` +
  committed artifact).
- ADR-0002 tiered glyph detection (locale is not font; `nerd` is opt-in).
- ADR-0003 modern-terminal integration (OSC 133 / OSC 7) and why.
- ADR-0004 transient prompt — the mechanism and the edge cases.
- ADR-0005 async rendering — the architecture and an honest record of the tradeoff
  (true in-place refresh vs deferred-on-next-prompt) and the limitations accepted.
- ADR-0006 bash-only, bash 4.4+ — why not cross-shell, why not bash 3.2.
- `docs/diagrams/render-pipeline.md` (Mermaid: PROMPT_COMMAND → modules → PS1; the
  async path; the transient path).
- Commit(s): `docs: add v2 spec, plan, ADRs and diagrams`.

### M1 — Modular refactor + build pipeline + CI skeleton

- Split the current `new.bashrc` into `lib/00..95-*.bash` (behaviour unchanged).
- `bin/build.sh` + `Makefile` (`build`, `test`, `lint`, `demo`); regenerate
  `new.bashrc`; assert byte-identical behaviour with a test that diffs `${PS1@P}`
  across a set of scenarios before and after the split.
- `.editorconfig`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`
  (`[Unreleased]` plus a retroactive `[1.0.0]`), `.gitignore` update.
- `tests/run.sh` + `tests/lib.sh` (each lib sources cleanly) + `tests/scenarios.sh`
  (render in fake repos / locales / states; assert no error and expected
  substrings) + `tests/perf.sh` (render-time budget).
- `.github/workflows/ci.yml`: shellcheck (`lib/`, `new.bashrc`, scripts);
  "`new.bashrc` is up to date" check; `make test`.
- Fix the README author email `hello@` → `waldemar@` (the full README rewrite is
  M6, but fix the email now).
- Tag `v2.0.0-beta.1`. Commits: `refactor: split prompt into lib/ modules`,
  `build: add build.sh + Makefile; regenerate new.bashrc`,
  `test: scenario + perf + lib tests`, `ci: shellcheck + build-freshness + tests`,
  `chore: add CHANGELOG/CONTRIBUTING/SECURITY/.editorconfig`,
  `docs: fix contact email in README`.

### M2 — OSC 133 + OSC 7 (Tier 1)

- `lib/70-osc.bash`: OSC 133 `A`/`B` around PS1; `C` in the preexec hook; `D;$?`
  at the start of the prompt cycle; OSC 7 each prompt; keep OSC 0/2 title.
  `BASHGITAWARE_OSC=0` to disable.
- Wire into `lib/90-hooks.bash` (the preexec hook is the DEBUG trap, guarded to
  fire once per command — it already exists for the timer; extend it).
- Tests: capture `${PS1@P}` and assert `\e]133;A` / `\e]133;B`; simulate the
  preexec hook and assert `\e]133;C`; simulate the next cycle and assert
  `\e]133;D;<code>`.
- Tag `v2.0.0-beta.2`. Commit: `feat(osc): emit OSC 133 semantic marks and OSC 7 cwd`.

### M3 — Presets (Tier 1)

- `lib/00-options.bash`: `BASHGITAWARE_PRESET` sets defaults for the other knobs;
  individual variables still override.
- `lib/60-render.bash`: the `powerline` preset render (colored arrow segments via
  Powerline glyphs, with a graceful no-glyph fallback).
- Tests: each preset renders without error; key knob overrides still take effect
  under a preset.
- Tag `v2.0.0-beta.3`. Commit: `feat(presets): minimal / default / powerline / full`.

### M4 — Transient prompt (Tier 2)

- `lib/80-transient.bash`: on command submit, move the cursor to the start of the
  just-printed prompt, clear to end of screen, reprint the minimal transient
  prompt, then run the command. Track the prompt's printed line count (computed in
  render). Handle: multi-line prompt, first prompt, empty submit, `Ctrl-C` at the
  prompt, `clear`. `BASHGITAWARE_TRANSIENT=0` to disable.
- Wire into `lib/90-hooks.bash`.
- Tests: unit-test the transient string; `tests/MANUAL.md` checklist for the
  interactive behaviour; (stretch) a pty-driven test (`python -m pty` / `expect`)
  that drives an interactive bash and asserts the screen.
- Tag `v2.0.0-rc.1`. Commit: `feat(transient): collapse the previous prompt after submit`.

### M5 — Async / non-blocking rendering (Tier 3)

- `lib/85-async.bash`: split git/runtime work into "cheap" (always sync:
  `rev-parse`, cached runtime, filesystem-only state checks) and "expensive" (full
  `status --porcelain=v2`, cold-cache version commands). The prompt renders
  immediately with the cheap info plus a subtle placeholder for the expensive
  part; a background job computes the expensive part, writes it to a per-shell temp
  file, and signals the shell; on signal — or, as a fallback, on the next prompt —
  the prompt re-renders with the full info. No leaked jobs; no terminal
  corruption; `BASHGITAWARE_ASYNC=0` → fully synchronous.
- Update ADR-0005 with what was actually built (in-place refresh if it proved
  robust; deferred-on-next-prompt otherwise) and the limitations.
- Tests: assert the sync-fast path renders without the expensive info; run the
  expensive computation synchronously and assert the re-render includes it; assert
  no background jobs survive after the prompt.
- Tag `v2.0.0-rc.2`. Commit(s): `feat(async): render immediately; fill slow git/runtime info in the background`.

### M6 — Demo + install + README + docs polish

- `demo/demo.tape` (vhs) → `demo/demo.svg` (committed); `make demo` regenerates it.
- `install.sh` (back up `~/.bashrc`; install; optional preset/glyph line;
  next-steps).
- Full README rewrite: hero (the vhs SVG), "what it demonstrates", install
  (one-liner via `install.sh` plus manual), prompt-anatomy / module reference
  (update the v1 reference tables), configuration + presets, compatibility matrix,
  customization, troubleshooting (the "symbols were breaking → glyph tiers"
  section), performance notes, contributing, license.
- `docs/diagrams/` final; `CHANGELOG.md` `[2.0.0]` drafted.
- Tag `v2.0.0-rc.3`. Commits: `docs: rewrite README for v2`,
  `chore(demo): add vhs tape and generated SVG`, `feat(install): add install.sh`.

### M7 — CI matrix, perf budget, final polish, release

- CI matrix: bash 4.4 / 5.0 / 5.1 / 5.2 / latest × ubuntu-latest + macos-latest
  (Homebrew bash); shellcheck; build-freshness; `make test`; perf budget enforced
  (fail if over).
- Final review against `SPEC.md` success criteria; fix gaps.
- Repo metadata: `description`, topics.
- `CHANGELOG.md` finalized; tag `v2.0.0`; GitHub Release with notes.
- Commit: `chore: release v2.0.0`.

## Notes & risks

- **M5 (async) is the highest-risk milestone.** A true in-place refresh in bash
  fights readline; the guaranteed-deliverable fallback is "deferred refresh on the
  next prompt" — still useful, because the slow work is never on the critical path
  of *showing* the prompt. ADR-0005 records the choice and its limits honestly.
- **M4 (transient) edge cases** (resize, multi-line, `Ctrl-C`) need care; the
  manual checklist plus the pty test mitigate.
- **No AI-tool attribution** anywhere in commit messages or committed content. The
  spec-driven / AI-assisted way of working is described in process terms in these
  docs without naming any tool.
- The order of milestones is also a fallback ladder: M0–M3 alone already deliver a
  modern, well-tested, well-documented prompt; M4 and M5 are the standout features
  layered on top.

## Cross-references

- Spec → [`SPEC.md`](SPEC.md). Decisions → [`adr/`](adr/). Render pipeline →
  [`diagrams/render-pipeline.md`](diagrams/render-pipeline.md).
