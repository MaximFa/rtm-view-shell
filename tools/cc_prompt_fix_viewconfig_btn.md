# CC Task: DayTrend view config — button in header, chart type selector, localization fix

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Overview of changes

1. Move ⚙ button from inside widget body → into widget header (ScreenFullscreenPage)
2. Use @ref chain: ScreenFullscreenPage → RenderWidget → DayTrendWidget to call OpenLocalConfigAsync()
3. Add chart type selector (Line / Bar / Area / Step) to local config modal General tab
4. Add bar chart support to daytrendChart.js
5. Add missing localization keys to all 3 .resx files
6. Clean up CSS (remove absolute-positioned button styles)

---

## File 1 — `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

### 1a — Remove floating button block
Delete the `@if (IsViewMode)` button block at the top of the template
(the 5-line block with `<button class="daytrendview-settings-btn"...>`).
The button moves to the header. The modal stays inside the widget.

### 1b — Make OpenViewConfigAsync public and rename

Change `private async Task OpenViewConfigAsync()` → `public async Task OpenLocalConfigAsync()`.
Update the call site inside the modal HTML (`@onclick="OpenViewConfigAsync"` → remove,
the method is now called externally via @ref, not from inside the widget).
Keep `_showViewConfig = true` at the end of the method.

### 1c — Add chart type fields

After `private bool _showViewConfig;` add:
```csharp
private string? _localChartType;   // null = use saved config value
private string _viewChartType = "line";  // current selection in modal
```

In `LoadLocalOverridesAsync()`, add after agentMetrics parsing:
```csharp
if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
{
    _localChartType = ctEl.GetString();
    _viewChartType  = _localChartType ?? "line";
}
```

In `SaveLocalOverridesAsync()`, extend the anonymous object:
```csharp
var obj = new
{
    buId         = _localBuId,
    metrics      = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
    chartType    = _viewChartType
};
```

In `ClearLocalOverridesAsync()`, after resetting other fields:
```csharp
_localChartType = null;
_viewChartType  = _chartType;   // revert to saved config chart type
```

In `OpenLocalConfigAsync()`, after loading BU list:
```csharp
_viewChartType = _localChartType ?? _chartType;
```

### 1d — Add EffectiveChartType property

```csharp
private string EffectiveChartType => _localChartType ?? _chartType;
```

### 1e — Use EffectiveChartType in RenderChartAsync

Find the `options` object passed to `JS.InvokeVoidAsync("dayTrendChart.render", ...)`.
Change `chartType = _chartType` → `chartType = EffectiveChartType`.

### 1f — Add chart type selector to modal (General tab section, after BU dropdown)

```razor
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
```

---

## File 2 — `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css`

Replace entire file content with:

```css
/* Modal overlay — fixed so it renders above all widget content */
.daytrendview-modal-overlay {
    position: fixed;
    inset: 0;
    z-index: 1060;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
}
```

Remove all `.daytrendview-settings-btn` styles (button is now in the header).
Remove `position: relative` on `.daytrend-widget` (no longer needed).

Also update the modal HTML in DayTrendWidget.razor: change
`<div class="modal fade show d-block" tabindex="-1" style="background:rgba(0,0,0,0.5);">`
to use the new CSS class:
`<div class="daytrendview-modal-overlay" @onclick:stopPropagation="true">`

---

## File 3 — `src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor`

### 3a — Add @ref field for DayTrendWidget

In `@code`:
```csharp
private DayTrendWidget? _dayTrendWidget;
```

### 3b — Add @ref to DayTrendWidget render

Change the DayTrend case:
```razor
case var n when n.Contains("day") && n.Contains("trend"):
    <DayTrendWidget @ref="_dayTrendWidget"
                    @key="Widget.Id"
                    Config="Widget.Config"
                    DarkMode="DarkMode"
                    WidgetInstanceId="Widget.Id"
                    IsViewMode="IsViewMode" />
    break;
```

### 3c — Expose public method

```csharp
public async Task OpenDayTrendLocalConfigAsync()
{
    if (_dayTrendWidget is not null)
        await _dayTrendWidget.OpenLocalConfigAsync();
}
```

### 3d — Add @using for DayTrendWidget namespace (if needed)

Check that `@using CcDashboard.Web.Components.Widgets` is present at the top.

---

## File 4 — `src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor`

### 4a — Add refs dictionary

In `@code`, add:
```csharp
private readonly Dictionary<Guid, RenderWidget?> _renderWidgetRefs = new();
```

### 4b — Helper: is DayTrend widget

```csharp
private static bool IsDayTrendWidget(PlacedWidget w) =>
    (w.OriginalWidgetName ?? w.Name ?? "").Contains("day", StringComparison.OrdinalIgnoreCase)
    && (w.OriginalWidgetName ?? w.Name ?? "").Contains("trend", StringComparison.OrdinalIgnoreCase);
```

### 4c — Initialize ref slot before rendering each widget

In the `@foreach (var widget in PlacedWidgets)` block, at the very top:
```razor
@{ _renderWidgetRefs.TryAdd(widget.Id, null); }
```

### 4d — Add @ref to RenderWidget

Change:
```razor
<RenderWidget Widget="widget" DarkMode="_darkMode" IsViewMode="true" />
```
To:
```razor
<RenderWidget @ref="_renderWidgetRefs[widget.Id]"
              Widget="widget" DarkMode="_darkMode" IsViewMode="true" />
```

### 4e — Add ⚙ button in widget header for DayTrend

Change the header block:
```razor
@if (!isHeaderHidden)
{
    <div class="widget-header" style="@GetHeaderStyle(config)">
        @(config?.DisplayName ?? widget.Name)
    </div>
}
```
To:
```razor
@if (!isHeaderHidden)
{
    <div class="widget-header d-flex align-items-center justify-content-between"
         style="@GetHeaderStyle(config)">
        <span>@(config?.DisplayName ?? widget.Name)</span>
        @if (IsDayTrendWidget(widget))
        {
            var wId = widget.Id;
            <button class="btn btn-sm btn-link p-0 ms-2 opacity-75"
                    style="color: inherit; line-height: 1;"
                    title="@L["Widget_LocalViewSettings"]"
                    @onclick="async () => { if (_renderWidgetRefs.TryGetValue(wId, out var rw) && rw is not null) await rw.OpenDayTrendLocalConfigAsync(); }"
                    @onclick:stopPropagation="true">
                <i class="bi bi-sliders" style="font-size: 0.85rem;"></i>
            </button>
        }
    </div>
}
```

### 4f — Add @using for RenderWidget

Ensure at top of file:
```razor
@using CcDashboard.Web.Components.Dashboard
```

---

## File 5 — `src/CcDashboard.Web/wwwroot/js/daytrendChart.js`

In the `configuredDatasets.map` block, add bar chart support:

Find:
```js
let chartType = options?.chartType || 'line';
if (chartType === 'area') chartType = 'line';
if (chartType === 'step') {
    chartType = 'line';
    configuredDatasets.forEach(ds => ds.stepped = true);
}
```

Replace with:
```js
let chartType = options?.chartType || 'line';
let isBar = chartType === 'bar';
if (chartType === 'area') chartType = 'line';
if (chartType === 'step') {
    chartType = 'line';
    configuredDatasets.forEach(ds => ds.stepped = true);
}
if (isBar) {
    chartType = 'bar';
    configuredDatasets.forEach(ds => {
        ds.backgroundColor = ds.borderColor + '99';
        ds.borderWidth = 1;
        delete ds.tension;
        delete ds.fill;
        delete ds.pointRadius;
        delete ds.pointHoverRadius;
    });
}
```

---

## File 6 — Localization keys (all 3 .resx files)

Add before `</root>` in each file.

### SharedResources.en-US.resx
```xml
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>Local view settings</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>Use default</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>Reset to default</value>
  </data>
  <data name="Apply" xml:space="preserve">
    <value>Apply</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>Call metrics</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>Agent metrics</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>Chart type</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>Line</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>Bar</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>Area (filled)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>Step</value>
  </data>
```

### SharedResources.ru-RU.resx
```xml
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>Локальные настройки отображения</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>Использовать по умолчанию</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>Сбросить к настройкам</value>
  </data>
  <data name="Apply" xml:space="preserve">
    <value>Применить</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>Метрики звонков</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>Метрики агентов</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>Тип графика</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>Линия</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>Бар</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>Область (заливка)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>Ступенчатый</value>
  </data>
```

### SharedResources.he-IL.resx
```xml
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>הגדרות תצוגה מקומיות</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>השתמש בברירת מחדל</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>איפוס להגדרות</value>
  </data>
  <data name="Apply" xml:space="preserve">
    <value>החל</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>מדדי שיחות</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>מדדי סוכנים</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>סוג גרף</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>קו</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>עמודות</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>שטח (מלא)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>מדרגות</value>
  </data>
```

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Apply all 6 file changes via Python atomic write + fsync (Edit tool BANNED)
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `feat: DayTrend view config — button in header, chart type selector, localization`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css" \
  "src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor" \
  "src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor" \
  "src/CcDashboard.Web/wwwroot/js/daytrendChart.js" \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
