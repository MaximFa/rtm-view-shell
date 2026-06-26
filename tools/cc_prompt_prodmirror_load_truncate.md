# CC TASK — Seed-ProdMirror.ps1 LOAD clear = TRUNCATE global-PK CC tables (operator Q1=A)  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. Mode=Load failed: COPY NGC_Site → duplicate PK_NGC_Site (SiteId)=(IL); the CC tables have GLOBAL business-key PKs (no TenantId), so DELETE-by-TenantId can't clear cross-tenant PK collisions. Operator ruled A: TRUNCATE the global-PK CC tables before COPY; keep DELETE-by-TenantId for permission_groups/pg_*; keep exclusions. Tx rolled back atomically, backup intact. This task edits ONLY the LOAD clear-strategy. No execution.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §5 (multi-tenancy), §24/§35, §39.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_load_truncate.md | status: open
### DIRECTIVE (spec->CC): LOAD clear = TRUNCATE global-PK CC tables (operator A); keep DELETE-by-tenant for permission_groups/pg_*. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX (keep .ps1 UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL)

### 4.1 Replace the clear loop (current L577-586) with the operator-A strategy
The block runs AFTER `BEGIN;` + `SET session_replication_role = replica;` (L572-573). Replace the CURRENT block:
```powershell
$loadSql += "-- TRUNCATE target tenant rows"
foreach ($t in $tablesToLoad) {
    $tbl = $t.Name
    if ($TenantIdTables -contains $tbl) {
        $loadSql += "DELETE FROM `"$tbl`" WHERE `"TenantId`" = '$targetTenant';"
    } else {
        # Non-tenant table (RTSData_ChatMessage) - truncate all
        $loadSql += "TRUNCATE TABLE `"$tbl`";"
    }
}
```
WITH:
```powershell
$loadSql += "-- Clear (operator Q1=A): global business-key PK CC tables -> TRUNCATE; permission_groups/pg_* -> DELETE WHERE TenantId"
# Global business-key PK tables (NO TenantId in PK) — DELETE-by-tenant cannot clear cross-tenant PK collisions (e.g. NGC_Site SiteId='IL').
$truncateSet = @(
    "NGC_Site", "NGC_BusinessUnit", "NGC_Supergroup", "NGC_Queues", "NGC_AgentGroups",
    "NGC_BusinessUnitQueueClassification", "NGC_BusinessUnitSupergroup",
    "NGC_SupergroupAgentgroup", "NGC_UserAgentgroup",
    "RTSData_Interaction", "RTSData_UserStatus", "RTSData_ChatMessage"
)
$toTruncate = @($tablesToLoad | Where-Object { $truncateSet -contains $_.Name } | ForEach-Object { '"' + $_.Name + '"' })
if (@($toTruncate).Count -gt 0) {
    # ONE TRUNCATE for the whole self-contained CC set; runs under session_replication_role=replica
    # (no CASCADE — must NOT touch KEPT tables; the set's inter-FKs are cleared together).
    $loadSql += "TRUNCATE TABLE " + (@($toTruncate) -join ", ") + ";"
}
foreach ($t in $tablesToLoad) {
    $tbl = $t.Name
    if ($truncateSet -contains $tbl) { continue }   # already truncated above
    if ($TenantIdTables -contains $tbl) {
        $loadSql += "DELETE FROM `"$tbl`" WHERE `"TenantId`" = '$targetTenant';"
    } else {
        $loadSql += "TRUNCATE TABLE `"$tbl`";"
    }
}
```

### 4.2 Notes / invariants
- TRUNCATE is a SINGLE multi-table statement → the CC set's inter-table FKs are satisfied (all cleared together). NO `CASCADE` (CASCADE could clear KEPT tables — forbidden).
- KEPT (never in $tablesToLoad, never truncated): our schema, identity/superadmin, report_*, RTSGrid*/RTSUserGrid*, widget_catalog, tenants/tenant_settings(other tenants).
- permission_groups + pg_business_units/pg_queues/pg_skills/pg_supergroups → DELETE WHERE TenantId=$targetTenant (uuid/PG-scoped PKs, faithful per-tenant).
- If TRUNCATE errors "cannot truncate a table referenced in a foreign key constraint" (a KEPT table FK-references a CC table) → DO NOT add CASCADE; STOP and report (new finding for escalation). Under replica role this is not expected.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-06-25 · RTM CC tables (NGC_*/RTSData_*) have GLOBAL business-key PKs with NO TenantId (NGC_Site=SiteId, NGC_BusinessUnit=BusinessUnitId, RTSData_Interaction=(InteractionId,Segment,OnDate,ServerId,Workgroup),...). A per-tenant DELETE cannot clear cross-tenant PK collisions (our seed SiteId='IL' vs prod's). Prod-mirror load (operator A) = TRUNCATE these global-PK tables (one multi-table stmt under session_replication_role=replica, no CASCADE), DELETE-by-tenant only for uuid/PG-scoped tables (permission_groups/pg_*). · SOURCE: Mode=Load NGC_Site PK clash 2026-06-26 + schema.sql PKs · status: active
```

## 6. Acceptance
- Clear loop replaced: ONE `TRUNCATE TABLE "NGC_Site","NGC_BusinessUnit",...,"RTSData_ChatMessage";` (only those present in $tablesToLoad), no CASCADE; permission_groups/pg_* still DELETE-by-tenant; exclusions untouched.
- .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse PARSE-OK (Parser::ParseFile).
- role-dba §B has the new lesson.
- NO execution (operator re-runs Mode=Load after §4-bless).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 LOAD clear — TRUNCATE global-PK CC tables (operator A) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . TRUNCATE clear (no CASCADE) + DELETE pg_* . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
