# DayTrend Comparison Chart — Plan

> Status: PLANNED (2026-06-05). Local view config is stable. UserWidgetSettings table in place.
> **Storage: use UserWidgetSettings (not localStorage)** — see CLAUDE.md §41 + db/migrations/20260605_003.

---

## Summary

Overlay comparison periods on the DayTrend chart using the same BU/metrics but different dates.
All settings stored in **UserWidgetSettings** DB table (same as local view config).
Compare settings extend existing SettingsJson: add `"comparison":{...}` key.
No SQL changes — `DayTrendQuery` already supports `DateOnly? OnDate`.

## Comparison periods (all can be active simultaneously)

| Period | Date calculation |
|---|---|
| Yesterday | `DateOnly.Today.AddDays(-1)` |
| Same weekday last week | `DateOnly.Today.AddDays(-7)` |
| Custom date | User-selected via `<input type="date">` |

## Visual style

| Data type | Primary (today) | Comparison |
|---|---|---|
| Queue metrics | Solid line | Dots only (`showLine=false`, `pointRadius=5`) |
| Agent metrics | Dashed line `[5,5]` | Thin dashed `[8,4]`, `borderWidth 1.5` |
| Color | Metric color 100% | Same color, 45% opacity (`hexToRgba(color, 0.45)`) |

## X-axis alignment

Labels = union of all intervals from all periods (HH:mm format).
Gaps filled with `null` — Chart.js skips missing points automatically.

## localStorage structure (extends existing view config)

```json
{
  "buId": 5,
  "metrics": ["interaction.incoming_calls", "interaction.answered_calls"],
  "agentMetrics": [],
  "comparison": {
    "showYesterday": true,
    "showLastWeekSameDay": false,
    "showCustomDate": true,
    "customDate": "2026-06-04"
  }
}
```

## Files to change

| File | Changes |
|---|---|
| `DayTrendWidget.razor` | Fields: `_compShowYesterday`, `_compShowLastWeek`, `_compShowCustomDate`, `_compCustomDate`, `_comparisonResults`; method `LoadComparisonDataAsync`; new "Comparison" tab in ⚙ modal; extended `RenderChartAsync` (merged labels + comparison datasets with `isComparison` flag); load/save comparison state in localStorage |
| `daytrendChart.js` | Add `hexToRgba(hex, alpha)` helper; in `configuredDatasets.map` — check `isComparison` flag: dots for queue, dashed for agent, opacity via hexToRgba |
| `.resx` files | Keys: `DayTrend_Comparison`, `DayTrend_Yesterday`, `DayTrend_LastWeekSameDay`, `DayTrend_CustomDate` |

## Key implementation notes

- `DayTrendQuery` already has `DateOnly? OnDate = null` — NO SQL changes needed
- Load comparison data in parallel: `Task.WhenAll(compTasks)`
- Label for "last week": show actual date e.g. "Last Fri (May 29)"
- Comparison datasets get `isComparison: true` flag in the dataset object passed to JS
- The Comparison tab is added to the existing ⚙ View Config modal (3rd tab after General + Metrics)

## CC prompt

Create `tools/cc_prompt_daytend_comparison.md` when ready to implement.
Reference: `tools/cc_prompt_daytend_viewmode_config.md` for the modal/localStorage pattern.
