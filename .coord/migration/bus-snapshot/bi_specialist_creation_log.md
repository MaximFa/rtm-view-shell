# BI Specialist — creation log (RTM View Shell)
> Operator directive 2026-06-19: create a BI specialist for writing historical reports; JOURNAL every stage, decision, and its premise.
> Source spec: TZ_Historical_Reports_clean.md v1.0 (2026-06-17), uploaded by operator.

## STAGE 1 — 2026-06-19T10:17:58Z — TZ read + domain analysis (coordinator-0612)
WHAT THE MODULE IS (from TZ): Historical Reports module for RTM View Shell — post-hoc analytics over accumulated queue/agent data (NOT real-time widgets, NOT WFM, NOT OLAP/cross-joins in v1).
CORE ARCHITECTURE:
- Pre-aggregation pipeline: HistoricalAggregationService (BackgroundService/IHostedService) reads RTSData_Interaction + RTSData_UserStatusLog every 30 min, writes pre-aggregates to hist_queue_intervals + hist_agent_intervals via IDEMPOTENT upsert (DELETE interval-window + INSERT). Startup lookback 24h, periodic lookback 2h.
- Reports read ONLY aggregate tables — NEVER GROUP BY RTSData_Interaction live (too slow at 100k+ rows/day). HARD PRINCIPLE.
- Data layer: IHistoricalReportRepository + MediatR queries (v1: Q1 Queue Interval, Q5 Queue Wait Time, A4 Agent Monthly, A5 Agent Shift Detail). Computed metrics are NULLIF-guarded formulas (AbandonPct, SlPct, ASA, AvgWait, AHT, OccupancyPct, ShrinkagePct, CPH).
- 17 system reports (Q1-6, A1-7, S1-4) seeded in user_reports IsSystem=true (DatabaseInitializer), non-deletable. Plus a 4-step report-builder wizard -> user_reports.Config jsonb (timeGranularity/dateRangeType/metrics[]/queueIds/agentIds/sort/pageSize/thresholds).
- Multi-tenant (TenantId + GQF on all aggregate + user_reports tables). Clean arch (Application no EF, Infra no Blazor). CSV export v1 (server C# + JS blob download); Excel/PDF/email-schedule v2/v3.
- PG perms: Viewer can view all reports but not create; PG-filtered queue/agent lists via pg_queues; IsPublic visibility rules.
- Phases: v1 = data layer (CC-HIST-001) + UI (CC-HIST-002) + user reports (CC-HIST-003); v2 = remaining reports + Excel + email; v3 = combined/drill-down/PDF/public-link.
KEY RISK FLAGGED BY TZ ITSELF: real column names of RTSData_Interaction (WaitTimeSec/HandleTimeSec/TalkTimeSec/AcwTimeSec/IsAbandoned/StartTime/Direction/CallType/InteractionType) MUST be verified against live DB (\d "RTSData_Interaction") before coding — TZ's SQL is illustrative. Also AgentsStaffed/SumReadySec/SumBusySec are TODO (0) in the queue aggregation. JOIN NGC_Queue ON ExternalId=QueueId.
PREMISE: this aligns with existing project skills — rtm-metrics-expert (metric semantics), widget-planner/creator (Grid vs Chart, narrow-format, SUM_OVERLAP_MS). The BI specialist must reuse RTM metric knowledge, NOT reinvent it.

## STAGE 2 — 2026-06-19T10:17:58Z — OPEN DECISION (asking operator): specialist TYPE/shape
Decision needed before authoring: is the deliverable
 (a) role-bi — a §45 bus SPECIALIST ROLE (.claude/skills/role-bi/role-bi.md; §A/§B/§C/§D; INIT ritual; territory claims over Historical/Reports code) that OWNS the module and can be spun up as a session, OR
 (b) bi-reports-expert — a domain-KNOWLEDGE skill (like rtm-metrics-expert) read on-demand by any session touching reports, OR
 (c) BOTH (planner+creator split, like widget-planner+widget-creator).
PREMISE: project vocabulary "специалист" = a bus role (§42/§45). But the TZ is a feature spec, so a domain-expert skill is also defensible. Recording the question; awaiting operator before authoring (avoids building the wrong shape).

## STAGE 3 — DECISIONS (operator delegated to coordinator; premises recorded)
DECISION 1 — specialist TYPE = **role-bi** (§45 bus specialist role). PREMISE: (a) project vocabulary "специалист"=bus role (§42/§45); (b) Historical Reports is a coherent ownership territory (Historical/, Reports/, HistoricalAggregationService, Components/Reports/) needing an owner with claims per §26.2; (c) a role-skill (§A/§B/§C/§D) embeds domain knowledge in §D, subsuming the "expert" function — no separate bi-reports-expert needed; (d) planner+creator split premature (reports v1 is bounded, not a high-frequency repeated pattern like widgets; split later if volume warrants).
DECISION 2 — first act = **verify source-table columns vs reality** before baking the skill. PREMISE: TZ itself flags its SQL column names as illustrative; today's headline lesson = verify vs reality, never trust spec/memory. Grounds the skill in db/schema.sql (canonical, just-regenerated), not the TZ's illustration.
DECISION 3 — creation mechanism = **CC prompt** (tools/cc_prompt_create_role_bi.md -> .claude/skills/role-bi/role-bi.md). PREMISE: §0.7/NORM-CUR-03 — skill files are versioned repo code, edited via native CC, not Cowork direct-write (role-backend/role-shell were created this way). Coordinator designs content; CC materializes.

## STAGE 4 — COLUMN VERIFICATION vs db/schema.sql (MAJOR — TZ SQL is wrong)
The TZ's illustrative aggregation SQL uses column names that DO NOT EXIST. Verified real schema:
RTSData_Interaction (real cols): TenantId, InteractionId, Segment, OnDate, ServerId, **Workgroup** (queue ext-id, varchar), **UserId** (agent login, varchar), ClassificationCode, InteractionType, CallType, Direction, IsTransferred, **IsAnswered**, IsInQueue, IsTalk, **IsAbandoned**, **TimeInQueue** (int, = wait), **TalkTime** (int), **InQueueDateTime**, **AnsweredDateTime**, UpdateTime, LastUserId, LastWorkgroup, IsMessaging, IsCallbackRequest, CustomCallData1..20.
  -> TZ WaitTimeSec=TimeInQueue; TZ TalkTimeSec=TalkTime; TZ StartTime=InQueueDateTime; TZ i.QueueId=i.Workgroup.
  -> NO HandleTime / NO AcwTime / NO HoldTime columns exist. SumHandleTimeSec/SumAcwTimeSec NOT directly computable; AHT (TZ: Talk+Hold+ACW) reduces to TalkTime only. **GAP — specialist must flag; v1 AHT≈TalkTime or source ACW elsewhere.**
NGC_Queues (real, plural; TZ said NGC_Queue): Id(uuid), TenantId, **ExternalId**(varchar), Name, IsActive. JOIN = NGC_Queues.ExternalId = RTSData_Interaction.Workgroup (+ TenantId).
RTSData_UserStatusLog (agent source, EXISTS — TZ's fallback unnecessary): Id, TenantId, **UserId**(login varchar), StatusId, ServerId, OnDate, **StartTime**, **EndTime**, **Duration**(bigint), UpdateTime, TimeZone, **StatusGroup**(varchar). -> agent interval aggregation = SUM(Duration) FILTER per StatusGroup; bucket by StartTime.
RTSData_UserStatus (snapshot fallback): TotalDuration, MaxDuraction(typo-by-design), StatusGroup, etc.
ID-RESOLUTION GAP: RTSData_*.UserId + RTSData_Interaction.Workgroup are VARCHAR (login / external-id); hist_* tables key on uuid (AgentId=ApplicationUser.Id, QueueId=NGC_Queues.Id). Aggregation must resolve login->identity.users.Id and Workgroup->NGC_Queues.Id. Specialist §A must encode this.
CONCLUSION: the skill's §A/§D will carry the VERIFIED column contract + the AHT/ACW gap + the id-resolution rule — so the BI specialist builds on reality, not the TZ illustration. This single verification already prevented a class of runtime bugs (42703 column-not-exist) across the whole module.

## STAGE 5 — skill DESIGNED + CC prompt authored (coordinator-0612)
ARTIFACTS:
- docs/bi/TZ_Historical_Reports.md — operator's TZ saved into repo (1486 lines, exact copy) = durable §D reference.
- tools/cc_prompt_create_role_bi.md (§4-PASS) — materializes .claude/skills/role-bi/role-bi.md.
SKILL DESIGN (role-bi, §45 anatomy, house format role-skill-TEMPLATE):
- §A CORE (8 cardinal truths, source-pinned): pre-aggregation-only; idempotent upsert; multi-tenant+clean-arch; VERIFY-cols-vs-schema (TZ illustrative); joins+id-resolution (NGC_Queues.ExternalId=Workgroup, varchar→uuid); agent source=RTSData_UserStatusLog(Duration+StatusGroup); NULLIF computed metrics + AHT-gap; reuse rtm-metrics-expert. + "reality wins" caveat + territory claim.
- §B LESSONS: the column-verification lesson (TZ cols wrong → verify vs schema.sql).
- §C VERIFY: module-built-yet probe + re-verify RTSData_Interaction/UserStatusLog/NGC_Queues columns each init.
- §D REFERENCE: TZ pointer, computed-metric formulas, verified column→metric mapping, phase plan (CC-HIST-001/002/003), 4 OPEN GAPS (AHT/ACW no-source, AgentsStaffed TODO, login→uuid cost, bucketing column), related skills.
KEY VALUE: the skill encodes the VERIFIED column contract, so the module is built on reality (schema.sql) not the TZ's illustrative SQL — prevents 42703 across all aggregation. 4 open gaps surfaced for operator resolution before CC-HIST-001.
NEXT: operator runs tools/cc_prompt_create_role_bi.md (native CC) -> role-bi.md committed. Then BI specialist can be spun up to lead CC-HIST-001 (after resolving the 4 open gaps).

## STAGE 6 — fresh-server data-depth analysis (operator question, code-verified)
Q: on a freshly-deployed server, how far back do reports show data, and what sets the limit?
VERIFIED (db/functions/02_rtsdata_functions.sql:260): RTSData_MidnightClear(p_tenant_id) = DELETE RTSData_Interaction + DELETE RTSData_UserStatus per tenant (does NOT touch RTSData_UserStatusLog).
ANSWER: reports read ONLY hist_* aggregates (empty at deploy). Populated by HistoricalAggregationService (startup lookback 24h, periodic 2h). Depth bounded by THREE: (1) empty aggregates + StartupLookbackHours=24 (config ceiling); (2) RTSData_MidnightClear nightly-wipes RTSData_Interaction -> QUEUE raw source only holds since-last-midnight -> real floor for queue reports = last midnight, NOT 24h; (3) RTM Service start time. Agent reports source RTSData_UserStatusLog is NOT midnight-cleared -> deeper, but on fresh RTM only since start. Forward: hist_* never cleared -> rolling history accumulates day by day.
NEW GAP #5 (add to role-bi §D open-gaps + flag operator): because RTSData_Interaction is midnight-cleared, the aggregation MUST run before each midnight or that day's QUEUE intervals are lost permanently (gone from raw, never landed in hist_*). 24h startup-lookback only saves same-day. Mitigations to design: (a) ensure aggregation runs near 23:30 reliably / catch-up on restart within the day; (b) consider RTM not clearing until after aggregation, or aggregating from RTSData_UserStatusLog-style durable log; (c) NO hist_* retention/partitioning in TZ -> hist_* grows unbounded, needs a retention policy (like audit partitions §16/AUD-03).


## STAGE 7 — ARCHITECT VERDICT: two-tier data architecture (operator, 2026-06-19T18:55:05Z)
VERDICT: two tiers. PREMISE (operator): foundational (retention tiers drive table/partition/aggregator/migration design; retrofit expensive) + structural fix for GAP #5 (aggregator moves RT->hist before RT ages -> midnight race gone).
TIER1 RT RTSData_*: ~1mo sliding-window, OWN reliable mechanism (NOT MidnightClear until failure understood); comparative/short metrics.
TIER2 HIST hist_*: 6-7yr, monthly RANGE partitions (audit.audit_logs §6). Populated by aggregation from RT BEFORE RT-window expiry.
234 LIVE FLOOR: RTSData_Interaction NOT cleared since 2026-06-02 (>=17d) -> MidnightClear disabled/not-firing. CODE: caller EXISTS RTM/RTM/DBMng.cs:466 (ExecuteNonQuery RTSData_MidnightClear @TenantId); fn exists db/functions/02:260. NOT missing-caller. Reasons (operator verdict, EXTERNAL/RTM contour, no silent change): scheduler/midnight-trigger not firing | silent catch DBMng.cs:468 | disabled during TenantId migration (RTM-SEC-001) never re-enabled.
DONE: two-tier baked DURABLE -> docs/bi/TZ ADDENDUM A (rev1.1) + role-bi §A#9/§D (tools/cc_prompt_create_role_bi.md). GAP #5 superseded.
BLOCKERS before CC-HIST-001: (1) operator MidnightClear verdict (RTM contour); (2) durable two-tier DONE. Impl detail by role-bi/coordinator within contract.


## STAGE 8 — MidnightClear cause ESTABLISHED to the line + RT-retention concretised (operator verdict part 1+2, 2026-06-19T19:09:09Z)
TRACE (RTM, diagnosis only — external contour, NOTHING changed):
- DB wipe RTSData_MidnightClear invoked ONLY by DBMng.midnightClear() (RTM/RTM/DBMng.cs:460-466).
- Its SOLE caller = Engine.cs:957 `//_dbMng.midnightClear();` — COMMENTED OUT. The old midnightTimer mechanism (Engine.cs:955-972 body + 983-985 wiring) is also fully commented.
- LIVE midnight path = startMidnightTimer()->ScheduleNextCheck() (Engine.cs:1001)->TZTimer->CheckAndClear() (Engine.cs:1062): per-union, timezone-aware, union.ClearTime-based; on shouldClear calls union.midnightClear(_interactionsList) (Engine.cs:1106) = IN-MEMORY ONLY (clears inactive in-memory interactions + user counters; Union.cs:263). NEVER touches DB RTSData_*.
CAUSE (to the line, per operator's bar): the nightly DB wipe does not run because its only call site Engine.cs:957 is commented; the live CheckAndClear path is in-memory. => RTSData_Interaction/UserStatus grow unbounded (234 since 2026-06-02). NOT a scheduler-absent / silent-catch / migration-disable guess — it is dead-by-comment, established.
IMPLICATION: windowed RT mechanism will NOT collide with MidnightClear (dead). Risk only if Engine.cs:957 is uncommented -> windowed mechanism must be SOLE RT-lifecycle owner.
DURABLE-LAYER UPDATE (operator part 1): role-bi §A#9 + §D + TZ ADDENDUM A now say: RT = WINDOWED ~1mo via module's OWN purge (scheduled purge / drop partitions); RTSData_MidnightClear SUPERSEDED, do NOT re-enable; RT scheme = role-bi choice {(i) purge/partitions ON RTSData_* = touches RTM contour, operator-confirm-gated | (ii) separate reporting-owned RT-tier from RTSData_*, no contour touch}, MARK contour touches. All in tools/cc_prompt_create_role_bi.md (materialises on run).


## STAGE 9 — PROCESS NORM: role-raising = joint act (operator -> coordinator, 2026-06-19T20:52:07Z)
NORM: raising a new role is NOT solo. Coordinator GENERATES (domain content, schema-grounding, claims); curator POLISHES (discipline: role-skill-standard — §A ~40-line cap, source-pins, §C-verify, cold-start, §B format). Curator polish is MANDATORY BEFORE materialization.
ACTIONS: (1) role-bi materialization GATED — tools/cc_prompt_create_role_bi.md NOT run until curator polish. Routed role-bi to curator. (2) Pin norm into role-coordinator (my discipline). (3) PLACEMENT DECISION (coordinator): role-coordinator §D subsection 'Role-creation procedure (RARE)' — NOT §A (hot path, every-init -> would clog routine); §D is reference (surfaces when raising a role, invisible in routine). Per operator condition. (4) Curator + coordinator converge directly over the bus (inbox/curator.md), no operator relay.
KNOWN polish item flagged to curator: §A#9 (two-tier truth) is bloated — one very long cardinal line; likely split/trim while PRESERVING the domain facts (two-tier, windowed RT, MidnightClear-superseded+established-cause). Curator polishes FORM, not facts.


## STAGE 10 — curator BLESS + norm ratified -> edits applied, ready to materialize (2026-06-19T21:23:52Z)
CURATOR (curator-0611) discipline pass: BLESS w/ 1 required edit — §A#9 bloated -> COMPRESS to one-line invariant (scheme-choice + Engine cause-trace stay in §D, where they already are). Else conforms (source-pins/§C-actionable/cold-start/§B/reality-wins all ✓). Reminder NORM-CUR-11c: RUN each §C green at materialization before commit.
ROLE-RAISING NORM: RATIFIED. role-coordinator §D placement CORRECT. Curator added canonical procedure to .coord/protocols/role-skill-standard.md (curator domain); role-coordinator §D = coordinator cross-ref. Draft wording approved ('ship it').
COORDINATOR APPLIED (in tools/cc_prompt_create_role_bi.md): (1) §A#9 compressed to curator's text; (2) NORM-CUR-11c §C-run reminder in VERIFY; (3) THE WORK part 3 = role-coordinator §D norm append (blessed draft + standard cross-ref); (4) commit msg + staging now include role-coordinator.md. Domain facts untouched (column contract / two-tier / MidnightClear cause — schema+trace grounded).
STATUS: role-bi is CURATOR-BLESSED. Gate cleared. Materialization = run tools/cc_prompt_create_role_bi.md (native-CC): creates role-bi.md + appends TZ ADDENDUM A + pins role-coordinator §D norm + runs §C green + commits docs:, NO push.


## STAGE 12 — operator B1-B5 decisions + IDENTITY RULE (2026-06-20T08:49:08Z)
B1 = A: partitions from v1 (EF + raw-SQL monthly RANGE) — matches foundational/retrofit-expensive; 'audit pattern' is doc-fiction (verified plain table).
B2 = CONTOUR: decide RTSData_* purge NOW (scheme i). bi designs windowed purge/partitions ON RTSData_* = touches RTM contour -> gated per-apply + RTM-side sub-track inside CC-HIST-001. (MidnightClear dead code; new purge must not collide if Engine.cs:957 ever uncommented.)
B3 = OPTION (operator): write the call-id WT.UUID (InteractionId) into RTSData_UserStatusLog per status row -> links status<->agent<->call -> TRUE per-call Hold/ACW (full AHT). CONTOUR change (RTM Engine writes it; call-id must be available at status-write). bi evaluates feasibility + RTM-side; gated. Supersedes the 'AHT=Talk only' fallback IF adopted.
B4 = CONFIRMED: queue staffing (AgentsStaffed/Ready/Busy) empty in v1, defer v2.
B5 = IDENTITY RULE (operator, GENERAL — 'always and everywhere'): legacy tables confuse User vs Agent. RULE: Queues + Agents = EXTERNAL (CC-platform) identifiers; system users (users) = INTERNAL identifiers. CORRECTS bi's agent-keying: do NOT resolve agent login -> ApplicationUser.Id; agents are EXTERNAL (keyed by RTSData_*.UserId / CC agent id), separate population from Shell system-users. Queues already external (NGC_Queues.ExternalId) ✓. -> hist_agent_intervals keys agents by external id (no ApplicationUser FK); ApplicationUser/internal uuid only for user_reports.CreatedByUserId etc.
DURABLE: identity rule = project-wide convention -> candidate for role-bi §A cardinal + CLAUDE.md (flagged). For now baked into CC-HIST-001 design direction.
