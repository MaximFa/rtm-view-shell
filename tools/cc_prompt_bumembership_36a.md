# CC task — BuMembershipResolver.ResolveAgents §36a: DETAIL axis must use SG-intersection (not flat OR) — AWAITING §4
> Owner: backend (backend-0626). Branch **v3**. Commit `fix(infra):`. **NO push** (§37). ⛔ЧП. Batches with the Shell rebuild.
> §4 DIRECTION already BLESSED (coordinator 16:18). Author → §4 bless before run.

## ROOT (object-store @ v3)
`src/CcDashboard.Infrastructure/Services/BuMembershipResolver.cs` `ResolveAgents` resolves a BU's agents in two axis branches:
- **CUMULATIVE (:123-156)** = ALREADY §36a: group SG→AG by SupergroupId (:129-133), per SG INTERSECT its AGs' member sets (:140-149 `sgAgentSet.IntersectWith`), UNION across SGs (:151-152). Correct SG=AND / BU=OR.
- **DETAIL (:117-122)** = the BUG: `agentSet = new HashSet(agMembershipList.Select(UserId))` = flat UNION of ALL agents across ALL AGs of ALL SGs = OR/superset. For BU DE All → agents in ANY of {Accounting,DE,Support,Retail,EV} = the over-broad pool.
The agent SET must be §36a (SG=AND, BU=OR) REGARDLESS of axis — the Detail/Cumulative axis governs METRIC aggregation, NOT which agents belong to the BU. So DETAIL's flat-OR is the §36a violation (CLAUDE.md §36a [AGENT-RES-01/03]).

## SCOPE NOTE (confirm #1 — important): `ResolveAgents` feeds HISTORICAL REPORTS ONLY
Callers: `ReportWidgetScopeService.cs:129` → `RunReportWidgetQueryHandler.cs:196/272` (report agent-scope, axis default Detail). It does NOT feed the LIVE AgentGrid (that is RTM-fed via updateUserGrid; RTM's UserManager.refreshUnions is already §36a-compliant). So this fix corrects the REPORTS agent-scope; the live AgentGrid 12-blank-cells is a SEPARATE issue (traced separately). Do NOT touch RTM/AgentGrid here.

## FIX — DETAIL uses the same §36a set as CUMULATIVE (agent set is §36a for both axes)
In `ResolveAgents`, make the agent-SET resolution §36a UNCONDITIONALLY (both axes). Extract the §36a computation (currently the CUMULATIVE body :125-153) into a small local and use it for both; the DETAIL flat-union (:117-122) is REMOVED. Concretely:
```csharp
// §36a [AGENT-RES-01]: BU agents = ∪ over SGs ( ∩ over the SG's AGs of the AG members ). Axis does NOT change the SET.
var sgToAgs = sgAgMappings
    .GroupBy(m => m.SupergroupId!.Value)
    .ToDictionary(g => g.Key, g => g.Select(m => m.AgentgroupId!).Distinct().ToList());

var agentSet = new HashSet<string>();
foreach (var (sgId, agsInSg) in sgToAgs)
{
    if (agsInSg.Count == 0) continue;
    HashSet<string>? sgAgentSet = null;
    foreach (var agId in agsInSg)
    {
        if (!agMembers.TryGetValue(agId, out var agSet)) continue;
        if (sgAgentSet == null) sgAgentSet = new HashSet<string>(agSet);   // first AG
        else sgAgentSet.IntersectWith(agSet);                              // AND the rest
    }
    if (sgAgentSet != null) agentSet.UnionWith(sgAgentSet);               // OR across SGs
}
```
- Replace the `if (axis == Detail) {flat union} else {…}` block (:115-156) with the single §36a computation above (drop the axis branch for the SET). Keep the `axis` parameter (used elsewhere for metric shaping) — only the agent-SET stops depending on it.
- Keep the PG-intersection (:158-162) + return UNCHANGED. 1:1-safe: a single-AG SG → sgAgentSet = that AG's members (no over/under).

## Mandatory reads (§40/§0.8): session-coord; role-backend §A(⛔ЧП)+§C; CLAUDE.md §36a; object-store BuMembershipResolver.cs (ResolveAgents full) + IBuMembershipResolver (axis) + the callers.
## INIT (§0.6a): HEAD==v3 (SHA); hash-verify claim vs HEAD; §0.3 Python+fsync; Edit BANNED. Claim=["src/CcDashboard.Infrastructure/Services/BuMembershipResolver.cs","tests/CcDashboard.Tests.Unit/HistoricalReports/BuMembershipResolverTests.cs","CLAUDE.md"]. NARROW-ADD; commit.lock; §0.6/§0.7; NO push.
## STEP 1 binding PREAMBLE (.coord/cc/backend.md).
## STEP 2 apply the fix. STEP 3 CLAUDE.md §36a[03] refine (docs): add a line that the RTM engine (UserManager.refreshUnions/ContainsAllItems) is §36a-COMPLIANT; the resolver fixed here is BuMembershipResolver.ResolveAgents (DETAIL axis flat-OR → §36a); the live AgentGrid row-source is RTM (separate). 
## STEP 4 TEST — extend `tests/CcDashboard.Tests.Unit/HistoricalReports/BuMembershipResolverTests.cs` (§36a lock): (a) multi-AG SG (AG X AND AG Y) → only agents in BOTH; (b) BU with 2 SGs → UNION of the two intersections; (c) 1:1 SG:AG → the AG's members; (d) DETAIL axis now == CUMULATIVE for the SET. Model on the existing tests in that file.
## STEP 5 VERIFY: dotnet build 0; dotnet test tests/CcDashboard.Tests.Unit → failed=0 incl new §36a tests (PASTE); object-store only the 3 claimed files, zero deletions.
## STEP 6 commit `fix(infra): BuMembershipResolver.ResolveAgents §36a - DETAIL axis SG-intersection not flat-OR (report agent-scope) + §36a[03] doc [backend]`, commit.lock, cc_post_commit, NO push. STEP 7 binding RESULT.
## ACCEPTANCE: ResolveAgents returns the §36a set for BOTH axes (∪_SG ∩_AG); DETAIL no longer OR-superset; PG-intersection unchanged; 1:1-safe. §36a[03] doc refined. build0 + unit0 incl §36a tests. 3 files, zero deletions, fix(infra) v3, NO push. (Report notes: this NARROWS report agent-scope from OR to §36a — a correct narrowing; flag operator if any report visibly changes. The live AgentGrid blank-cells = separate trace.)
