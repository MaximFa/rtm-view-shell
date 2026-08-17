# CC task — WFM-3c-widget (shell): WFM widget + transport (read IWfmSnapshotStore -> browser) — AWAITING §4
> GOAL: render the WFM Phase-1 §4 snapshot for a (tenant, queue) on a dashboard/report widget, live.
> BACKEND IS DONE (chain @515c355): WfmRealtimeLoop (Infrastructure/Wfm/WfmRealtimeLoop.cs) computes a `WfmSnapshot` per (tenant, queue) and writes it to `IWfmSnapshotStore` (Infrastructure/Wfm/WfmSnapshotStore.cs — a thread-safe **Singleton**, in-proc). Read side: `IWfmSnapshotStore.Get(Guid tenantId, string queueId)` / `GetForTenant(tenantId)`.
> CONTRACT (Application/Wfm/WfmTypes.cs): `WfmSnapshot(Guid TenantId, string QueueId, DateTime AsOfUtc, int WindowMin, WfmInputs Inputs, WfmErlang Erlang, string State, IReadOnlyDictionary<string,string> Rag)`.
>   WfmInputs(double LambdaPerHour, double AhtSec, int NActual, bool WrapIncluded).
>   WfmErlang(double TrafficA, double? PWaitC, double? PredictedSlPct, double? PredictedAsaSec, int RequiredAgents, bool RequiredCapped, double ErlangBPct, double? OccupancyPct, double? UnderstaffPct, int StaffVariance).
>   State ∈ {WfmSnapshot.StateOk="ok", StateOverloaded="overloaded", StateNoData="nodata"}. Rag = per-metric band map (key = metric name, value e.g. "green"/"amber"/"red").
> TRANSPORT DECISION (flag in §4): this is a **Blazor Server** widget, so per CLAUDE.md §34.7 it INJECTS the Singleton `IWfmSnapshotStore` directly and reads on a server-side PeriodicTimer — the store write happens in-proc, the widget renders over the existing circuit. This is NOT localStorage of business data (§41-safe) and is the direct analog of "Blazor components inject the service directly" (RtmRelayHub is explicitly the JS/EXTERNAL-client path). NO new hub, NO localStorage. If an external/JS WFM client is later needed, add a hub method then. **Confirm this transport in §4 before running.**
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat(web):`. **NO push**.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # must be v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-21T13:08:24Z | spec: shell | directive: tools/cc_prompt_shell_wfm3c_widget.md | status: open
### DIRECTIVE (spec->CC): WFM-3c-widget — new WfmWidget.razor reads IWfmSnapshotStore Singleton on a timer, renders §4 contract (Inputs/Erlang/State/RAG); register in RenderWidget dispatcher + widget catalog. v3, feat(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web territory)
- src/CcDashboard.Web/Components/Widgets/WfmWidget.razor                        (NEW)
- src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor                   (add dispatch case)
- widget catalog registration for a "WFM" item  (LOCATE where AgentStateDistribution is seeded — DatabaseInitializer / widget-catalog seed — add one WFM catalog item, Category e.g. "General metrics" or "Queues", IsActive true)
- src/CcDashboard.Web/Resources/SharedResources.*.resx                          (new UI-string keys en-US + ru-RU)

## THE WORK
### 1. WfmWidget.razor (NEW) — follow the AgentStateDistributionWidget conventions
- `@implements IAsyncDisposable`; `@inject IStringLocalizer<CcDashboard.Web.Resources.SharedResources> L`; `@inject IWfmSnapshotStore WfmStore`; `@inject ICurrentUserAccessor CurrentUser` (tenant). (No IJSRuntime needed unless you add a chart — v1 is a table/tiles, keep it simple.)
- Params: `[Parameter] public WidgetConfig? Config`, `[Parameter] public bool DarkMode`, (optional `[Parameter] public int GridId`). Mirror the param signature the dispatcher passes (see step 2).
- **Scope resolution:** tenantId = CurrentUser.TenantId; queueId (string, the RTM external queue id) = read from `Config` the SAME way the grid widgets read their queue scope (locate the queue-scope field in WidgetConfig; if the config carries a queue id/external id, use it). If no queue is configured -> render the "configure me" placeholder (mirror AgentStateDistribution's `Widget_SaveConfigFirst` empty-state).
- **Refresh loop:** on init, start a `PeriodicTimer(TimeSpan.FromSeconds(5))` background loop that calls `WfmStore.Get(tenantId, queueId)` and, if the snapshot's `AsOfUtc` changed, `await InvokeAsync(StateHasChanged)`. Cancel the timer + CTS in `DisposeAsync`. (Poll cadence 5s; the loop writes at the WFM cadence — reading a fresh in-proc Singleton is cheap.)
- **Render the §4 contract** (all labels via `L`, NO hardcoded strings; CSS logical properties; honor DarkMode + appearance style like other widgets):
  - **State badge** at top: ok -> green/normal, overloaded -> red ("System overloaded — N ≤ A"), nodata -> grey ("Waiting for data"). When overloaded/nodata, show the message and SUPPRESS the numeric Erlang rows that are undefined (PredictedSl/Asa/Occupancy may be null) — render "—" for any null, never a raw 0 that reads as real.
  - **Inputs** block: λ/hr (LambdaPerHour), AHT (AhtSec, mm:ss or s), N actual (NActual), Wrap included (WrapIncluded yes/no).
  - **Erlang** block: Traffic A (Erlangs), P(wait) (PWaitC as %), Predicted SL% (PredictedSlPct), Predicted ASA (PredictedAsaSec, s), Required agents (RequiredAgents; if RequiredCapped append a "capped" marker), Erlang-B % (ErlangBPct), Occupancy % (OccupancyPct), Understaff % (UnderstaffPct), Staff variance (StaffVariance, signed).
  - **RAG coloring:** for each metric that has a key in `Rag`, apply the band color (green/amber/red) to that metric's value cell/tile. Map band->CSS class; unknown/missing key -> neutral. Keep it accessible (not color-only: add a small text/aria hint of the band).
  - Footer: a live dot + `AsOfUtc` (converted to the user's local time in the UI layer, §I18N-04) + WindowMin ("30-min window").
- Nullable doubles: format null as "—".
- **PERCENTAGE SCALING — PINNED (coordinator §4 condition, verified @515c355 in WfmRealtimeLoop.cs):** the loop ALREADY scales the `*Pct` fields to 0..100 — PredictedSlPct (line 147 `* 100.0`), ErlangBPct (line 137/151 `* 100.0`), OccupancyPct + UnderstaffPct (from calculator `OccupancyPct()/UnderstaffPct()` which return 0..100; PROVEN by ComputeRag comparing against 50/85/95). => the widget renders ALL FOUR `*Pct` AS-IS with a "%" suffix and MUST NOT ×100 again (a double-scaled 80% -> 8000% is the classic bug). **PWaitC IS DIFFERENT:** it is the raw Erlang-C P(wait) FRACTION 0..1 (line 146, no `*100`, no "Pct" in the name) -> the widget ×100 for a "%" display (or show as a 0..1 probability — pick %, ×100). PredictedAsaSec = seconds; StaffVariance = signed int (agents); TrafficA = Erlangs. The RESULT must restate this pin (Pct fields as-is, PWaitC ×100).
- §41: NO localStorage of any business data. (Per-user UI prefs, if any, would need userId in the key — but v1 needs none.)

### 2. RenderWidget.razor — add a dispatch case
Add before the `default:` case, matching the existing string-contains style:
```
case var n when n.Contains("wfm") || (n.Contains("workforce")):
    <WfmWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" DarkMode="DarkMode" />
    break;
```
(Match the exact param names the other cases use; if WfmWidget doesn't need GridId, drop it.)

### 3. Widget catalog — add one WFM item
Locate the seed that registers catalog items (where "Agent Status"/"Queue Summary"/AgentStateDistribution live — DatabaseInitializer or a data seed). Add ONE active WFM catalog item so it appears in the widget picker: Name e.g. "WFM Forecast" (OriginalWidgetName must contain "wfm" so the dispatcher matches), Category e.g. "General metrics", IsActive=true, a Description + icon consistent with siblings. Idempotent (guard on existing by name, like the other seeds).

### 4. Do NOT touch: the store, the loop, WfmTypes, TenantSettings (config is the separate 3c-config task).

## VERIFY / DoD
- Object-store: WfmWidget.razor exists (injects IWfmSnapshotStore + ICurrentUserAccessor; PeriodicTimer poll; DisposeAsync cancels; renders Inputs+Erlang+State+RAG with null->"—" and overloaded/nodata handling; strings via L; dark mode + logical props); RenderWidget has the wfm case; catalog seed has one active wfm item; new .resx keys (en+ru).
- Soma (host-Chrome): POST /ops/build -> 0; POST /ops/test?suite=unit -> failed 0. If Soma down: build-evidence-pending (route devops), do NOT claim build0 without evidence.
- **LIVE (coord/operator, may defer):** place the WFM widget on a screen scoped to a queue that the WFM loop is producing -> it shows the §4 numbers, State=ok with real λ/AHT/N, RAG colors, AsOfUtc ticks each window; overloaded/nodata render their messages, not raw zeros. Percentage fields not double-scaled.

## COMMIT
- `bash tools/pre-commit-check.sh` -> commit.lock -> stage ONLY claimed files -> `feat(web): WFM-3c-widget — WfmWidget renders §4 snapshot from IWfmSnapshotStore + dispatch + catalog [shell-0609]` -> post-commit verify (§0.6) -> journal append -> release lock -> **NO push** -> §0.7 re-sync.

## §0.6b CAPTURE -> role-shell §B
"WFM real-time delivery to a Blazor Server widget = inject the in-proc Singleton IWfmSnapshotStore + poll it on a server-side PeriodicTimer, rendering over the circuit — NOT a new SignalR hub and NOT localStorage (§41). Per §34.7 Blazor widgets inject the service directly; the RtmRelayHub is the JS/external-client path only. Snapshot has undefined-metric sentinels (State overloaded/nodata + nullable doubles) — render null as '—' and suppress numerics on overloaded/nodata so a raw 0 never reads as a real value." SOURCE:WfmTypes.cs + WfmSnapshotStore.cs + RtmRelayHub.cs(docstring) + CLAUDE.md §34.7 @515c355.

## §0.6b BINDING POSTAMBLE — append RESULT to .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files WfmWidget.razor(new) + RenderWidget.razor + <catalog-seed>.cs + SharedResources.resx . status done|failed . blockers . verified: object-store
```
