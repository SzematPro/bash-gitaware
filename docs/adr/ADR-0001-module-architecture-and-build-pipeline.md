# ADR-0001: Module architecture and the build pipeline

- Status: Accepted
- Date: 2026-05-13

## Context

bash-gitaware v1 is a single `new.bashrc` (~21 KB, ~750 lines) that the user
copies to `~/.bashrc`. The drop-in single-file install is the whole UX: clone,
copy, source, done. That UX is non-negotiable.

The single file has paid for itself, but v2 adds substantially more surface
(OSC integration, tiered glyphs, transient prompt, async rendering, presets).
Keeping everything in one 1,500+ line file would mix concerns (path,
git, runtime detection, render, hooks, terminal escapes) in a way that is
awkward to read, to review and to test. Splitting along concern boundaries is
the cheapest readability win available.

The complication: the user-facing artifact must stay a single file. The split
is for source maintainers, not for installers.

## Decision

Maintain the source as a set of small numbered modules under `lib/` and
generate the single-file artifact:

- Source of truth: `lib/00-options.bash`, `lib/10-detect.bash`,
  `lib/20-palette.bash`, `lib/30-git.bash`, `lib/40-path.bash`,
  `lib/50-runtime.bash`, `lib/60-render.bash`, `lib/70-osc.bash`,
  `lib/80-transient.bash`, `lib/85-async.bash`, `lib/90-hooks.bash`,
  `lib/95-shell.bash`. Numeric prefixes define concatenation order.
- Build script: `bin/build.sh` concatenates `lib/[0-9][0-9]-*.bash` in numeric
  order with a header banner into `new.bashrc`. `make build` is the friendly
  entry point.
- Generated artifact `new.bashrc` is committed. The drop-in install
  (`cp new.bashrc ~/.bashrc`) keeps working without anyone needing to run a
  build.
- CI runs `bin/build.sh` and `git diff --exit-code new.bashrc`. If a contributor
  edited `lib/` without regenerating, CI fails fast.

## Alternatives considered

- **Keep everything in one file.** Cheaper short term, but mixes concerns and
  makes each subsequent feature harder to land. Rejected.
- **Ship `lib/` and have users source it directly from `~/.bashrc`.** Forces
  users to track multiple files and a fixed install path; harder to teach
  ("source which file?"); doesn't compose with the bash `.bashrc` mental model.
  Rejected.
- **Build with `make` but do not commit the artifact.** Means a fresh clone is
  non-functional until the user installs Make and runs it; throws away the
  drop-in install UX. Rejected.

## Consequences

- Editors touch `lib/`. The single-file `new.bashrc` is a build product; if you
  edit it directly, CI catches you on the next push.
- A typical feature PR carries two changes: a `feat:`/`refactor:` of one or
  more `lib/*.bash`, plus a `build:` regenerating `new.bashrc`. The duplication
  is mechanical and trivial to review; accept it.
- Module ordering (`00`..`95`) is meaningful. Renaming a module requires
  keeping its numeric prefix.
- Each module is small enough to read in one screen, which makes the code part
  of what the project ships, not an opaque blob.
- CI gains one extra step (build freshness check). Negligible cost.
