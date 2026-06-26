# CC TASK — Seed-ProdMirror.ps1 Phase-5 verify query: real column names  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. The LOAD is DONE+COMMITTED and the HARD ACCEPTANCE is already PROVEN manually (PG Administrators → 5 queues Q001-Q005 with 180-240 interactions each on rtmviewdb/019e03e9). Only the script's Phase-5 chain-proof query uses CLAUDE.md §6 column names that don't exist in the real schema → it errored. This fixes the query so future Load runs self-verify. DB-state correct; this is a query-only fix. No execution beyond the operator's later re-run.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §36.4 (Workgroup=NGC_Queues.ExternalId; QueueId), §46 (IDENT), §35, §39.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_fix_phase5.md | status: open
### DIRECTIVE (spec->CC): Phase-5 chain-proof query real column names. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX — Phase-5 query column names (verified against schema.sql + proven by manual run)

### 4.1 Queue branch (current L752-754) — `NGC_Queues` key is `ExternalId`, not `QueueId`
Replace:
```
SELECT q."ExternalId", q."Name", (SELECT count(*) FROM "RTSData_Interaction" i WHERE i."Workgroup" = q."ExternalId") as interactions
FROM "NGC_BusinessUnitQueueClassification" bqc
JOIN "NGC_Queues" q ON q."QueueId" = bqc."QueueId" AND q."TenantId" = bqc."TenantId"
```
WITH:
```
SELECT q."ExternalId", q."Name", (SELECT count(*) FROM "RTSData_Interaction" i WHERE i."Workgroup" = q."ExternalId" AND i."TenantId" = '$targetTenant') as interactions
FROM "NGC_BusinessUnitQueueClassification" bqc
JOIN "NGC_Queues" q ON q."ExternalId" = bqc."QueueId" AND q."TenantId" = bqc."TenantId"
```
(Also add `AND bqc."ClassificationId" = 'ALL'` to the WHERE at L755 to match §36 routing — the WHERE currently filters BusinessUnitId+TenantId; append ClassificationId='ALL'.)

### 4.2 Agent branch (current L766-774) — NGC_AgentGroups is `Id`/`ExternalId`/`Name`; joins via `ExternalId`
NGC_AgentGroups has NO `AgentGroupId`/`AgentGroupName`. NGC_SupergroupAgentgroup.AgentgroupId (varchar) and NGC_UserAgentgroup.AgentgroupId (varchar) both equal NGC_AgentGroups.ExternalId (§46 external id). Replace the agent-branch query WITH:
```
SELECT ag."ExternalId", ag."Name",
       (SELECT count(*) FROM "NGC_UserAgentgroup" uag WHERE uag."AgentgroupId" = ag."ExternalId" AND uag."TenantId" = '$targetTenant') as agents,
       (SELECT count(*) FROM "RTSData_UserStatus" us
        JOIN "NGC_UserAgentgroup" uag2 ON uag2."UserId" = us."UserId" AND uag2."TenantId" = us."TenantId"
        WHERE uag2."AgentgroupId" = ag."ExternalId" AND us."TenantId" = '$targetTenant') as statuses
FROM "NGC_BusinessUnitSupergroup" bus
JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bus."SupergroupId" AND sag."TenantId" = bus."TenantId"
JOIN "NGC_AgentGroups" ag ON ag."ExternalId" = sag."AgentgroupId" AND ag."TenantId" = bus."TenantId"
WHERE bus."BusinessUnitId" = $buId AND bus."TenantId" = '$targetTenant'
LIMIT 3
```

### 4.3 Leave as-is
The pg_business_units→NGC_BusinessUnit query (L736-740) is correct (BusinessUnitId/BusinessUnitName exist). The pg selection (L725) correct. Do not touch the load/clear/Inspect phases.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-06-25 · RTM chain real columns (verified schema.sql + live proof): NGC_Queues key = "ExternalId" (=Workgroup §36.4), NO "QueueId"; NGC_BusinessUnitQueueClassification."QueueId"(varchar)=NGC_Queues."ExternalId". NGC_AgentGroups = Id/ExternalId/Name (NO AgentGroupId/Name); NGC_SupergroupAgentgroup."AgentgroupId" & NGC_UserAgentgroup."AgentgroupId" (varchar) = NGC_AgentGroups."ExternalId"; NGC_UserAgentgroup."UserId"=RTSData_UserStatus."UserId" (external, §46). Verify chain joins against schema, NOT CLAUDE.md §6 (§6 names stale). · SOURCE: Seed-ProdMirror Phase-5 + manual proof 2026-06-26 (PG Administrators→Q001-Q005, 180-240 interactions) · status: active
```

## 6. Acceptance
- Queue branch: `q."ExternalId" = bqc."QueueId"`, interactions tenant-scoped, WHERE has ClassificationId='ALL'.
- Agent branch: ExternalId-based joins; agents/statuses tenant-scoped.
- grep `AgentGroupId|AgentGroupName|q\."QueueId"` in Phase-5 = 0.
- .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse PARSE-OK.
- role-dba §B has the new lesson.
- NO execution.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 Phase-5 — real chain columns (ExternalId joins) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . Phase-5 ExternalId joins . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
