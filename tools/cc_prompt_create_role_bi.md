# CC task — CREATE role-bi specialist skill (BI / Historical Reports) — Phase: skill creation
> §4-PASS coordinator-0612 2026-06-19T10:28:22Z. Owner: coordinator (authoring a new specialist role-skill). Commit `docs:`. NO push.
> Operator directive 2026-06-19: create a BI specialist for writing historical reports. Domain spec already in repo:
> docs/bi/TZ_Historical_Reports.md (v1.0). Coordinator designed the skill content (grounded in db/schema.sql column
> verification — see .coord/bi_specialist_creation_log.md STAGE 1-4). This task MATERIALIZES the skill file.

## Mandatory — read before starting
Read: .coord/protocols/role-skill-standard.md (house format for role-skills)
Read: .coord/protocols/role-skill-TEMPLATE.md
Read: docs/bi/TZ_Historical_Reports.md (the domain spec — so you can sanity-check the skill against it)

## INIT + discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store. §0.3 Python+fsync (this is a tracked .md — write via Python, verify tail/wc). Edit tool BANNED.
- Binding PREAMBLE -> .coord/cc/coordinator.md. commit.lock around commit. NO push (§37).

## THE WORK — create .claude/skills/role-bi/role-bi.md
1. `mkdir -p .claude/skills/role-bi` (via Python os.makedirs(exist_ok=True)).
2. Write the file VERBATIM with the content in the SKILL PAYLOAD block below (between the BEGIN/END markers). Use Python binary-safe UTF-8 write + fsync. Do NOT reformat, re-wrap, or "improve" it — the §A cap, source-pins, and verified column contract are deliberate.
3. Sanity-check against docs/bi/TZ_Historical_Reports.md: the skill's §D section/phase references should match the TZ's section numbers. If you find a CONTRADICTION between the skill and the TZ on a COLUMN NAME, the skill is right (it was verified vs schema.sql); the TZ is illustrative. Do NOT change the skill to match the TZ on columns.

### SKILL PAYLOAD — write everything between BEGIN/END verbatim to .claude/skills/role-bi/role-bi.md
--- BEGIN role-bi.md ---
---
role: bi
project: RTM View Shell
version: 1.0
last_verified: 2026-06-19
owner: bi
reviewer: curator
---
# role-bi — BI / Historical Reports specialist (Specialist Protocol)
> Domain spec: docs/bi/TZ_Historical_Reports.md (v1.0, 2026-06-17). Cold-started from the TZ + db/schema.sql column
> verification (2026-06-19, coordinator-0612), NOT session narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: BI specialist OWNS the Historical Reports module — pre-aggregation pipeline + report catalogue (17 system + user
reports) + report builder. Territory claim: src/**/Historical/**, src/**/HistoricalReports/**,
src/**/BackgroundServices/HistoricalAggregationService*, src/CcDashboard.Web/Components/Reports/**,
src/CcDashboard.Web/Pages/Reports/**, db/migrations for hist_*/user_reports, Reports.* resx. NOT real-time widgets
(widget-*/RtmRelay), NOT WFM, NOT OLAP cross-joins (v3).
**Reality wins — update me.** If §C VERIFY finds §A disagrees with code/schema, the CODE/SCHEMA is right; mark superseded.
Cardinal truths (each SOURCE-pinned):
1. PRE-AGGREGATION ONLY — reports read hist_queue_intervals / hist_agent_intervals; NEVER GROUP BY RTSData_Interaction live (slow @100k+ rows/day). · SOURCE: TZ §2.1
2. IDEMPOTENT upsert = DELETE interval-window + INSERT; re-aggregating an interval is safe/repeatable. 30-min intervals; startup lookback 24h, periodic 2h. · SOURCE: TZ §2.1/§4.2
3. MULTI-TENANT — hist_*/user_reports all carry TenantId + GQF. Clean arch (Application no EF, Infra no Blazor). PG queue-filter via pg_queues happens in the REPOSITORY, not the aggregation (aggregates hold all tenant queues). · SOURCE: TZ §2.1/§11.2
4. VERIFY RTM source columns vs db/schema.sql BEFORE any aggregation SQL — the TZ's column names are ILLUSTRATIVE/WRONG. Real RTSData_Interaction: Workgroup(queue ext-id), UserId(agent login), TimeInQueue(=wait, int), TalkTime(int), IsAnswered/IsAbandoned/IsTalk/IsInQueue(bool), InQueueDateTime/AnsweredDateTime(ts), InteractionType/CallType/Direction. NO HandleTime/ACW/Hold columns. · SOURCE: schema.sql verified 2026-06-19
5. JOINS & ID-RESOLUTION — queue join = NGC_Queues.ExternalId = RTSData_Interaction.Workgroup (+TenantId); the NGC table is PLURAL NGC_Queues. RTSData_*.UserId + .Workgroup are VARCHAR → resolve login→identity.users.Id and Workgroup→NGC_Queues.Id during aggregation (hist_* keys are uuid). · SOURCE: schema.sql 2026-06-19
6. AGENT source = RTSData_UserStatusLog (Duration bigint + StatusGroup + StartTime/EndTime) → SUM(Duration) FILTER per StatusGroup, bucket by StartTime. TZ's RTSData_UserStatus snapshot fallback is unnecessary — the log exists and RTM writes it. · SOURCE: schema.sql 2026-06-19, migrations _004/_006
7. Computed metrics = NULLIF-guarded formulas, NEVER stored (AbandonPct, SlPct, ASA, AvgWait, AHT, OccupancyPct, ShrinkagePct, CPH). ⚠ AHT v1 ≈ TalkTime ONLY (no ACW/Hold in source) — a KNOWN GAP; flag scope to operator, never fabricate Handle/ACW. · SOURCE: TZ §3.1/§3.2 + schema.sql gap
8. Reuse RTM metric semantics — read .claude/skills/rtm-metrics-expert before metric work; hist aggregates map to RTSGrid_Metric families; agent StatusGroup SUM mirrors widget SUM_OVERLAP_MS. Don't reinvent. · SOURCE: rtm-metrics-expert, widget-creator
9. TWO-TIER (architect verdict 2026-06-19, FOUNDATIONAL): RT-tier = real-time, WINDOWED ~1mo retention via the module's OWN reliable purge; RTSData_MidnightClear SUPERSEDED — NEVER re-enable (dead code; cause Engine.cs:957). HISTORICAL tier = hist_* 6-7yr monthly RANGE partitions; aggregator moves RT->historical BEFORE RT ages out. Reports read historical; short comparatives may read RT. RT-tier SCHEME + full cause-trace -> §D TWO-TIER CONTRACT. · SOURCE: architect verdict + Engine.cs trace 2026-06-19, creation-log STAGE 7-8

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-19 · Cold-start: TZ aggregation SQL referenced NON-EXISTENT columns (WaitTimeSec/HandleTimeSec/TalkTimeSec/AcwTimeSec/StartTime/i.QueueId, table "NGC_Queue"). Live schema.sql has TimeInQueue/TalkTime/InQueueDateTime/Workgroup, plural NGC_Queues, and NO Handle/ACW/Hold. · RULE: always verify RTM source columns vs db/schema.sql (or \d on server) BEFORE writing aggregation — spec column names are illustrative; this prevents a class of 42703 column-not-exist bugs across the whole module. · SOURCE: db/schema.sql, TZ §4.3 (self-flagged), .coord/bi_specialist_creation_log.md STAGE 4 · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act on stale)
- Module implemented yet? `ls src/CcDashboard.Domain/Domain/Historical/ 2>/dev/null` + grep -ril hist_queue_intervals db/migrations. At cold-start (2026-06-19) NOT YET built — this skill LEADS implementation. If now present, verify entity/column/DTO names match §A.
- Re-verify RTSData_Interaction cols: `awk '/CREATE TABLE.*"RTSData_Interaction"/,/^\);/' db/schema.sql`. Confirm Workgroup/UserId/TimeInQueue/TalkTime/IsAnswered/IsAbandoned/InQueueDateTime present, still NO HandleTime/Acw. If RTM later adds HandleTime/Acw → supersede truth #7's AHT-gap.
- Agent source: confirm RTSData_UserStatusLog still has Duration + StatusGroup + StartTime/EndTime.
- Queue join: confirm NGC_Queues (plural) + ExternalId present.

## §D REFERENCE  (optional · NOT loaded each init)
- FULL SPEC: docs/bi/TZ_Historical_Reports.md (v1.0). §1 scope, §2 arch, §3 data model (hist_queue_intervals / hist_agent_intervals / user_reports DDL + computed-field tables), §4 HistoricalAggregationService (BackgroundService), §5 IHistoricalReportRepository + CQRS (Q1/Q5/A4/A5 query+DTO records), §6 17 system reports (Q1-6 / A1-7 / S1-4), §7 report builder (4-step wizard → user_reports.Config jsonb: timeGranularity/dateRangeType/metrics[]/queueIds/agentIds/sort/pageSize/thresholds), §8 UI (ReportFilterBar/ReportTable/ReportSummaryTiles/ReportBuilder + ReportColumnDef), §9 CSV(v1) + Excel/PDF/email(v2/v3), §10 i18n (Reports.*), §11 perms, §12 phases, §13 tests.
- COMPUTED-METRIC FORMULAS (NULLIF-guarded): Queue — AbandonPct=Abandoned*100/Offered, SlPct=InSl*100/Answered, ASA=AvgWait=SumWaitAnswered/Answered, AHT=SumHandle/Answered (v1≈Talk), OccupancyPct=Busy*100/(Ready+Busy). Agent — OccupancyPct=(Talk+Hold+Acw)*100/Ready, ShrinkagePct=(Break+NotReady+Paperwork)*100/Shift, CPH=Handled*3600/Shift, AHT=(Talk+Hold+Acw)/Handled.
- VERIFIED column→metric mapping (schema.sql 2026-06-19): offered/answered/abandoned via IsAnswered/IsAbandoned + InteractionType='Call' AND CallType='External' AND Direction='Incoming'; wait = TimeInQueue; SL = COUNT FILTER (TimeInQueue <= threshold AND NOT IsAbandoned); queue join NGC_Queues.ExternalId=i.Workgroup; agent times = SUM(RTSData_UserStatusLog.Duration) FILTER per StatusGroup.
- PHASE PLAN: v1 = CC-HIST-001 (EF migration hist_*/user_reports + HistoricalAggregationService + HistoricalReportRepository + MediatR Q1/Q5/A4/A5 + 6 unit tests), CC-HIST-002 (ReportFilterBar/Table/SummaryTiles + pages + NavMenu + CSV + i18n + reports.css + 4 UI tests), CC-HIST-003 (UserReport entity+repo+CQRS + ReportBuilder wizard + seed 17 system reports in DatabaseInitializer). v2 = remaining reports + ClosedXML Excel + report_schedules email. v3 = combined/drill-down/period-compare/QuestPDF/public-link.
- OPEN GAPS to resolve with operator before/at CC-HIST-001: (a) AHT/ACW/Hold — no source columns → decide AHT≈Talk or source ACW elsewhere (RTSGrid_Metric? RTM Service?); (b) queue AgentsStaffed/SumReadySec/SumBusySec are TODO(0) in TZ → derive from RTSData_UserStatusLog joined to queue, or defer to v2; (c) login→uuid + Workgroup→uuid resolution cost → index or denormalise ext-ids into hist_*; (d) interval bucketing column for offered calls = InQueueDateTime (verify vs OnDate string).
- TWO-TIER CONTRACT (architect verdict 2026-06-19, FOUNDATIONAL — see docs/bi/TZ_Historical_Reports.md ADDENDUM A): (1) RT-tier — WINDOWED ~1mo retention via the module's OWN reliable purge (scheduled purge / drop partitions); RTSData_MidnightClear SUPERSEDED, do NOT re-enable. Scheme = role-bi's choice: (i) purge/partitions ON RTSData_* (touches RTM contour → operator-confirm-gated) OR (ii) separate reporting-owned RT-tier populated FROM RTSData_* (no contour touch); MARK contour touches. (2) Historical tier hist_* — retention 6-7yr, monthly RANGE partitions (audit.audit_logs §6), aggregator populates from RT BEFORE RT-window expiry. SUPERSEDES GAP #5 midnight-race. Implementation (partitions, RT window mechanism, 6-7yr archival, possible separate warehouse) by role-bi/coordinator WITHIN contract. MIDNIGHTCLEAR CAUSE ESTABLISHED (operator-recorded, NO change made — diagnosis only): DEAD CODE — sole caller Engine.cs:957 commented; live midnight Engine.cs:1062 CheckAndClear → Engine.cs:1106 union.midnightClear is IN-MEMORY only, never wipes RTSData_* → unbounded growth. Windowed mechanism must be the SOLE RT-lifecycle owner; never uncomment Engine.cs:957.
- RELATED SKILLS: rtm-metrics-expert (metric semantics/dedup/ISO-18295), widget-planner/widget-creator (Grid vs Chart, narrow-format, SUM_OVERLAP_MS — agent StatusGroup aggregation is the same shape), session-coord (bus/claims), role-dba (migrations: PROCEDURE vs FUNCTION, GQF, UUIDv7).

--- END role-bi.md ---


## THE WORK (part 2) — append Two-Tier ADDENDUM to the TZ (CC writes natively; Cowork hit a mount PermissionError on this file)
Append the ADDENDUM below to docs/bi/TZ_Historical_Reports.md (insert BEFORE the trailing footer "*Проект: RTM View Shell*" if present, else append at end) verbatim, and add revision row "| 1.1 | 2026-06-19 | ADDENDUM A — two-tier data architecture (architect verdict) |" right after "| 1.0 | 2026-06-17 | Начальная версия |". Python+fsync, then tail/wc verify.
--- BEGIN ADDENDUM A ---

---

## ADDENDUM A — Two-Tier Data Architecture (Architect Verdict, 2026-06-19) — FOUNDATIONAL, supersedes single-store assumptions

> Verified on live server 234: RTSData_Interaction is NOT being cleared — data accumulated since 2026-06-02 (>=17 days)
> -> RTSData_MidnightClear is disabled or not firing. RT table grows unbounded; no retention, no historical store.
> This addendum SUPERSEDES single-store assumptions in this TZ.

Two tiers:
1. RT-tier — WINDOWED ~1 month retention via the module's OWN reliable purge (scheduled purge / drop partitions). RTSData_MidnightClear is SUPERSEDED — do NOT re-enable. Scheme is role-bi's choice within the contract: (i) purge/partitions ON the RTSData_* tables (touches the RTM external contour → applied ONLY on operator confirmation) OR (ii) a separate reporting-owned RT-tier populated FROM RTSData_* (no contour touch); MARK where it touches the contour. Comparative/short metrics.
2. Historical tier (hist_*) — retention 6-7 years, monthly RANGE partitioning (audit.audit_logs §6 pattern), populated by aggregation from the RT source BEFORE data ages out of the RT window.

Why now: foundational (drives table/partition/aggregator/migration design; retrofit expensive) + structural fix for GAP #5 (aggregator moves RT->historical before RT ages -> midnight race gone).

MidnightClear cause — ESTABLISHED (2026-06-19, diagnosis only, NOTHING changed): the DB nightly wipe is DEAD CODE — RTSData_MidnightClear's sole caller Engine.cs:957 (//_dbMng.midnightClear();) is commented out; the live midnight path Engine.cs:1062 CheckAndClear -> Engine.cs:1106 union.midnightClear(_interactionsList) is IN-MEMORY only and never wipes the DB tables -> RTSData_* grow unbounded (234: since 2026-06-02). The windowed RT mechanism does NOT collide with MidnightClear; it must be the SOLE RT-lifecycle owner -> do NOT uncomment Engine.cs:957. (EXTERNAL RTM contour — diagnosis recorded for operator; no change made.)

Designed by role-bi/coordinator WITHIN contract: exact partition scheme, RT sliding-window purge, 6-7yr archival, possible separate warehouse.

--- END ADDENDUM A ---

## VERIFY (object-store)
- NORM-CUR-11c (curator): RUN each §C-verify check in role-bi.md GREEN before commit (e.g. `ls src/CcDashboard.Domain/Domain/Historical/`, `awk` the RTSData_Interaction columns) — confirm the cardinal truths still hold against current code/schema; if a check fails, mark that §A line superseded rather than committing a stale truth.
- `git show HEAD:.claude/skills/role-bi/role-bi.md | head -3` shows the frontmatter (role: bi); last line is the §D RELATED SKILLS line (not truncated); `wc -l` ~ matches payload.
- grep the verified-contract anchors present: "TimeInQueue", "Workgroup", "NGC_Queues", "RTSData_UserStatusLog", "PRE-AGGREGATION ONLY", "Reality wins".


## THE WORK (part 3) — pin the role-raising NORM into role-coordinator §D (curator RATIFIED 2026-06-19)
Append the following subsection at the END of the §D REFERENCE section of .claude/skills/role-coordinator/role-coordinator.md (after the last §D line; do NOT touch §A/§B/§C). Python+fsync, then tail/wc verify. The canonical procedure ALSO lives in .coord/protocols/role-skill-standard.md (curator added it) — this §D entry is the coordinator-side cross-ref.
--- BEGIN role-coordinator §D append ---

### Role-creation procedure (RARE — joint act, not solo) [norm 2026-06-19, curator-ratified]
Raising a new specialist role is a JOINT act, NOT solo: coordinator GENERATES (domain content, schema-grounding, claims/territory); curator POLISHES (discipline: role-skill-standard conformance — §A ~40-line cap, source-pins, actionable §C-verify, cold-start-from-artifacts framing, §B append-format). Curator polish is a MANDATORY step BEFORE the role is materialized (before the create CC prompt runs).
Procedure: (1) coordinator drafts the role-skill (CC prompt embedding §A/B/C/D, schema-grounded) + claims; (2) route to curator (inbox/curator.md) for the discipline pass; (3) curator polishes/blesses; (4) only then materialize (run the create prompt) + commit (native-CC, no push). Canonical standard: .coord/protocols/role-skill-standard.md (curator domain). SOURCE: operator norm 2026-06-19 (role-bi = first run).

--- END role-coordinator §D append ---

## COMMIT (docs:, NO push) under commit.lock
`docs: create role-bi specialist skill (BI/Historical Reports, curator-blessed) + pin role-raising norm into role-coordinator §D — schema-grounded; domain spec docs/bi/TZ_Historical_Reports.md`
Stage ONLY: .claude/skills/role-bi/role-bi.md + docs/bi/TZ_Historical_Reports.md (ADDENDUM A) + .claude/skills/role-coordinator/role-coordinator.md (§D norm append). NOT a broad add.
then §0.6 post-commit + §0.7 re-sync + sync.

## REPORT -> binding cc/coordinator.md RESULT + inbox/coordinator.md: commit hash; role-bi.md line count + the grep-anchor confirmation; whether docs/bi/TZ was newly tracked. NO push.
