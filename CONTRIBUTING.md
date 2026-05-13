# Contributing to bash-gitaware

Thanks for your interest. This is a small project; the contribution workflow
is intentionally simple.

## Quick start

```bash
git clone git@github.com:SzematPro/bash-gitaware.git
cd bash-gitaware

# Run the test suite.
make test

# Lint (requires shellcheck installed).
make lint
```

## Where to edit

The source of truth is the modules under `lib/[0-9][0-9]-*.bash`. The
single-file `new.bashrc` that users install is a build artifact regenerated
by `bin/build.sh` and committed alongside the source.

Workflow:

1. Edit the relevant `lib/*.bash`.
2. Run `make build` to regenerate `new.bashrc`.
3. Run `make test`.
4. Commit both the source change and the regenerated `new.bashrc` in the same
   commit (or in two commits within the same PR -- the build-freshness gate
   only cares about the final state).

If you forget step 2, the CI build-freshness check fails. `make check` runs
the same gate locally.

## Commit style

[Conventional Commits](https://www.conventionalcommits.org/). The types you
will most often need:

- `feat(scope): ...` for user-visible additions.
- `fix(scope): ...` for bug fixes.
- `refactor(scope): ...` for changes that do not alter behaviour.
- `docs(scope): ...` for documentation.
- `test: ...` for test changes.
- `ci: ...` for CI changes.
- `build: ...` for build-pipeline changes.
- `chore: ...` for repo housekeeping.

The subject line is in imperative mood, under ~70 characters when practical.
Use the body to explain the *why* when it is not obvious from the diff.

## Design decisions

Significant decisions live as ADRs under [`docs/adr/`](docs/adr/). If you are
proposing a change that affects architecture, the glyph strategy, terminal
integration, the transient or async paths, or the bash-version support
boundary, propose a new ADR alongside the change. Copy
[`docs/adr/template.md`](docs/adr/template.md) to
`docs/adr/ADR-NNNN-short-kebab-title.md`.

## Tests

`tests/run.sh` runs:

1. `bash -n` syntax check on every `lib/*.bash`.
2. Build-freshness check (`bin/build.sh` output matches the committed
   `new.bashrc`).
3. Nine scenario tests in throwaway git repos: non-git path, clean repo,
   dirty repo, ahead-of-remote, detached HEAD, in-progress rebase, NO_COLOR,
   `BASHGITAWARE_GLYPHS=ascii`, `BASHGITAWARE_PATH_MAXDEPTH` trim.
4. A render-time perf budget (50 renders, generous budget).

If you add a feature, add at least one scenario. If you change behaviour,
update the scenarios.

## Identity and provenance

The only identity associated with this repository is **SzematPro**. Do not
add `Co-Authored-By` trailers; do not credit any AI assistant or third-party
tool in commit messages, code comments, README text or PR descriptions.

## Reporting bugs

Open an issue on GitHub with:

- bash version (`bash --version`).
- OS / terminal emulator.
- The `BASHGITAWARE_*` variables you have set (if any).
- What you expected.
- What you saw (ideally a screenshot or the literal output).
