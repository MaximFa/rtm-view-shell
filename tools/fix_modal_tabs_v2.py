#!/usr/bin/env python3
"""Add 3-tab layout to DayTrend local view settings modal."""
import os

BASE = r"D:\Claude\Projects\RTM View Shell"

def fix_razor():
    path = os.path.join(BASE, "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add _viewTab field after _showViewConfig
    text = text.replace(
        "    private bool _showViewConfig;",
        '    private bool _showViewConfig;\n    private string _viewTab = "general";'
    )

    # 2. Add _viewTab = "general"; in OpenLocalConfigAsync before _showViewConfig = true;
    text = text.replace(
        "        _showViewConfig = true;\n    }",
        '        _viewTab = "general";\n        _showViewConfig = true;\n    }'
    )

    # 3. Replace flat modal-body with tabbed version
    old_modal_body = '''<div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
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
                            <div class="mt-3 mb-2 fw-semibold small">@L["DayTrend_AgentMetrics"]</div>
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
                    </div>'''

    new_modal_body = '''<div class="modal-body p-0">
                        <ul class="nav nav-tabs px-3 pt-2 border-bottom">
                            <li class="nav-item">
                                <button class="nav-link @(_viewTab=="general"?"active":"")" @onclick='()=>_viewTab="general"'>
                                    @L["DayTrend_TabGeneral"]
                                </button>
                            </li>
                            <li class="nav-item">
                                <button class="nav-link @(_viewTab=="queue"?"active":"")" @onclick='()=>_viewTab="queue"'>
                                    @L["DayTrend_TabQueueMetrics"]
                                </button>
                            </li>
                            <li class="nav-item">
                                <button class="nav-link @(_viewTab=="agent"?"active":"")" @onclick='()=>_viewTab="agent"'>
                                    @L["DayTrend_TabAgentMetrics"]
                                </button>
                            </li>
                        </ul>

                        <div style="max-height: 55vh; overflow-y: auto; padding: 1rem;">

                            @if (_viewTab == "general")
                            {
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
                                <div class="mb-3">
                                    <label class="form-label fw-semibold">@L["DayTrend_ChartType"]</label>
                                    <select class="form-select form-select-sm" @bind="_viewChartType">
                                        <option value="line">@L["DayTrend_ChartLine"]</option>
                                        <option value="bar">@L["DayTrend_ChartBar"]</option>
                                        <option value="area">@L["DayTrend_ChartArea"]</option>
                                        <option value="step">@L["DayTrend_ChartStep"]</option>
                                    </select>
                                </div>
                            }

                            @if (_viewTab == "queue")
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
                            }

                            @if (_viewTab == "agent")
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
                            }

                        </div>
                    </div>'''

    text = text.replace(old_modal_body, new_modal_body)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    fix_razor()
    print("\nDayTrendWidget.razor updated with 3-tab modal!")
