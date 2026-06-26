# CC TASK — CreateReportScreenCommand optional Guid? TenantId (create under the selected tenant)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. Operator confirmed design (a): a Superadmin's NEW report uses the page-selected tenant;
> "All Tenants"/no selection → session tenant (Platform), as today. Completes the per-page selector (create+list+view).
> Mirrors the blessed query rule (fcf5458). Lands WITH shell's create-pass. NO push.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short   # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode): src/CcDashboard.Application/Reports/Commands/CreateReportScreenCommand.cs + tests/CcDashboard.Tests.Unit/** + .claude/skills/role-bi/role-bi.md (§B). No shell/other overlap.
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## THE CHANGE (single file — CreateReportScreenCommand.cs; minimal, grounded at HEAD)
Object-store facts (HEAD): record L11 `CreateReportScreenCommand(CreateReportScreenRequest Request) : IRequest<ReportScreenDto>, ITransactional, IAuditable`; handler L27 `var tenantId = currentUser.TenantId!.Value;`; entity sets `TenantId = tenantId` EXPLICITLY (L32) and the PG-01 ReportPermission sets `TenantId = tenantId` (L54). **Verified: NO interceptor stamps TenantId** (only the IAuditable interceptor stamps CreatedAt/By; GQF affects READS only, not the INSERT). So changing the SOURCE of `tenantId` flows through to both the screen and the PG-01 permission automatically.

EDIT 1 — record: add optional TenantId:
```csharp
public record CreateReportScreenCommand(CreateReportScreenRequest Request, Guid? TenantId = null)
    : IRequest<ReportScreenDto>, ITransactional, IAuditable
```

EDIT 2 — handler L27: gated resolution (mirror fcf5458; non-Superadmin param IGNORED):
```csharp
var tenantId = currentUser.Role == "Superadmin"
    ? (cmd.TenantId ?? currentUser.TenantId!.Value)   // SA: page-selected tenant; null (All-Tenants) → session
    : currentUser.TenantId!.Value;                     // non-SA: own tenant, param IGNORED (no cross-tenant create)
```
NOTHING else changes: `screen.TenantId = tenantId` (L32) + the PG-01 `ReportPermission.TenantId = tenantId` (L54) now both carry the resolved tenant. No interceptor override (verified). No IgnoreQueryFilters — the handler only Adds (INSERT, unaffected by GQF) and returns a DTO from the in-memory entity (no cross-tenant read). The (TenantId,Name) unique index stays DB-enforced.

NOTE (PG-01 for Superadmin): a Superadmin has `PermissionGroupId == null` → the `if (currentUser.PermissionGroupId.HasValue)` block does NOT add a PG-01 permission for a Superadmin cross-tenant create (correct — Superadmin has no PG; IsPublic / Superadmin-bypass governs visibility). PG-01 still fires for a non-Superadmin creating in their OWN tenant. Leave that block as-is.

## PUBLISH (in RESULT, for shell)
`CreateReportScreenCommand(CreateReportScreenRequest Request, Guid? TenantId = null)` — shell threads the ReportsListPage-selected TenantId into the create command (Superadmin-only; server ignores it for non-Superadmin).

## TESTS (tests/CcDashboard.Tests.Unit/)
- Superadmin + cmd.TenantId = X → created ReportScreen.TenantId == X (and its PG-01 permission, if any, == X).
- Superadmin + cmd.TenantId = null → ReportScreen.TenantId == session tenant (All-Tenants behaviour).
- non-Superadmin + cmd.TenantId = X → IGNORED: ReportScreen.TenantId == own session tenant (assert X NOT used).

## ACCEPTANCE (DoD)
1. Build 0. 2. Unit tests GREEN (3 cases above). 3. A Superadmin with 019e03e9 selected creates a screen whose TenantId == 019e03e9 (not Platform). 4. non-Superadmin cannot create cross-tenant (param ignored). 5. NO migration. 6. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify edits post-commit.
- commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `feat: CreateReportScreenCommand optional TenantId — Superadmin create under selected tenant [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (signature + the gated resolution + tests, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · CreateReportScreenCommand takes optional Guid? TenantId — Superadmin-gated (cmd.TenantId ?? own for SA; IGNORED for non-SA). Screen+PG-01 set TenantId explicitly (NO TenantId-stamping interceptor exists; GQF affects reads only, INSERT is fine cross-tenant). · SOURCE: §29.2 + coordinator 2026-06-26 + CreateReportScreenCommand.cs · status: active`

## DO NOT
- Do NOT honor a non-Superadmin's TenantId param (own tenant only).
- Do NOT change the AuditBehavior / PG-01 block / repo / other commands.
- NO migration / NO push.

## FLAG TO COORDINATOR (in RESULT)
The generic AuditBehavior writes the ReportScreen.Created audit under the ACTOR's session ITenantContext.TenantId (Platform for a Superadmin), while the SCREEN lands under the target tenant. If the operator wants the audit row itself under the target tenant (not just the actor's), that is a separate AuditBehavior change — flag, do not fold here (the screen+PG-01 are correctly under the target; the audit is actor-scoped, standard).
