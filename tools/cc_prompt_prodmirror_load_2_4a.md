# CC TASK — Seed-ProdMirror.ps1 LOAD path = 2.4a (original prod TenantId, NO re-stamp)  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. Inspect is GREEN (inspect_20260626-020044.txt): single client tenant 019e03e9 owns the full chain (NGC_* + RTSData_Interaction 64110 + its permission_groups/pg_* rows); 019e0422 = orphan (ignored by WHERE TenantId=src). Operator ruling 2.4a: load under the ORIGINAL prod TenantId, NO re-stamp. This task edits the LOAD path only. Mode=Load still operator-run AFTER §4-bless + backend seeder-gate LIVE (it is). No execution here.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §5 (multi-tenancy/GQF), §6 (tenants/tenant_settings shape), §33 (TenantId), §35, §39, §46 (IDENT).

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_load_2_4a.md | status: open
### DIRECTIVE (spec->CC): LOAD path 2.4a (target==source 019e03e9, no re-stamp, create original-id tenant row, pg_supergroups name). claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX (keep .ps1 UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL)

### 4.1 Replace the "Resolve target tenant" block (current L507-542) with 2.4a logic
2.4a = NO re-stamp → target tenant == source tenant (the ORIGINAL prod id). Create the tenant row with that ORIGINAL id (do NOT mint a new GUID). Replace everything from `# Resolve target tenant` through its closing `}` (the slug-resolve / new-GUID branch) with:
```powershell
# 2.4a: load under the ORIGINAL prod TenantId — target == source, NO re-stamp.
$targetTenant = $srcTenant
$nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss.ffffff")
$ensureTenantQ = @"
INSERT INTO tenants ("Id", "Slug", "Name", "Status", "CreatedAt", "UpdatedAt")
VALUES ('$srcTenant', '$TargetTenantSlug', 'Prod Mirror (original prod tenant)', 'Active', '$nowUtc', '$nowUtc')
ON CONFLICT ("Id") DO NOTHING;
INSERT INTO tenant_settings ("TenantId", "PasswordMinLength", "PasswordExpireDays", "Require2faForAll", "AuditRetentionDays", "DefaultLocale", "SoftDeleteDashboards", "SoftDeleteRetentionDays", "MaxConcurrentConnections", "PurchasedLicences")
VALUES ('$srcTenant', 12, 90, false, 365, 'en-US', true, 90, 0, 0)
ON CONFLICT ("TenantId") DO NOTHING;
"@
$null = Invoke-Psql -Database $DbName -Query $ensureTenantQ
Write-Host "2.4a: target tenant = source (original prod id) $targetTenant; tenant row ensured."
```
(VERIFIED against AppDbContextModelSnapshot: the NOT-NULL int columns are PasswordMinLength/PasswordExpireDays/AuditRetentionDays/SoftDeleteRetentionDays/MaxConcurrentConnections/PurchasedLicences + bools Require2faForAll/SoftDeleteDashboards + required DefaultLocale — ALL now in the INSERT. MaxConcurrentConnections=0 & PurchasedLicences=0 (0=unlimited, §21). All other columns nullable. Do NOT add columns absent from the snapshot.)

### 4.2 The existing re-stamp now emits the ORIGINAL id (identity = faithful 2.4a)
With `$targetTenant = $srcTenant`, the load's `'$targetTenant'::uuid AS "TenantId"` emits the SAME id as the source row → NO actual re-stamp, original prod id preserved. LEAVE that mechanism as-is (it is now identity). DELETE-our-rows `WHERE "TenantId"='$targetTenant'` = WHERE 019e03e9 → no-op on a clean dev DB, idempotent on re-run. No change needed.

### 4.3 pg_agent_supergroups → pg_supergroups (chain arrays — folded here per coordinator)
Current table name is `pg_supergroups` (AppDbContextModelSnapshot:760 + 234 staging; CLAUDE.md §6 stale). Replace BOTH:
- `$ChainTables` (L179): `"pg_agent_supergroups",` -> `"pg_supergroups",`
- `$TenantIdTables` (L201): `"pg_agent_supergroups",` -> `"pg_supergroups",`
(Inspect showed pg_agent_supergroups [TABLE NOT IN STAGING]; with the correct name pg_supergroups loads the SG-scope.)

### 4.4 Keep unchanged
backup-our-DB-first (Phase 1), staging pg_restore (Phase 2), Inspect (Phase 3), FK-order selective DATA-ONLY load via `-f` temp files + intersection columns (Phase 4), Phase-5 BU∩PG chain proof, SET session_replication_role=replica, exclusions (keep our schema/superadmin/report_*/RTSGrid*/widget_catalog). Column drift (NGC_AgentGroups/NGC_Queues staging-only CreatedDatetime) is already handled by the intersection logic.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-06-25 · Prod-mirror seed = 2.4a (operator): load under the ORIGINAL prod TenantId, NO re-stamp; target tenant == source. Create the `tenants` row with the ORIGINAL id (ON CONFLICT Id DO NOTHING) + tenant_settings. Single source tenant 019e03e9 (orphan 019e0422 excluded by WHERE TenantId=src). · SOURCE: coordinator §4 2026-06-26 (operator 2.4a) + inspect_20260626-020044 · status: active
```

## 6. Acceptance
- Tenant-resolve block replaced: `$targetTenant = $srcTenant`; tenants+tenant_settings ensured for the ORIGINAL id (ON CONFLICT). No new-GUID minting.
- `pg_agent_supergroups` replaced by `pg_supergroups` in BOTH arrays (grep `pg_agent_supergroups` = 0).
- .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse: `powershell -NoProfile -Command "$null=[System.Management.Automation.Language.Parser]::ParseFile('db\tools\Seed-ProdMirror.ps1',[ref]$null,[ref]$null);'PARSE-OK'"` → PARSE-OK.
- role-dba §B has the new lesson.
- NO execution (operator runs Mode=Load after §4-bless; seeder-gate is LIVE).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `feat:` — `feat(db): Seed-ProdMirror.ps1 LOAD = 2.4a (original prod TenantId, no re-stamp, create tenant row) + pg_supergroups + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . 2.4a target==source + pg_supergroups . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
