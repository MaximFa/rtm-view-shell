---
name: daytend-implementation-insights
description: "DayTrend widget polish — 7 production fixes: modal tabs, Chart.js dataset passthrough, tooltip mode, time formatting, parameter tracking, label fallback"
metadata:
  type: impl
updated: 2026-05-27
---

# DayTrend Widget — Implementation Insights (production polish)

## Changes applied during final polish session

### 1. ScreenEditorPage.razor — Thresholds tab hidden for DayTrend
DayTrend has no thresholds concept. Tab conditionally hidden:
```razor
@if (!IsDayTrendWidget(ConfiguringWidget)) { <li>Thresholds tab</li> }
```

### 2. ScreenEditorPage.razor — MetricId removed from config UI
MetricId is technical — user should never see it. Config rows show only:
toggle + color picker + label input.

### 3. DayTrend.razor — GetDisplayLabel fallback
Empty Label formats MetricId automatically:
"interaction.incoming_calls" → "Incoming Calls" via Split('.')[1] + Split('_') + capitalize.

### 4. DayTrend.razor — interval parameter tracking
OnParametersSetAsync must track ALL data-affecting params, not just BU:
```csharp
if (_businessUnitId != _lastBusinessUnitId || _intervalMinutes != _lastIntervalMinutes)
    await LoadDataAsync();
```

### 5. daytrendChart.js — isTimeMetric passthrough
Custom dataset properties MUST be explicitly copied into configuredDatasets:
```js
isTimeMetric: ds.isTimeMetric  // required for tooltip formatter
```
Without this, tooltip callback cannot access the flag.

### 6. daytrendChart.js — tooltip interaction mode
For multi-line charts use nearest+intersect (not index):
```js
interaction: { mode: 'nearest', intersect: true }
```

### 7. daytrendChart.js — time formatting
Time metrics formatted as mm:ss in tooltip and Y-axis ticks.
```js
function formatTime(s) { return `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`; }
```

## Files changed
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
- src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
- src/CcDashboard.Web/wwwroot/js/daytrendChart.js

## Reference
Full patterns documented in .claude/skills/widget-creator/widget-creator.md §24

---

## BU Dropdown Bug (not in CC report — captured separately)

### Symptom
DayTrend BU dropdown showed only 1 item (current selection) instead of full list.

### Root cause
`DayTrendBuSearchText` was pre-filled with the selected BU name. On dropdown open, filter was already active → list filtered to one match.

### Fix — ScreenEditorPage.razor line ~424
Added `@onfocus` to clear search text on open:
```razor
@onfocus="() => { DayTrendBuSearchText = string.Empty; DayTrendBuDropdownOpen = true; }"
```
`@onblur` restores the selected name when dropdown closes.

### General rule
For any searchable dropdown with a pre-selected value:
- EITHER don't pre-fill the search field
- OR clear it on `@onfocus`

Without this, the dropdown will show only the matching item on open.
See widget-creator.md §24.8 for full pattern.
