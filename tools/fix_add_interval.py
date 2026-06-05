#!/usr/bin/env python3
"""Add Time Interval selector to DayTrend local view settings General tab."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"

def main():
    print(f"Processing {PATH}")

    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add interval fields after _localBuId
    text = text.replace(
        "    private int _localBuId;                          // 0 = use saved config value",
        """    private int _localBuId;                          // 0 = use saved config value
    private int _localIntervalMinutes;                   // 0 = use saved config value
    private int _viewIntervalMinutes = 30;               // current selection in modal"""
    )

    # 2. Add EffectiveIntervalMinutes after EffectiveBuId
    text = text.replace(
        "    private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;",
        """    private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;
    private int EffectiveIntervalMinutes => _localIntervalMinutes > 0 ? _localIntervalMinutes : _intervalMinutes;"""
    )

    # 3. LoadLocalOverridesAsync: restore interval after agentMetricColors block
    old_load = '''            if (root.TryGetProperty("agentMetricColors", out var amcEl) && amcEl.ValueKind == JsonValueKind.Object)
            {
                _localAgentMetricColors = amcEl.EnumerateObject()
                    .Where(p => !string.IsNullOrEmpty(p.Value.GetString()))
                    .ToDictionary(p => p.Name, p => p.Value.GetString()!);
                _agentMetrics = _agentMetrics.Select(m =>
                    _localAgentMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
            }
        }
        catch (Exception ex)'''

    new_load = '''            if (root.TryGetProperty("agentMetricColors", out var amcEl) && amcEl.ValueKind == JsonValueKind.Object)
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
        catch (Exception ex)'''

    text = text.replace(old_load, new_load)

    # 4. SaveLocalOverridesAsync: add intervalMinutes to obj
    old_save = '''        var obj = new
        {
            buId         = _localBuId,
            metrics      = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType    = _viewChartType,
            metricColors = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
            agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
        };'''

    new_save = '''        var obj = new
        {
            buId            = _localBuId,
            metrics         = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            agentMetrics    = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
            chartType       = _viewChartType,
            intervalMinutes = _viewIntervalMinutes,
            metricColors    = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
            agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
        };'''

    text = text.replace(old_save, new_save)

    # 5. ApplyViewConfigAsync: add _localIntervalMinutes after _localChartType
    text = text.replace(
        "        _localChartType = _viewChartType;\n\n        _showViewConfig = false;",
        "        _localChartType = _viewChartType;\n        _localIntervalMinutes = _viewIntervalMinutes;\n\n        _showViewConfig = false;"
    )

    # 6. ClearLocalOverridesAsync: reset interval fields
    text = text.replace(
        "        _localChartType = null;\n        _viewChartType = _chartType;",
        "        _localChartType = null;\n        _localIntervalMinutes = 0;\n        _viewIntervalMinutes = _intervalMinutes;\n        _viewChartType = _chartType;"
    )

    # 7. OpenLocalConfigAsync: add interval pre-populate after _viewChartType
    text = text.replace(
        "        _viewChartType = _localChartType ?? _chartType;\n\n        // Pre-select current effective values",
        "        _viewChartType = _localChartType ?? _chartType;\n        _viewIntervalMinutes = _localIntervalMinutes > 0 ? _localIntervalMinutes : _intervalMinutes;\n\n        // Pre-select current effective values"
    )

    # 8. LoadDataAsync: use EffectiveIntervalMinutes instead of _intervalMinutes
    text = text.replace(
        "            var result = await Mediator.Send(new DayTrendQuery(\n                EffectiveBuId,\n                _intervalMinutes,",
        "            var result = await Mediator.Send(new DayTrendQuery(\n                EffectiveBuId,\n                EffectiveIntervalMinutes,"
    )

    # 9. General tab HTML: add time interval buttons after chart type selector
    old_general = '''                                <div class="mb-3">
                                    <label class="form-label fw-semibold">@L["DayTrend_ChartType"]</label>
                                    <select class="form-select form-select-sm" @bind="_viewChartType">
                                        <option value="line">@L["DayTrend_ChartLine"]</option>
                                        <option value="bar">@L["DayTrend_ChartBar"]</option>
                                        <option value="area">@L["DayTrend_ChartArea"]</option>
                                        <option value="step">@L["DayTrend_ChartStep"]</option>
                                    </select>
                                </div>
                            }'''

    new_general = '''                                <div class="mb-3">
                                    <label class="form-label fw-semibold">@L["DayTrend_ChartType"]</label>
                                    <select class="form-select form-select-sm" @bind="_viewChartType">
                                        <option value="line">@L["DayTrend_ChartLine"]</option>
                                        <option value="bar">@L["DayTrend_ChartBar"]</option>
                                        <option value="area">@L["DayTrend_ChartArea"]</option>
                                        <option value="step">@L["DayTrend_ChartStep"]</option>
                                    </select>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label fw-semibold">@L["DayTrend_TimeInterval"]</label>
                                    <div class="btn-group w-100" role="group">
                                        <button type="button"
                                                class="btn btn-sm @(_viewIntervalMinutes == 15 ? "btn-primary" : "btn-outline-secondary")"
                                                @onclick='() => _viewIntervalMinutes = 15'>15 min</button>
                                        <button type="button"
                                                class="btn btn-sm @(_viewIntervalMinutes == 30 ? "btn-primary" : "btn-outline-secondary")"
                                                @onclick='() => _viewIntervalMinutes = 30'>30 min</button>
                                        <button type="button"
                                                class="btn btn-sm @(_viewIntervalMinutes == 60 ? "btn-primary" : "btn-outline-secondary")"
                                                @onclick='() => _viewIntervalMinutes = 60'>60 min</button>
                                    </div>
                                </div>
                            }'''

    text = text.replace(old_general, new_general)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    main()
