# ADR-0011: Administrator policy file

- Status: Accepted
- Date: 2026-11-25

## Context

The v3 spec deferred a "policy file" to 3.1. The owner defined it on
2026-11-25: a system-wide file that an administrator controls, which sets and
locks settings above each user's config and environment. Typical uses:
forcing plain mode on build hosts, keeping the background worker off on
shared machines with slow network filesystems, or setting a house theme on
managed laptops.

Every setting comes from one of three places today
(`lib/00-options.bash`): the environment, then the user's config file
(`key = value`, parsed and never sourced, refused when other users can
write it), then preset defaults. A policy adds a layer above all three, and
that layer has to be at least as hard to tamper with as the user's config.

## Decision

- **Path.** `/etc/bash-gitaware/policy`. It is fixed, so there is no
  `XDG_CONFIG_DIRS` search, and an absent file costs one `[ -e ]` test.
- **Format.** The same `key = value` grammar, parser and per-key validation
  as the user config. Unknown keys, invalid values and malformed lines are
  reported with `policy:N:` and skipped. The file is never sourced.
- **Precedence.** Policy > environment > user config > preset. Every valid
  key in the policy is **locked**: its value is assigned even when the
  variable is already set (and exported) from the environment. The user
  config's line for it is skipped without a warning at startup: a warning
  in every new shell would be noise the user cannot fix. `bga doctor` and
  `bga config list` show the shadowed line instead. Locked keys are recorded
  in `_bga_policy_locked`.
- **CLI.** `bga config set`/`unset` on a locked key exits 1 and names the
  policy file. `bga theme set` goes through the same check. `bga config
  list` marks locked keys. `bga doctor` reports the policy as absent,
  applied (with the locked keys) or refused (with the reason), and exits 1
  when it is refused.
- **Trust.** The policy is used only if all of these hold:
  - it is a regular file and not a symlink;
  - it and every directory on its physical path (resolved with `cd -P`, so
    a root-owned `/etc -> /private/etc` symlink on macOS is fine) are owned
    by uid 0;
  - none of them is writable by group or others;
  - no ACL entry grants write access (`getfacl` where it exists, `ls -le`
    on macOS).

  A policy that fails any check is ignored as a whole, with one warning that
  names the reason. That warning appears in every shell, on purpose: a
  policy that cannot be trusted is a problem for the administrator to fix.
  Using part of an untrusted file would be worse than using none of it. The checks run only when the file exists, in one `find`
  call over all the path components, plus one ACL query.
- **Threat model.** The policy protects users from *other* local users:
  nobody but root can write it, so nobody but root can change another
  user's prompt through it. It is **not** a boundary against the account
  owner. They can always skip `new.bashrc`, or change variables after it
  loads. The policy sets defaults for managed machines, not enforcement.
- **Test seam.** The suite needs other policy paths. An *unexported* shell
  variable `_BGA_POLICY`, set before `new.bashrc` is sourced, replaces the
  path. An exported value is ignored, the same rule as `_BGA_CLI`, so a
  parent process cannot redirect it through the environment. The same trust
  checks apply, so even the seam accepts only root-owned files. The CI
  containers create such files as root before they switch to `bgauser`. Runs
  without a way to create them skip those tests instead of failing.

## Alternatives considered

- **`XDG_CONFIG_DIRS` search (`/etc/xdg/bash-gitaware/...`).** That is a
  search path for defaults the user can override, which is the opposite of
  a lock, and every directory on it would need the trust checks.
- **Sourcing a shell file from `/etc/profile.d`.** Administrators can
  already do that today, but it runs code, cannot lock anything, and gives
  `bga` nothing to report.
- **Locking by making the variables `readonly`.** `bga reload` and
  re-sourcing would then fail on the first assignment, and an owner can
  still start a shell without the file. It costs robustness and protects
  nothing.
- **A per-repository policy file.** It would let a cloned repository change
  the prompt, which is the threat GHSA-596h-h6gh-q2w6 was about.
- **Using the valid lines of a policy that fails the trust check.** Rejected:
  an attacker who can write the file would choose those lines.

## Consequences

- Administrators get one documented file with the same grammar users already
  know.
- Users see why a setting does not change (`bga config set` names the
  policy, and `bga doctor` lists the locked keys) instead of silently
  getting another value.
- A shell started when a policy exists pays a few milliseconds at startup
  for the trust checks. With no policy file, the cost is one `[ -e ]` test.
- Testing needs root-owned fixtures: the containers in CI, `sudo` in the
  macOS job, and skips elsewhere.
