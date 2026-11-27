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

`make test` (or `bash tests/run.sh`) runs about 500 checks:

1. `bash -n` on every `lib/*.bash` and the build-freshness gate.
2. Scenario files in `tests/`, each in throwaway repositories and a
   sandboxed environment: rendering and layout (`scenarios.sh`, `lean.sh`,
   `plain.sh`, `theme.sh`, `width.sh`), git and its trust model
   (`gitconfig.sh`, `gitdetail.sh`), runtimes and contexts (`runtime.sh`,
   `context.sh`), hooks and shell state (`hooks.sh`, `shellstate.sh`), the
   CLI and completion (`cli.sh`, `complete.sh`), the installer
   (`install.sh`), the config file and policy (`config.sh`, `shell.sh`,
   `policy.sh`), vi mode and OSC 9;4 (`vimode.sh`, `progress.sh`), and
   hostile input (`security.sh`).
3. Startup and render budgets (`perf.sh`, `budgets.sh`).

Some checks need extra setup and are skipped, not failed, without it:

- **Policy trust:** root-owned fixtures. Run `sudo sh tests/policy-fixtures.sh`
  once (CI does it before switching to an unprivileged user).
- **pty runs** (vi mode, completion, `config edit`, interactive installer):
  `script(1)`, in either the util-linux or the BSD/macOS form.

CI runs the suite on bash 4.4, 5.0, 5.1, 5.2 and 5.3 (Alpine containers, as a
non-root user), on Ubuntu, and on macOS with and without Homebrew coreutils.
`tests/MANUAL.md` lists the checks that need a human at a real terminal.

If you add a feature, add tests for it. If you change behaviour, update the
tests that pin it.

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
