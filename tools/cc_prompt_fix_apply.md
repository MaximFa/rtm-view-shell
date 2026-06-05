# CC Task: Fix DayTrend — update _localMetricIds after Apply (settings reset on re-open)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: ONE FILE ONLY
Only `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`.

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

`SaveLocalOverridesAsync()` writes to localStorage but does NOT update the in-memory
fields `_localMetricIds`, `_localAgentMetricIds`, `_localChartType`, `_localBuId`.

So when user clicks Apply → closes modal → reopens modal:
`OpenLocalConfigAsync()` re-applies the OLD `_localMetricIds` (pre-Apply values),
overwriting the user's just-saved selections.

---

## Fix — `ApplyViewConfigAsync()` in DayTrendWidget.razor

Find:
```csharp
private async Task ApplyViewConfigAsync()
{
    await SaveLocalOverridesAsync();
    _showViewConfig = false;
    await LoadDataAsync();
}
```

Replace with:
```csharp
private async Task ApplyViewConfigAsync()
{
    await SaveLocalOverridesAsync();

    // Update in-memory caches to match what was just saved,
    // so OpenLocalConfigAsync() re-apply shows correct state on next open.
    _localMetricIds = _metrics
        .Where(m => m.Enabled)
        .Select(m => m.MetricId)
        .ToHashSet();
    _localAgentMetricIds = _agentMetrics
        .Where(m => m.Enabled)
        .Select(m => m.MetricId)
        .ToHashSet();
    _localChartType = _viewChartType;

    _showViewConfig = false;
    await LoadDataAsync();
}
```

---

## Verification

```bash
grep -A 15 "private async Task ApplyViewConfigAsync" \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
```
Must show `_localMetricIds = _metrics.Where...` block.

```bash
git diff --name-only
```
Must show ONLY `DayTrendWidget.razor`.

Build:
```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
```
0 errors.

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: DayTrend local settings persist on modal re-open — update _localMetricIds after Apply"
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
