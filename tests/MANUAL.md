# Manual test checklist

Things that are awkward to automate. Walk through this before tagging a
release. Each item should pass on a fresh terminal (no env-var overrides).

## Visual rendering

- [ ] Open a new terminal in a non-git directory (e.g. `cd /tmp`). The prompt
      shows `/tmp` then a newline then `❯ ` (unicode) or `> ` (ascii). No
      `on`, no branch info.
- [ ] `cd` into a git repo on `main` with no changes. The prompt shows
      `<repo-name>` then ` on main@<hash>` then a newline then `❯ `.
- [ ] Modify a tracked file (`echo x >> README.md`). The prompt gains a
      yellow `●` after `<hash>`.
- [ ] `git add` the modification, then check again: still dirty, `●` shown.
- [ ] `git commit`, no changes left: `●` gone.
- [ ] `git stash` something: prompt shows ` ≡1`.
- [ ] In a rebase: prompt shows `REBASE n/m`.
- [ ] `git checkout <some-hash>` (detached): prompt shows `detached@<hash>`,
      no `@hash` suffix (because the branch label already has the hash).
- [ ] Long path (5+ components deep): the path is trimmed to the last 3 with
      a leading `…`. Set `BASHGITAWARE_PATH_MAXDEPTH=0` to disable trimming
      and verify the full path appears.
- [ ] In a Node project (`package.json` present): prompt gains ` via node X.Y`.
- [ ] In a Python project with a venv active: prompt gains
      ` via python X.Y (<envname>)`.
- [ ] Run a slow command (`sleep 3; ls`): the prompt shows ` took 3s`.
- [ ] Run a failing command (`false`): the prompt symbol turns red and the
      line gains ` ✘1` (or ` exit 1` in ascii).

## Glyph tiers

- [ ] On a terminal with a Nerd Font installed, set
      `BASHGITAWARE_NERD_FONT=1` and re-source: the Powerline branch glyph
      ``  appears before the branch name. No tofu (missing-glyph square)
      anywhere.
- [ ] Without `BASHGITAWARE_NERD_FONT=1`, no `` appears (no Nerd Font is
      assumed). The unicode glyphs (`↑ ↓ ● ≡ ↳ ❯`) render correctly.
- [ ] Set `BASHGITAWARE_GLYPHS=ascii` and re-source: glyphs become `^ v * s commit:`
      and `>`. No tofu.

## Color and accessibility

- [ ] Set `NO_COLOR=1` and re-source: the prompt has no ANSI colors, all the
      same information is present in plain text.
- [ ] In an SSH session (`ssh localhost` is enough): `user@host` appears in
      the prompt. The host name is bold.
- [ ] As root: `user@host` always appears; the prompt symbol is `#`.

## Behaviour preservation across the build pipeline (M1)

- [ ] After editing any `lib/*.bash`, run `make build` and `make check` -- it
      should succeed. If you forget `make build`, `make check` fails with
      "new.bashrc is out of date".
- [ ] `make test` passes on a clean working tree.
- [ ] `make lint` passes (shellcheck across `lib/` and `bin/`).

## Transient prompt (M4)

After Enter, the previous prompt collapses to a one-line form
`❯ <typed-command>` (or `> <typed-command>` on the ascii tier), colored by
that command's exit code. The live prompt stays full and informative; the
scrollback stays compact. Disable with `BASHGITAWARE_TRANSIENT=0`.

- [ ] Open a fresh terminal, source the bashrc, run a few commands. Each
      submission collapses the old multi-line prompt to a single
      `❯ <command>` line in scrollback; the live prompt below is the full
      multi-line form.
- [ ] Run a failing command (e.g. `false`). The collapsed line of that
      command shows the symbol in red.
- [ ] Press Enter on an empty line at the very first prompt of the
      session: no visible collapse (no prior prompt to collapse against).
- [ ] Press Ctrl-C with a half-typed command: the line is discarded, the
      full prompt stays on screen, no collapse fires. The next Enter
      collapses as usual.
- [ ] Type `clear` and press Enter: collapse fires, then `clear` wipes the
      screen; final state is a clean screen with one full prompt.
- [ ] Type a command long enough to wrap onto a second physical line, then
      Enter: the collapse may misalign by a row (known limit -- the
      recorded line count does not account for input wrapping). The next
      prompt re-syncs.
- [ ] Resize the terminal between rendering and submit, then press Enter:
      same caveat as wrapping; next prompt re-syncs.
- [ ] Set `BASHGITAWARE_TRANSIENT=0` and re-source: previous prompts stay
      in scrollback as full multi-line entries, no collapse.
- [ ] Set `BASHGITAWARE_GLYPHS=ascii` (or `BASHGITAWARE_PRESET=minimal`):
      the collapsed symbol is `>`, not `❯`.

## Async rendering (M5)

Expensive git info (dirty / ahead / behind from `git status --porcelain=v2`)
is computed in a background subshell and surfaced on the *next* prompt
cycle. The cheap info (branch, hash, in-progress state, commit subject,
stash count) renders immediately every prompt. Disable with
`BASHGITAWARE_ASYNC=0`.

- [ ] `cd` into a clean repo. The first prompt shows the branch and hash;
      no dirty marker (correct). Press Enter on an empty line. The next
      prompt is identical (no dirty marker; the cache landed and confirmed
      "clean").
- [ ] Touch a file (`echo x > foo`) and press Enter. The first prompt
      after the change still shows the prior cache (`●` may persist from
      the prior cycle if the change was just made). Press Enter again.
      The next prompt shows the updated state, including `●`.
- [ ] `cd` into a large monorepo (e.g. linux kernel, chromium). The first
      prompt appears instantly; a faint `…` (or `...` on ascii) trails the
      branch info while the background job runs. Press Enter. The next
      prompt has full info; the placeholder is gone.
- [ ] Set `BASHGITAWARE_ASYNC=0` and re-source. The first prompt in a
      large repo now takes the full sync time; no placeholder appears; no
      background job is spawned (verify with `jobs -l`).
- [ ] Open a fresh shell with async on. `cd` into a repo. Observe the
      cache file appears at `${XDG_RUNTIME_DIR:-/tmp}/bga-${$}.cache`.
      Exit the shell. The cache file is removed by the `EXIT` trap.
- [ ] Run `kill -9` on a still-running async job (find it via `jobs -l`).
      The next prompt cycle dispatches a new job; the cache eventually
      lands; no orphans.

## Out of scope until later milestones

These have placeholder modules in `lib/` and are documented in `docs/adr/`;
they should *not* render or change behaviour yet:

(none -- M5 was the last placeholder; subsequent milestones M6/M7 are
demo/install/CI polish, not behavioural placeholders.)
