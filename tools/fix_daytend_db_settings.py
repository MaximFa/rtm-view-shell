#!/usr/bin/env python3
"""Replace localStorage with UserWidgetSettings DB table in DayTrendWidget."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"

def main():
    print(f"Processing {PATH}")

    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add @using for Commands.Widgets after the first @using line
    text = text.replace(
        "@using CcDashboard.Application.Queries.Widgets\n@using CcDashboard.Application.Queries.Configuration",
        "@using CcDashboard.Application.Queries.Widgets\n@using CcDashboard.Application.Commands.Widgets\n@using CcDashboard.Application.Queries.Configuration"
    )

    # 2. Remove @inject CurrentUser line
    text = text.replace(
        "@inject CcDashboard.Domain.Interfaces.ICurrentUserAccessor CurrentUser\n",
        ""
    )

    # 3. Remove LocalStorageKey property
    text = text.replace(
        '''    private string LocalStorageKey =>
        $"cc:daytrendview:{CurrentUser.UserId}:{WidgetInstanceId}";

    // Effective values''',
        "    // Effective values"
    )

    # 4. Replace LoadLocalOverridesAsync method
    old_load = '''    private async Task LoadLocalOverridesAsync()
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

            if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
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

            if (root.TryGetProperty("intervalMinutes", out var intEl) && intEl.TryGetInt32(out var intVal) && intVal > 0)
            {
                _localIntervalMinutes = intVal;
                _viewIntervalMinutes  = intVal;
            }
        }
        catch (Exception ex)
        {
            Logger.LogDebug(ex, "DayTrendWidget: failed to load local overrides");
        }
    }'''

    new_load = '''    private async Task LoadLocalOverridesAsync()
    {
        try
        {
            var json = await Mediator.Send(new GetUserWidgetSettingsQuery(WidgetInstanceId), _cts.Token);
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

            if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
            {
                _localChartType = ctEl.GetString();
                _viewChartType = _localChartType ?? "line";
            }

            if (root.TryGetProperty("intervalMinutes", out var intEl) && intEl.TryGetInt32(out var intVal) && intVal > 0)
            {
                _localIntervalMinutes = intVal;
                _viewIntervalMinutes  = intVal;
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
        catch (Exception ex)
        {
            Logger.LogDebug(ex, "DayTrendWidget: failed to load user widget settings");
        }
    }'''

    text = text.replace(old_load, new_load)

    # 5. Replace SaveLocalOverridesAsync method
    old_save = '''    private async Task SaveLocalOverridesAsync()
    {
        _localChartType = _viewChartType;
        var obj = new
        {
            buId            = _localBuId,
            metrics         = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics    = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType       = _viewChartType,
            intervalMinutes = _viewIntervalMinutes,
            metricColors    = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
            agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
        };
        var json = JsonSerializer.Serialize(obj);
        await JS.InvokeVoidAsync("localStorage.setItem", LocalStorageKey, json);
    }'''

    new_save = '''    private async Task SaveLocalOverridesAsync()
    {
        _localChartType = _viewChartType;
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
        var json = JsonSerializer.Serialize(obj);
        await Mediator.Send(new SaveUserWidgetSettingsCommand(WidgetInstanceId, json), _cts.Token);
    }'''

    text = text.replace(old_save, new_save)

    # 6. Replace ClearLocalOverridesAsync: localStorage.removeItem -> DeleteUserWidgetSettingsCommand
    text = text.replace(
        'await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);',
        'await Mediator.Send(new DeleteUserWidgetSettingsCommand(WidgetInstanceId), _cts.Token);'
    )

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    main()
