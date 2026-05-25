# Backlog B1 #11 — Introduce `BackendEmulationDbContext`

**Type:** Infrastructure refactor  
**Estimate:** ~2–3 h Claude Code  
**Unblocks:** Sprint T3 (multi-tenancy integration), Sprint T5 Phase B (widget lifecycle)  
**ADR reference:** ADR-007 (Database boundary — shell tables vs backend tables)

---

## 1. Problem

`AppDbContext` currently owns **all** tables — both our shell tables
(`snake_case`) and backend-owned tables (`PascalCase`: `NGC_*`,
`RTSGrid_*`, `RTSUserGrid_*`). Our EF migrations create the backend
tables in dev, but in production those tables already exist (created and
maintained by the backend team's own deployment). This means:

- `dotnet ef database update` in prod **fails** with "relation already
  exists" for every backend-owned table.
- There is no clean way for tests (T3, T5) to seed or reset backend
  reference data independently of the shell's transaction-rollback
  fixture pattern.

---

## 2. Goal

Introduce `BackendEmulationDbContext` — a second EF `DbContext` that:

1. Connects to the **same database** as `AppDbContext` (same connection
   string, same schema).
2. Contains `DbSet<T>` for all backend-owned entities:
   - `NgcSite`, `NgcBusinessUnit`, `NgcSupergroup`, `NgcQueue`,
     `NgcAgentGroup`, `NgcBusinessUnitQueueClassification`,
     `NgcBusinessUnitSupergroup`, `NgcSupergroupAgentgroup`
   - `RtsGridMetric`
   - `RtsUserGridGrid`, `RtsUserGridColumnsSet`, `RtsUserGridColumn`
3. Has its own EF migration history table
   (`__BackendEmulationMigrationsHistory`) so its migrations are
   independent of `AppDbContext`'s history.
4. Its first (and only, for now) migration creates all backend-owned
   tables from scratch — this migration runs **only in dev/test**, not
   in production.
5. `AppDbContext` retains its `DbSet<T>` properties for backend entities
   (Application-layer code references them for reading/writing); only
   the **migration ownership** moves.

**Out of scope for B1 #11:**
- Marking backend entities with `ExcludeFromMigrations()` in `AppDbContext`
  (that would require a new AppDbContext migration — separate task).
- Changing application commands/queries that read/write backend tables.
- Dual-write pattern (ADR-008 — separate sprint).
- Removing existing AppDbContext migrations that created backend tables
  (risky; separate task after all tests are green on new setup).

---

## 3. Architectural micro-choices (sign-off required)

| # | Question | Options | Decision |
|---|---|---|---|
| MC-B1-1 | Migration history table name | A. `__BackendEmulationMigrationsHistory`  B. `__EFMigrationsHistory` (same as prod backend) | **A** — keeps dev/prod boundary explicit |
| MC-B1-2 | Where to register `BackendEmulationDbContext` | A. Always registered, dev-only migrations  B. Registered only when `IsDevelopment() or IsTesting()` | **A** — simpler; context is harmless in prod if migrations don't run |
| MC-B1-3 | Dev migration trigger | A. Manual: `dotnet ef database update --context BackendEmulationDbContext`  B. Auto in `DatabaseInitializer` when env = Development/Testing | **B** — consistent with existing `DatabaseInitializer` pattern |

**Decision: MC-B1-1=A, MC-B1-2=A, MC-B1-3=B**  
*(These are architect-recommended defaults; override before hand-off if needed.)*

---

## 4. Definition of Done

- [ ] **DoD-1:** `BackendEmulationDbContext` class exists in
  `CcDashboard.Infrastructure/Persistence/` with all 11 backend DbSets.
- [ ] **DoD-2:** Separate migration folder `Migrations/BackendEmulation/`
  contains one initial migration (`InitialBackendSchema`) that creates
  all backend-owned tables.
- [ ] **DoD-3:** `BackendEmulationDbContext` is registered in DI in
  `InfrastructureServiceExtensions` with its own `MigrationsHistoryTable`
  option set to `__BackendEmulationMigrationsHistory`.
- [ ] **DoD-4:** `DatabaseInitializer.InitializeAsync` applies
  `BackendEmulationDbContext` migrations when
  `IHostEnvironment.IsDevelopment() || IHostEnvironment.EnvironmentName == "Testing"`.
- [ ] **DoD-5:** `PostgresFixture` in `Tests.Security` exposes
  `BackendEmulationDbContext BeDb` property (alongside existing
  `AppDbContext Db`) for use in T3 / T5 test seeding.
- [ ] **DoD-6:** All 247 existing tests still pass (`dotnet test
  CcDashboard.sln`).
- [ ] **DoD-7:** `dotnet build CcDashboard.sln` — 0 errors, 0 warnings
  (except pre-existing nullable warnings if any).

---

## 5. Key files to read before starting

```
src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs
src/CcDashboard.Infrastructure/Persistence/InfrastructureServiceExtensions.cs (or DI registration file)
src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs
src/CcDashboard.Domain/Domain/NgcEntities.cs
src/CcDashboard.Domain/Domain/RtsEntities.cs
src/CcDashboard.Domain/Domain/RtsGridMetric.cs
tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs
```

---

## 6. Notes / gotchas

- `BackendEmulationDbContext` must NOT have Global Query Filters — these
  entities are backend-owned and don't have shell-side `TenantId`
  ownership semantics (or if they do, it's for read-filtering only).
- `RtsUserGridGrid` does not have a `TenantId` column — it's a pure
  backend adaptation table. Do not add one.
- The existing `AppDbContext` entity configurations for backend tables
  (in `AppDbContext.OnModelCreating` or `IEntityTypeConfiguration<T>`
  files) should be **copied** to `BackendEmulationDbContext.OnModelCreating`,
  not removed from `AppDbContext`. Both contexts need the same table
  mappings to operate correctly against the same schema.
- When scaffolding the migration: `dotnet ef migrations add
  InitialBackendSchema --context BackendEmulationDbContext --project
  src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`
- Use Python read→modify→write (not Edit tool) for any file with ≥2
  changes. After every write: `tail -3 <path>` + `wc -l` to verify.
  See CLAUDE.md §0.3.

---

## 7. Hand-off to Claude Code

```
Read: docs/sprints/backlog-b1-11-backend-emulation.md

§2 micro-choices are pre-signed (MC-B1-1=A, MC-B1-2=A, MC-B1-3=B).

Implement B1 #11 per the brief. DoD-1 through DoD-7 are the acceptance
criteria.

Working agreement:
1. Read the five key files listed in §5 before writing any code.
2. Diagnostics first, fix later — if a build or test fails, report
   expected vs actual + root cause hypothesis before changing code.
3. No changes to existing AppDbContext migrations or to any file outside
   the scope described in §2.
4. Use Python read→modify→write for any file requiring ≥2 edits
   (CLAUDE.md §0.3). After every write: tail -3 + wc -l via bash.
5. Do not touch tests outside Fixtures/PostgresFixture.cs.

On completion:
- Confirm DoD-1..7 with git log reference for the commit.
- Write a gap-analysis table (DoD | Required | Actual | Status) as the
  first close-out artefact.
- Commit message: "feat(B1-11): introduce BackendEmulationDbContext per ADR-007"
```
