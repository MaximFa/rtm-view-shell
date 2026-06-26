# CC task — DEVOPS: Soma /db structured endpoints F-QA-8 (3x 500 — tooling, non-blocking)
> §4-PASS coordinator-0623 2026-06-24T11:59:48Z (blessed w/ STEP-0 amend applied). Owner devops-0619.
> Branch **v3**. Claim file-mode: `tools/Soma/Program.cs` ONLY. SELECT-only; keep SF-SOMA-001 (soma_ro, *_safe, secrets revoked) intact; loopback; NARROW-ADD; NO push. fix: prefix.
> ⚠ SEQUENCING: single shared v3 WT — run AFTER backend R1/R2 release the tree (coordinator/operator pick window). AUTHOR + §4 now (non-committing). NON-URGENT.

## STEP 0 — PRE-FLIGHT
- MANDATORY READ (§40/§0.8): `.claude/skills/role-devops/role-devops.md` (§A core + §C verify) + `.claude/skills/session-coord/session-coord.md` before any work.
- INIT: `git checkout v3`; verify BOTH `git rev-parse --abbrev-ref HEAD` == v3 AND `git rev-parse HEAD` == v3 tip by-SHA (object-store, §0.5 — mount HEAD-ref reads may truncate). §0.2 integrity.
- §42.6 S1 FREEZE-CHECK: `cat .coord/push/request.md` — if FREEZE ACTIVE/OPEN -> STOP (no new commit); CLOSED/tombstone -> proceed. Single shared v3 WT: run only AFTER backend R1/R2 release the tree (commit.lock).
- Re-verify the ~L485 (/db/agent-states), ~L501 (/db/queues), ~L515 (/db/dashboards) anchors before editing (confirm no drift).

## GROUNDING (authoritative — live DB via Soma /db/query, soma_ro, 2026-06-24)
- `tenant_agent_states` columns = Id, TenantId, **AgentState**, IsActive, CreatedAt, UpdatedAt  → there is **NO `AgentStateName`** column.
- table `queues` does **NOT exist**; the real table is **`public."NGC_Queues"`** (cols Id, TenantId, ExternalId, Name, IsActive — identical to what the query selects).
- `dashboards` cols (all the query uses exist): Id,TenantId,Name,Description,Status,IsPublic,CreatedByUserId,CreatedAt,UpdatedAt,UpdatedByUserId,IsDeleted,DeletedAt,DeletedByUserId,LayoutJson,CategoryId,IsDarkMode.
- `dashboard_widgets` cols (all the widget-subquery uses exist): Id,DashboardId,TenantId,WidgetCatalogItemId,IsDeleted,PositionJson,ConfigJson,GridId.

## THE FIX (tools/Soma/Program.cs — re-verify line anchors; ~L485/L501/L515 in e40a3dc)
1. **/db/agent-states** (~L485): the query uses `tas."AgentStateName"` (SELECT col + `ORDER BY`). The column does not exist (42703). Change BOTH refs `tas."AgentStateName"` → `tas."AgentState"`. (Output JSON field may stay `AgentStateName` via `tas."AgentState" AS "AgentStateName"`, or rename to AgentState — keep the reader index mapping intact.)
2. **/db/queues** (~L501): `FROM public.queues q` → `FROM public."NGC_Queues" q` (42P01). Columns already match (Id/ExternalId/Name/IsActive/TenantId); the RTSData_Interaction subquery (Workgroup = q.ExternalId) is unchanged. Keep quoting consistent.
3. **/db/dashboards** (~L515): GROUNDING shows BOTH the main SELECT and the widget-subquery reference ONLY existing columns + reader types match — the e40a3dc code looks correct; the QA 500 was on the OLD running 2.0.2. **VERIFY after the 2.4.x deploy: call /db/dashboards** — if it returns 200, NO change needed (note "already correct in e40a3dc"). If it still 500s, capture the Npgsql error and fix the specific column/table (do NOT guess — ground against information_schema like above).

Keep all other /db endpoints + SF-SOMA-001 guards + SELECT-only + loopback unchanged. No new surface.

## VERIFY (build + live)
- `dotnet build tools/Soma` OK. Object-store: only tools/Soma/Program.cs changed; /db/agent-states uses "AgentState"; /db/queues uses "NGC_Queues"; SF-SOMA-001/soma_ro/*_safe untouched.
- Live (operator/QA via Soma after deploy): /db/agent-states -> 200 rows; /db/queues -> 200 rows; /db/dashboards -> 200 (confirm).

## COMMIT (fix:, NO push) under commit.lock — NARROW ADD
`fix(soma): /db structured endpoints — agent-states col AgentStateName->AgentState (42703), queues table public.queues->NGC_Queues (42P01); dashboards verified vs live schema (F-QA-8) [devops]`
then §0.6 post-commit (status clean of non-claimed; zero deletions) + §0.6b binding -> .coord/cc/devops.md + §0.7 re-sync.

## ACCEPTANCE
agent-states "AgentState" + queues "NGC_Queues" fixed (grounded vs live schema); dashboards verified (fix only if it still 500s, grounded); SF-SOMA-001 intact; narrow-add (Program.cs only); build OK; NO push. Submit coordinator §4 BEFORE run; EXECUTE in a v3 window after backend R1/R2.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, the 2-3 endpoint fixes, build OK, live 200s, NO push.
