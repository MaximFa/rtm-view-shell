# CC Task W3: roll MetricWizard into DataSlot + Agent Grid metric pickers

> Stage-2 wizard rollout to the remaining single-metric pickers. W2 already wired Queue Grid (button ->
> page-level <MetricWizard MetricTypeFilter="Data">). W3 does the same for the two other single-metric
> pickers in ScreenEditorPage.razor: DataSlot (Data) and Agent Grid columns (Agent).
> OUT OF SCOPE: DayTrend (multi-metric set with toggles/colours/labels) and ASD (auto status-group
> metrics) — different selection models, NOT a single-metric field; leave them untouched.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 hard-stop)
Read file: .claude/skills/widget-creator/widget-creator.md   (§16 dark mode, §18; W2 pattern is the template)
Only after reading: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): .coord/push/request.md has content -> STOP.

## Claims (file-mode, metrics-0605)
- web: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor  (EXCLUSIVE hold; most-contended
       file — checker FIRST; if any active session holds it, §9-queue. Release promptly after commit.)
       src/CcDashboard.Web/Components/Shared/MetricWizard.razor (mine; only if a tweak needed)
       SharedResources.{en-US,ru-RU,he-IL}.resx — only if a new label key is needed (reuse Common_SelectMetric
       like W2 did; if so, no resx change). Confirm hash==HEAD (false-M) before any resx edit.

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block (slug + claims).

## Reference — the W2 pattern (already in the file, copy it)
W2 added: a per-column metric BUTTON -> `OpenQueueMetricWizard(colId)`; page-level
`<MetricWizard Visible="_queueMetricWizardVisible" MetricTypeFilter="Data" CurrentMetricId=... DarkMode="_darkMode"
OnSelected="OnQueueMetricWizardSelected" OnCancel=.../>`; state `_queueMetricWizard*`; handlers Open/OnSelected.
Mirror this exactly for the two pickers below. You MAY instead refactor to ONE shared wizard instance with a
`_metricWizardTypeFilter` field + a generic open/callback if cleaner — but do NOT break the working Queue Grid wiring.

## Picker 1 — DataSlot (single metric)  → MetricTypeFilter="Data"
Location: `@if (IsDataSlotWidget(ConfiguringWidget))` block (~line 373-405), the searchable dropdown using
`ConfigDataSlotMetricId` + `DataSlotMetricSearchText` + `DataSlotMetricDropdownOpen`.
- Replace the input+dropdown with a button showing `GetMetricDescription(ConfigDataSlotMetricId)` (or
  `@L["Common_SelectMetric"]` placeholder when empty), `@onclick` opens the wizard with
  MetricTypeFilter="Data", CurrentMetricId=ConfigDataSlotMetricId.
- OnSelected sets `ConfigDataSlotMetricId = metricId;` (DataSlot has a single metric, no column Name to default).
- Leave `DataSlotMetricSearchText/DropdownOpen` plumbing only if used elsewhere; otherwise it becomes dead — fine.

## Picker 2 — Agent Grid columns  → MetricTypeFilter="Agent"
Location: `@if (ConfigActiveTab == "columns" && IsAgentGridWidget(ConfiguringWidget))` (~1559), per-column
picker (~1607-1635) using `_activeMetricDropdown` / `OpenMetricDropdown(colId,e)` / `SelectMetric(colId,id)` /
`GetFilteredMetrics()` over `ConfigAgentColumnDefs`.
- Replace the input+dropdown with a button -> open wizard with **MetricTypeFilter="Agent"**,
  CurrentMetricId=col.MetricId.
- OnSelected sets `col.MetricId = metricId; if (string.IsNullOrWhiteSpace(col.Name)) col.Name = GetMetricDescription(metricId);`
- Do NOT remove `SelectMetric/GetFilteredMetrics/_activeMetricDropdown` if still referenced elsewhere
  (shared-helper safety); if now unused for Agent Grid, leaving them is acceptable.

## Wizard instances
Add the needed page-level `<MetricWizard>` instance(s) (DataSlot: Data; Agent Grid: Agent) OR one shared
instance keyed by a `_metricWizardTypeFilter` field. Pass `DarkMode="_darkMode"`. The z-index fix (10050)
from 1898c88 already lets it render above the config modal.

## Build & manual verify
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean.
- Manual (report): DataSlot config -> metric button -> wizard opens (Data metrics only, on top) -> pick -> set.
  Agent Grid config -> Columns -> column metric button -> wizard opens (Agent metrics only) -> pick -> set + Name default.
  Queue Grid still works (regression check).

## Commit
`web: roll MetricWizard into DataSlot + Agent Grid metric pickers (W3)`
pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.

## Acceptance criteria
1. dotnet build clean.
2. DataSlot picker uses MetricWizard (MetricTypeFilter="Data"); Agent Grid columns use it (MetricTypeFilter="Agent", Agent metrics only).
3. Queue Grid wiring still works (no regression).
4. DayTrend + ASD metric selection UNCHANGED (out of scope).
5. Dark mode + on-top rendering work (z-index 10050 already in place).
6. One web: commit; tree clean (ignore known false-M); journal + S4b; lock released; no push. Release ScreenEditorPage after commit.
