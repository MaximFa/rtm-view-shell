# CC Task: DayTrend local view settings — add Time Interval selector to General tab

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

### 1 — Add fields

After `private int? _localBuId = 0;` (or near other local fields), add:
```csharp
private int _localIntervalMinutes;   // 0 = use saved config value
private int _viewIntervalMinutes = 30; // current selection in modal
```

Add computed property after `EffectiveBuId`:
```csharp
private int EffectiveIntervalMinutes =>
    _localIntervalMinutes > 0 ? _localIntervalMinutes : _intervalMinutes;
```

### 2 — LoadLocalOverridesAsync: restore interval

After the `chartType` restore block, add:
```csharp
if (root.TryGetProperty("intervalMinutes", out var intEl) && intEl.TryGetInt32(out var intVal) && intVal > 0)
{
    _localIntervalMinutes = intVal;
    _viewIntervalMinutes  = intVal;
}
```

### 3 — SaveLocalOverridesAsync: include interval

Add `intervalMinutes = _viewIntervalMinutes` to the anonymous object:
```csharp
var obj = new
{
    buId              = _localBuId,
    metrics           = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    agentMetrics      = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    chartType         = _viewChartType,
    intervalMinutes   = _viewIntervalMinutes,
    metricColors      = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
    agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
};
```

### 4 — ApplyViewConfigAsync: update cache

After `_localChartType = _viewChartType;` add:
```csharp
_localIntervalMinutes = _viewIntervalMinutes;
```

### 5 — ClearLocalOverridesAsync: reset interval

After `_localChartType = null;` add:
```csharp
_localIntervalMinutes  = 0;
_viewIntervalMinutes   = _intervalMinutes;
```

### 6 — OpenLocalConfigAsync: pre-populate interval

After `_viewChartType = _localChartType ?? _chartType;` add:
```csharp
_viewIntervalMinutes = _localIntervalMinutes > 0 ? _localIntervalMinutes : _intervalMinutes;
```

### 7 — LoadDataAsync: use EffectiveIntervalMinutes

Find the `DayTrendQuery(...)` call and change `_intervalMinutes` to `EffectiveIntervalMinutes`:
```csharp
var result = await Mediator.Send(new DayTrendQuery(
    EffectiveBuId,
    EffectiveIntervalMinutes,    // ← was _intervalMinutes
    includeAgentMetrics), _cts.Token);
```

### 8 — General tab HTML: add Time Interval buttons

In the `@if (_viewTab == "general")` block, after the Chart type selector `</div>`, add:

```razor
<!-- Time interval -->
<div class="mb-3">
    <label class="form-label fw-semibold">@L["DayTrend_TimeInterval"]</label>
    <div class="btn-group w-100" role="group">
        <button type="button"
                class="btn btn-sm @(_viewIntervalMinutes == 15 ? "btn-primary" : "btn-outline-secondary")"
                @onclick='() => _viewIntervalMinutes = 15'>15 min</button>
        <button type="button"
                class="btn btn-sm @(_viewIntervalMinutes == 30 ? "btn-primary" : "btn-outline-secondary")"
                @onclick='() => _viewIntervalMinutes = 30'>30 min</button>
        <button type="button"
                class="btn btn-sm @(_viewIntervalMinutes == 60 ? "btn-primary" : "btn-outline-secondary")"
                @onclick='() => _viewIntervalMinutes = 60'>60 min</button>
    </div>
</div>
```

### 9 — Add localization key

Check if `DayTrend_TimeInterval` exists in `SharedResources.en-US.resx`.
If NOT — add to all 3 .resx files:
- en-US: `DayTrend_TimeInterval` = `Time Interval`
- ru-RU: `DayTrend_TimeInterval` = `Интервал`
- he-IL: `DayTrend_TimeInterval` = `מרווח זמן`

---

## L-34 Verification

```bash
grep -Po '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | sort -u > /tmp/razor_keys.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/resx_keys.txt
comm -23 /tmp/razor_keys.txt /tmp/resx_keys.txt
# Must be EMPTY
```

## Build & commit

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
# 0 errors

bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: DayTrend local view settings — Time Interval selector in General tab"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```
