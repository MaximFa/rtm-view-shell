---
role: backend
project: RTM View Shell
version: 0.1
last_verified: 2026-06-16T06:15:00Z
owner: backend
reviewer: curator
---
# role-backend — RTM Server / Shell Backend role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log RTM/ + .coord/journal.md backend lines + .claude/memory/rtm-*), NOT session
> narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: RTM Windows Service engine (RTM/RTM/*.cs) + SQL routines (db/functions/*.sql) + Shell<->RTM SignalR relay.
Claim: RTM/, db/functions/ (routine logic; DBA reviews DB-consistency).

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **RTM-SEC-002: RTM write routines MUST be PROCEDURE, not FUNCTION.**
   `CALL` on a FUNCTION raises 42809 (wrong object type) at RTM runtime on EVERY event.
   · SOURCE: fb118ff (12 NGC_* FUNCTION->PROCEDURE), aae7efa (RTSData_* FUNCTION->PROCEDURE), journal 2026-06-07T15:07Z

2. **`@TenantId`/`p_tenant_id` is the LAST parameter in all multi-tenant routines.**
   Minimises positional breaks in existing C# call sites.
   · SOURCE: CLAUDE.md §33.3, b4fe8ac (TenantId support commit)

3. **One RTM Service instance = one Tenant.** TenantId from `RTM:TenantId` in appsettings.json.
   · SOURCE: CLAUDE.md §33.1, AppConfig.cs:TenantId

4. **Shell connects to RTM via SignalR CLIENT (single-port relay).** Browser never contacts RTM directly.
   RTM hub URL from `TenantSettings.SignalRConnectionUrl`.
   · SOURCE: CLAUDE.md §34, RtmRelayService.cs, 0c3c902 (CC-003 relay commit)

5. **DataGrid requires BOTH `init` AND `refreshCells` to receive initial data push.**
   `init` alone does not trigger a push.
   · SOURCE: .claude/memory/rtm-relay-implementation.md, RTMHub.cs:init

6. **All hub params use `JsonElement`.** Typed params cause silent message drops.
   · SOURCE: CLAUDE.md §34.5, RTM-PROTO-01

7. **Engine.LoadData runs at STARTUP ONLY.** No hot-reload of grid/union/cell config.
   · SOURCE: Engine.cs:LoadData, rtm-service-expert §2

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-06 · NGC_Set/DeleteUserAgentgroup shipped as FUNCTION; plumbing test (SELECT) passed but prod CALL -> 42809 · ALWAYS test via CALL, verify prokind='p' · SOURCE:_009 hotfix, journal 2026-06-07 · status: active
- 2026-06-06 · StatusGroup column missing from RTSData_UserStatusLog (pgloader gap) -> empty DayTrend agent metrics · migration _004 · SOURCE:_004, rtm-service-expert §10 · status: active
- 2026-06-07 · Compare baseline had 13 routines as FUNCTION while prod (correct) had PROCEDURE; align.sql would have reverted prod -> 42809 storm · NEVER run align.sql blindly; verify which side is right · SOURCE:rtm-service-expert §10, journal 2026-06-07T15:14Z · status: active
- 2026-06-07 · sig-specific DROP FUNCTION fails if server has different arity; use sig-agnostic DROP · SOURCE:55eb049, journal 2026-06-08T01:36Z · status: active
- 2026-06-09 · Engine TryGetValue guards needed on UnionList/_gridList (whole-list-killed bug) · SOURCE:803832a, 160259a · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `grep -c 'CREATE PROCEDURE' db/functions/01_ngc_functions.sql` — must be >10 (RTM-SEC-002)
2. `grep 'p_tenant_id uuid' db/functions/*.sql | grep -v 'p_tenant_id uuid)' | wc -l` — expect 0 (TenantId last)
3. `grep 'TenantId' RTM/RTM/appsettings.json` — must exist
4. `grep 'SubscribeUnionAsync\|SubscribeGridAsync' src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs` — relay methods exist
5. `grep 'JsonElement' src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | wc -l` — multiple hits (typed params avoided)

## §D REFERENCE  (optional · NOT loaded each init)
Full reference: `.claude/skills/rtm-service-expert/rtm-service-expert.md` (engine architecture, SQL routine catalogue, data flows).
Shell relay: `.claude/memory/rtm-relay-implementation.md`.
