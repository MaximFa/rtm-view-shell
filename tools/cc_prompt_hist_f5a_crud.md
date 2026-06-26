# CC-HIST-F5a — report_screens / report_widgets CRUD + permissions (BACKEND, foundation for Ф5b)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3 (tip aa544d0 — checkout by SHA, §0.5). §4-bless BEFORE run. RUN FIRST (Ф5b depends).
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-24T23:20Z). Mirror dashboard CRUD; entities Ф1, NO migration ✓; permission enforcement App-layer non-bypassable (CODE-03) ✓; PG-scoped queries + server-pagination (PERF-02) ✓; GQF+xmin; IsSystem-gap correctly flagged for Ф8 (parked, not needed now); claim Application/Reports/** no shell overlap ✓; all process blocks (branch-by-SHA aa544d0, reads, sync slug bi-0619, BINDING PRE/POST, lock 5×60s, NO push). RUN FIRST + PUBLISH the CRUD signatures/DTOs in RESULT (shell Ф5b binds to them). CLEARED TO RUN.
> Entities EXIST (Ф1): Domain/Reports/{ReportScreen, ReportWidget, ReportPermission, ReportCategory} + EF configs. CRUD ONLY — **NO new migration**.
> MIRROR the proven dashboard CRUD (Commands/Dashboards, Queries/Dashboards, IDashboardRepository, dashboard_permissions) — same shapes/semantics (master §3/§8/§15).

## STEP 0 — integrity + branch-by-SHA (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD   # expect aa544d0 (verify object-store)
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — mandatory reads + §C VERIFY + sync block
Read role-bi §A/§C + session-coord. Apply sync block: slug=`bi-0619`, claims (file-mode, bi territory):
`src/CcDashboard.Application/Reports/**` (Commands+Queries+DTOs+Interfaces for report-screen CRUD),
`src/CcDashboard.Infrastructure/Persistence/Repositories/ReportScreenRepository.cs`,
`src/CcDashboard.Infrastructure/Handlers/*ReportScreen*`/CRUD handlers, `tests/CcDashboard.Tests.Unit/Reports/**`.
NO overlap with shell `Components/**` / `Pages/**` (frontend). Reference (read-only) the dashboard CRUD to mirror.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

---

## THE WORK — mirror dashboard CRUD for report_screens (entities from Ф1, NO migration)

### A. MediatR commands (Application/Reports/Commands)
- CreateReportScreenCommand(Name, Description?, CategoryId?, IsPublic, IsDarkMode) -> ReportScreenDto. On create: set Created/Updated audit; **PG-01: creator's PG gets AccessLevel=7 (Full)** in report_permissions (mirror dashboard PG-01).
- UpdateReportScreenCommand(Id, Name, Description?, CategoryId?, Status, IsPublic, IsDarkMode, LayoutJson?) — xmin concurrency check.
- DeleteReportScreenCommand(Id) — **SOFT delete** (IsDeleted/DeletedAt/DeletedByUserId), like dashboards. (Soft-delete => no PG-06 hard-delete blocker needed; if a hard-delete path is ever added, guard on active report_schedules referencing the screen — note, not built here.)
- SaveReportWidgetsCommand(ReportScreenId, widgets:[{ Id?, WidgetType, PositionJson, ConfigJson, IsDeleted }]) — upsert/replace the widget set for a screen (editor save). ConfigJson = §2-LOCKED schema; validate via the Ф2.5 ReportWidgetConfigValidator (reuse) before persist; soft-remove dropped widgets.
- (Optional, mirror) RestoreReportScreenCommand(Id).

### B. MediatR queries (Application/Reports/Queries)
- GetReportScreensQuery(search?, categoryId?, status?, isPublic?, page, pageSize) -> paged ReportScreenDto[] — **PG-scoped**: return screens where the user's PG has View (report_permissions AccessLevel & 1) OR IsPublic (no explicit PG deny); Superadmin = all tenant. Server-side pagination (PERF-02).
- GetReportScreenQuery(Id) -> ReportScreenDetailDto (screen + widgets[]) — requires View; deny otherwise.
- GetReportCategoriesQuery() -> ReportCategoryDto[] (for the list filter).

### C. Permission enforcement (master §15, CODE-03)
report_permissions bitmask View=1/Edit=2(stored 3)/Delete=4(stored 5)/Full=7. [Authorize] on the entry + **Application-layer
check** (handler or AuthorizationBehavior) — NOT UI-only: List filters by View; Get requires View; Update requires Edit;
Delete requires Delete; SaveReportWidgets requires Edit. **Superadmin bypass** (all). PG-01 creator-Full on Create.
Effective permission = union of the user's PG report_permissions (most permissive wins), mirror dashboards.

### D. Repository + DTOs
- IReportScreenRepository (Application/Reports/Interfaces) + EF impl (Infrastructure/Persistence/Repositories/ReportScreenRepository.cs):
  AsNoTracking reads; GQF = TenantId && !IsDeleted (combined, like Dashboard); xmin as [ConcurrencyCheck] -> on
  DbUpdateConcurrencyException surface "Record modified by another user". Include Widgets on Get.
- DTOs (Application/Reports/DTOs): ReportScreenDto (Id, Name, Description, CategoryId, CategoryName, Status, IsPublic,
  IsDarkMode, UpdatedAt, AccessLevel-for-user), ReportScreenDetailDto (+ LayoutJson + Widgets[]), ReportWidgetDto
  (Id, WidgetType, PositionJson, ConfigJson), ReportCategoryDto (Id, Name).
- FluentValidation on commands (Name required, etc.).

### E. NO MIGRATION — flag gaps
Ф1 entities suffice for CRUD. ⚠ FLAG (do NOT add): ReportScreen has NO IsSystem column — the Ф8 default/system screens
(IsSystem non-deletable) need it; **Ф8 IsSystem A/B is operator-PARKED** — CRUD does not need it now; surface that Ф8 will
require an IsSystem migration. If any OTHER needed column is missing, STOP + flag (do not silently migrate).

### Tests (unit, tests/CcDashboard.Tests.Unit/Reports/) — DoD GREEN
(1) Create -> creator PG gets Full (PG-01); (2) List PG-scoped (View-only screens + IsPublic; out-of-PG excluded; Superadmin all);
(3) Get requires View (deny otherwise); (4) Update requires Edit + xmin concurrency conflict surfaces; (5) Delete soft + requires
Delete; (6) SaveReportWidgets requires Edit + ConfigJson validated + soft-remove dropped; (7) GQF tenant isolation.

### ACCEPTANCE (DoD)
- Soma /ops/build = exit 0; /ops/test?suite=unit GREEN (CRUD + permission-enforcement tests). serilog clean.
- NO migration (Ф1 entities); contour read-only; permission checks non-bypassable (Application-layer, not UI-only).
- **PUBLISH in RESULT: every command/query signature + DTO shape** = the CRUD contract shell's Ф5b binds to.

## STEP 3 — binding POSTAMBLE RESULT -> .coord/cc/bi.md (commit, build/test, files) + the CRUD signatures/DTOs for shell.
## STEP 4 — §0.6b CAPTURE role-bi §B if a lesson; cc_post_commit.sh + §0.6/PD-007 re-sync.
## COMMIT: feat: (Application/Infrastructure report CRUD), commit.lock (5x60s), object-store verify, NO push (§37, bundled barrier).
