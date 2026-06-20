# CC-HIST-001 — Historical Reports: Track A (data layer)

> Module owner: role-bi (bi-0619). Domain spec: docs/bi/TZ_Historical_Reports.md (v1.0 + ADDENDUM A two-tier) +
> docs/bi/Historical_Reports_Project_Plan.md §3 Track A. role-skill: .claude/skills/role-bi/role-bi.md.
> STATUS: §4-review DRAFT (rev2, 2026-06-20) — operator decisions folded: full agent AHT via StatusId-level Hold
> within ONPHONE (NO contour); B3 per-call attribution = SEPARATE gated prompt tools/cc_prompt_hist_a3_callid.md.
> Do NOT execute until coordinator §4 = PASS.
> SCOPE: data layer ONLY. READ-ONLY on the RTM external contour (RTSData_*/NGC_*/identity). No UI.
> EXCLUDED here (separate gated prompts): RTSData_* purge (A2, contour, operator-gated), WT.UUID write (A3/B3, contour).

---

## STEP 0 — MANDATORY integrity block (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync; echo "=== integrity complete ==="
```

## STEP 1 — MANDATORY skills (§40) — read before any work
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Read: .claude/skills/role-bi/role-bi.md   (§A core + §C VERIFY + §D reference)
```
Run §C VERIFY green BEFORE coding (NORM-CUR-11c): confirm RTSData_Interaction cols (Workgroup/UserId/TimeInQueue/
TalkTime/IsAnswered/IsAbandoned/InQueueDateTime; NO Handle/ACW/Hold), RTSData_UserStatusLog (Duration/StatusGroup/
StartTime/EndTime), NGC_Queues (plural)+ExternalId — via `awk` over db/schema.sql. If schema diverges → STOP, report.

## STEP 2 — sync block (§42.6)
Apply tools/cc_prompt_sync_block.md with: slug=`bi-0619`, claims=
`src/CcDashboard.Domain/Domain/Historical/**`, `src/CcDashboard.Application/HistoricalReports/**`,
`src/CcDashboard.Infrastructure/**/Historical*`, `src/CcDashboard.Web/BackgroundServices/HistoricalAggregationService*`,
`db/migrations/*hist_*`, `db/migrations/*user_reports*`, EF migration files under
`src/CcDashboard.Infrastructure/Migrations/App/`, `tests/CcDashboard.Tests.Unit/Historical/**`.
Touch ONLY these. RTSData_*/NGC_*/identity tables = READ-ONLY (no DDL/DML against them).

## STEP 3 — binding PREAMBLE (§0.6b) — append to .coord/cc/bi.md
```
## BINDING <UTC> | spec: bi | directive: tools/cc_prompt_hist_001.md | status: open
### DIRECTIVE: CC-HIST-001 Track A data layer. Claims: Historical/** + migrations + tests. Prefix: web:/db:.
```

---

## THE WORK — CC-HIST-001 data layer

### Foundations (LOCKED — do not deviate)
- Pre-aggregation only: reports read hist_* — NEVER GROUP BY RTSData_Interaction live (role-bi §A#1).
- Idempotent upsert = DELETE interval-window + INSERT (re-aggregation safe). 30-min intervals; startup lookback 24h, periodic 2h.
- Multi-tenant: every hist_*/user_reports row carries TenantId + GQF. Clean arch (Application no EF; Infra no Blazor).
- IDENTITY RULE (B5): Queues + Agents = EXTERNAL CC identifiers. Agents keyed by RTSData_*.UserId (external id);
  do NOT resolve agent login → ApplicationUser.Id. Internal uuid (ApplicationUser.Id) used ONLY for user_reports
  creators/permissions. Queues: keep external Workgroup + resolve QueueId via NGC_Queues.ExternalId (nullable).
- Bucket by InQueueDateTime (tstz) — NOT OnDate (varchar). Agent agg buckets by RTSData_UserStatusLog.StartTime.
- AHT (operator-corrected): "Hold" is a STATUS (StatusName='Hold') INSIDE StatusGroup ONPHONE — RTSData_UserStatusLog
  has BOTH StatusId/StatusName AND StatusGroup. So ONPHONE-group = talk + hold; PAPERWORK-group = wrap-up/ACW
  (StatusName='Wrap Up' is a PAPERWORK sub-state). => AGENT AHT is FULL & honest from the status log, NO contour:
  AgentAht = (SumOnphoneMs + SumPaperworkMs)/1000 / NULLIF(Handled,0)  [talk+hold+acw]. Granular report columns:
  Hold = SUM(Duration) FILTER StatusName='Hold'; pure Talk = SumOnphoneMs - SumHoldMs; ACW = SumPaperworkMs.
  QUEUE per-call AHT (Q1, from RTSData_Interaction.TalkTime) STAYS Talk-only here — upgraded to full per-call AHT
  only by A3 (call-id linkage, separate gated prompt). NEVER fabricate. Re-verify Hold StatusName vs live data
  (DISTINCT "StatusId","StatusName" WHERE "StatusGroup"='ONPHONE'); if no Hold row in this tenant -> Hold=0, labelled.

### T1 — EF + raw-SQL migration (B1=A: monthly RANGE partitions from v1)
Three tables in schema `public`. EF Core 8 cannot express native PG partitioning → create the partitioned parents
and partitions via `migrationBuilder.Sql(...)` raw SQL inside ONE EF migration (App context); map the entities so EF
can query them (EF is partition-agnostic at query time). Companion idempotent raw SQL also goes to
`db/migrations/20260620_0NN_hist_reports.sql` for the DB module (Export-All later). Self-record in db_patch_history (§38a).

**hist_queue_intervals** (PARTITION BY RANGE ("IntervalStart")):
- Id uuid, TenantId uuid, IntervalStart timestamptz, Workgroup varchar(100), QueueId uuid NULL,
  Offered int, Answered int, Abandoned int, AnsweredInSl int, SumWaitAnswered bigint, SumTalk bigint,
  CreatedAt timestamptz, UpdatedAt timestamptz.
- PK (Id, IntervalStart); UNIQUE (TenantId, IntervalStart, Workgroup)  [partition key MUST be in every unique key].
- Index (TenantId, IntervalStart). (Queue staffing fields DEFERRED to v2 per B4 — do NOT add.)

**hist_agent_intervals** (PARTITION BY RANGE ("IntervalStart")):
- Id uuid, TenantId uuid, IntervalStart timestamptz, AgentExternalId varchar(100), AgentDisplayName varchar(200) NULL,
  SumAvailableMs bigint, SumOnphoneMs bigint, SumPaperworkMs bigint, SumBreakMs bigint, SumTrainingMs bigint,
  SumUnavailableMs bigint, SumLoggedInMs bigint, Handled int, CreatedAt timestamptz, UpdatedAt timestamptz.
- PK (Id, IntervalStart); UNIQUE (TenantId, IntervalStart, AgentExternalId).
- Index (TenantId, IntervalStart).  NO AgentId uuid (B5 — agents are external).

**user_reports** (NOT partitioned — small config table):
- Id uuid PK (UUIDv7), TenantId uuid, Name varchar(200), Description varchar(500) NULL, IsSystem bool, IsPublic bool,
  OwnerUserId uuid NULL (INTERNAL ApplicationUser.Id), Config jsonb, CreatedAt, UpdatedAt, CreatedByUserId uuid,
  UpdatedByUserId uuid. UNIQUE (TenantId, Name). (Entity + table now; SEED of 17 system reports = CC-HIST-003.)

**Partition management (dba pre-review FIX — partition COVERAGE gap):** the 24h startup lookback near a month boundary
buckets into the PRIOR month -> INSERT into a missing partition -> first-run runtime error. Robust combo (do ALL):
(1) migration creates PRIOR + current + next-2-months partitions; (2) a DEFAULT partition as a safety net (catches any
window not yet pre-created); (3) `fn_hist_ensure_partitions(p_table text, p_months_back int, p_months_ahead int)` covers
the FULL lookback window — BackgroundService calls it daily with back=1, ahead=2. `fn_hist_drop_aged(p_table text,
p_keep_months int)` default keep ~84mo.
>> §33.8: fn_hist_ensure_partitions + fn_hist_drop_aged are SHELL-CALLED VIA SELECT -> they MUST be FUNCTIONs, NOT
PROCEDUREs. RTM-SEC-002 (prokind='p') applies ONLY to RTM CALL routines — do NOT convert these to PROCEDURE.
NOTE: monthly RANGE partitioning is NET-NEW (audit.audit_logs is a PLAIN table despite §6 — verified). dba reviews
partitions/coverage/indexes + confirms fn kind = FUNCTION.

### T2 — Domain entities (Domain/Domain/Historical/)
HistQueueInterval, HistAgentInterval, UserReport (POCOs, no EF attrs). Computed-metric value records (NOT stored):
QueueMetrics, AgentMetrics with NULLIF-guarded formulas (role-bi §D): AbandonPct=Abandoned*100.0/NULLIF(Offered,0);
SlPct=AnsweredInSl*100.0/NULLIF(Answered,0); Asa=AvgWait=SumWaitAnswered*1.0/NULLIF(Answered,0);
QueueAht=SumTalk*1.0/NULLIF(Answered,0) [Talk-only, labelled]; Agent OccupancyPct=(SumOnphoneMs+SumPaperworkMs)*100.0/
NULLIF(SumAvailableMs+SumOnphoneMs+SumPaperworkMs,0); AgentAht=(SumOnphoneMs+SumPaperworkMs)/1000.0/NULLIF(Handled,0)
[FULL: ONPHONE already includes hold + PAPERWORK=acw]; HoldPct=SumHoldMs*100.0/NULLIF(SumOnphoneMs,0); TalkPureMs=SumOnphoneMs-SumHoldMs.

### T3 — HistoricalAggregationService (IHostedService) — place in src/CcDashboard.Infrastructure/BackgroundServices/ (§3, coordinator §4 minor)
- Timers: startup lookback 24h; periodic every 2h with 2h lookback; daily ensure_partitions.
- Per-tenant loop: create DI scope, set ITenantContext.TenantId explicitly (ARCH-07) before DB ops.
- Idempotent: for each (tenant, 30-min interval-window) DELETE existing hist rows for the window + INSERT recomputed.
- QUEUE agg (read RTSData_Interaction, AsNoTracking / raw read; bucket by InQueueDateTime, 30-min floor):
  Offered = COUNT WHERE InteractionType='Call' AND CallType='External' AND Direction='Incoming' (confirm enum values
  on data; if uncertain, parameterise) ; Answered = ... AND IsAnswered ; Abandoned = ... AND IsAbandoned ;
  AnsweredInSl = ... AND IsAnswered AND TimeInQueue <= @SlThresholdSec (see SL note) ; SumWaitAnswered=SUM(TimeInQueue)
  FILTER IsAnswered ; SumTalk=SUM(TalkTime) FILTER IsAnswered. Group by 30-min bucket + Workgroup.
  Resolve QueueId via LEFT JOIN NGC_Queues ON ExternalId=Workgroup AND TenantId (NULL if unmatched — keep Workgroup).
- AGENT agg (read RTSData_UserStatusLog; reuse the overlap_ms pattern from db/functions/02_rtsdata_functions.sql:422
  fn_daytrendagentstatus — interval overlap × 1000ms, SUM FILTER per StatusGroup): SumAvailableMs/SumOnphoneMs/
  SumPaperworkMs/SumBreakMs/SumTrainingMs/SumUnavailableMs/SumLoggedInMs; bucket by StartTime; key by UserId
  (=AgentExternalId, B5 — NO ApplicationUser resolution). Handled = COUNT RTSData_Interaction WHERE UserId=agent AND
  IsAnswered, bucketed by AnsweredDateTime.
  HOLD (operator correction): also SUM(overlap_ms) FILTER ("StatusGroup"='ONPHONE' AND "StatusName"='Hold') -> SumHoldMs
  (StatusName-level inside ONPHONE; SumOnphoneMs stays the full group = talk+hold). BEFORE coding, run on the live DB
  `SELECT DISTINCT "StatusId","StatusName" FROM "RTSData_UserStatusLog" WHERE "StatusGroup"='ONPHONE'` to confirm the
  Hold value (catalog says StatusName='Hold', metric MonAgentHeldDuration db/data/02_metrics.sql:43); if absent in this
  tenant's data -> SumHoldMs=0, labelled (do NOT fabricate). This yields FULL agent AHT with NO contour change.
- Watermark: persist "aggregated-through" timestamp per tenant (small table or tenant_settings-adjacent) so the future
  A2 RT-purge never deletes un-aggregated data. (A2 purge itself = SEPARATE gated prompt, NOT here.)
- SL note: TenantSettings has NO SL-target column. v1 = single SlThresholdSec constant (default 20) in aggregation
  config. Configurable-per-report SL = v2 (TenantSettings field or wait-bucket histogram). Flag in code comment.

### T4 — IHistoricalReportRepository + EF impl (Infrastructure)
- AsNoTracking reads of hist_* only. PG queue-filter via pg_queues IN THE REPOSITORY (role-bi §A#3) — NOT in aggregation
  (aggregates hold all tenant queues). Computed metrics NULLIF-guarded in the projection/DTO. CancellationToken throughout.

### T5 — MediatR queries + DTOs (Application)
Q1 Queue Interval, Q5 Queue Wait Time, A4 Agent Monthly, A5 Agent Shift Detail (records + handlers + FluentValidation
validators). Server-side pagination (PERF-02). DTOs in Application (Contracts project not yet split).

### T6 — Unit tests (>=6, tests/CcDashboard.Tests.Unit/Historical/)
(1) aggregation idempotency: re-run same window → identical rows (DELETE+INSERT). (2) NULLIF: zero-denominator metrics
→ null/0, no divide-by-zero. (3) resolution: unmatched Workgroup → QueueId NULL + Workgroup retained (no data loss).
(4) interval bucketing boundary (call at :29:59 vs :30:00). (5) multi-tenant isolation (tenant A agg never reads B).
(6) SL threshold filter (TimeInQueue <= threshold counted, > excluded; abandoned excluded).

### ACCEPTANCE
- `dotnet build CcDashboard.sln` green; `dotnet test tests/CcDashboard.Tests.Unit` ≥6 new tests green.
- Migration applies on fresh AND existing DB; partitions created; idempotent re-run safe.
- ZERO writes to RTSData_*/NGC_*/identity (read-only contour) — verify no DDL/DML against them in the diff.
- Object-store verified commit (git cat-file), commit prefixes web:/db:, NO push (§37).

---

## STEP 4 — binding POSTAMBLE (§0.6b) — append RESULT to .coord/cc/bi.md
```
### RESULT: commit <hash> . build <pass/fail> . tests <n pass> . files <list+lines> . status done|failed . blockers . verified: object-store
```
## STEP 5 — CAPTURE (NORM-CUR-11): if a lesson emerged, append dated source-pinned line to role-bi §B BEFORE close.
## STEP 6 — commit lock release + journal + §0.7 re-sync from HEAD (per sync block S4/S4b). NO git push.

---

## CONTOUR DECISION PACKAGE (operator — NOT part of this prompt's execution)
- A2 RTSData_* purge (B2): windowed ~1mo purge ON RTSData_* (scheme i) = CONTOUR TOUCH → separate gated prompt,
  operator-confirm per apply, coordinate RTM Engine (no MidnightClear collision — dead code Engine.cs:957).
- A3/B3 call-id linkage: operator decided B3 IS IN (create the call-id). Authored as a SEPARATE gated contour prompt
  tools/cc_prompt_hist_a3_callid.md (add call-id col to RTSData_UserStatusLog + RTM Engine stamps active InteractionId
  per status row + join UserStatusLog<->RTSData_Interaction -> full PER-CALL queue AHT). Backend feasibility coord +
  operator-confirm per apply. NOT part of this foundation prompt (CC-HIST-001 stays read-only on contour).
