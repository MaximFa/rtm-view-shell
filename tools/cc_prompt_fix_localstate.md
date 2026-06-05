# CC Task: Fix DayTrend local view settings — re-apply localStorage state on modal open

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: ONE FILE ONLY
Only `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`.
Do NOT touch any other file.

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

## Problem

When the user applies local settings and then reopens the configurator modal,
the modal shows the original (DB) config instead of the saved local settings.

Root cause: `ParseConfig()` is called on every `OnParametersSetAsync()` and resets
`_metrics` / `_agentMetrics` to the DB config. `LoadLocalOverridesAsync()` runs only
once at init, so `_localMetricIds` / `_localAgentMetricIds` are populated but not
re-applied to `_metrics` after each `ParseConfig()` call.

---

## Fix — `OpenLocalConfigAsync()` in DayTrendWidget.razor

Find the method `OpenLocalConfigAsync()`. It currently looks like:

```csharp
public async Task OpenLocalConfigAsync()
{
    if (!_viewBuList.Any())
        _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

    _viewTab = "general";
    _viewChartType = _localChartType ?? _chartType;
    _showViewConfig = true;
}
```

Replace with:

```csharp
public async Task OpenLocalConfigAsync()
{
    if (!_viewBuList.Any())
        _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

    _viewTab = "general";
    _viewChartType = _localChartType ?? _chartType;

    // Re-apply saved localStorage state so modal always shows user's saved preferences,
    // not the DB config that ParseConfig() may have restored since last Apply.
    if (_localMetricIds is not null)
        _metrics = _metrics
            .Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) })
            .ToList();

    if (_localAgentMetricIds is not null)
        _agentMetrics = _agentMetrics
            .Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) })
            .ToList();

    _showViewConfig = true;
}
```

---

## Verification

```bash
grep -A 20 "public async Task OpenLocalConfigAsync" \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
```

Must show both `_localMetricIds` and `_localAgentMetricIds` re-apply blocks.

Build:
```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
```
0 errors.

Verify ONE file changed:
```bash
git diff --name-only
```
Must show ONLY `DayTrendWidget.razor`.

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: DayTrend local view settings persist on modal re-open (re-apply localStorage in OpenLocalConfigAsync)"
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
