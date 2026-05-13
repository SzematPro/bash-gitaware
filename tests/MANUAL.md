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

## Out of scope until later milestones

These have placeholder modules in `lib/` and are documented in `docs/adr/`;
they should *not* render or change behaviour yet:

- M2 OSC 133 / OSC 7 -- a terminal with the integration enabled should not
  start showing prompt marks until M2 lands.
- M4 transient prompt -- previous prompts should not collapse until M4.
- M5 async rendering -- the prompt should be fully synchronous until M5.
