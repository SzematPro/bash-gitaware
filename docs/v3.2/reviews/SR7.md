# SR7: context segments

- Date: 2026-11-27
- Scope: d61f021 (`lib/52-context.bash`), the labels' path to PS1, and the
  state-directory marker
- Method: an independent reviewer with shell and Docker access, a second
  local user as the attacker, and hostile kubeconfig and `.terraform`
  files. Each finding was reproduced. The fixes have regression tests
  (`tests/context.sh`, scenario SR7).

No finding lets a repository or another user run code.

| ID | Severity | Finding | Fix |
|---|---|---|---|
| F1 | Medium | The kubeconfig line loop was quadratic: a 64 KB file of newlines took 141 s per prompt | One bounded read and one regex match |
| F2 | Low | A future mtime (kept by tar/zip) defeated the cache, so the file was reread on every prompt | Accepted: after F1 the reread is a single bounded read (under 10 ms); documented |
| F3 | Medium | A state directory deleted by a cleaner while the shell lived could be recreated by another user, with `kube.mark` as a symlink that truncated a victim's file. The async cache write had the same root cause since 3.0 | `__bga_state_ok` (builtin tests: a real directory we own, not a symlink) before the marker write and before each async job |
| F4 | Low | Under `noclobber`, the marker write failed with an error on every prompt | `{ : >\| "$mark"; } 2>/dev/null` |
| F5 | Low | `.terraform` as a symlink to a directory outside the repository read that directory's `environment` | `.terraform` itself must pass `__bga_link_inside` |
| F6 | Low | Bidi and format controls (U+200E/F, U+202A-E, U+2066-9) passed the escaper: they were counted as one cell but drawn as zero, and could reorder a name on screen. This predates 3.2 (branch names too) | Replaced with `?` in `__bga_ps1_lit` and `__bga_term_safe` |

Blocked correctly: `$(...)`, backticks, prompt escapes and arithmetic in
kubeconfig values and in `AWS_PROFILE`/`AWS_VAULT`; terminal sequences;
FIFOs, `/dev/zero`, NUL files and `/proc` files; wide and combining
characters (width computed correctly).
