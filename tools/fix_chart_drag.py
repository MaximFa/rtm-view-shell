#!/usr/bin/env python3
"""Fix DayTrend: null values → 0, draggable modal header."""
import os

BASE = r"D:\Claude\Projects\RTM View Shell"

def fix_daytrendchart():
    path = os.path.join(BASE, "src/CcDashboard.Web/wwwroot/js/daytrendChart.js")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # Replace data: ds.data with null→0 mapping
    old = "data: ds.data,"
    new = "data: ds.data.map(v => (v === null || v === undefined) ? 0 : v),"

    if old not in text:
        print("  ERROR: pattern not found!")
        return False

    text = text.replace(old, new)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done")
    return True

def fix_appjs():
    path = os.path.join(BASE, "src/CcDashboard.Web/wwwroot/js/app.js")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # Add draggable functions at the end
    new_code = '''
window.ccApp.makeModalDraggable = function (header, dialog) {
    if (!header || !dialog) return;
    var offsetX = 0, offsetY = 0, startX = 0, startY = 0;
    header.style.cursor = 'move';
    header.onmousedown = function (e) {
        e.preventDefault();
        startX = e.clientX - offsetX;
        startY = e.clientY - offsetY;
        document.onmouseup = function () {
            document.onmousemove = null;
            document.onmouseup = null;
        };
        document.onmousemove = function (e) {
            offsetX = e.clientX - startX;
            offsetY = e.clientY - startY;
            dialog.style.transform = 'translate(' + offsetX + 'px, ' + offsetY + 'px)';
        };
    };
};

window.ccApp.resetModalPosition = function (dialog) {
    if (dialog) dialog.style.transform = '';
};
'''

    text = text.rstrip() + new_code

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done")
    return True

def fix_razor():
    path = os.path.join(BASE, "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # 1. Add ElementReference fields after _showViewConfig
    text = text.replace(
        '    private bool _showViewConfig;\n    private string _viewTab = "general";',
        '    private bool _showViewConfig;\n    private string _viewTab = "general";\n    private ElementReference _modalHeader;\n    private ElementReference _modalDialog;'
    )

    # 2. Add CloseModal method after ApplyViewConfigAsync
    old_apply = '''    private async Task ApplyViewConfigAsync()
    {
        await SaveLocalOverridesAsync();

        // Update in-memory caches to match what was just saved,
        // so OpenLocalConfigAsync() re-apply shows correct state on next open.
        _localMetricIds = _metrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localAgentMetricIds = _agentMetrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localChartType = _viewChartType;

        _showViewConfig = false;
        await LoadDataAsync();
    }'''

    new_apply = '''    private async Task ApplyViewConfigAsync()
    {
        await SaveLocalOverridesAsync();

        // Update in-memory caches to match what was just saved,
        // so OpenLocalConfigAsync() re-apply shows correct state on next open.
        _localMetricIds = _metrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localAgentMetricIds = _agentMetrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localChartType = _viewChartType;

        _showViewConfig = false;
        await LoadDataAsync();
    }

    private async Task CloseModal()
    {
        _showViewConfig = false;
        try { await JS.InvokeVoidAsync("ccApp.resetModalPosition", _modalDialog); }
        catch { }
    }'''

    text = text.replace(old_apply, new_apply)

    # 3. Extend OnAfterRenderAsync to include modal draggable
    old_render = '''    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (!firstRender && !_loading && !_isNoQueues && _error is null && _intervals.Count > 0)
        {
            await RenderChartAsync();
        }
    }'''

    new_render = '''    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (!firstRender && !_loading && !_isNoQueues && _error is null && _intervals.Count > 0)
        {
            await RenderChartAsync();
        }
        if (_showViewConfig)
        {
            try { await JS.InvokeVoidAsync("ccApp.makeModalDraggable", _modalHeader, _modalDialog); }
            catch { }
        }
    }'''

    text = text.replace(old_render, new_render)

    # 4. Add @ref to modal dialog and header
    text = text.replace(
        '<div class="modal-dialog modal-lg" @onclick:stopPropagation="true">',
        '<div class="modal-dialog modal-lg" @ref="_modalDialog" @onclick:stopPropagation="true">'
    )
    text = text.replace(
        '<div class="modal-header py-2">',
        '<div class="modal-header py-2" @ref="_modalHeader">'
    )

    # 5. Replace close handlers with CloseModal
    text = text.replace(
        '@onclick="() => _showViewConfig = false"',
        '@onclick="CloseModal"'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done")
    return True

if __name__ == "__main__":
    fix_daytrendchart()
    fix_appjs()
    fix_razor()
    print("\nAll files updated!")
