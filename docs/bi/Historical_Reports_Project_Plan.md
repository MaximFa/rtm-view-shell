# Historical Reports — Project Plan (from now to deploy)
> Author: coordinator-0612 · 2026-06-20 · Module owner: role-bi. Domain spec: docs/bi/TZ_Historical_Reports.md (v1.0 + ADDENDUM A two-tier).
> Status: v1.1 (2026-06-20). role-bi materialized; B1-B5 decided; B3 now IN (build call-id/WTUUID linkage for full AHT); agent AHT full via StatusId; identity rule in CLAUDE.md §46. cc_prompt_hist_001 §4-PASS (revising for full agent AHT).
> Discipline: every code task = CC prompt -> coordinator §4-review -> native CC, commit, NO push. Contour touches (RTSData_*/RTM Engine) = operator-gated.

---

## 0. Foundations (locked)
- **Two-tier contract** (architect verdict): RT-tier (RTSData_*, windowed ~1mo, OWN purge — MidnightClear is dead code Engine.cs:957, NEVER re-enable) + Historical tier (hist_*, 6-7yr, monthly RANGE partitions). Aggregator moves RT->historical before RT ages out.
- **Verified column contract** (schema.sql): RTSData_Interaction = Workgroup/UserId/TimeInQueue/TalkTime/IsAnswered/IsAbandoned/InQueueDateTime (NO Handle/ACW/Hold). Queue join NGC_Queues.ExternalId=Workgroup. Agent source RTSData_UserStatusLog (Duration+StatusGroup+Start/End).
- **Identity rule (B5)**: Queues + Agents = EXTERNAL CC ids; system users = INTERNAL uuid. Agents NOT keyed on ApplicationUser. (Durable: CLAUDE.md §46 + role-bi §A.)
- **AHT (corrected)**: Hold is a STATUS inside the ONPHONE group → agent AHT = Talk+Hold+ACW is assembled from RTSData_UserStatusLog at StatusId level (no contour). Queue per-call full AHT needs the call-id/WTUUID linkage (B3, below).
- **Operator decisions**: B1=A (partitions from v1, EF+raw-SQL) · B2=CONTOUR (RTSData_* purge now, gated) · B3=IN — create call-id (WTUUID) in RTSData_UserStatusLog + RTM Engine stamps it → join Interaction↔UserStatusLog → full per-call AHT (contour A3, gated; bi+backend) · B4=staffing empty v1 · B5=identity rule.

---

## 1. Roles & who does which part
| Part | Owner (authors) | Review-gate | Notes |
|---|---|---|---|
| Module orchestration, data model, aggregator, repo, CQRS | **bi** | coordinator §4 | leads, owns Historical/** + HistoricalReports/** |
| DB migrations (hist_*/user_reports, partitions), schema correctness | bi authors -> **dba** review | dba | EF-only; raw-SQL for PG partitioning |
| RT-tier purge on RTSData_* (B2) + WT.UUID write (B3) | bi design -> **backend** (RTM) | operator gate + dba | CONTOUR — operator-confirm per apply |
| UI (ReportFilterBar/Table/SummaryTiles/pages/Builder), CSV, i18n, css | **shell** (spec from bi) | security + §4 | shell territory; bi gives spec |
| Aggregation BackgroundService | bi/**backend** | §4 | server-side, reads RTM tables read-only |
| Multitenant isolation, PG-filter, Viewer-cannot-create, IsPublic | — | **security** | review gate, no territory |
| Module documentation (user/admin guide) | **techwriter** | doc gate | after features land |
| Packaging, deploy scripts, Compare | **devops** | — | reuses lesson-complete Update-RTMView |
| §4-review every prompt, push barriers, claim arbitration | **coordinator** | — | me |

Sub-claims (no overlap): bi = `src/**/Historical/**`, `src/**/HistoricalReports/**`, `BackgroundServices/HistoricalAggregationService*`, `Components/Reports/**`, `Pages/Reports/**`, `hist_*`/`user_reports` migrations · shell = the Report .razor/.css it builds + `Reports.*` resx · dba = reviews migrations (file-claims at task time) · backend = `RTM/RTM/*.cs` for B2/B3.

---

## 2. PHASE 0 — Design finalization (NOW, in progress)
- [bi] Revise data model per B5 (external agent keys; drop ApplicationUser resolution for agents).
- [bi] Fold B1 (partitions-from-v1) + B2 (RTSData_* purge sub-track) + evaluate B3 (WT.UUID feasibility w/ backend).
- [bi] Author `tools/cc_prompt_hist_001.md` -> **[coordinator §4-review]** -> on PASS issue.
- [operator] Verdict on B3 (adopt WT.UUID now=v1, or defer=v2) after bi+backend feasibility.
- **Exit:** §4-blessed CC-HIST-001 prompt + B3 verdict.

## 3. PHASE 1 — v1 build (TZ Phase 1)
### Track A — CC-HIST-001 Data Layer  [bi authors · dba review · §4 · security]
- EF migration: `hist_queue_intervals` + `hist_agent_intervals` + `user_reports` — monthly RANGE partitions (B1=A, raw-SQL), TenantId + GQF, indexes.
- `HistoricalAggregationService` (BackgroundService) — read-only on RTSData_*/NGC_*; idempotent DELETE-window+INSERT; bucket by InQueueDateTime; agent agg = SUM(Duration) per StatusGroup; resolve Workgroup->NGC_Queues, agents=external id (B5); aggregated-through watermark.
- `IHistoricalReportRepository` + EF impl (AsNoTracking; pg_queues filter IN repo; NULLIF metrics).
- MediatR Q1/Q5/A4/A5 + DTOs + FluentValidation.
- >=6 unit tests (idempotency, NULLIF, unmatched->NULL+raw kept, bucketing, tenant isolation, SL threshold).
- **Gates:** dba (schema/partitions/indexes) · security (multitenant/PG-filter) · coordinator §4 · build+tests green.

### Track A2 — RT-tier purge (B2, CONTOUR)  [bi design · backend · OPERATOR-gated · dba]
- Windowed ~1mo purge/partitions ON RTSData_* (scheme i). Coordinate RTM Engine; ensure no MidnightClear collision (dead code Engine.cs:957).
- **Operator confirmation required before ANY apply to RTSData_*.** Mark every contour-touch.

### Track A3 — call-id/WTUUID linkage (B3, CONTOUR — IN, operator-gated)  [bi design · backend RTM · dba migration]
- The call-id does NOT exist yet in RTSData_UserStatusLog (verified schema.sql) — CREATE it: add a call-id column to RTSData_UserStatusLog + RTM Engine stamps the active call's id per status row; join UserStatusLog↔RTSData_Interaction on call-id+Workgroup → full per-call AHT (Talk+Hold+ACW).
- KEY feasibility (backend): the status feed (Engine.userStatusChanged / RTSData_SetUserStatus) carries NO call-id — Engine must reliably know the active call at status-change (risk on transfer/consult/messaging).
- Contour change, operator-gated per apply. v1 ships the read-only foundation (Track A); queue AHT upgrades to full once A3 lands.

### Track B — CC-HIST-002 UI Layer  [shell · bi spec · §4 · security]  (depends on Track A queries)
- `ReportFilterBar`, `ReportTable`, `ReportSummaryTiles` (Blazor; dark/RTL/a11y).
- Pages: Q1, Q5, A4, A5, `ReportsIndex` + NavMenu "Reports".
- CSV export (server C# + JS blob). i18n `Reports.*` (en-US/ru-RU[/he-IL]). `reports.css`. >=4 UI tests.
- **Gates:** security (authz/XSS) · coordinator §4.

### Track C — CC-HIST-003 User Reports  [bi + shell · §4 · security]  (depends on Track A repo)
- `UserReport` entity + EF config + repo + CQRS (Save/Delete/Get/Run).
- `ReportBuilder` 4-step wizard + `UserReportsList` + `CustomReportPage`.
- Seed 17 system reports (IsSystem=true) in DatabaseInitializer.
- **Gates:** security (Viewer-cannot-create, IsPublic, PG-filter enforced in Application layer) · §4.

## 4. PHASE 2 — Integration & verification
- All tracks build green; unit (>=6) + UI (4) + integration (aggregation idempotency, tenant isolation) + security tests.
- coordinator §4 per prompt; security review; **techwriter** module docs (user/admin guide).
- Acceptance: /reports renders; Q1/Q5/A4/A5 show data; builder saves/runs; CSV exports; aggregation populates hist_*; (B2) RT purge bounds RTSData_*.

## 5. PHASE 3 — Deploy prep & release  [devops · dba · coordinator · operator]
- [dba] Export DB module (Export-All) -> schema.sql + new migrations (hist_*/user_reports[/RTSData_* purge]).
- [devops] Package (lesson-complete Update-RTMView + new migrations) — all 4 today's fixes baked.
- **[MANDATORY] Compare-ToBaseline BEFORE deploy, per server** (today's headline norm — never by memory; each server its OWN -MigrationList).
- [coordinator/operator] Push barrier for the BI commits (+ the 6 already unpushed).
- Deploy per server (234, 45...): pg_dump backup -> E1 gate -> apply (postgres, ordered -MigrationList) -> binaries -> start -> Compare-after. Anti-saga discipline; any error -> STOP + rollback from backup.

## 6. PHASE 4 — Post-deploy verify
- Compare-after (drift closed); smoke (/reports + each report + builder + CSV); aggregation running; (B2) RTSData_* bounded.

---

## 7. Dependencies & gates (critical path)
Phase 0 (bi+§4) -> Track A (data layer) -> {Track B (UI), Track C (user reports)} in parallel -> Phase 2 (integ/verify) -> Phase 3 (deploy) -> Phase 4 (verify).
- Track A2 (RTSData_* purge) + A3 (WT.UUID) = CONTOUR, parallel but **operator-gated**; not on the v1 critical path unless B3 adopted for v1.
- Every code task: CC prompt -> §4 -> native CC -> commit (no push). Pushes only at the Phase-3 barrier.
- OPERATOR decision points: B3 adopt v1/v2 (Phase 0); each RTSData_* contour apply (A2); push barrier; deploy go per server.

## 8. Open risks
- AHT fidelity: v1 queue AHT = Talk-only unless B3 (WT.UUID) adopted -> label honestly in UI.
- Partitioning is net-new (audit pattern is doc-fiction) -> dba designs RANGE + create-ahead/drop-aged carefully.
- Identity match (B5): confirm RTM UserId vs external agent id population on 234/45 (empirical) before relying on agent keys.
- RTSData_* unbounded growth bounded ONLY by A2 (contour) — until applied, growth continues.
