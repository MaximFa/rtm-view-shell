---
name: rtm-service-expert
description: "Deep expert on the RTM Service engine (RTM/ directory): Engine/DBMng/WorkgroupManager/UserManager architecture, the DBAdapter -> PostgreSQL stored-routine layer, SQL routine conventions (PROCEDURE-not-FUNCTION, @TenantId-last), the NGC_*/RTSData_* contracts, agent-status + interaction + BU-scope membership data flows, the SignalR relay protocol, and RTM deployment/ops gotchas. Trigger for ANY work on the RTM Windows Service: Engine.cs, DBMng.cs, RTMAdapter, WorkgroupManager, userWorkgroupActivation, DBAdapter.ExecuteNonQuery, NGC_* / RTSData_* stored routines, fn_daytrendagentstatus, RTSData_UserStatusLog/StatusGroup, NGC_UserAgentgroup membership, MidnightClear, RTM multi-tenancy (TenantId), the Shell<->RTM SignalR relay, or any 42809/owner/BOM error deploying RTM SQL."
type: reference
updated: 2026-06-06 (v1.0 — initial capture from CLAUDE.md §33-34 + RTM bug-fix session 2026-06-06)
---

# rtm-service-expert

Normative spec: **CLAUDE.md §33 (multi-tenancy) + §34 (relay)**. This skill is the operational
deep-dive on the RTM Service engine and its PostgreSQL stored-routine layer. Read it for ANY
change to `RTM/` or the `db/functions/*.sql` routines RTM calls.

## 1. What RTM Service is
Windows Service collecting real-time CC data (agent status, interactions) from the CC platform
(Cisco Finesse — see finesse-expert) and writing it to PostgreSQL for the Shell/widgets to read.
No HTTP context, no authenticated user. **One RTM Service instance = one Tenant** (§33.1). TenantId
is static config (`RTM:TenantId` in appsettings, `AppConfig.TenantId`); empty TenantId = fatal start.

## 2. Engine architecture (RTM/RTM/)
- `Engine` (Engine.cs) — the engine loop. `LoadData` reads grid/union/cell config + queue->union
  mappings at STARTUP ONLY (no hot-reload). `getOrAddWGManager(workgroup, ...)` routes events to a
  `WorkgroupManager`.
- `WorkgroupManager` / `WorkgroupManagerList` — per-workgroup (queue) call/interaction counters.
- `UserManager` / `UserManagerList` — per-agent state; holds in-memory workgroup membership
  (`_workgroups`) which is NOT persisted by default (P1/P2 added persistence — see §6).
- `RTMAdapter` — inbound CC-platform event handlers (e.g. `userWorkgroupActivation`) that call into Engine.
- `DBMng` (DBMng.cs) — ALL DB access. Calls stored routines via `DBAdapter.ExecuteNonQuery(name, params)`
  using `CommandType.StoredProcedure` -> emits SQL `CALL "name"(...)`. Holds `_tenantId = AppConfig.TenantId`.
- `DBAdapter` — thin Npgsql wrapper. `ExecuteNonQuery` => `CALL`; `GetDataTable` => `SELECT * FROM fn()`.

## 3. Multi-tenancy (§33)
Every multi-tenant routine takes `p_tenant_id uuid` as the **LAST** parameter (minimises positional
breaks in existing C# call sites). `DBMng` passes `@TenantId` = `AppConfig.TenantId` last. Reads filter
`WHERE "TenantId" = p_tenant_id`; writes set it on INSERT/UPSERT.

## 4. SQL routine conventions — CRITICAL
**[RTM-SEC-002 / §33.8] PROCEDURE, not FUNCTION.** Any routine invoked by `DBAdapter.ExecuteNonQuery`
(CommandType.StoredProcedure -> `CALL`) MUST be a `CREATE PROCEDURE`, never `FUNCTION ... RETURNS void`.
`CALL` on a function raises **42809 (wrong object type)** at RTM runtime on EVERY event.
- PITFALL: plumbing/unit tests that invoke via `SELECT fn(...)` PASS on a function -> the defect only
  surfaces at RTM runtime. **Test via `CALL`, and verify `prokind='p'` (not just `pronargs`).**
- Converting an existing function: `DROP FUNCTION IF EXISTS name(args)` FIRST — `CREATE OR REPLACE
  PROCEDURE` cannot change routine kind. Make migrations idempotent: DROP FUNCTION + DROP PROCEDURE + CREATE PROCEDURE.
- Routines READ by the Shell via `SELECT` (e.g. `fn_daytrendagentstatus`, `RTSGrid_*` reads) stay
  FUNCTIONs (RETURNS TABLE) — only the `CALL`-invoked write routines must be procedures.
- `@TenantId`/`p_tenant_id` always LAST. Mirror the naming of the nearest existing routine.

## 5. Stored-routine catalogue (db/functions/)
- `01_ngc_functions.sql` — NGC_* config CRUD: BusinessUnit, Supergroup, Agentgroup, queue-classification
  mappings, and **NGC_UserAgentgroup** membership (NGC_SetUserAgentgroup/NGC_DeleteUserAgentgroup =
  PROCEDUREs, p_user_id, p_agentgroup_id, p_tenant_id; ON CONFLICT (TenantId,UserId,AgentgroupId) DO NOTHING / DELETE).
- `02_rtsdata_functions.sql` — RTSData_* writes (SetInteraction, **SetUserStatus** = 15-param PROCEDURE
  that writes RTSData_UserStatus + RTSData_UserStatusLog incl. StatusGroup; SetChatMessage) + reads
  (getUsersStatuses, getInteractions) + **RTSData_MidnightClear**.
- `03_rtsgrid_read.sql` / `04_misc_functions.sql` — RTSGrid_*/RTSUserView_* reads (FUNCTIONs, platform config).
**[RTM-SEC-001] MidnightClear is tenant-scoped.** It once did unscoped `DELETE FROM RTSData_*` (wiped ALL
tenants). MUST be `WHERE "TenantId" = p_tenant_id`. Never run an unscoped MidnightClear.

## 6. Data flows
**Agent status:** Finesse event -> Engine -> `RTSData_SetUserStatus` writes RTSData_UserStatus (current)
+ appends RTSData_UserStatusLog (history) WITH `StatusGroup`. The Shell's `fn_daytrendagentstatus`
reads UserStatusLog filtered by `StatusGroup` -> DayTrend Agent Metrics. **`RTSData_UserStatusLog` MUST
have a `StatusGroup varchar(50)` column** — the original MSSQL/pgloader migration omitted it, so the
INSERT failed silently and the Log stayed empty (fixed: migration _004, 2026-06-06).
**Interactions:** Finesse -> Engine.getOrAddWGManager -> WorkgroupManager -> RTSData_SetInteraction.
**Membership (BU-scope, P1/P2):** Engine.userWorkgroupActivation loops call `DBMng.setUserAgentgroup` /
`deleteUserAgentgroup` -> NGC_UserAgentgroup. Persists the otherwise in-memory `UserManager._workgroups`
so the Shell can scope agent metrics to a Business Unit without depending on live calls.

## 7. BU-scope membership model
Agent -> AgentGroup membership lives in `NGC_UserAgentgroup`. Resolve agent -> BU as:
- **Supergroup membership = AND**: an agent is in a Supergroup only if in ALL of that Supergroup's
  agent groups (`GROUP BY UserId,SupergroupId HAVING COUNT(DISTINCT AgentgroupId) = total_ag`).
- **BU membership = OR**: an agent is in a BU if in ANY of the BU's supergroups (DISTINCT union).
Chain: NGC_UserAgentgroup -> NGC_SupergroupAgentgroup (AND) -> NGC_BusinessUnitSupergroup (OR) -> BU.

## 8. Shell <-> RTM SignalR relay (§34)
The Shell acts as a SignalR CLIENT to RTM Service (single port 443; RTM not browser-reachable).
`RtmRelayService` (Singleton) holds one HubConnection per (TenantId, UnionId). Hub URL from
`TenantSettings.SignalRConnectionUrl`. Protocol: client->server `init "{groupId}"` (`u{unionId}` for
AgentGrid, `{gridId}` for DataGrid) + `refreshCells` (DataGrid only); server->client `updateUserGrid`/
`removeUser`/`updateGridData`. **Always use `JsonElement` for ALL params** (typed params silently drop
messages). DataGrid needs BOTH `init` + `refreshCells` to get an initial push.

## 9. Deployment & ops gotchas
- DDL on `RTSData_*` / table-owner ops MUST run as `postgres` (table owner); `ccdashboard_user` gets
  "must be owner". DML (INSERT/UPDATE) can run as `ccdashboard_user`.
- `psql -f` REJECTS a UTF-8 BOM ("syntax error at or near ï»¿"). Write temp SQL BOM-less
  (`[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`; `Set-Content -Encoding UTF8` adds a BOM in WinPS5).
- RTM SQL routines/migrations apply via PowerShell + `psql.exe` (Windows path); `psql` is not on PATH in
  the WSL2 bash that CC uses. Keep DB-deploy steps in PowerShell, repo/.coord ops in bash.
- New RTM deploy: get TenantId from CcDashboard admin -> set `RTM:TenantId` -> verify startup log ->
  confirm scoped data exists.

## 10. Known bugs / lessons (2026-06-06 session)
- RTM-SEC-001: MidnightClear must be tenant-scoped.
- RTM-SEC-002 / §33.8: RTM write routines must be PROCEDUREs (CALL), not FUNCTIONs (42809). Verify prokind='p', test via CALL.
- StatusGroup column missing on RTSData_UserStatusLog (pgloader gap) -> empty DayTrend agent metrics (migration _004).
- P1 shipped NGC_Set/DeleteUserAgentgroup as FUNCTIONs (plumbing test used SELECT, passed) -> 42809 on prod -> hotfix _009.
- The fn (read side, fn_daytrendagentstatus) is rewritten ONCE with BU-scope + UNAVAILABLE outputs (P3); don't double-edit it.
