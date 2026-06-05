#!/usr/bin/env python3
"""DayTrend view config — button in header, chart type selector, localization fix."""

import os
import re

def atomic_write(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
        f.flush()
        os.fsync(f.fileno())
    print(f"Updated: {path} ({len(content.splitlines())} lines)")

# ─────────────────────────────────────────────────────────────────────────────
# 1. DayTrendWidget.razor — major changes
# ─────────────────────────────────────────────────────────────────────────────
daytrend_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"
with open(daytrend_path, "r", encoding="utf-8") as f:
    daytrend = f.read()

# 1a. Remove floating button block
old_button_block = '''<div class="daytrend-widget h-100" style="@GetWidgetStyle()">
    @if (IsViewMode)
    {
        <button class="btn btn-sm btn-link p-0 daytrendview-settings-btn"
                title="@L["Widget_LocalViewSettings"]"
                @onclick="OpenViewConfigAsync">
            <i class="bi bi-sliders" style="font-size: 0.9rem;"></i>
        </button>
    }

    @if (_loading)'''

new_button_block = '''<div class="daytrend-widget h-100" style="@GetWidgetStyle()">
    @if (_loading)'''

daytrend = daytrend.replace(old_button_block, new_button_block)

# 1b. Add chart type fields after _showViewConfig
old_view_fields = '''    // View-mode local config
    private bool _showViewConfig;
    private List<BusinessUnitDto> _viewBuList = [];'''

new_view_fields = '''    // View-mode local config
    private bool _showViewConfig;
    private string? _localChartType;   // null = use saved config value
    private string _viewChartType = "line";  // current selection in modal
    private List<BusinessUnitDto> _viewBuList = [];'''

daytrend = daytrend.replace(old_view_fields, new_view_fields)

# 1c. Add EffectiveChartType property after EffectiveBuId
old_effective = '''    // Effective values used for data loading and rendering
    private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;

    // Colors'''

new_effective = '''    // Effective values used for data loading and rendering
    private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;
    private string EffectiveChartType => _localChartType ?? _chartType;

    // Colors'''

daytrend = daytrend.replace(old_effective, new_effective)

# 1d. Update RenderChartAsync to use EffectiveChartType
old_options = '''        var options = new
        {
            chartType = _chartType,
            showDataLabels = _showDataLabels,
            showLegend = _showLegend,
            fontColor = EffectiveFontColor
        };'''

new_options = '''        var options = new
        {
            chartType = EffectiveChartType,
            showDataLabels = _showDataLabels,
            showLegend = _showLegend,
            fontColor = EffectiveFontColor
        };'''

daytrend = daytrend.replace(old_options, new_options)

# 1e. Update LoadLocalOverridesAsync to load chartType
old_load_local = '''            if (root.TryGetProperty("agentMetrics", out var amEl) && amEl.ValueKind == JsonValueKind.Array)
            {
                _localAgentMetricIds = amEl.EnumerateArray()
                    .Select(x => x.GetString() ?? "")
                    .Where(s => !string.IsNullOrEmpty(s))
                    .ToHashSet();
                _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();
            }
        }
        catch (Exception ex)'''

new_load_local = '''            if (root.TryGetProperty("agentMetrics", out var amEl) && amEl.ValueKind == JsonValueKind.Array)
            {
                _localAgentMetricIds = amEl.EnumerateArray()
                    .Select(x => x.GetString() ?? "")
                    .Where(s => !string.IsNullOrEmpty(s))
                    .ToHashSet();
                _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();
            }

            if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
            {
                _localChartType = ctEl.GetString();
                _viewChartType = _localChartType ?? "line";
            }
        }
        catch (Exception ex)'''

daytrend = daytrend.replace(old_load_local, new_load_local)

# 1f. Update SaveLocalOverridesAsync to save chartType
old_save_local = '''    private async Task SaveLocalOverridesAsync()
    {
        var obj = new
        {
            buId = _localBuId,
            metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray()
        };'''

new_save_local = '''    private async Task SaveLocalOverridesAsync()
    {
        _localChartType = _viewChartType;
        var obj = new
        {
            buId = _localBuId,
            metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType = _viewChartType
        };'''

daytrend = daytrend.replace(old_save_local, new_save_local)

# 1g. Update ClearLocalOverridesAsync
old_clear = '''    private async Task ClearLocalOverridesAsync()
    {
        await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);
        _localBuId = 0;
        _localMetricIds = null;
        _localAgentMetricIds = null;
        _showViewConfig = false;
        ParseConfig();'''

new_clear = '''    private async Task ClearLocalOverridesAsync()
    {
        await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);
        _localBuId = 0;
        _localMetricIds = null;
        _localAgentMetricIds = null;
        _localChartType = null;
        _viewChartType = _chartType;
        _showViewConfig = false;
        ParseConfig();'''

daytrend = daytrend.replace(old_clear, new_clear)

# 1h. Rename OpenViewConfigAsync to OpenLocalConfigAsync and make public
old_open = '''    private async Task OpenViewConfigAsync()
    {
        if (!_viewBuList.Any())
            _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

        // Pre-select current effective values in the metric lists
        if (_localMetricIds is not null)
            _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();

        if (_localAgentMetricIds is not null)
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();

        _showViewConfig = true;
    }'''

new_open = '''    public async Task OpenLocalConfigAsync()
    {
        if (!_viewBuList.Any())
            _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

        _viewChartType = _localChartType ?? _chartType;

        // Pre-select current effective values in the metric lists
        if (_localMetricIds is not null)
            _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();

        if (_localAgentMetricIds is not null)
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();

        _showViewConfig = true;
    }'''

daytrend = daytrend.replace(old_open, new_open)

# 1i. Add modal HTML before closing </div> and @code
modal_html = '''
    @if (IsViewMode && _showViewConfig)
    {
        <div class="daytrendview-modal-overlay" @onclick="() => _showViewConfig = false" @onclick:stopPropagation="true">
            <div class="modal-dialog modal-lg" @onclick:stopPropagation="true">
                <div class="modal-content">
                    <div class="modal-header py-2">
                        <h6 class="modal-title mb-0">@L["Widget_LocalViewSettings"]</h6>
                        <button type="button" class="btn-close" @onclick="() => _showViewConfig = false"></button>
                    </div>
                    <div class="modal-body">
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
                            <div class="mt-2 mb-2 fw-semibold small">@L["DayTrend_AgentMetrics"]</div>
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
                    <div class="modal-footer py-2 d-flex justify-content-between">
                        <button class="btn btn-sm btn-outline-danger" @onclick="ClearLocalOverridesAsync">
                            <i class="bi bi-arrow-counterclockwise me-1"></i>@L["Widget_ResetToDefault"]
                        </button>
                        <div>
                            <button class="btn btn-sm btn-secondary me-2" @onclick="() => _showViewConfig = false">
                                @L["Cancel"]
                            </button>
                            <button class="btn btn-sm btn-primary" @onclick="ApplyViewConfigAsync">
                                <i class="bi bi-check2 me-1"></i>@L["Apply"]
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    }
'''

# Insert modal before closing </div> and @code
daytrend = daytrend.replace('    }\n</div>\n\n@code {', '    }\n</div>\n' + modal_html + '\n@code {')

atomic_write(daytrend_path, daytrend)

# ─────────────────────────────────────────────────────────────────────────────
# 2. DayTrendWidget.razor.css — new CSS
# ─────────────────────────────────────────────────────────────────────────────
css_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor.css"
css_content = '''/* Modal overlay — fixed so it renders above all widget content */
.daytrendview-modal-overlay {
    position: fixed;
    inset: 0;
    z-index: 1060;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
}
'''
atomic_write(css_path, css_content)

# ─────────────────────────────────────────────────────────────────────────────
# 3. RenderWidget.razor — add @ref and method
# ─────────────────────────────────────────────────────────────────────────────
render_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\RenderWidget.razor"
with open(render_path, "r", encoding="utf-8") as f:
    render = f.read()

# Add @ref to DayTrendWidget
old_daytrend_render = '''case var n when n.Contains("day") && n.Contains("trend"):
            <DayTrendWidget @key="Widget.Id" Config="Widget.Config" DarkMode="DarkMode" WidgetInstanceId="Widget.Id" IsViewMode="IsViewMode" />
            break;'''

new_daytrend_render = '''case var n when n.Contains("day") && n.Contains("trend"):
            <DayTrendWidget @ref="_dayTrendWidget"
                            @key="Widget.Id"
                            Config="Widget.Config"
                            DarkMode="DarkMode"
                            WidgetInstanceId="Widget.Id"
                            IsViewMode="IsViewMode" />
            break;'''

render = render.replace(old_daytrend_render, new_daytrend_render)

# Add field and method to @code block
old_code = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public bool IsViewMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
}'''

new_code = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public bool IsViewMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }

    private DayTrendWidget? _dayTrendWidget;

    public async Task OpenDayTrendLocalConfigAsync()
    {
        if (_dayTrendWidget is not null)
            await _dayTrendWidget.OpenLocalConfigAsync();
    }
}'''

render = render.replace(old_code, new_code)

atomic_write(render_path, render)

# ─────────────────────────────────────────────────────────────────────────────
# 4. ScreenFullscreenPage.razor — add header button
# ─────────────────────────────────────────────────────────────────────────────
fullscreen_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenFullscreenPage.razor"
with open(fullscreen_path, "r", encoding="utf-8") as f:
    fullscreen = f.read()

# Add refs dictionary field after existing private fields
old_darkmode = '''    private bool _positionsApplied;
    private bool _darkMode = false;'''

new_darkmode = '''    private bool _positionsApplied;
    private bool _darkMode = false;
    private readonly Dictionary<Guid, RenderWidget?> _renderWidgetRefs = new();'''

fullscreen = fullscreen.replace(old_darkmode, new_darkmode)

# Add IsDayTrendWidget helper after ToggleDarkMode
old_toggle = '''    private void ToggleDarkMode() => _darkMode = !_darkMode;

    // Effective colors'''

new_toggle = '''    private void ToggleDarkMode() => _darkMode = !_darkMode;

    private static bool IsDayTrendWidget(ScreenEditorPage.PlacedWidget w) =>
        (w.OriginalWidgetName ?? w.Name ?? "").Contains("day", StringComparison.OrdinalIgnoreCase)
        && (w.OriginalWidgetName ?? w.Name ?? "").Contains("trend", StringComparison.OrdinalIgnoreCase);

    // Effective colors'''

fullscreen = fullscreen.replace(old_toggle, new_toggle)

# Add TryAdd at start of foreach loop
old_foreach = '''                    @foreach (var widget in PlacedWidgets)
                    {
                        var config = widget.Config;'''

new_foreach = '''                    @foreach (var widget in PlacedWidgets)
                    {
                        @{ _renderWidgetRefs.TryAdd(widget.Id, null); }
                        var config = widget.Config;'''

fullscreen = fullscreen.replace(old_foreach, new_foreach)

# Add @ref to RenderWidget
old_render_widget = '''<RenderWidget Widget="widget" DarkMode="_darkMode" IsViewMode="true" />'''
new_render_widget = '''<RenderWidget @ref="_renderWidgetRefs[widget.Id]"
                                              Widget="widget" DarkMode="_darkMode" IsViewMode="true" />'''

fullscreen = fullscreen.replace(old_render_widget, new_render_widget)

# Update header block to include button for DayTrend
old_header = '''@if (!isHeaderHidden)
                            {
                                <div class="widget-header" style="@GetHeaderStyle(config)">
                                    @(config?.DisplayName ?? widget.Name)
                                </div>
                            }'''

new_header = '''@if (!isHeaderHidden)
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
                            }'''

fullscreen = fullscreen.replace(old_header, new_header)

atomic_write(fullscreen_path, fullscreen)

# ─────────────────────────────────────────────────────────────────────────────
# 5. daytrendChart.js — add bar chart support
# ─────────────────────────────────────────────────────────────────────────────
js_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\wwwroot\js\daytrendChart.js"
with open(js_path, "r", encoding="utf-8") as f:
    js = f.read()

old_charttype = '''        // Determine chart type
        let chartType = options?.chartType || 'line';
        if (chartType === 'area') chartType = 'line';
        if (chartType === 'step') {
            chartType = 'line';
            configuredDatasets.forEach(ds => ds.stepped = true);
        }'''

new_charttype = '''        // Determine chart type
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
        }'''

js = js.replace(old_charttype, new_charttype)

atomic_write(js_path, js)

# ─────────────────────────────────────────────────────────────────────────────
# 6. Localization files — update with all keys
# ─────────────────────────────────────────────────────────────────────────────

# Keys to add/update in each locale
new_keys_en = '''  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
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
  </data>'''

new_keys_ru = '''  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
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
  </data>'''

new_keys_he = '''  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
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
  </data>'''

resx_files = [
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.en-US.resx", new_keys_en),
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.ru-RU.resx", new_keys_ru),
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.he-IL.resx", new_keys_he),
]

for resx_path, new_keys in resx_files:
    with open(resx_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check if chart type keys already exist
    if "DayTrend_ChartType" not in content:
        # Insert before </root>
        content = content.replace("</root>", new_keys + "\n</root>")
        atomic_write(resx_path, content)
    else:
        print(f"Skipped: {resx_path} (chart type keys already exist)")

print("\nDone. Run: dotnet build CcDashboard.sln")
