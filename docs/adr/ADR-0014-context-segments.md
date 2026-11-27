# ADR-0014: Context segments (kube, aws, terraform), opt-in

- Status: Accepted
- Date: 2026-11-27

## Context

Many users work across clusters, cloud accounts and Terraform workspaces. A
wrong context there is costly, and other prompts show it. bash-gitaware has
a right-aligned block for runtimes (ADR-0007), and two rules that every
segment must follow: no program runs per prompt, and text from a repository
is untrusted (ADR-0008, SR6).

## Decision

- **Opt-in:** `contexts = kube,aws,tf`, empty by default.
- **kube:** the `current-context:` line of the first file in `$KUBECONFIG`
  (or `~/.kube/config`), from one bounded read (64 KB, NUL-terminated).
  `kubectl` is never run. The file is read again only when it is newer than
  a marker file in the private state directory. `: > marker` refreshes the
  marker without a fork. Without a state directory, the file is read on
  every prompt, which is still bounded.
- **aws:** `$AWS_PROFILE`, else `$AWS_VAULT`. No file is read.
- **tf:** `./.terraform/environment`. It comes from the repository, so it
  goes through `__bga_read_version`: a symlink is followed only inside the
  repository, a NUL ends the read, and the value must be version-like (first
  word, 32 characters of a fixed set). No file means no segment.
- **Display:** `k8s NAME`, `aws NAME`, `tf NAME`, each in its own color
  token, with names longer than 40 characters shortened from the start (the
  end of an EKS ARN is the part that matters). They go after the runtimes,
  and are dropped before the runtimes, after the clock, when space runs out.
  The classic layout shows them as `[k8s NAME]`. Plain mode shows none.
- Every label is escaped with `__bga_ps1_lit`.

## Alternatives considered

- **Running `kubectl config current-context`:** about 50 ms and a fork
  per prompt.
- **Parsing the full kubeconfig for the namespace:** that needs real YAML
  parsing of the contexts list. It is left out until someone asks for it.
- **Showing `tf default` when `.terraform` exists without `environment`:**
  it would be noise in every Terraform repository.

## Consequences

- With `contexts` empty, the only cost is one string test per prompt.
- The kube cache relies on mtime. The file is read again unless the marker
  is strictly newer than it. On bash before 5.1, which compares whole
  seconds, a change in the same second as the last read is still picked
  up. The cost is extra reads during that one second.
