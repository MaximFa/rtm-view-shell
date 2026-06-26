# CC TASK — Seed-ProdMirror.ps1: add RTSData_UserStatusLog to the load set (agent time-series)  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. GATED: present/submit ONLY after action#1 confirms RTSData_UserStatusLog has rows for 019e03e9 in staging. The agent aggregation (HistoricalAggregationService.cs:153) reads RTSData_UserStatusLog (StartTime time-series) → it was MISSING from the load set → hist_agent_intervals=0. This adds it. Edits 3 arrays only. No execution.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §35, §39, §46.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_add_userstatuslog.md | status: open
### DIRECTIVE (spec->CC): add RTSData_UserStatusLog to ChainTables+TenantIdTables+truncateSet in Seed-ProdMirror.ps1. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX — add `RTSData_UserStatusLog` (3 arrays). Keep .ps1 UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL.
RTSData_UserStatusLog: PK=Id(int), HAS "TenantId" + StartTime/EndTime/UpdateTime/UserId/StatusGroup (schema.sql). It is a global-PK CC time-series table → TRUNCATE with the CC set + load WHERE TenantId.

### 4.1 `$ChainTables` — add after "RTSData_UserStatus"
```powershell
    "RTSData_UserStatus",
    "RTSData_UserStatusLog",
    "RTSData_ChatMessage"
```

### 4.2 `$TenantIdTables` — add after "RTSData_UserStatus" (it carries TenantId)
```powershell
    "RTSData_UserStatus",
    "RTSData_UserStatusLog"
```
(keep the list's existing members/order otherwise.)

### 4.3 `$truncateSet` (in the load clear block) — add "RTSData_UserStatusLog"
```powershell
    "RTSData_Interaction", "RTSData_UserStatus", "RTSData_UserStatusLog", "RTSData_ChatMessage"
```
(So the agent log is TRUNCATEd with the CC set, then COPY-loaded under the original tenant. The intersection-column load + identity TenantId (target==source) already handle it — no other code change. Phase-5 unaffected.)

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-06-25 · hist_agent_intervals aggregation reads RTSData_UserStatusLog (StartTime time-series), NOT RTSData_UserStatus (current snapshot, no usable history). Prod-mirror agent-history load MUST include RTSData_UserStatusLog (has TenantId + StartTime/EndTime); omitting it → hist_agent_intervals=0 while queue side is fine. Always cross-check the aggregation service's source tables against the load set. · SOURCE: HistoricalAggregationService.cs:153 + backfill hist_agent_intervals=0 2026-06-26 · status: active
```

## 6. Acceptance
- RTSData_UserStatusLog present in $ChainTables, $TenantIdTables, $truncateSet (grep count = 3).
- .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse PARSE-OK (Parser::ParseFile).
- role-dba §B has the new lesson.
- NO execution (operator re-runs Mode=Load after §4-bless → reloads all incl the log).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 — add RTSData_UserStatusLog to load set (agent hist source) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . RTSData_UserStatusLog in 3 arrays . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
