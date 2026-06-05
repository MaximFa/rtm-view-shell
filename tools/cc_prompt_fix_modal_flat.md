# CC Task: Fix DayTrend modal — restore CSS + revert to flat structure (no tabs)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Problem

`DayTrendWidget.razor.css` is truncated in the working tree (PD-007) —
`justify-content: center;` is missing. Modal falls into normal flow and squeezes widget.
Additionally, the tab structure (from previous commit) is unwanted — revert to flat modal.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\\Claude\\Projects\\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f (HEAD=$H, wt=$W) — restoring"
        git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Fix 1 — Restore `DayTrendWidget.razor.css` from HEAD

```bash
git show HEAD:"src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css" \
  > "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css"
sync
tail -3 "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css"
# Must end with: }
```

---

## Fix 2 — Revert modal body to flat structure in `DayTrendWidget.razor`

Find the entire `<div class="modal-body ...">...</div>` block (the one with tab nav and tab-content)
and replace with the flat version below. Also remove `_viewTab` field from @code.

### Remove this field from @code:
```csharp
private string _viewTab = "general";  // "general" | "queue" | "agent"
```

### Remove the `_viewTab = "general";` line from `OpenLocalConfigAsync()`.

### Replace modal-body with flat version:

```razor
<div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
    <!-- BU selector -->
    <div class="mb-3">
        <label class="form-label fw-semibold">@L["Widgets_BusinessUnit"]</label>
        <select class="form-select form-select-sm" @bind="_localBuId">
            <option value="0">— @L["Widget_UseDefault"] —</option>
            @foreach (var bu in _viewBuList)
            {
                <option value="@bu.BusinessUnitId">@bu.BusinessUnitName</option>
            }
        </select>
    </div>

    <!-- Chart type -->
    <div class="mb-3">
        <label class="form-label fw-semibold">@L["DayTrend_ChartType"]</label>
        <select class="form-select form-select-sm" @bind="_viewChartType">
            <option value="line">@L["DayTrend_ChartLine"]</option>
            <option value="bar">@L["DayTrend_ChartBar"]</option>
            <option value="area">@L["DayTrend_ChartArea"]</option>
            <option value="step">@L["DayTrend_ChartStep"]</option>
        </select>
    </div>

    <!-- Interaction metrics -->
    <div class="mb-2 fw-semibold small">@L["DayTrend_InteractionMetrics"]</div>
    @foreach (var m in _metrics)
    {
        var metric = m;
        <div class="form-check form-check-sm mb-1">
            <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                   checked="@metric.Enabled"
                   @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
            <label class="form-check-label small" for="vm_@metric.MetricId">
                @GetDisplayLabel(metric)
            </label>
        </div>
    }

    <!-- Agent metrics -->
    @if (_agentMetrics.Any())
    {
        <div class="mt-3 mb-2 fw-semibold small">@L["DayTrend_AgentMetrics"]</div>
        @foreach (var m in _agentMetrics)
        {
            var metric = m;
            <div class="form-check form-check-sm mb-1">
                <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                       checked="@metric.Enabled"
                       @onchange="e => { var idx = _agentMetrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _agentMetrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                <label class="form-check-label small" for="vm_@metric.MetricId">
                    @GetDisplayLabel(metric)
                </label>
            </div>
        }
    }
</div>
```

---

## Implementation steps

1. Read skill files
2. Restore CSS from HEAD (bash command above)
3. Rewrite modal body in DayTrendWidget.razor via Python atomic write + fsync
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `fix: DayTrend modal — restore CSS (truncation fix) + flat layout (remove tabs)`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
