# Manual test checklist

Things that are awkward to automate. Walk through this list before tagging a
release, in a real terminal (not a pipe), on a fresh shell with no
`BASHGITAWARE_*` overrides unless a check sets one. To try a change without
touching your own setup, run `bash --rcfile new.bashrc`. To re-apply a
setting in a running shell, run `bga reload`.

The examples below use the default Lean style and the `unicode` glyph tier.
Colors are left out.

## Lean layout (default style)

- [ ] `cd /tmp`: line 1 is `/tmp`, line 2 is `❯ `. No git info.
- [ ] `cd` into a clean repository on `main`: line 1 is `<repo>  main`. There
      are no `on`, `via` or `took` connector words, and no hash.
- [ ] `echo x >> README.md`: on the next prompt line 1 ends with ` ●`.
      `git stash`: ` ≡1`. `git commit` ahead of the upstream: ` ↑1`.
- [ ] `git checkout --detach HEAD`: the branch reads `detached@<hash>`.
- [ ] Start a rebase that stops (`git rebase -i HEAD~3`, `edit` on a line):
      line 1 shows `REBASE n/m`. Clean up with `git rebase --abort`.
- [ ] Go 5 or more directories deep inside a repository: the path reads
      `<repo>/…/c/d/e`. `bga config set path_maxdepth 0` and `bga reload`
      show the full path.
- [ ] In a project with `package.json` and `.nvmrc`: `node <version>`
      appears at the right edge of line 1. Shrink the terminal: on the next
      prompt the block follows the edge and disappears before it touches the
      left side. Then the left side falls back to the last path component.
- [ ] `bga config set clock 1`, `bga reload`: the time appears after the
      runtimes, and is the first thing dropped when space runs out.
- [ ] Type at a prompt that has a right block: arrows, Ctrl-A/Ctrl-E and
      history work normally. The block never pushes or wraps the typed text.
- [ ] A directory named with wide characters (`mkdir 日本語`) or emoji: the
      right block still lines up with the edge, give or take one cell for
      emoji sequences (ADR-0007).
- [ ] `BASHGITAWARE_STYLE=classic bash --rcfile new.bashrc`: the v2 layout,
      `<repo> on main@<hash> via node <version>`, then `↳ <subject>`, then
      `❯ `.

## Command ledger and transient prompt

- [ ] Run `false`: the next prompt is preceded by `  ✘1`. Run `sleep 3`:
      `  3s`. Both together (`sleep 3; false`): `  ✘1 · 3s`. A fast
      successful command, or Enter on an empty line, adds no result line.
- [ ] After Enter, the previous two-line prompt collapses to one line,
      `❯ <command>`, shown once, with the symbol colored by the exit code.
- [ ] Paste a command that contains an escape character: the collapsed line
      shows `^[` and does not act on the terminal.
- [ ] Ctrl-C with a half-typed command: no collapse, and the full prompt
      stays. The next Enter collapses as usual.
- [ ] `clear`: the screen is cleared and shows one full prompt.
- [ ] A command long enough to wrap, or a resize between drawing and Enter:
      the collapse may be off by a row (known limit), and the next prompt
      re-syncs.
- [ ] `BASHGITAWARE_TRANSIENT=0`: old prompts stay in full in the scrollback.

## Glyphs, themes and color

- [ ] Default tier: `● ↑ ↓ ≡ ❯ …` render with no missing-glyph boxes.
- [ ] With a Nerd Font, `bga config set glyphs nerd` and `bga reload`: a
      branch glyph appears before the branch name, and a thin Powerline
      separator appears between path and git. `bga config set powerline 0`
      removes the separator.
- [ ] `bga config set glyphs ascii`: `* ^ v s >` and `...`. No boxes.
- [ ] `bga theme list` shows `aware (current)`, `contrast`, `light`.
      `bga theme preview light` prints a sample and leaves this prompt
      alone. `bga theme set light` and `bga reload` apply it, and it stays
      readable on a white background.
- [ ] Theme colors on a 24-bit terminal (`COLORTERM=truecolor`), a 256-color
      terminal, and `TERM=xterm` (16 colors): no unreadable tokens.
- [ ] `NO_COLOR=1 bash --rcfile new.bashrc`: no color, including on the
      collapsed line, and all the same information is there.
- [ ] Over SSH (`ssh localhost`): `user@host` appears before the path, with
      the host highlighted. As root: `user@host` appears and the symbol is
      `#`.

## Plain mode

- [ ] `TERM=dumb bash --rcfile new.bashrc`, `CI=1` or
      `BASHGITAWARE_MODE=plain`: one ASCII line, `<path> (<branch>[ *]) $ `,
      plus `[exit N]` after a failure. No escape sequences: pipe a session
      through `cat -v` and look for `^[`.
- [ ] `BASHGITAWARE_MODE=full` with `CI=1`: the full Lean prompt is back.

## Background git worker

- [ ] `cd` into a large repository (for example a Linux kernel checkout):
      the first prompt appears at once and ends with a faint ` …`. Press
      Enter: the next prompt has the full status and the `…` is gone.
- [ ] In a small repository, `echo x > new-file` and press Enter: the dirty
      mark shows on that prompt or the next one.
- [ ] Find the state directory with `bga doctor` (the `state` line). It is
      `bga.XXXXXXXX` under `$XDG_RUNTIME_DIR`, or under `${TMPDIR:-/tmp}`
      when that is missing or not private, with mode `0700`
      (`ls -ld <dir>`). Exit the shell: the directory is gone.
- [ ] `kill -9` the worker while it runs (`jobs -l` does not list it; use
      `pgrep -f 'git status'`): the next prompt starts a new one, and no
      process is left over after the shell exits.
- [ ] `BASHGITAWARE_ASYNC=0`: no `…` and no worker. The first prompt in a
      large repository takes the full synchronous time.

## `bga` and the installer

- [ ] `bga doctor` in a normal terminal: every line is `ok` or `info`, and
      it exits 0. `bga config set theme 'bad value'` is refused (exit 2).
      Write `theme = bad value` into the config file by hand: `doctor`
      prints `FAIL config` with `config:1: invalid value for 'theme'` and
      exits 1.
- [ ] `bga config list`, `get`, `set`, `unset` round-trip a value; comments
      in the config file are kept.
- [ ] `./install.sh` in a terminal asks for mode, theme and glyphs; a new
      shell picks them up. `./install.sh --uninstall` removes the block, and
      a second `--uninstall` changes nothing.

## Build pipeline

- [ ] After editing any `lib/*.bash`, `make check` rebuilds `new.bashrc` and
      fails with "new.bashrc is out of date" until the rebuilt file is
      committed (CI runs the same check).
- [ ] `make lint` and `make test` pass on a clean working tree.
