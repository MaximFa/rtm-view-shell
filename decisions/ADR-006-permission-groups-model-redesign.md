# ADR-006: Permission Groups model redesign — drop Skills, split SG/AG, AccessLevel bitmask, MenuPermissions extension

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner), Architecture team
**Tags:** permissions, data-model

## Context

The original TZ v1.0 Permission Groups model had:
- Skills as a separate resource type (permitted via `pg_skills` junction table).
- Agent Supergroups and Agent Groups conflated under a single junction.
- Dashboard access as a binary allow/deny flag.
- Menu permissions limited to five keys.

During wireframe review the following changes were requested:

1. **Drop `pg_skills`** — CC platform routing by skill is handled upstream; RTM dashboards
   never need skill-level filtering. Removing skills simplifies the permission editor.
2. **Split `pg_agent_supergroups`** — Agent Supergroups (NGC_Supergroup) and Agent Groups
   (NGC_Agentgroup) are different entities; they must be permissioned separately.
3. **AccessLevel bitmask for dashboards** — Replace binary with View=1 / Edit=2 / Delete=4 / Full=7.
4. **Extend menu keys** — Add `menu.tenantSettings`, `menu.tenants`; update role constraints.

## Options considered

### Option A — Preserve original model; add columns/tables incrementally
- **Pros:** Backward-compatible; existing migrations untouched.
- **Cons:** Confusing schema with vestigial `pg_skills` table; AccessLevel bool requires
  a second migration when bitmask is needed.
- **Cost estimate:** Lower now, higher migration debt later.

### Option B — Redesign model in a single migration; implement as specified above (chosen)
- **Pros:** Clean schema matches the final mental model. No vestigial tables.
  AccessLevel bitmask enables fine-grained permission checks from day one.
- **Cons:** Larger initial migration; requires regenerating seed data.
- **Cost estimate:** +1 sprint day (migration complexity).

## Decision

We chose **Option B**.

## Rationale

1. The codebase is pre-production; no live data to migrate. A clean-break redesign
   is lower-risk than incremental patching.
2. `pg_skills` carries a permanent maintenance cost (UI tab, tests, query joins) for
   zero business value in the RTM context. Removing it now saves that cost permanently.
3. The AccessLevel bitmask ([PG-01], section 15) is a first-class requirement in TZ v1.3;
   implementing as bool first would require a breaking migration within weeks.
4. Splitting Supergroups from Agent Groups matches the CC data model
   (`NGC_Supergroup` vs `NGC_Agentgroup`) and avoids ambiguity in permission editor UI.

## Requirement traceability

- Implements: section 6.2 `pg_queues`, `pg_agent_supergroups`, `pg_business_units` (skills removed)
- Implements: section 6.2 `dashboard_permissions` `AccessLevel INTEGER`
- Implements: section 6.2 `menu_permissions` extended key set
- Implements: [PG-01], [PG-03], [PG-04], [PG-06], [PG-07]

## Open questions

- OQ-1: Should AccessLevel `Edit` (bit 2) implicitly grant `View` (bit 1), or must
  both bits be set? — Status: Resolved 2026-05-15. Store combined mask (Edit stored as 3,
  Delete stored as 5, Full = 7); query checks `(AccessLevel & requiredBit) != 0`.

## Consequences

**Positive**

- Clean, minimal schema; permission editor tabs match entity types.
- Bitmask enables future `Share` or `Publish` bits without schema change.

**Negative / trade-offs**

- `pg_skills` table removed entirely; any future skill-level filtering must be added back.
- Initial migration is larger and requires careful test-data seeding.

**Migration / rollout impact**

- Drop `pg_skills` table in migration.
- Add `pg_agent_supergroups` and `pg_business_units` junction tables if not present.
- Alter `dashboard_permissions.AccessLevel` from BOOLEAN to INTEGER.
- Seed extended `menu_permissions` keys.

## Notes

- Code: `src/CcDashboard.Infrastructure/Persistence/Configurations/`.
- See also: ADR-007 (database boundary for NGC_* tables).
