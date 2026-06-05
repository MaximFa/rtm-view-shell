# CC Task: DayTrend local view settings — 2 UX fixes

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: 2 files
- `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`
- `src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor`

---

## Step 0 — Integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        git show HEAD:"$f" > "$f" && echo "Restored: $f"
    fi
done && sync
```

---

## Fix 1 — DayTrendWidget.razor: BU dropdown shows current effective BU

### Problem
When the modal opens, BU dropdown shows "— Use default —" even when the widget
has an admin-configured BU (`_businessUnitId > 0`).
User expects to see the currently active BU pre-selected.

### Fix: in `OpenLocalConfigAsync()`, pre-populate `_localBuId` from effective value

Find the line:
```csharp
_viewChartType = _localChartType ?? _chartType;
```

Add BEFORE it:
```csharp
// Pre-select effective BU so dropdown shows current value, not "Use default"
if (_localBuId == 0 && _businessUnitId > 0)
    _localBuId = _businessUnitId;
```

---

## Fix 2 — ScreenFullscreenPage.razor: move ⚙ icon to far right of header

### Problem
Icon appears inline after the widget title with `ms-2` margin — looks misplaced.

### Fix: use `justify-content-between` on header and push icon to the right

Find the header block:
```razor
<div class="widget-header d-flex align-items-center justify-content-between"
     style="@GetHeaderStyle(config)">
    <span>@(config?.DisplayName ?? widget.Name)</span>
    @if (IsDayTrendWidget(widget))
    {
        var wId = widget.Id;
        <button class="btn btn-sm btn-link p-0 ms-2 opacity-75"
                style="color: inherit; line-height: 1;"
```

Replace with:
```razor
<div class="widget-header d-flex align-items-center justify-content-between"
     style="@GetHeaderStyle(config)">
    <span class="text-truncate">@(config?.DisplayName ?? widget.Name)</span>
    @if (IsDayTrendWidget(widget))
    {
        var wId = widget.Id;
        <button class="btn btn-sm btn-link p-0 flex-shrink-0 ms-2 opacity-60"
                style="color: inherit; line-height: 1;"
```

The `justify-content-between` is already there — just ensure the title has `text-truncate`
and the button has `flex-shrink-0` so it always stays visible at the right edge.

---

## Build & commit

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
# 0 errors

git diff --name-only
# Only DayTrendWidget.razor and ScreenFullscreenPage.razor

bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor \
  src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor \
  src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: DayTrend local view — BU dropdown pre-selects current value; settings icon to right edge"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor"; do
  git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```
