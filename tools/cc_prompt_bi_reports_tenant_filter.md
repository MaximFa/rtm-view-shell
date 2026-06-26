# CC TASK — optional Guid? TenantId on the 4 report queries (Superadmin per-page tenant-filter)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. Replaces the REVERTED ARCH-02 global switch with the SAME per-page tenant-selector the
> admin pages already ship (GetPermissionGroupsQuery pattern, §29.2). NOT a security feature (no claim/command/impersonation).
> A Superadmin may pass any TenantId (cross-tenant read, like Users/PG pages); a non-Superadmin's param is IGNORED (own tenant).
> Lands WITH shell's UI half (ReportsListPage tenant-selector threading the chosen TenantId). NO push (bundled barrier).

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short   # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode, bi Application + the report repo — no shell [web] overlap):
- src/CcDashboard.Application/Reports/Queries/GetReportScreensQuery.cs
- src/CcDashboard.Application/Reports/Queries/GetReportCategoriesQuery.cs
- src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs  (GetMyBusinessUnitsQuery only — touch just that record+handler)
- src/CcDashboard.Application/HistoricalReports/Queries/RunReportWidgetQuery.cs
- src/CcDashboard.Application/Handlers/RunReportWidgetQueryHandler.cs
- src/CcDashboard.Infrastructure/Persistence/Repositories/ReportScreenRepository.cs
- tests/CcDashboard.Tests.Unit/** (handler tenant-resolution tests)
- .claude/skills/role-bi/role-bi.md (§B)
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## RESOLUTION RULE (apply identically in all 4 handlers) — Superadmin-gated, non-Superadmin param IGNORED
```csharp
var tenantId = currentUser.Role == "Superadmin"
    ? (query.TenantId ?? currentUser.TenantId!.Value)
    : currentUser.TenantId!.Value;          // non-Superadmin: param IGNORED → own tenant (no cross-tenant leak)
```
This is STRICTER than GetPermissionGroupsQuery's non-Superadmin branch (`query.TenantId ?? own`, which HONORS the param) — deliberate per the operator/coordinator rule "non-Superadmin's param is ignored". SF-BI-001 BU∩PG stays intact (the scope resolver uses currentUser's PG; Superadmin → FullScope).

## EDITS

### EDIT 1 — GetReportScreensQuery.cs
Record (L10): `public record GetReportScreensQuery(ReportScreenListRequest Request, Guid? TenantId = null) : IRequest<PagedResult<ReportScreenDto>>;`
Handler (L24): replace `var tenantId = currentUser.TenantId!.Value;` with the RESOLUTION RULE. (`isSuperadmin`/`pgId` unchanged — passed to repo.GetPageAsync; Superadmin viewing another tenant → isSuperadmin=true → repo skips PG filter, queries the chosen tenant.)

### EDIT 2 — GetReportCategoriesQuery.cs
Record (L8): `public record GetReportCategoriesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<ReportCategoryDto>>;`
Handler (L17): replace `var tenantId = currentUser.TenantId!.Value;` with the RESOLUTION RULE.

### EDIT 3 — ConfigurationQueries.cs (GetMyBusinessUnitsQuery ONLY)
Record (L52): `public record GetMyBusinessUnitsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<BusinessUnitDto>>;`
Handler (L60+): name the param (`Handle(GetMyBusinessUnitsQuery query, ...)` — currently `_`). Add at the top:
`var tenantId = user.Role == "Superadmin" ? (query.TenantId ?? user.TenantId) : user.TenantId;`
Then in the existing `if (user.Role is "Superadmin" or "Administrator")` branch, change `repo.GetAllByTenantAsync(user.TenantId, ct)` → `repo.GetAllByTenantAsync(tenantId, ct)`. (Administrator stays own tenant — tenantId resolves to own for non-Superadmin. NgcBusinessUnitRepository.GetAllByTenantAsync already IgnoreQueryFilters → cross-tenant safe.) The non-admin PG-scoped branch is UNCHANGED.

### EDIT 4 — RunReportWidgetQuery.cs + RunReportWidgetQueryHandler.cs
Record (L10-16): append `, Guid? TenantId = null` as the LAST param (after `int Page = 1`).
Handler (L32): replace `var tenantId = currentUser.TenantId!.Value;` with the RESOLUTION RULE. (Hist repo GetQueue/AgentIntervalsAsync ALREADY IgnoreQueryFilters + explicit TenantId == tenantId → cross-tenant works; scope service uses currentUser → Superadmin FullScope. No further change.)

### EDIT 5 — ReportScreenRepository.cs: IgnoreQueryFilters for the cross-tenant read path (§29.2)
These two methods rely on the GQF (TenantId [&& !IsDeleted]) so a Superadmin-chosen tenantId would be pinned to the SESSION tenant → empty. Add IgnoreQueryFilters + re-add the filters the GQF provided:
- **GetPageAsync (L53):** change `.Where(s => s.TenantId == tenantId)` to add `.IgnoreQueryFilters()` BEFORE the Where AND re-add the soft-delete filter: `.IgnoreQueryFilters().Where(s => s.TenantId == tenantId && !s.IsDeleted)`. (The GQF was `TenantId && !IsDeleted` — must keep !IsDeleted explicit once filters are ignored. Place IgnoreQueryFilters right after the Includes/AsNoTracking, like the other methods in this repo at L106/173/206.)
- **GetCategoriesAsync (L93):** add `.IgnoreQueryFilters()` (explicit `c.TenantId == tenantId && c.IsActive` already present; ReportCategory GQF is TenantId-only, no soft-delete).
(HistoricalReportRepository + NgcBusinessUnitRepository already IgnoreQueryFilters — NO change there.)

## PUBLISH (in RESULT, for shell)
The 4 updated signatures: GetReportScreensQuery(ReportScreenListRequest, Guid? TenantId=null) ; GetReportCategoriesQuery(Guid? TenantId=null) ; GetMyBusinessUnitsQuery(Guid? TenantId=null) ; RunReportWidgetQuery(WidgetType, ConfigJson, From, To, Page=1, Guid? TenantId=null). Shell threads the ReportsListPage-selected TenantId into all four.

## TESTS (tests/CcDashboard.Tests.Unit/)
- Resolution: Superadmin + TenantId=X → handler uses X (cross-tenant); Superadmin + null → own; non-Superadmin + TenantId=X → IGNORED, uses own tenant (assert X is NOT used). Cover at least RunReportWidgetQuery + GetReportScreens.
- Repo (if feasible): GetPageAsync/GetCategoriesAsync with IgnoreQueryFilters return the passed-tenant rows + GetPage still excludes IsDeleted.

## ACCEPTANCE (DoD)
1. Build 0. 2. Unit tests GREEN (resolution gate + non-Superadmin-ignored). 3. Superadmin can read another tenant's reports/BUs/categories/widget-data via the optional TenantId; non-Superadmin's TenantId param is ignored. 4. GetPageAsync still excludes soft-deleted (IgnoreQueryFilters + explicit !IsDeleted). 5. SF-BI-001 intact. 6. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify edits post-commit.
- commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `feat: report queries optional TenantId — Superadmin per-page tenant-filter (§29.2) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (4 signatures + repo IgnoreQF, build/tests, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · report queries take optional Guid? TenantId — Superadmin-gated (query.TenantId ?? own for Superadmin; IGNORED for non-Superadmin = own tenant, no leak). ReportScreenRepository.GetPageAsync/GetCategoriesAsync needed IgnoreQueryFilters + explicit !IsDeleted (GQF would pin a Superadmin-chosen tenant to the session tenant); hist + NgcBU repos already IgnoreQueryFilters. · SOURCE: §29.2 + coordinator 2026-06-26 + AppDbContext GQF · status: active`

## DO NOT
- Do NOT honor a non-Superadmin's TenantId param (own tenant only).
- Do NOT drop the soft-delete filter when adding IgnoreQueryFilters to GetPageAsync (re-add !IsDeleted).
- Do NOT touch shell Reports UI (shell owns the selector) / other ConfigurationQueries / Program.cs.
- NO migration / NO push.
