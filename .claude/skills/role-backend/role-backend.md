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
### ⛔ ЧП / EMERGENCY MODE — ACTIVE (declared 2026-06-25 coordinator-0624; REMOVE on operator lift)
Release is bug-ridden (dashboards) + the reports version blocking its fixes is in catastrophic state → emergency until the operator lifts ЧП.
1. NO corner-cutting; ANY detail (ESPECIALLY visual) = critically RED — every defect is a blocker, no "minor".
2. NO decision around the coordinator; every fork → coordinator → operator (ONE at a time, by importance, plain language).
3. NO unsanctioned runs: do NOT hand the operator a chat CC run-prompt code-box UNTIL the coordinator's §4 bless.
4. Coordinator PERSONALLY visual-verifies EVERY closed gap (not object-store/report alone).
5. Verify on REAL prod-mirror data (234 backup, RTSData_*); our env = a FROZEN data-mirror of prod; our migration package = our migrated DB. One-time seed from the backup.
6. Protocol shorthand: `.` = `коорд: входящие`; `..` = "check the result" (specs know it).
7. Coordinator + operator steer the recovery out of the dive.

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

8. **[WIRE-01..05] Adapter↔RTM Service wire is a byte-compat CONTRACT — MANDATORY validate on ANY wire change.**
   Adapter code (RTM.Adapter.Common, adapters branch) is decoupled from RTM-core, but the pipe JSON dict shape
   (`"method"`+field names), DateFormatString, Agent DTO PascalCase, NamedPipe framing (Unicode+Message+name), and
   serializer settings MUST match RTM Service. Contract round-trip test gates BOTH branches' push barriers (QA).
   · SOURCE: CLAUDE.md §48, .coord/wire_contract.md

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-06 · NGC_Set/DeleteUserAgentgroup shipped as FUNCTION; plumbing test (SELECT) passed but prod CALL -> 42809 · ALWAYS test via CALL, verify prokind='p' · SOURCE:_009 hotfix, journal 2026-06-07 · status: active
- 2026-06-06 · StatusGroup column missing from RTSData_UserStatusLog (pgloader gap) -> empty DayTrend agent metrics · migration _004 · SOURCE:_004, rtm-service-expert §10 · status: active
- 2026-06-07 · Compare baseline had 13 routines as FUNCTION while prod (correct) had PROCEDURE; align.sql would have reverted prod -> 42809 storm · NEVER run align.sql blindly; verify which side is right · SOURCE:rtm-service-expert §10, journal 2026-06-07T15:14Z · status: active
- 2026-06-07 · sig-specific DROP FUNCTION fails if server has different arity; use sig-agnostic DROP · SOURCE:55eb049, journal 2026-06-08T01:36Z · status: active
- 2026-06-09 · Engine TryGetValue guards needed on UnionList/_gridList (whole-list-killed bug) · SOURCE:803832a, 160259a · status: active
- 2026-06-25 · ref: visual-check prep runbook = **docs/Visual-Test-Preflight.md** (profiles A=rebuild / B=running; shared gate Chrome→Soma /health:5199→Shell /ops/health.up→restart×3→start). Use when running or awaiting a visual check. · SOURCE: docs/Visual-Test-Preflight.md · status: active
- 2026-07-11 · Adapter uses only 9 files of RTM.Tools/RTM.Types, ZERO RTM-core coupling → minimal RTM.Adapter.Common (NOT a full-lib fork). But serializer + NamedPipe transport + Agent DTO are a WIRE CONTRACT with RTM Service: code may diverge, FORMAT may NOT. [WIRE-01..05] + a mandatory round-trip contract test = push-barrier gate on BOTH v3 (RTM pipe/Agent/serializer change) AND adapters (adapter change); whoever changes one side flags the counterpart to re-validate together. · SOURCE: CLAUDE.md §48, .coord/wire_contract.md · status: active
- 2026-07-15 · Runtime defect NOT deducible from code + not resolvable at the current log level (AgentGrid empty on 140: 3 contradictory field facts, root oscillated adapter↔RTM-1:many↔delivery) · FIRST expand LOGS in the problem area (log-only, no logic change) BEFORE hypothesising a fix — log-only deploys are fast + prod-safe (scope to OUR binary; legacy is a separate binary → untouched). Add the DECISIVE discriminator line at the exact fork (e.g. refreshUnions MISS need=[wgArr] have=[_workgroups] — arrives-but-token-mismatch vs never-arrives) · SOURCE:tools/cc_prompt_rtm_diaglog.md, operator directive 2026-07-15 · status: active
- 2026-07-15 · AgentGrid rows present but ALL per-agent cells blank (name/state/duration/OCC/ADH) · ROOT = user-grid METRICS not defined in RTSGrid_Metric → union.UserGridMetrics empty → UserManager.UserData stays roster-only (AgentLoginName+USERID) → updateUserGrid ships no cells (CollectData LongestAction=0). NOT widget, NOT assembly (Union.getUnionUserData ships userMng.UserData fine). Diagnostic ladder: Shell `RECV updateUserGrid union N` fields=[..] (DiagPushLogging) → RTSUserGrid_Grid/Column config → RTSGrid_Metric has the 5 agent metrics (AgentName/AgentState/AgentStateDuration/AgentOccupancy/AgentAdherence). Fix = seed the metrics; MUST export to git db baseline (Export-All → db/data/02_metrics.sql) or it regresses on fresh install. · SOURCE: Engine.cs Union_UserGridEvent/getUnionUserData, UserManager.cs:43 UserData, 140 fix 2026-07-15 · status: active
- 2026-07-16 · Postgres `AT TIME ZONE '<numeric-offset-text>'` (e.g. '+02:00') INVERTS the sign (POSIX) → a +02:00 timestamptz maps to the PREVIOUS local day; broke the RTSData_GetInteractions TZ-guard (undercount) · For a TimeZone column holding OFFSET strings use `AT TIME ZONE ((tz)::interval)` (interval does NOT invert); reserve bare `AT TIME ZONE 'name'` for NAMED zones ('Israel'/'UTC'). Mixed column → CASE on `^[+-]\d{2}:\d{2}$` · SOURCE: 0b07651 bug + fix tools/cc_prompt_tzguard_signfix.md, 140 data 2026-07-16 · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `grep -c 'CREATE PROCEDURE' db/functions/01_ngc_functions.sql` — must be >10 (RTM-SEC-002)
2. `grep 'p_tenant_id uuid' db/functions/*.sql | grep -v 'p_tenant_id uuid)' | wc -l` — expect 0 (TenantId last)
3. `grep 'TenantId' RTM/RTM/appsettings.json` — must exist
4. `grep 'SubscribeUnionAsync\|SubscribeGridAsync' src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs` — relay methods exist
5. `grep 'JsonElement' src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | wc -l` — multiple hits (typed params avoided)

## §D REFERENCE  (optional · NOT loaded each init)
Full reference: `.claude/skills/rtm-service-expert/rtm-service-expert.md` (engine architecture, SQL routine catalogue, data flows).
Shell relay: `.claude/memory/rtm-relay-implementation.md`.

2026-07-20 · MAXWAIT F5-reset: live UI repro (queue unchanged 12/11/1, F5 dropped 01:06->00:23) beat a static-code read that had (wrongly) concluded 'no rebase'. Operator lead: reset = per-service-instance CONSTANT (8s/48s) = startup-anchored base, not now-enqueue/now-resubscribe. Relay ruled out (CellSnapshot refreshed per-push + wiped on dispose). · RULE: for a timing/state bug, a controlled live before/after with an UNCHANGED input beats a static read AND an incomplete log window; and a per-instance CONSTANT reset => a startup-anchored base, look at where enqueue-time is stamped at service start. · SOURCE:RtmRelayService.cs:687 + Engine.cs:3054/IDInteraction.cs:298 + live 140 repro · status: active

2026-07-20 · MAXWAIT F5-reset ROOT = SHELL widget local-tick anchor, NOT RTM enqueue re-stamp (I chased RTM for 3 rounds; operator's 'RTM sends start, Shell ticks on visual' model was right). QueueGridWidget.ApplyMetricValue anchors on (received-elapsed, receipt-walltime) + PeriodicTimer(1s) climbs client-side; RTM freezes the pushed elapsed; F5 loses local accumulation -> re-anchors to stale frozen base. · RULE: when a value CLIMBS smoothly 1s/s but RESETS on client refresh, suspect CLIENT-SIDE ticking/anchoring FIRST, not the server — check the widget's timer/anchor before instrumenting the server. Fix = anchor on the ABSOLUTE start instant the server already provides (Value2 datetime), not received-elapsed+receipt-time. · SOURCE:QueueGridWidget.razor:1300-1320,1375 + RtmRelayService.cs:683 + live 140 repro · status: active
