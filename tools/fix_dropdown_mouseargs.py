#!/usr/bin/env python3
"""Replace JS.InvokeAsync with MouseEventArgs for dropdown positioning."""
import os

razor_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(razor_path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix 1: OpenMetricDropdown - async JS → sync MouseEventArgs
old_open_metric = '''    private async Task OpenMetricDropdown(string colId)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"metric-{colId}");
        _dropdownRects[$"metric-{colId}"] = rect;
        StateHasChanged();
    }'''

new_open_metric = '''    private void OpenMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"metric-{colId}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

if old_open_metric not in text:
    print("ERROR: OpenMetricDropdown async pattern not found")
    exit(1)
text = text.replace(old_open_metric, new_open_metric)

# Fix 2: OpenQueueRowBuDropdown - async JS → sync MouseEventArgs
old_open_bu = '''    private async Task OpenQueueRowBuDropdown(int rowIdx)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"queuerowbu-{rowIdx}");
        _dropdownRects[$"queuerowbu-{rowIdx}"] = rect;
        StateHasChanged();
    }'''

new_open_bu = '''    private void OpenQueueRowBuDropdown(int rowIdx, MouseEventArgs e)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"queuerowbu-{rowIdx}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

if old_open_bu not in text:
    print("ERROR: OpenQueueRowBuDropdown async pattern not found")
    exit(1)
text = text.replace(old_open_bu, new_open_bu)

# Fix 3: OpenQueueMetricDropdown - async JS → sync MouseEventArgs
old_open_qm = '''    private async Task OpenQueueMetricDropdown(string colId)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"queuemetric-{colId}");
        _dropdownRects[$"queuemetric-{colId}"] = rect;
        StateHasChanged();
    }'''

new_open_qm = '''    private void OpenQueueMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"queuemetric-{colId}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

if old_open_qm not in text:
    print("ERROR: OpenQueueMetricDropdown async pattern not found")
    exit(1)
text = text.replace(old_open_qm, new_open_qm)

# Fix 4: Update @onclick handlers to pass MouseEventArgs
# AgentGrid metric
text = text.replace(
    '@onclick="() => OpenMetricDropdown(colId)"',
    '@onclick="e => OpenMetricDropdown(colId, e)"'
)

# QueueGrid BU
text = text.replace(
    '@onclick="() => OpenQueueRowBuDropdown(rowIdx)"',
    '@onclick="e => OpenQueueRowBuDropdown(rowIdx, e)"'
)

# QueueGrid metric
text = text.replace(
    '@onclick="() => OpenQueueMetricDropdown(colId)"',
    '@onclick="e => OpenQueueMetricDropdown(colId, e)"'
)

# Fix 5: Update GetDropdownStyle to have visible fallback
old_style = '''    private string GetDropdownStyle(string prefix, string id)
    {
        var key = $"{prefix}{id}";
        var r = _dropdownRects.GetValueOrDefault(key);
        if (r == null)
            return "position: fixed; top: 0; left: 0; width: 200px; max-height: 200px; overflow-y: auto; z-index: 1060; display: none;";
        return $"position: fixed; top: {r.Top:F0}px; left: {r.Left:F0}px; width: {r.Width:F0}px; max-height: 200px; overflow-y: auto; z-index: 1060;";
    }'''

new_style = '''    private string GetDropdownStyle(string prefix, string id)
    {
        var key = $"{prefix}{id}";
        var r = _dropdownRects.GetValueOrDefault(key);
        if (r == null)
            return "position: fixed; top: 100px; left: 100px; width: 280px; max-height: 200px; overflow-y: auto; z-index: 1060;";
        return $"position: fixed; top: {r.Top:F0}px; left: {r.Left:F0}px; width: {r.Width:F0}px; max-height: 200px; overflow-y: auto; z-index: 1060;";
    }'''

if old_style not in text:
    print("ERROR: GetDropdownStyle pattern not found")
    exit(1)
text = text.replace(old_style, new_style)

with open(razor_path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed ScreenEditorPage.razor ({len(text.splitlines())} lines)")

# Optional: Remove JS helper from app.js (leave it for now - doesn't hurt)
js_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\wwwroot\js\app.js"
with open(js_path, "r", encoding="utf-8") as f:
    js_text = f.read()

# Remove getDropdownAnchorPosition if exists
old_js = '''

window.getDropdownAnchorPosition = function (dataId) {
    const el = document.querySelector('[data-dropdown-id="' + dataId + '"]');
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    const viewportHeight = window.innerHeight;
    const dropdownHeight = 220; // max-height 200 + buffer
    const spaceBelow = viewportHeight - rect.bottom;
    const openUpward = spaceBelow < dropdownHeight && rect.top > dropdownHeight;
    return {
        top: openUpward ? (rect.top - dropdownHeight + 20) : rect.bottom,
        left: rect.left,
        width: rect.width,
        openUpward: openUpward
    };
};'''

if old_js in js_text:
    js_text = js_text.replace(old_js, '')
    with open(js_path, "w", encoding="utf-8") as f:
        f.write(js_text)
        f.flush()
        os.fsync(f.fileno())
    print(f"Removed getDropdownAnchorPosition from app.js ({len(js_text.splitlines())} lines)")
else:
    print("app.js: getDropdownAnchorPosition not found or already removed")
