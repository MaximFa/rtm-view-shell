# CC Task W2: wire MetricWizard into Queue Grid column metric picker (PILOT)

> Stage-2 wizard rollout, pilot. Replace the Queue Grid columns' per-column searchable metric dropdown
> with a "Select metric…" button that opens the W1 MetricWizard (MetricTypeFilter="Data"). Pilot scope:
> Queue Grid ONLY. Agent Grid and DataSlot pickers are NOT touched in W2 (that is W3).

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 barrier hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Read file: .claude/skills/widget-creator/widget-creator.md   (§16 dark mode, §30/L-36 draggable, L-34 localization)
Only after reading all three: proceed.

## Git push: NONE (§37). Commit only.

## BARRIER CHECK (S1) — content-based hard-stop
If `.coord/push/request.md` has content, STOP and report "barrier active". (Empty/phantom = proceed.)

## Claims (file-mode, metrics-0605)
- web: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
       src/CcDashboard.Web/Components/Shared/MetricWizard.razor   (may need a minor parameter tweak)
       src/CcDashboard.Web/Resources/SharedResources.en-US.resx (+ ru-RU, he-IL) — SHARED; confirm
       hash==HEAD (false-M) before editing, add keys ADDITIVELY; §9-queue if another session claims them.
> ScreenEditorPage.razor is large and shared — run coord_check_claims on it FIRST; if any active session
> holds it, §9-queue before claiming. Do NOT touch Agent Grid / DataSlot metric pickers or any
> daytrend-claimed file.

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block
git fetch; verify HEAD==origin/v2; restore truncated working files (hash-check, known false-M on
db/*.sql + large .cs). Then the sync block from tools/cc_prompt_sync_block.md (slug + all claims incl 3 resx).

## Target — the EXACT block to change
In `ScreenEditorPage.razor`, the Queue Grid columns tab:
`@if (ConfigActiveTab == "queuecolumns" && IsQueueGridWidget(ConfiguringWidget))` (~line 1965+),
the per-column metric picker that uses `_activeQueueMetricDropdown` / `_queueColumnMetricSearch`
(~line 2021), iterating `ConfigQueueGridColumnDefs`.
> Confirm by inspection: it is under the "columns (QM / Agent Group metrics)" header and the
> `queuecolumns` tab. The OTHER metric picker (~line 1614, `_activeMetricDropdown` / `SelectMetric`,
> under `ConfigAgentColumnDefs`) is Agent Grid — DO NOT touch it.

## What to build
1. Replace the Queue Grid column's searchable metric dropdown with a button per column:
   `<button class="form-control form-control-sm text-start" @onclick="() => OpenMetricWizard(colId)">`
   showing `GetMetricDescription(col.MetricId)` (the human label) or a "Select metric…" placeholder
   when empty. Keep the column Name input and the rest of the row as-is.
2. Add ONE page-level `<MetricWizard>` instance (render near the config modal):
   ```razor
   <MetricWizard Visible="_metricWizardVisible"
                 MetricTypeFilter="Data"
                 CurrentMetricId="_metricWizardCurrentId"
                 DarkMode="_darkMode"
                 OnSelected="OnMetricWizardSelected"
                 OnCancel="() => _metricWizardVisible = false" />
   ```
3. C# state + handlers:
   ```csharp
   private bool _metricWizardVisible;
   private string? _metricWizardColId;
   private string? _metricWizardCurrentId;
   private void OpenMetricWizard(string colId) {
       var col = ConfigQueueGridColumnDefs.FirstOrDefault(c => c.Id == colId);
       _metricWizardColId = colId; _metricWizardCurrentId = col?.MetricId;
       _metricWizardVisible = true;
   }
   private void OnMetricWizardSelected(string metricId) {
       var col = ConfigQueueGridColumnDefs.FirstOrDefault(c => c.Id == _metricWizardColId);
       if (col != null) {
           col.MetricId = metricId;
           if (string.IsNullOrWhiteSpace(col.Name))
               col.Name = GetMetricDescription(metricId);   // default column name to the metric label
       }
       _metricWizardVisible = false;
       StateHasChanged();
   }
   ```
4. `@using CcDashboard.Web.Components.Shared` if not already imported (or fully-qualify the component).
5. Pass the page's existing dark-mode flag (find the real field name; CC used `_darkMode` elsewhere — confirm).
6. Localization (L-34): if you add a visible string (e.g. "Select metric…"), use `@L["Widget_SelectMetric"]`
   (reuse if it exists, else add to all 3 resx, additively, exact key match; run the comm -23 verify).
7. Leave `GetFilteredMetrics`/`SelectMetric`/`_activeQueueMetricDropdown` plumbing in place IF still used by
   another picker; otherwise it may become dead for Queue Grid — do not delete shared helpers used elsewhere.

## Build & manual verify
- Stop dotnet (§28) → `dotnet build CcDashboard.sln` clean.
- Manual (describe in report; cannot automate UI): open a Queue Grid widget config → Columns tab →
  click a column's metric button → wizard opens showing ONLY Data metrics → search/facet → pick →
  column shows the DisplayName, col.MetricId set. Dark-mode + draggable confirmed (W1 behaviour).

## Commit
`web: wire MetricWizard into Queue Grid column metric picker (W2 pilot)`
pre-commit-check → §0.6 verify → journal → S4b post-commit flush to coordinator → release lock → PD-007 re-sync. No push.

## Acceptance criteria
1. `dotnet build CcDashboard.sln` clean.
2. Queue Grid columns tab uses the MetricWizard (button → modal), MetricTypeFilter="Data" (no Agent metrics shown).
3. Selecting a metric sets col.MetricId and shows its DisplayName; empty column shows placeholder.
4. Agent Grid + DataSlot metric pickers UNCHANGED; no other widget touched.
5. L-34 passes if any key added; dark-mode + draggable work.
6. One web: commit; tree clean (ignore known false-M); journal + S4b; lock released; no push.
