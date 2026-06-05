#!/usr/bin/env python3
"""DayTrend — add local view config in View Mode (BU + metrics, localStorage)."""

import os
import re

def atomic_write(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
        f.flush()
        os.fsync(f.fileno())
    print(f"Updated: {path} ({len(content.splitlines())} lines)")

# ─────────────────────────────────────────────────────────────────────────────
# 1. RenderWidget.razor — add IsViewMode parameter
# ─────────────────────────────────────────────────────────────────────────────
render_widget_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\RenderWidget.razor"
with open(render_widget_path, "r", encoding="utf-8") as f:
    render_widget = f.read()

# Add IsViewMode parameter to @code block
old_code_block = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
}'''

new_code_block = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public bool IsViewMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
}'''

render_widget = render_widget.replace(old_code_block, new_code_block)

# Update DayTrendWidget invocation to pass IsViewMode
old_daytrend_line = '<DayTrendWidget @key="Widget.Id" Config="Widget.Config" DarkMode="DarkMode" WidgetInstanceId="Widget.Id" />'
new_daytrend_line = '<DayTrendWidget @key="Widget.Id" Config="Widget.Config" DarkMode="DarkMode" WidgetInstanceId="Widget.Id" IsViewMode="IsViewMode" />'

render_widget = render_widget.replace(old_daytrend_line, new_daytrend_line)

atomic_write(render_widget_path, render_widget)

# ─────────────────────────────────────────────────────────────────────────────
# 2. ScreenFullscreenPage.razor — add IsViewMode="true" to RenderWidget
# ─────────────────────────────────────────────────────────────────────────────
fullscreen_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenFullscreenPage.razor"
with open(fullscreen_path, "r", encoding="utf-8") as f:
    fullscreen = f.read()

old_render = '<RenderWidget Widget="widget" DarkMode="_darkMode" />'
new_render = '<RenderWidget Widget="widget" DarkMode="_darkMode" IsViewMode="true" />'

fullscreen = fullscreen.replace(old_render, new_render)

atomic_write(fullscreen_path, fullscreen)

# ─────────────────────────────────────────────────────────────────────────────
# 3. DayTrendWidget.razor — add all view mode functionality
# ─────────────────────────────────────────────────────────────────────────────
daytrend_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"
with open(daytrend_path, "r", encoding="utf-8") as f:
    daytrend = f.read()

# 3.1 Add using directives
old_using = '''@using CcDashboard.Application.Queries.Widgets
@using CcDashboard.Infrastructure.Persistence'''

new_using = '''@using CcDashboard.Application.Queries.Widgets
@using CcDashboard.Application.Queries.Configuration
@using CcDashboard.Contracts.DTOs
@using CcDashboard.Infrastructure.Persistence'''

daytrend = daytrend.replace(old_using, new_using)

# 3.2 Add IsViewMode parameter
old_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public Guid WidgetInstanceId { get; set; }'''

new_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public Guid WidgetInstanceId { get; set; }
    [Parameter] public bool IsViewMode { get; set; }'''

daytrend = daytrend.replace(old_params, new_params)

# 3.3 Add view mode fields after existing private fields
old_fields = '''    // Colors
    private string _backgroundColor = "";'''

new_fields = '''    // View-mode local config
    private bool _showViewConfig;
    private List<BusinessUnitDto> _viewBuList = [];
    private int _localBuId;                          // 0 = use saved config value
    private HashSet<string>? _localMetricIds;        // null = use saved config
    private HashSet<string>? _localAgentMetricIds;   // null = use saved config

    private string LocalStorageKey => $"cc:daytrendview:{WidgetInstanceId}";

    // Effective values used for data loading and rendering
    private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;

    // Colors
    private string _backgroundColor = "";'''

daytrend = daytrend.replace(old_fields, new_fields)

# 3.4 Update OnInitializedAsync to call LoadLocalOverridesAsync
old_init = '''    protected override async Task OnInitializedAsync()
    {
        await LoadMetricsFromDbAsync();
        ParseConfig();
        _lastBusinessUnitId = _businessUnitId;
        _lastIntervalMinutes = _intervalMinutes;
        await LoadDataAsync();
        StartAutoRefresh();
    }'''

new_init = '''    protected override async Task OnInitializedAsync()
    {
        await LoadMetricsFromDbAsync();
        ParseConfig();
        _lastBusinessUnitId = _businessUnitId;
        _lastIntervalMinutes = _intervalMinutes;
        if (IsViewMode)
            await LoadLocalOverridesAsync();
        await LoadDataAsync();
        StartAutoRefresh();
    }'''

daytrend = daytrend.replace(old_init, new_init)

# 3.5 Update LoadDataAsync to use EffectiveBuId
old_load_check = '''    private async Task LoadDataAsync()
    {
        if (_businessUnitId == 0)'''

new_load_check = '''    private async Task LoadDataAsync()
    {
        if (EffectiveBuId == 0)'''

daytrend = daytrend.replace(old_load_check, new_load_check)

old_query = '''            var result = await Mediator.Send(new DayTrendQuery(
                _businessUnitId,
                _intervalMinutes,
                includeAgentMetrics), _cts.Token);'''

new_query = '''            var result = await Mediator.Send(new DayTrendQuery(
                EffectiveBuId,
                _intervalMinutes,
                includeAgentMetrics), _cts.Token);'''

daytrend = daytrend.replace(old_query, new_query)

# 3.6 Add new methods before DisposeAsync
old_dispose = '''    public async ValueTask DisposeAsync()'''

new_methods_and_dispose = '''    private async Task LoadLocalOverridesAsync()
    {
        try
        {
            var json = await JS.InvokeAsync<string?>("localStorage.getItem", LocalStorageKey);
            if (string.IsNullOrEmpty(json)) return;

            var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.TryGetProperty("buId", out var buEl) && buEl.TryGetInt32(out var buId) && buId > 0)
                _localBuId = buId;

            if (root.TryGetProperty("metrics", out var mEl) && mEl.ValueKind == JsonValueKind.Array)
            {
                _localMetricIds = mEl.EnumerateArray()
                    .Select(x => x.GetString() ?? "")
                    .Where(s => !string.IsNullOrEmpty(s))
                    .ToHashSet();
                _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();
            }

            if (root.TryGetProperty("agentMetrics", out var amEl) && amEl.ValueKind == JsonValueKind.Array)
            {
                _localAgentMetricIds = amEl.EnumerateArray()
                    .Select(x => x.GetString() ?? "")
                    .Where(s => !string.IsNullOrEmpty(s))
                    .ToHashSet();
                _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();
            }
        }
        catch (Exception ex)
        {
            Logger.LogDebug(ex, "DayTrendWidget: failed to load local overrides");
        }
    }

    private async Task SaveLocalOverridesAsync()
    {
        var obj = new
        {
            buId = _localBuId,
            metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray()
        };
        var json = JsonSerializer.Serialize(obj);
        await JS.InvokeVoidAsync("localStorage.setItem", LocalStorageKey, json);
    }

    private async Task ClearLocalOverridesAsync()
    {
        await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);
        _localBuId = 0;
        _localMetricIds = null;
        _localAgentMetricIds = null;
        _showViewConfig = false;
        ParseConfig();
        await LoadMetricsFromDbAsync();
        await LoadDataAsync();
    }

    private async Task OpenViewConfigAsync()
    {
        if (!_viewBuList.Any())
            _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

        // Pre-select current effective values in the metric lists
        if (_localMetricIds is not null)
            _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();

        if (_localAgentMetricIds is not null)
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();

        _showViewConfig = true;
    }

    private async Task ApplyViewConfigAsync()
    {
        await SaveLocalOverridesAsync();
        _showViewConfig = false;
        await LoadDataAsync();
    }

    public async ValueTask DisposeAsync()'''

daytrend = daytrend.replace(old_dispose, new_methods_and_dispose)

# 3.7 Add settings button and modal in HTML
old_widget_div = '''<div class="daytrend-widget h-100" style="@GetWidgetStyle()">
    @if (_loading)'''

new_widget_div = '''<div class="daytrend-widget h-100" style="@GetWidgetStyle()">
    @if (IsViewMode)
    {
        <button class="btn btn-sm btn-link p-0 daytrendview-settings-btn"
                title="@L["Widget_LocalViewSettings"]"
                @onclick="OpenViewConfigAsync">
            <i class="bi bi-sliders" style="font-size: 0.9rem;"></i>
        </button>
    }

    @if (_loading)'''

daytrend = daytrend.replace(old_widget_div, new_widget_div)

# Add modal before closing </div> of root
old_closing = '''    </div>
</div>

@code {'''

new_closing = '''    </div>

    @if (IsViewMode && _showViewConfig)
    {
        <div class="modal fade show d-block" tabindex="-1" style="background:rgba(0,0,0,0.5);">
            <div class="modal-dialog modal-lg">
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
</div>

@code {'''

daytrend = daytrend.replace(old_closing, new_closing)

atomic_write(daytrend_path, daytrend)

# ─────────────────────────────────────────────────────────────────────────────
# 4. DayTrendWidget.razor.css — add CSS for settings button
# ─────────────────────────────────────────────────────────────────────────────
css_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor.css"
css_content = """.daytrendview-settings-btn {
    position: absolute;
    top: 4px;
    right: 4px;
    z-index: 10;
    opacity: 0.4;
    transition: opacity 0.2s;
    color: inherit;
}
.daytrend-widget:hover .daytrendview-settings-btn {
    opacity: 1;
}
"""
atomic_write(css_path, css_content)

# ─────────────────────────────────────────────────────────────────────────────
# 5. Localization files — add new keys
# ─────────────────────────────────────────────────────────────────────────────
new_keys_en = '''  <data name="Widget_LocalViewSettings"><value>Local view settings</value></data>
  <data name="Widget_UseDefault"><value>Use default</value></data>
  <data name="Widget_ResetToDefault"><value>Reset to default</value></data>
  <data name="Apply"><value>Apply</value></data>'''

new_keys_ru = '''  <data name="Widget_LocalViewSettings"><value>Локальные настройки отображения</value></data>
  <data name="Widget_UseDefault"><value>Использовать по умолчанию</value></data>
  <data name="Widget_ResetToDefault"><value>Сбросить к настройкам</value></data>
  <data name="Apply"><value>Применить</value></data>'''

new_keys_he = '''  <data name="Widget_LocalViewSettings"><value>הגדרות תצוגה מקומיות</value></data>
  <data name="Widget_UseDefault"><value>השתמש בברירת מחדל</value></data>
  <data name="Widget_ResetToDefault"><value>אפס לברירת מחדל</value></data>
  <data name="Apply"><value>החל</value></data>'''

resx_files = [
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.en-US.resx", new_keys_en),
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.ru-RU.resx", new_keys_ru),
    (r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.he-IL.resx", new_keys_he),
]

for resx_path, new_keys in resx_files:
    with open(resx_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check if keys already exist
    if "Widget_LocalViewSettings" not in content:
        # Insert before </root>
        content = content.replace("</root>", new_keys + "\n</root>")
        atomic_write(resx_path, content)
    else:
        print(f"Skipped: {resx_path} (keys already exist)")

print("\nDone. Run: dotnet build CcDashboard.sln")
