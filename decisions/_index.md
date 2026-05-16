# ADR Index — RTM View Shell

This is the authoritative registry of all Architecture Decision Records.
**Rules:**

- ADR IDs are monotonic three-digit numbers (`ADR-001`, `ADR-002`, ...). **Never reuse.**
- An ADR file is created from `_template.md`.
- When an ADR is superseded, set its `Status` to `Superseded by ADR-XXX` — do not delete.
- The TZ (`CC_Dashboard_Shell_TZ_v1.3_EN.docx` and later versions) references ADRs by ID.

## Open

| ID | Title | Tags | Owner | Date |
|---|---|---|---|---|
| [ADR-001](ADR-001-widget-catalogue-scope.md) | Widget Catalogue scope — entity yes, admin CRUD screen no | scope, ui, permissions | TBD | 2026-05-15 |
| [ADR-002](ADR-002-navigation-menu-redesign.md) | Navigation menu redesign — new groups + new menu keys + tenant-settings folding | ui, permissions | TBD | 2026-05-15 |
| [ADR-003](ADR-003-per-tenant-licensing.md) | Per-tenant licensing model — Purchased licences + User connections | commercial, security, audit | TBD | 2026-05-15 |
| [ADR-004](ADR-004-signalr-widget-feed-seam.md) | External widget data feed seam — per-tenant SignalR Connection URL | integration, multi-tenancy | TBD | 2026-05-15 |
| [ADR-005](ADR-005-per-tenant-theme-palette.md) | Per-tenant theme palette — background/font colours + font-size presets | ui, theming, i18n | TBD | 2026-05-15 |
| [ADR-006](ADR-006-permission-groups-model-redesign.md) | Permission Groups model redesign — drop Skills, split SG/AG, AccessLevel, MenuPermissions extension | permissions, data-model | TBD | 2026-05-15 |
| [ADR-007](ADR-007-database-boundary.md) | Database boundary — shell tables vs backend tables in shared `RTMViewDB`; naming; dev emulation | architecture, persistence, deployment | TBD | 2026-05-15 |
| [ADR-008](ADR-008-dual-write-pattern.md) | Dual-write pattern — DB + Backend API notification for categories 3 & 4; replaces NoOpConfigurationApiHook | integration, reliability | TBD | 2026-05-15 |

## Accepted

| ID | Title | Tags | Date |
|---|---|---|---|

## Superseded

| ID | Title | Superseded by | Date |
|---|---|---|---|

## Withdrawn

| ID | Title | Reason | Date |
|---|---|---|---|

---

## How to write an ADR

1. Copy `_template.md` to `ADR-NNN-short-slug.md` (next free ID, kebab-case slug).
2. Fill in **Context** with enough detail that a reader six months later can reconstruct
   the situation without asking.
3. Document **at least two options**. "Do nothing" or "keep current behaviour" is a
   legitimate option.
4. **Rationale** must reference concrete requirements/markers — vague justification is
   a red flag.
5. List **Open Questions** explicitly. An ADR with unanswered OQs can still be Accepted
   if the OQs don't block implementation; mark them clearly.
6. Add an entry to the appropriate table in this index file.

## When NOT to write an ADR

- A coding-style preference (use a linter / `.editorconfig`).
- A trivial library choice with no alternatives debated (just commit it).
- A bug fix (use a commit message).

The litmus test: *Will a future developer/auditor want to know "why did we do this?"
six months from now?* If yes → ADR.
