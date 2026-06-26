# CC TASK — Scope BU-ONLY + queue widgets BU-AGGREGATED (operator architecture decision)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. Operator ruled: scope = BusinessUnit(s) ONLY (drop direct queue selection); MULTI-BU;
> queue-widget grain = BU-AGGREGATED + multi-BU POOLED (one row/interval, summed across all selected BUs' queues).
> LANDS TOGETHER with shell FIX-E (already §4-PASS) — the ConfigJson scope shape must agree. NO push (bundled barrier).
> Canonical scope shape (published, shell matches): {"scope":{"businessUnitIds":[<int>,...],"agentAxis":"detail"|"cumulative"}}

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C VERIFY) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short   # each M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode, all bi Application territory — no overlap with shell [web]):
- src/CcDashboard.Application/HistoricalReports/ReportWidgetConfig.cs
- src/CcDashboard.Application/HistoricalReports/Validators/ReportWidgetConfigValidator.cs
- src/CcDashboard.Infrastructure/Services/ReportWidgetScopeService.cs
- src/CcDashboard.Application/Handlers/RunReportWidgetQueryHandler.cs
- src/CcDashboard.Application/HistoricalReports/Queries/GetQueueIntervalReportQuery.cs + GetQueueWaitTimeReportQuery.cs (DTO Workgroup nullability — see EDIT 5)
- tests/CcDashboard.Tests.Unit/HistoricalReports/** (scope/aggregate tests)
- .claude/skills/role-bi/role-bi.md (§B)
BINDING PREAMBLE → .coord/cc/bi.md (status: open, directive ref).

## EDITS (verbatim before/after; object-store-anchored at HEAD 5d7da4f)

### EDIT 1 — ReportWidgetConfig.cs: ReportWidgetScope drop Mode + QueueIds
Replace the record (currently L96-111):
```csharp
public record ReportWidgetScope
{
    /// <summary>Business Unit IDs (NGC_BusinessUnit.BusinessUnitId int) — REQUIRED (scope is BU-only).</summary>
    public IReadOnlyList<int>? BusinessUnitIds { get; init; }

    /// <summary>Agent axis ("detail"|"cumulative") — required for agent widget types.</summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public AgentReportAxis? AgentAxis { get; init; }
}
```
(DROP `Mode` and `QueueIds` entirely.)

### EDIT 2 — ReportWidgetConfig.cs: DefaultColumns drop "Workgroup" from BOTH queue widgets (BU-aggregated → no per-queue column)
- QueueInterval (L69-73): `{ "IntervalStart", "Offered", "Answered", "Abandoned", "AnsweredInSl", "AbandonPct", "SlPct", "Asa", "QueueAht" }` (remove "Workgroup").
- QueueWaitTime (L74-77): `{ "IntervalStart", "Answered", "Asa", "AnsweredInSl", "SlPct" }` (remove "Workgroup").
(Agent + Distribution default columns UNCHANGED.)

### EDIT 3 — ReportWidgetConfigValidator.cs: BU-only rules
- REMOVE the Mode rule (`RuleFor(x => x.Scope.Mode)...` + the ValidModes set).
- REMOVE the QueueIds rule (`RuleFor(x => x.Scope.QueueIds)...`).
- CHANGE the BusinessUnitIds rule to ALWAYS required (drop the `.When(Mode=='bu')`):
  `RuleFor(x => x.Scope.BusinessUnitIds).NotEmpty().WithMessage("BusinessUnitIds required (scope is BU-only)");`
- In `ReportWidgetConfigWithTypeValidator`: drop `IsBuMode`/`IsQueuesMode` helpers; the AgentAxis rule becomes
  `Must(x => !IsAgentWidget(x.WidgetType) || x.Config.Scope.AgentAxis.HasValue)` (agent widgets ALWAYS need axis now);
  REMOVE the "Agent widgets do not support queues" rule (queues mode gone). Keep Title/Interval/PageSize/Columns(optional) rules.

### EDIT 4 — ReportWidgetScopeService.cs: ResolveRequestedWorkgroupsAsync always BU (drop the queues branch)
Replace ResolveRequestedWorkgroupsAsync (currently L115-135) body:
```csharp
private async Task<IReadOnlySet<string>> ResolveRequestedWorkgroupsAsync(
    Guid tenantId, ReportWidgetConfig config, CancellationToken ct)
{
    var buIds = config.Scope.BusinessUnitIds ?? Array.Empty<int>();
    return await buResolver.ResolveQueuesAsync(tenantId, buIds.ToList(), ReportScope.Full(), ct);
}
```
(Removes the Mode=="queues" branch + the direct beDb.NgcQueues lookup. Remove now-unused usings if any.)
**KEEP `ResolveQueueScopeAsync` itself** — it performs the SF-BI-001 PG-intersect + SF-BI-002 drop-log + empty-PG DENY, which BuMembershipResolver.ResolveQueuesAsync(ReportScope.Full()) does NOT (it's called with Full() so PG-intersect happens HERE). Deleting the method would lose SF-BI-001/002 enforcement → do NOT delete it; only its requested-workgroups source changes to BU. (This is the security-correct reading of "remove queue selection".)

### EDIT 5 — RunReportWidgetQueryHandler.cs: queue widgets BU-AGGREGATED (GROUP BY IntervalStart only, SUM, recompute)
**RunQueueIntervalAsync** — after `GetQueueIntervalsAsync(...)` returns per-Workgroup `intervals`, REPLACE the per-Workgroup `rows` projection (L84-98) with a GROUP-BY-IntervalStart aggregation:
```csharp
var rows = intervals
    .GroupBy(i => i.IntervalStart)
    .Select(g =>
    {
        var offered      = g.Sum(i => i.Offered);
        var answered     = g.Sum(i => i.Answered);
        var abandoned    = g.Sum(i => i.Abandoned);
        var answeredInSl = g.Sum(i => i.AnsweredInSl);
        var sumWait      = g.Sum(i => i.SumWaitAnswered);
        var sumTalk      = g.Sum(i => i.SumTalk);
        return new QueueIntervalRow(
            g.Key,
            null,                       // Workgroup: BU-aggregated, no single queue (column dropped from defaults)
            null,                       // QueueId: aggregated
            offered, answered, abandoned, answeredInSl, sumWait, sumTalk,
            offered  == 0 ? null : abandoned * 100.0 / offered,        // AbandonPct from SUMS
            answered == 0 ? null : answeredInSl * 100.0 / answered,    // SlPct
            answered == 0 ? null : (double)sumWait / answered,         // Asa
            answered == 0 ? null : (double)sumTalk / answered);        // QueueAht
    })
    .OrderBy(r => r.IntervalStart)
    .ToList();
```
**RunQueueWaitTimeAsync** — same GROUP-BY-IntervalStart aggregation; REPLACE the per-Workgroup `rows` (L125-133):
```csharp
var rows = intervals
    .GroupBy(i => i.IntervalStart)
    .Select(g =>
    {
        var answered     = g.Sum(i => i.Answered);
        var sumWait      = g.Sum(i => i.SumWaitAnswered);
        var answeredInSl = g.Sum(i => i.AnsweredInSl);
        return new QueueWaitTimeRow(
            g.Key, null, answered, sumWait,
            answered == 0 ? null : (double)sumWait / answered,        // Asa
            answeredInSl,
            answered == 0 ? null : answeredInSl * 100.0 / answered);  // SlPct
    })
    .OrderBy(r => r.IntervalStart)
    .ToList();
```
Recompute `OverallAsa` (QueueWaitTimeReportResult) from the summed totals over ALL rows: `totalAns = rows.Sum(Answered); overallAsa = totalAns==0 ? null : rows.Sum(r=>r.SumWaitAnswered)*1.0/totalAns` (or sum the raw intervals — keep the existing OverallAsa computation but over the aggregated set). Pagination + result envelope UNCHANGED.
**RunDistributionAsync** — UNCHANGED (BuildDistributionBuckets already pools all intervals; scope resolution already BU via EDIT 4). **Agent methods UNCHANGED** (operator #2).

### EDIT 5b — DTO nullability (GetQueueIntervalReportQuery.cs / GetQueueWaitTimeReportQuery.cs)
`QueueIntervalRow.Workgroup` and `QueueWaitTimeRow.Workgroup` change `string` → `string?` (BU-aggregated rows carry null). QueueId already `Guid?`. No other DTO field changes. (Shell FIX-E expects no Workgroup column in defaults — null is fine.)

## TESTS (update + add; tests/CcDashboard.Tests.Unit/HistoricalReports/)
- Validator: BU-only config (businessUnitIds set, no Mode/QueueIds) = VALID; missing businessUnitIds = INVALID; agent widget without agentAxis = INVALID. Remove Mode/QueueIds-based test cases.
- RunQueueIntervalAsync/WaitTime: given per-Workgroup hist rows across 2 queues of 1 BU in the same interval → ONE aggregated row/interval with SUMMED components + metrics recomputed from sums (e.g. SlPct uses summed AnsweredInSl/Answered, not averaged); Workgroup null. Multi-BU pooled (2 BUs → still one row/interval summed across all their queues).
- Scope: ResolveQueueScopeAsync still PG-intersects + drops out-of-PG (SF-BI-001/002) over the BU-resolved set; empty PG ⇒ Denied.

## ACCEPTANCE (DoD)
1. Build 0 (Soma /ops/build or dotnet build). 2. Unit tests GREEN (validator + BU-aggregate + scope). 3. ConfigJson scope shape = {businessUnitIds:[int],agentAxis} ONLY (no Mode/QueueIds) — matches shell FIX-E. 4. Queue widgets return BU-aggregated rows (one/interval, summed, metrics from sums, Workgroup null). 5. SF-BI-001/002 intact (ResolveQueueScopeAsync kept). 6. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native-CC edits; object-store-verify edited regions post-commit.
- commit.lock (retry 5×60s, phantom-safe) → `bash tools/pre-commit-check.sh` → git add (claimed files) → commit `feat: report scope BU-only + queue widgets BU-aggregated (multi-BU pooled, operator decision) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (commits/files/build/tests/object-store-verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · report-widget scope = BU-ONLY (businessUnitIds[] multi; Mode/QueueIds dropped); queue widgets BU-AGGREGATED (GROUP BY IntervalStart only, SUM components, recompute metrics from sums, Workgroup null) — operator decision "measure by BU", matches legacy GetCallDataByInterval GROUP-BY-interval. ResolveQueueScopeAsync KEPT (SF-BI-001/002 PG-intersect+drop-log live there; deleting loses enforcement). · SOURCE: operator ruling 2026-06-26 + GetCallDataByInterval RTM/H_RTM.sql L18270 · status: active`

## DO NOT
- Do NOT delete ResolveQueueScopeAsync (SF-BI-001/002 live there) — only its requested source changes to BU.
- Do NOT change agent methods / Distribution / Delete / aggregation service.
- Do NOT touch shell Components/Pages (shell FIX-E owns the client ConfigJson + UI).
- NO migration / NO push.

## COORDINATE / land-together
Shell FIX-E (already §4-PASS) must serialize the SAME ConfigJson scope shape (businessUnitIds:[int]+agentAxis, no Mode/QueueIds). Both land in the bundled barrier. Publish-and-confirm with shell before the joint run.
