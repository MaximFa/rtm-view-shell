# CC task — Reports-as-Dashboards Ф1: entities + EF migration + widget-type seed
> Coordinator-authored (operator-directed) per docs/Reports-AsDashboards-v1-Spec.md. Owner: BACKEND (EF entities/migration) + DBA (schema co-review: GQF, indexes, FK, types). Executor: native CC. Branch **v3**. Commit `web:`/`feat:`. **NO push** (§37). FREE/MIT only.
> SCOPE Ф1 = the SEPARATE report entity layer + migration + widget-type seed ONLY. NO UI, NO resolver logic, NO export/distribution (later phases). Reuses (NO change): hist_*, the 4 MediatR report queries, HistoricalReportRepository, ReportScopeResolver, TenantSettings.EmailProviderConfig, IEmailSender.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A+§C (executing role)
- `docs/Reports-AsDashboards-v1-Spec.md` §2 (decisions: SEPARATE entity), §3 (domain model), §4 (scope model — for FK/shape awareness only; resolver is Ф2)
Only after reading: proceed.

## INIT — branch v3 + integrity + sync
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE, never mount `git status` §0.5).
- §0.2 integrity. §0.3 writes via Python+os.fsync (Edit BANNED on the mount; native-CC editor OK on Windows — but verify by object-store after).
- §42.6 sync: S1 `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (CLOSED tombstone → proceed). Slug = executing backend slug. Claims (NEW territory, file-mode): `src/CcDashboard.Domain/Domain/Reports/**`, `src/CcDashboard.Infrastructure/Persistence/Configurations/Report*`, `src/CcDashboard.Infrastructure/Migrations/App/**` (new migration only), `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs` (DbSet additions — re-sync from HEAD first), `docs/Reports-AsDashboards-v1-Spec.md`.
- ⚠ NARROW-ADD (L-SC-09 / 9c6ac0e lesson): `git add` ONLY the explicit new/edited paths above; NEVER `git add -A`/sweep; `git status --short` before commit; re-sync any shared file (AppDbContext.cs) from HEAD before editing so you don't revert others.
- §0.6b binding PREAMBLE/POSTAMBLE → `.coord/cc/backend.md`. commit.lock around commit. NO push.

## THE WORK — 5 new entities (SEPARATE from dashboards), mirror the dashboard shapes

All multi-tenant: `TenantId` (uuid) + Global Query Filter `e => e.TenantId == _tenantContext.TenantId`. PKs uuid **UUIDv7** (`UUIDNext.Uuid.NewSequential()`). Timestamps `timestamptz` UTC. IEntityTypeConfiguration<T> per entity. Schema `public`.

1. **`report_screens`** (mirror `Dashboard`): `Id, TenantId, Name varchar(200), Description varchar(500)?, CategoryId uuid?, Status (ReportScreenStatus: Draft|Published), IsPublic bool, IsDarkMode bool, LayoutJson jsonb?, CreatedByUserId, CreatedAt, UpdatedByUserId, UpdatedAt, IsDeleted bool, DeletedAt?, DeletedByUserId?, RowVersion (xmin shadow concurrency token)`. **Combined GQF: `TenantId && !IsDeleted`**. Index `(TenantId, Name)`.
2. **`report_widgets`** (mirror `DashboardWidget`, NO GridId — reports query hist_*, not RTM SignalR): `Id, ReportScreenId (FK→report_screens), TenantId, ReportWidgetType (enum: QueueInterval|QueueWaitTime|AgentMonthly|AgentShiftDetail|Distribution), PositionJson jsonb?, ConfigJson jsonb?, IsDeleted bool`. **Combined GQF `TenantId && !IsDeleted`** (backend+dba flag 2026-06-24 — soft-deleted widgets must NOT surface). Index `(ReportScreenId)`, `(TenantId)`.
3. **`report_permissions`** (mirror `DashboardPermission`): `PermissionGroupId (FK), ReportScreenId (FK), TenantId, AccessLevel int` (bitmask View=1/Edit=2/Delete=4/Full=7). PK `(PermissionGroupId, ReportScreenId)`.
4. **`report_categories`** (mirror `DashboardCategory`): `Id, TenantId, Name, IsActive`. **DBA-CONFIRMED (2026-06-24): SEPARATE table** — decoupled from the dashboard category lifecycle; no scope-discriminator (avoids GQF complexity + cross-scope leakage). Build separate.
5. **`report_schedules`**: `Id, ReportScreenId (FK), TenantId, Cadence varchar (cron-ish), Recipients jsonb, Format (enum: Xlsx|Pdf|Both), DateWindow (enum: RollingDays|PreviousMonth|Fixed) + RollingDays int? + FixedFrom/To?, IsActive bool, LastRunAt?, NextRunAt?, CreatedByUserId, CreatedAt`. Index `(TenantId, IsActive, NextRunAt)`.

## AppDbContext + migration
- Add `DbSet<>` for all 5; register configs; apply GQF: **report_screens AND report_widgets** both combined `TenantId && !IsDeleted`; the other 3 = TenantId-only. xmin shadow concurrency on report_screens (pattern: §29.3).
- `dotnet ef migrations add AddReportEntities --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`. Auto-generated migration ONLY (MAINT-04). Self-record per §38a if it's a db/migrations SQL file — N/A here (EF migration; EF tracks it).
- Indexes per DATA-08 — **all FK columns indexed (dba fold 2026-06-24):** `report_permissions(ReportScreenId)` (PK is (PermissionGroupId,ReportScreenId) → ReportScreenId not index-leading), `report_schedules(ReportScreenId)`, `report_screens(CategoryId)`; plus (TenantId,Name) on screens + the schedule (TenantId,IsActive,NextRunAt). (report_widgets(ReportScreenId) already covered.) DBA reviews the generated `ef migrations script` DDL before commit.

## SEED — report-widget type registry (idempotent, first-run)
Seed the 5 ReportWidgetType entries (catalog/registry the palette reads) — category "Reports": QueueInterval, QueueWaitTime, AgentMonthly, AgentShiftDetail, Distribution. Idempotent (skip if present). NO default report-screens here (that's Ф8 migration).

## VERIFY (build + object-store)
- `dotnet build CcDashboard.sln` = 0 errors. `dotnet ef migrations script` (or `--idempotent`) generates clean (DBA reviews the DDL for GQF/indexes/types/FK).
- A re-run `ef migrations add` probe = NO further model diff (snapshot consistent).
- Object-store: committed set = ONLY the claimed paths (Domain/Reports/**, Configurations/Report*, new Migration, AppDbContext.cs, the spec doc) — `git diff --name-only` clean of non-claimed; no CLAUDE.md/other-shared sweep.

## COMMIT (web:/feat:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the explicit paths (incl `docs/Reports-AsDashboards-v1-Spec.md` as the authoritative artifact) → commit -m "feat(reports): Ф1 — report_screens/_widgets/_permissions/_categories/_schedules entities + EF migration + widget-type seed (Reports-as-Dashboards v1) [backend]" → §0.6 post-commit (git show v3:) → `bash tools/cc_post_commit.sh <slug> <hash>` → PD-007 re-sync → sync.

## Binding RESULT → .coord/cc/backend.md: commit hash; 5 entities + migration + seed + spec doc; build 0; ef-probe no-diff; only-claimed-files; NO push. verified: object-store.
## REPORT (chat) + flag coordinator: DBA category decision (separate vs shared), any schema concern. Ф2 (BuMembershipResolver) is the next phase.
