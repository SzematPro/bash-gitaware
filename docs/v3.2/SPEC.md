# bash-gitaware 3.2: spec

- Status: Released as 3.2.0 and 3.2.1 on 2026-11-27 (scope chosen by the owner the same day)
- Base: 3.1.0 (`v3.1.0`, cd121d8) plus #3 (7d8a4d1)
- Builds on: [`../v3/SPEC.md`](../v3/SPEC.md) (locked decisions,
  non-functional requirements, lessons) and [`../v3.1/SPEC.md`](../v3.1/SPEC.md).

## 1. Scope

| ID | Item | Priority |
|---|---|---|
| C1 | Bash completion for `bga`: subcommands, config keys, valid values, theme names | Must |
| C2 | `bga config list --all`: the effective value of every key and where it comes from | Must |
| G1 | Detailed git status (opt-in): staged, unstaged, untracked and conflict counts, plus an "upstream gone" mark | Should |
| X1 | Context segments (opt-in): kubectl context, AWS profile, Terraform workspace in the right block | Should |

Out of scope: a templating mini-language; flipping the `shell_defaults`
default (4.0).

## 2. Requirements

### C1 Completion

- `complete -F __bga_complete bga` in interactive shells, defined in
  `lib/94-cli.bash`. Nothing is registered for `bin/bga`, and nothing in
  plain mode.
- It completes, in order: subcommands; the `config` and `theme`
  subcommands; keys after `config get|set|unset`; the values of a key after
  `config set KEY`; theme names after `theme preview|set`.
- Keys and values come from one table, `_bga_config_keys`, which
  `__bga_config_valid` also uses, so the two cannot drift apart.
- It does not depend on bash-completion being installed, and does not
  replace a completion the user already set for `bga`.

### C2 `bga config list --all`

- One line per key: `key = value   (source)`. The source is `policy`,
  `environment`, `config:N` (the line number) or `default`. Keys with no
  value say `(unset, default)`.
- Values are made safe for the terminal (`__bga_term_safe`).
- Plain `bga config list` is unchanged.

### G1 Detailed git status

- New key `git_status = compact | detail`. The default is `compact`, which
  keeps today's look: `●` when anything changed.
- `detail` shows `+N` staged, `!N` unstaged, `?N` untracked and `✘N`
  conflicts (ASCII forms in the ascii tier), with a color token for each.
- Only the background worker counts, and it reads at most 2000 status
  entries. A capped count shows as `N+`. The sync path (`async = 0`) keeps
  its 3 s limit and gives the same counts.
- "Upstream gone": a branch whose upstream is configured but no longer
  exists shows `⇣gone` (`gone` in ascii), in both modes.
- The cache format gains the new fields. Old cache files are discarded,
  not misread.

### X1 Context segments

- New key `contexts`, a comma list of `kube`, `aws`, `tf`. The default is
  empty, so nothing new shows.
- `kube`: `current-context` from the first file in `$KUBECONFIG`, or
  `~/.kube/config` if that is unset. The read is bounded, the file is
  parsed as data, and `kubectl` is never run. Cached by file and mtime, so
  the file is not reread on every prompt.
- `aws`: `$AWS_PROFILE`, or `$AWS_VAULT` if that is unset.
- `tf`: the workspace from `.terraform/environment` in the current
  directory. This file comes from the repository, so it is untrusted and
  gets the same rules as version files (symlink, NUL, value pattern).
- They go in the right block after the runtimes, are dropped before the
  runtimes when space runs out, and have a color token each.

## 3. Release criteria

1. Completion works in a pty on bash 4.4 to 5.3 for each position in C1.
2. `config list --all` names the correct source for a key set in each of
   the four places, using the policy fixtures.
3. In a 100k-file repository, the render budget holds with
   `git_status = detail` and async on.
4. A hostile `.terraform/environment` (NUL, symlink out of the repository,
   escapes) is handled like a version file (SR7).
5. CI is green on every job, and no budget is raised.
