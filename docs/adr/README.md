# Architecture Decision Records

Decisions that shape bash-gitaware v2. Each ADR captures the context, the choice
made, the alternatives considered and the consequences. We use a lightweight
MADR-style template (see [`template.md`](template.md)).

| #    | Title                                                                                          | Status   |
|------|------------------------------------------------------------------------------------------------|----------|
| 0001 | [Module architecture and the build pipeline](ADR-0001-module-architecture-and-build-pipeline.md)| Accepted |
| 0002 | [Tiered glyph detection (locale is not font)](ADR-0002-tiered-glyph-detection.md)              | Accepted |
| 0003 | [Modern terminal integration: OSC 133 + OSC 7](ADR-0003-osc-133-and-osc-7-terminal-integration.md) | Accepted |
| 0004 | [Transient prompt](ADR-0004-transient-prompt.md)                                               | Accepted |
| 0005 | [Async / non-blocking rendering](ADR-0005-async-rendering.md)                                  | Accepted |
| 0006 | [Bash-only, bash 4.4+](ADR-0006-bash-only-bash-44-plus.md)                                     | Accepted |

## Conventions

- New decisions: copy [`template.md`](template.md) to
  `ADR-NNNN-short-kebab-title.md`. The number increases monotonically; never
  reuse a retired number.
- A decision that supersedes an older one: set the older ADR's status to
  `Superseded by ADR-NNNN` and link forward. Do not delete superseded ADRs.
- Status values: `Proposed`, `Accepted`, `Rejected`, `Deprecated`,
  `Superseded by ADR-NNNN`.
- ADRs document the why. The spec and the plan are in
  [`../SPEC.md`](../SPEC.md) and [`../PLAN.md`](../PLAN.md); the implementation
  lives in `lib/`; the render pipeline is drawn in
  [`../diagrams/render-pipeline.md`](../diagrams/render-pipeline.md).
