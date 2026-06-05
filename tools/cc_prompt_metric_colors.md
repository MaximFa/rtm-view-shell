# CC Task: DayTrend local view settings — color picker per metric

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: ONE FILE ONLY
`src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Changes — DayTrendWidget.razor

### 1 — Add color dictionary fields

After `private HashSet<string>? _localAgentMetricIds;` add:
```csharp
private Dictionary<string, string> _localMetricColors = new();
private Dictionary<string, string> _localAgentMetricColors = new();
```

### 2 — LoadLocalOverridesAsync: restore colors

After the `chartType` restore block (the last `if (root.TryGetProperty("chartType"...))` block),
add:
```csharp
if (root.TryGetProperty("metricColors", out var mcEl) && mcEl.ValueKind == JsonValueKind.Object)
{
    _localMetricColors = mcEl.EnumerateObject()
        .Where(p => !string.IsNullOrEmpty(p.Value.GetString()))
        .ToDictionary(p => p.Name, p => p.Value.GetString()!);
    _metrics = _metrics.Select(m =>
        _localMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
}

if (root.TryGetProperty("agentMetricColors", out var amcEl) && amcEl.ValueKind == JsonValueKind.Object)
{
    _localAgentMetricColors = amcEl.EnumerateObject()
        .Where(p => !string.IsNullOrEmpty(p.Value.GetString()))
        .ToDictionary(p => p.Name, p => p.Value.GetString()!);
    _agentMetrics = _agentMetrics.Select(m =>
        _localAgentMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
}
```

### 3 — SaveLocalOverridesAsync: include colors

Find the anonymous object in `SaveLocalOverridesAsync()`:
```csharp
var obj = new
{
    buId = _localBuId,
    metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    chartType = _viewChartType
};
```

Replace with:
```csharp
var obj = new
{
    buId         = _localBuId,
    metrics      = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    chartType    = _viewChartType,
    metricColors = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
    agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
};
```

### 4 — ApplyViewConfigAsync: update color caches

After the existing `_localMetricIds = _metrics.Where...` block, add:
```csharp
_localMetricColors = _metrics.ToDictionary(m => m.MetricId, m => m.Color);
_localAgentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color);
```

### 5 — ClearLocalOverridesAsync: reset color caches

After `_localAgentMetricIds = null;` add:
```csharp
_localMetricColors = new();
_localAgentMetricColors = new();
```

### 6 — OpenLocalConfigAsync: re-apply colors

After the existing `_localAgentMetricIds` re-apply block, add:
```csharp
if (_localMetricColors.Any())
    _metrics = _metrics.Select(m =>
        _localMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();

if (_localAgentMetricColors.Any())
    _agentMetrics = _agentMetrics.Select(m =>
        _localAgentMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
```

### 7 — Modal HTML: add color picker next to each metric checkbox

**Queue Metrics tab** — replace the `<div class="form-check form-check-sm mb-2">` block for `_metrics`:

```razor
@if (_viewTab == "queue")
{
    @foreach (var m in _metrics)
    {
        var metric = m;
        <div class="d-flex align-items-center mb-2 gap-2">
            <input class="form-check-input mt-0" type="checkbox" id="vm_@metric.MetricId"
                   checked="@metric.Enabled"
                   @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
            <input type="color" value="@metric.Color" style="width:28px;height:24px;padding:1px;border:1px solid #ccc;border-radius:4px;cursor:pointer;"
                   @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Color = e.Value?.ToString() ?? metric.Color }; }" />
            <label class="form-check-label mb-0" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
        </div>
    }
}
```

**Agent Metrics tab** — same pattern for `_agentMetrics`:

```razor
@if (_viewTab == "agent")
{
    @if (_agentMetrics.Any())
    {
        @foreach (var m in _agentMetrics)
        {
            var metric = m;
            <div class="d-flex align-items-center mb-2 gap-2">
                <input class="form-check-input mt-0" type="checkbox" id="vm_@metric.MetricId"
                       checked="@metric.Enabled"
                       @onchange="e => { var idx = _agentMetrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _agentMetrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                <input type="color" value="@metric.Color" style="width:28px;height:24px;padding:1px;border:1px solid #ccc;border-radius:4px;cursor:pointer;"
                       @onchange="e => { var idx = _agentMetrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _agentMetrics[idx] = metric with { Color = e.Value?.ToString() ?? metric.Color }; }" />
                <label class="form-check-label mb-0" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
            </div>
        }
    }
    else
    {
        <p class="text-muted small">@L["DayTrend_NoAgentMetrics"]</p>
    }
}
```

---

## Verification

```bash
grep -c "type=\"color\"" src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
# Must return 2 (one per tab)

grep "_localMetricColors\|_localAgentMetricColors" src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | wc -l
# Must return > 5

git diff --name-only
# Must show ONLY DayTrendWidget.razor

dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
# 0 errors
```

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: DayTrend local view settings — color picker per metric (saved in localStorage)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Re-sync (§0.6 PD-007)

```bash
git show HEAD:"src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  > "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor"
sync
echo "Re-synced: $(wc -l < src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor) lines"
```
