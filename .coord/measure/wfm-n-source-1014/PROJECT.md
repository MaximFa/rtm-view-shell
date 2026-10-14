# Wfm N from engine metrics (source A) — design, no code

Snapped 2026-10-14T08:30:17Z by backend-0919, on the directive of coordinator-0924 at 08:25:26Z.
Everything below is read from the **v4 branch** (`git show v4:<path>`), not from v3 and not from
memory. Line numbers are v4's.

## 0. What the directive settles and what it leaves open

Settled by metrics-1014: the database has no current agent state. `RTSData_UserStatus` accumulates
rows per date and the log writes a status only once it ends, which is why N came out 38 against 25
logged-in agents. Source A it is: N per BU = sum of the current `UsersInStatusGroupCount_<group>`
values over the tenant's serving groups, from the same engine metrics ASD shows.

Left open and answered here: how the server-side loop reaches those values, what the BU → grid →
cells mapping is, and what happens when a group's metric is missing. λ scope is the operator's
question and is not touched.

## 1. How the loop gets the values

**Finding that decides it: the relay already keeps the last snapshot per grid, and hands it to a
late subscriber immediately.**

- `RtmRelayService` holds `ConcurrentDictionary<(Guid TenantId, int GridId), GridState>` (:30), and
  `GridState.CellSnapshot` is `Dictionary<int CellId, (string Value, string? Value2)>` (:833),
  filled on every hub push (:795).
- On `SubscribeGridAsync`, when a connection already exists and the snapshot is non-empty, the
  service delivers the whole snapshot to the new handler at once (:561-570, log line "delivering
  snapshot of {Count} cells to late subscriber").

So the loop does **not** need a new interface method and does **not** need to wait for the engine's
next push: it subscribes through the existing `IRtmRelayService.SubscribeGridAsync`
(`IRtsRelayService` contract at `src/CcDashboard.Application/Interfaces/IRtmRelayService.cs`) and is
served the current cells on subscribe. Reading `CellSnapshot` directly would mean widening the
interface and reaching into another component's private state; subscribing uses the path ASD already
uses and that is known to work in production.

Shape, per tenant, inside the existing 30-second tick:

1. resolve the BU set as today (`GetActiveBusAsync`);
2. for each BU resolve its grid (section 2) and subscribe once, keeping the subscription alive
   across ticks — not subscribe/unsubscribe per tick, which would churn hub connections and defeat
   the ref-counting in `GridState.RefCount`;
3. keep the latest cell values per (BU, MetricId) in the loop's own small map, updated by the
   handler;
4. at tick time read that map, sum the serving groups, write N into the snapshot store.

The subscription outliving the tick is the point: the handler fires when the engine pushes, the tick
only reads. That also means N is as fresh as the engine's push, not as fresh as our tick.

## 2. BU → grid → cells, without ASD on screen

This is the part the directive asked about, and it resolves without the widget's configuration:

- **BU → grid.** `RTSGrid_Grid.UnionId` **is** the BusinessUnitId. Not an inference — the code says
  so in three places: `SaveAgentGridRtsCommand.cs:97` (`UnionId = cmd.BusinessUnitId`),
  `RtsRepository.cs:66` (`grid.UnionId = businessUnitId`), and the comment at
  `SaveDataSlotRtsCommand.cs:59` ("Row (RowNumber=1, UnionId=BusinessUnitId)"). So the loop finds the
  grid by `UnionId = <BU>`, with no widget involved.
- **grid → cells → metric names.** `GetCellMapForGridAsync` (`RtsRepository.cs:305`) returns
  CellId → MetricId by joining `RTSGrid_Cell` to `RTSGrid_Row` on `GridId`. The metric id lives in
  the **cell row itself**, in the database — not in the widget config.
- **which metric is which group.** The ids carry the group in the name:
  `UsersInStatusGroupCount_<Group>` (ASD comments it at :633). The loop therefore selects the cells
  whose MetricId starts with that prefix and reads the group from the suffix.

**What the widget config holds, and why we must not depend on it.** ASD takes its group → metric map
from `Config.GroupColumnMetricIds` (:603) and `Config.StateColumnMetricIds` (:658), "resolved at save
time". That map exists only where an operator configured a screen. Deriving the same mapping from the
cell rows plus the metric-name prefix keeps the loop independent of whether any dashboard was ever
built — which is exactly the condition the directive put ("if there is no ASD on screen for this BU").

## 3. Missing metric: N is unknown, not zero

Three distinct absences, and all three must read as **unknown**, never as 0:

| what is missing | how it is detected | result |
|---|---|---|
| no grid for the BU | no row with `UnionId = <BU>` | N unknown for that BU |
| grid exists, no cell for a serving group | the group's MetricId absent from the cell map | N unknown |
| cell exists, no value in the snapshot yet | key absent from the snapshot map | N unknown |

"Unknown" has to be a separate state in the snapshot store, not `0` and not `-1`: a sentinel number
is the same defect as the zero, one step later. ASD already draws this distinction and names it —
"Value of the connected-agents metric, or **null** when its cell is absent from the snapshot.
ContainsKey is what separates 'absent' from 'present and zero'" (:727 area). Wfm must follow the
same rule, and the Erlang step must treat unknown N as "no result for this BU this tick" rather than
computing with a substituted number. That matches the operator's standing rule: on any division by
zero, show empty, and log the anomaly explicitly.

**Partial sums are also unknown.** If three serving groups are configured and only two have cells,
the sum of two is not N. One missing group makes N unknown for that BU, and the log must name which
group was missing.

## 4. The question I cannot answer by measurement — group names

The setting holds group names (`TenantSettings.WfmServingStateGroups`); the metric ids hold a suffix
(`UsersInStatusGroupCount_Available`). Matching them needs a rule, and the data gives two candidates
that disagree:

- the StatusGroup values in the live data are UPPER CASE ("AVAILABLE") — that is the 13.10 finding;
- the metric suffix as it appears in ASD's own comment is Pascal/mixed ("_Available").

So an exact match on the configured string will fail on the very tenant this ticket came from, and a
case-insensitive match contradicts the exactness used everywhere else in this pipeline. **I am not
choosing.** Options, for the coordinator or the operator:

1. the operator picks serving groups from a list built from the **metric suffixes** present in the
   tenant's grid — then the stored value matches the metric by construction, and this also disposes of
   the casing problem for good. This is the same "pick from a list" the operator already chose on
   13.10 for the serving-groups setting;
2. match case-insensitively at this one seam, documented as a deliberate exception;
3. store a mapping table group → MetricId per tenant.

My recommendation is (1), because it removes the mismatch instead of tolerating it, and the operator
has already approved that shape once. But it changes the settings UI, which is shell's territory and
not mine to decide.

## 5. What gets removed, and what happens to the N=0 Warning

- The `RTSData_UserStatus` count query in `GetServingAgentCountsAsync`
  (`WfmInputQueryService.cs:240-245`) and its twin in `GetBuServingAgentCountAsync` (:282-287) both
  go: they answer a question the data cannot answer, which is what metrics-1014 proved.
- With them, the whole §36a roster resolution for this purpose becomes dead weight for N — BU → SG →
  AG → user existed only to build `agentList`. It must **not** be deleted blindly: the same chain may
  be used elsewhere. Scope check before removal, named, not assumed.
- The N=0 Warning changes subject. Under source A there is no "roster with nobody serving"; there is
  "metric present and zero" (legitimate, quiet) and "metric absent" (unknown, and worth a Warning
  naming the BU and the missing group). The fragment delivered today
  (`.coord/measure/wfm-n0-warning-1014/`, blobs `cac53467` / `ab4347ad`) becomes obsolete the moment
  source A lands — its tests pin a query that will no longer exist. I am not deleting it; say whether
  it still goes into this leg or is dropped.

## 6. Tests, both halves

Against the loop's own mapping and summing, with the relay substituted:

1. two serving groups with values 3 and 4 → N = 7; **negative half:** the same two groups where one
   cell is absent → N unknown, not 3, and the log names the missing group;
2. metric present with value 0 → N = 0 and **no** Warning (zero is a fact); **negative half:** metric
   absent → unknown and a Warning;
3. no grid for the BU → unknown; **negative half:** grid exists for a different BU only → still
   unknown for ours, which guards the `UnionId` lookup against matching the wrong union;
4. a cell whose MetricId does not start with the prefix → ignored; **negative half:** a cell that does
   start with it but names a group that is not configured → also ignored, so N counts configured
   groups only;
5. two BUs in one tenant, different values → each BU gets its own N, no bleed. Guards the per-BU
   keying, which is where the 13.10 BU-key defect already bit once.

**Cross-check the directive asked for — "N = sum of ASD's groups on the same BU in the same tick":**
it cannot be done as a unit test, because ASD reads the same snapshot through its own config map. The
honest form is a live comparison on the stand: put an ASD for a BU on a screen, read its segment
values and the N the loop wrote for the same BU within one tick, and compare. That needs the stand
and the operator's eye, so I name it as a stand check, not as a test I can deliver green.

## 7. Risk I found while measuring, outside this leg

`GetCellMapForGridAsync` (`RtsRepository.cs:305`) filters by `GridId` only — there is no TenantId in
that query or its parameters. The cell map of any grid is readable by id. For the loop it is harmless
(we resolve the grid from the tenant's own BU), but as a query available through MediatR
(`GetRtsGridCellMapQuery`) it is a cross-tenant read by id, in the same family as the handler gate
closed earlier today. Named here, not fixed, and not part of this design.

— backend-0919
