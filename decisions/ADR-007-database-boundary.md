# ADR-007: Database boundary — shell tables vs backend tables in shared RTMViewDB; naming; dev emulation

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner), Architecture team
**Tags:** architecture, persistence, deployment

## Context

The RTM View Shell shares the `RTMViewDB` PostgreSQL database with the CC backend platform.
Two distinct ownership categories of tables must coexist:

- **Shell tables** (owned by this codebase): user management, permission groups, dashboards,
  widget catalogue, audit logs. Managed via EF Core Code-First migrations.
- **Backend tables** (owned by CC platform): `NGC_Queue`, `NGC_Supergroup`, `NGC_Agentgroup`,
  `NGC_BusinessUnit`, `RTSGrid_*`, `RTSUserGrid_*`. Written by the CC platform; read-only
  from the shell's perspective.

Problems to solve:
1. EF Core migrations must not touch backend tables.
2. In development, there is no live CC platform; backend tables must be emulated.
3. Naming conventions must make ownership unambiguous at a glance.

## Options considered

### Option A — Two separate PostgreSQL databases (shell DB + CC platform DB)
- **Pros:** Perfect isolation; EF migrations never risk CC tables.
- **Cons:** Cross-database joins are impossible in PostgreSQL without `dblink` or FDW.
  Read queries for permission-group resource lists require remote calls.
  Deployment complexity on a single Windows Server is high.
- **Cost estimate:** High; foreign data wrapper adds network latency.

### Option B — Shared database; EF only manages shell schema; backend tables are read via raw SQL / Dapper
- **Pros:** Cross-table joins are cheap. Shell can filter permissions against live CC data.
- **Cons:** EF `DbContext` cannot have navigation properties to backend tables.
  Raw SQL bypass loses type safety.
- **Cost estimate:** Medium; Dapper adds dependency.

### Option C — Shared database; separate BackendEmulationDbContext for dev; read-only DbSets in AppDbContext for backend tables (chosen)
- **Pros:** In production: `AppDbContext` has `DbSet<NgcQueue>`, `DbSet<NgcSupergroup>`, etc.
  as read-only (no migrations; configured via `IEntityTypeConfiguration`).
  In development: `BackendEmulationDbContext` with its own migration history
  (`__BackendEmulationMigrationsHistory`) creates the backend tables with test data.
  Naming convention enforced: shell tables use `snake_case`; backend tables use `PascalCase`
  (`NGC_*`, `RTSGrid_*`, `RTSUserGrid_*`).
- **Cons:** Two `DbContext` types; developers must remember not to run backend migrations in production.
- **Cost estimate:** +1 sprint day (B1 #11 implementation).

## Decision

We chose **Option C**.

## Rationale

1. Shared database is a hard deployment constraint (single Windows Server, single PostgreSQL
   instance; no FDW); cross-database joins ruled out Option A.
2. Separate `BackendEmulationDbContext` with its own `__BackendEmulationMigrationsHistory`
   guarantees EF never auto-detects backend tables in its main migration history.
3. `PascalCase` table naming (`NGC_Queue`) vs `snake_case` (`permission_groups`) is a
   visually unambiguous ownership signal that survives schema dumps and log files.
4. Read-only `DbSet`s in `AppDbContext` allow LINQ joins for permission queries; EF entity
   configurations mark these tables with explicit key mapping and no migration output.

## Requirement traceability

- Implements: project_data_ownership.md (5-category table ownership model)
- Implements: [ARCH-01] (GQF applies to backend junction tables with TenantId)
- Implements: [DEPLOY-08] (single-server, single-DB topology)

## Open questions

- OQ-1: Should backend tables in `AppDbContext` use `HasNoKey()` or explicit surrogate PK?
  — Status: Resolved 2026-05-25. Surrogate PK required for navigation properties
  (e.g., `NgcSupergroupAgentgroup.Id`); see section 29.3 EF Core gotchas in CLAUDE.md.
- OQ-2: In CI, does `BackendEmulationDbContext` target the same Testcontainers Postgres
  instance as `AppDbContext`? — Status: Resolved 2026-05-25. Yes; `PostgresFixture`
  exposes `CreateBackendEmulationDbContext()` for the same connection string.

## Consequences

**Positive**

- EF migrations are safe; backend tables cannot be accidentally altered or dropped.
- Dev/CI environment fully emulates production data without a live CC platform.
- `PascalCase` naming convention is self-documenting.

**Negative / trade-offs**

- Two `DbContext` types increase DI configuration complexity.
- Developers must remember the `--context AppDbContext` flag for EF migration commands.

**Migration / rollout impact**

- `BackendEmulationDbContext` migrations run only in dev/CI; guarded by environment check.
- Production never runs `BackendEmulationDbContext.Database.MigrateAsync()`.

## Notes

- Code: `src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs`.
- Common dev command:
  `dotnet ef migrations add <Name> --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`
- See section 27 (common commands) and section 29.3 (EF gotchas) in CLAUDE.md.
