# CC-HIST-F2.5 — report-widget -> query scope-wiring + ConfigJson validation (BACKEND)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3 (tip af41c68 — checkout by SHA, §0.5). §4-review (коорд: ревью) BEFORE run.
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-24T20:40Z). Design = single non-bypassable RunReportWidgetQuery entry (scope+validation server-side, SF-BI-001) — CORRECT + the canonical contract the frontend MUST call. All blocks present (integrity+branch-by-SHA af41c68, role-bi §A/§C+session-coord, sync slug bi-0619 file-mode, BINDING PRE/POST, commit.lock 5×60s, NO push); claim no-overlap with shell Components/ReportWidgets ✓. RUN FIRST (shell Ф4 depends on this entry). CLEARED TO RUN.
> Builds the SERVER run-path per Reports-Backend-v1-Spec §2/§3 (ConfigJson §2 LOCKED). Reuses the 4 landed queries +
> ReportScopeResolver + BuMembershipResolver (Ф2). Scope resolution is SERVER-SIDE, NEVER bypassable (SF-BI-001).

## STEP 0 — integrity + branch-by-SHA (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD   # expect af41c68 tip (verify object-store)
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — mandatory reads + §C VERIFY + sync block
Read: role-bi §A/§C + session-coord (§40/§0.8). Apply tools/cc_prompt_sync_block.md: slug=`bi-0619`, claims (file-mode, bi territory):
`src/CcDashboard.Application/HistoricalReports/**`, `src/CcDashboard.Infrastructure/Handlers/HistoricalReportHandlers.cs`,
`src/CcDashboard.Infrastructure/Services/*ReportWidget*` / scope wiring, `tests/CcDashboard.Tests.Unit/HistoricalReports/**`.
NO overlap with shell's `Components/ReportWidgets/**` (frontend) — touch ONLY Application/Infrastructure run-path + tests.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

---

## THE WORK (Reports-Backend-v1-Spec §2/§3)

### A. ConfigJson parse + server-side VALIDATION (FluentValidation)
Parse ConfigJson -> ReportWidgetConfig record (Application): { Title?, Scope{ Mode("queues"|"bu"), QueueIds?:int[],
BusinessUnitIds?:int[], AgentAxis?("detail"|"cumulative") }, Columns:string[], Thresholds, Interval?(30|60), PageSize?, Metric?, Appearance(opaque) }.
Validator: Mode in {queues,bu}; if bu -> BusinessUnitIds non-empty (+ AgentAxis required for agent widget types); if queues ->
QueueIds non-empty; Interval in {30,60} (QueueInterval only); PageSize in {25,50,100} default 25; Columns non-empty.
Title = persisted opaque (not validated beyond length). Appearance = IGNORED server-side. Invalid -> ValidationException.

### B. Scope chain (SERVER-SIDE, NON-BYPASSABLE — §3, SF-BI-001 preserved)
A ReportWidgetScopeService (Application) — inject ICurrentUserAccessor + IBuMembershipResolver + ReportScopeResolver:
1. Superadmin (Role) -> FullScope (no restriction).
2. Resolve REQUESTED set by widget axis + scope.Mode:
   - QUEUE widgets (QueueInterval/QueueWaitTime/Distribution): Mode=bu -> BuMembershipResolver.ResolveQueuesAsync(tenantId,
     BusinessUnitIds) ; Mode=queues -> the client QueueIds (as workgroup ext-ids). 
   - AGENT widgets (AgentMonthly/AgentShiftDetail): Mode=bu -> BuMembershipResolver.ResolveAgentsAsync(tenantId,
     BusinessUnitIds, AgentAxis) ; Mode=queues -> N/A (agent widgets are bu/agent-scoped; reject queues-mode for agent types).
3. INTERSECT with the PG-allowed set from ReportScopeResolver (queues vs agents): effective = requested ∩ PG-allowed.
   - out-of-PG entries (requested \ PG-allowed) DROPPED + LOGGED as a security event (userId, PG, dropped count+entries;
     aggregate, not error-spam) — this LANDS SF-BI-002 [LOW detective].
   - empty PG-allowed (non-Superadmin) -> DENY (PG-03): return empty result / Forbidden (match existing repo deny semantics).
4. Return effective Workgroups (queue) / AgentExternalIds (agent). Repo already filters IN unconditionally when !FullScope.

### C. ReportWidgetType -> query DISPATCH (reuse landed queries; no new agg/repo)
Given {WidgetType, effective scope set, From, To, PageSize}: DateRange inclusive-To = To.Date.AddDays(1) (F-QA-1, §2 table).
- QueueInterval    -> GetQueueIntervalReportQuery(From, ToExclusive, effectiveWorkgroups, PageSize, Page) (+Interval).
- QueueWaitTime    -> GetQueueWaitTimeReportQuery(From, ToExclusive, effectiveWorkgroups, PageSize, Page).
- AgentMonthly     -> GetAgentMonthlyReportQuery(From, ToExclusive, effectiveAgents, PageSize, Page).
- AgentShiftDetail -> GetAgentShiftDetailReportQuery(From, ToExclusive, effectiveAgents, PageSize, Page).
- Distribution     -> DERIVE from Q1/Q5 output (no new query): run the queue query, shape into distribution buckets by Metric.
Expose as a MediatR entry (e.g. RunReportWidgetQuery(WidgetType, ConfigJson, From, To) -> typed result per type / a tagged
union DTO) so the View calls ONE server entry per widget; scope+validation happen inside (frontend cannot bypass).

### D. Tests (unit, tests/CcDashboard.Tests.Unit/HistoricalReports/) — DoD GREEN
(1) scope: bu-queue -> ResolveQueues ∩ PG; bu-agent(detail/cumulative) -> ResolveAgents ∩ PG; queues-mode ∩ PG;
(2) out-of-PG entry dropped + a log emitted (SF-BI-002); (3) empty PG -> DENY; (4) Superadmin -> FullScope (no filter);
(5) ConfigJson validation: valid passes; bad Mode/Interval/PageSize/empty-BU/empty-Queues -> ValidationException;
(6) dispatch: each WidgetType -> correct query invoked with effective set; Distribution derives from Q1/Q5;
(7) DateRange inclusive-To (To.Date.AddDays(1)).

### ACCEPTANCE (DoD, functional)
- Soma self-build /ops/build = exit 0; /ops/test?suite=unit GREEN (new scope-chain + validation + dispatch tests incl SF-BI-002 drop-log + empty-PG deny + Superadmin bypass).
- serilog scan clean (no new errors). Scope resolution NON-bypassable (no code path lets a non-Superadmin skip the PG intersect).
- NO new aggregation/repo/migration (reuse landed). Reads-only on RTM contour.

## STEP 3 — binding POSTAMBLE RESULT -> .coord/cc/bi.md (commit, build/test, files). MUST state EXPLICITLY (shell Ф4 codes
## against it): the final RunReportWidgetQuery signature (params) + the RETURN shape (per-type result DTO / tagged-union) so
## the frontend binds its widgets to the canonical entry. STEP 4 — §0.6b CAPTURE role-bi §B if a lesson; cc_post_commit.sh + §0.6/PD-007 re-sync.
## COMMIT: feat: (Application/Infrastructure run-path), commit.lock (5x60s), object-store verify, NO push (§37, bundled barrier).
