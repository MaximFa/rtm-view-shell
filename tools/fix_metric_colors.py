#!/usr/bin/env python3
"""Add color picker per metric in DayTrend local view settings."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"

def main():
    print(f"Processing {PATH}")

    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add color dictionary fields after _localAgentMetricIds
    text = text.replace(
        "    private HashSet<string>? _localAgentMetricIds;   // null = use saved config",
        """    private HashSet<string>? _localAgentMetricIds;   // null = use saved config
    private Dictionary<string, string> _localMetricColors = new();
    private Dictionary<string, string> _localAgentMetricColors = new();"""
    )

    # 2. LoadLocalOverridesAsync: restore colors after chartType block
    old_charttype_block = '''            if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
            {
                _localChartType = ctEl.GetString();
                _viewChartType = _localChartType ?? "line";
            }
        }
        catch (Exception ex)'''

    new_charttype_block = '''            if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
            {
                _localChartType = ctEl.GetString();
                _viewChartType = _localChartType ?? "line";
            }

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
        }
        catch (Exception ex)'''

    text = text.replace(old_charttype_block, new_charttype_block)

    # 3. SaveLocalOverridesAsync: include colors
    old_save = '''        var obj = new
        {
            buId = _localBuId,
            metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType = _viewChartType
        };'''

    new_save = '''        var obj = new
        {
            buId         = _localBuId,
            metrics      = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType    = _viewChartType,
            metricColors = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
            agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
        };'''

    text = text.replace(old_save, new_save)

    # 4. ApplyViewConfigAsync: update color caches
    old_apply = '''        _localAgentMetricIds = _agentMetrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localChartType = _viewChartType;'''

    new_apply = '''        _localAgentMetricIds = _agentMetrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localMetricColors = _metrics.ToDictionary(m => m.MetricId, m => m.Color);
        _localAgentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color);
        _localChartType = _viewChartType;'''

    text = text.replace(old_apply, new_apply)

    # 5. ClearLocalOverridesAsync: reset color caches
    old_clear = '''        _localAgentMetricIds = null;
        _localChartType = null;'''

    new_clear = '''        _localAgentMetricIds = null;
        _localMetricColors = new();
        _localAgentMetricColors = new();
        _localChartType = null;'''

    text = text.replace(old_clear, new_clear)

    # 6. OpenLocalConfigAsync: re-apply colors
    old_open = '''        if (_localAgentMetricIds is not null)
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();

        _viewTab = "general";'''

    new_open = '''        if (_localAgentMetricIds is not null)
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();

        if (_localMetricColors.Any())
            _metrics = _metrics.Select(m =>
                _localMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();

        if (_localAgentMetricColors.Any())
            _agentMetrics = _agentMetrics.Select(m =>
                _localAgentMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();

        _viewTab = "general";'''

    text = text.replace(old_open, new_open)

    # 7. Modal HTML: replace queue metrics tab
    old_queue_tab = '''                            @if (_viewTab == "queue")
                            {
                                @foreach (var m in _metrics)
                                {
                                    var metric = m;
                                    <div class="form-check form-check-sm mb-2">
                                        <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                                               checked="@metric.Enabled"
                                               @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                                        <label class="form-check-label" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
                                    </div>
                                }
                            }'''

    new_queue_tab = '''                            @if (_viewTab == "queue")
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
                            }'''

    text = text.replace(old_queue_tab, new_queue_tab)

    # 7b. Modal HTML: replace agent metrics tab
    old_agent_tab = '''                            @if (_viewTab == "agent")
                            {
                                @if (_agentMetrics.Any())
                                {
                                    @foreach (var m in _agentMetrics)
                                    {
                                        var metric = m;
                                        <div class="form-check form-check-sm mb-2">
                                            <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                                                   checked="@metric.Enabled"
                                                   @onchange="e => { var idx = _agentMetrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _agentMetrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                                            <label class="form-check-label" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
                                        </div>
                                    }
                                }
                                else
                                {
                                    <p class="text-muted small">@L["DayTrend_NoAgentMetrics"]</p>
                                }
                            }'''

    new_agent_tab = '''                            @if (_viewTab == "agent")
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
                            }'''

    text = text.replace(old_agent_tab, new_agent_tab)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    main()
