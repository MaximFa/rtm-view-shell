#!/usr/bin/env python3
"""Fix dropdown clipping in configurator modals (position: fixed + flip)."""
import os

# Step 1: Add JS helper to app.js
js_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\wwwroot\js\app.js"
with open(js_path, "r", encoding="utf-8") as f:
    js_text = f.read()

js_addition = '''

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
};
'''

if "getDropdownAnchorPosition" not in js_text:
    js_text = js_text.rstrip() + js_addition
    with open(js_path, "w", encoding="utf-8") as f:
        f.write(js_text)
        f.flush()
        os.fsync(f.fileno())
    print(f"Fixed app.js ({len(js_text.splitlines())} lines)")
else:
    print("app.js already has getDropdownAnchorPosition")

# Step 2-9: Fix ScreenEditorPage.razor
razor_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(razor_path, "r", encoding="utf-8") as f:
    razor_text = f.read()

# Step 2: Add record and dictionary after _metricSearchText
old_state = '''    // Metric dropdown state
    private string? _activeMetricDropdown;
    private string _metricSearchText = "";'''

new_state = '''    // Metric dropdown state
    private string? _activeMetricDropdown;
    private string _metricSearchText = "";

    // Dropdown positioning (fixed + flip)
    private record DropdownRect(double Top, double Left, double Width, bool OpenUpward);
    private Dictionary<string, DropdownRect?> _dropdownRects = new();'''

if old_state not in razor_text:
    print("ERROR: State block not found")
    exit(1)
razor_text = razor_text.replace(old_state, new_state)

# Step 3a: Update OpenMetricDropdown
old_open_metric = '''    private void OpenMetricDropdown(string colId)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
    }'''

new_open_metric = '''    private async Task OpenMetricDropdown(string colId)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"metric-{colId}");
        _dropdownRects[$"metric-{colId}"] = rect;
        StateHasChanged();
    }'''

if old_open_metric not in razor_text:
    print("ERROR: OpenMetricDropdown not found")
    exit(1)
razor_text = razor_text.replace(old_open_metric, new_open_metric)

# Step 3b: Update OpenQueueRowBuDropdown
old_open_bu = '''    private void OpenQueueRowBuDropdown(int rowIdx)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
    }'''

new_open_bu = '''    private async Task OpenQueueRowBuDropdown(int rowIdx)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"queuerowbu-{rowIdx}");
        _dropdownRects[$"queuerowbu-{rowIdx}"] = rect;
        StateHasChanged();
    }'''

if old_open_bu not in razor_text:
    print("ERROR: OpenQueueRowBuDropdown not found")
    exit(1)
razor_text = razor_text.replace(old_open_bu, new_open_bu)

# Step 3c: Update OpenQueueMetricDropdown
old_open_qm = '''    private void OpenQueueMetricDropdown(string colId)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
    }'''

new_open_qm = '''    private async Task OpenQueueMetricDropdown(string colId)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
        var rect = await JS.InvokeAsync<DropdownRect?>("getDropdownAnchorPosition", $"queuemetric-{colId}");
        _dropdownRects[$"queuemetric-{colId}"] = rect;
        StateHasChanged();
    }'''

if old_open_qm not in razor_text:
    print("ERROR: OpenQueueMetricDropdown not found")
    exit(1)
razor_text = razor_text.replace(old_open_qm, new_open_qm)

# Step 4a + 5a: AgentGrid metric input + dropdown
old_agent_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select metric..."
                                                           value="@(_activeMetricDropdown == colId ? _metricSearchText : GetMetricDescription(col.MetricId))"
                                                           @onclick="() => OpenMetricDropdown(colId)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnMetricSearch(e.Value?.ToString())" />
                                                    @if (_activeMetricDropdown == colId)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseMetricDropdown"></div>
                                                        <div class="dropdown-menu show w-100" style="max-height: 200px; overflow-y: auto; position: absolute; top: 100%; left: 0; z-index: 1050;"
                                                             @onclick:stopPropagation>'''

new_agent_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select metric..."
                                                           data-dropdown-id="metric-@colId"
                                                           value="@(_activeMetricDropdown == colId ? _metricSearchText : GetMetricDescription(col.MetricId))"
                                                           @onclick="() => OpenMetricDropdown(colId)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnMetricSearch(e.Value?.ToString())" />
                                                    @if (_activeMetricDropdown == colId)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseMetricDropdown"></div>
                                                        <div class="dropdown-menu show" style="@GetDropdownStyle("metric-", colId)"
                                                             @onclick:stopPropagation>'''

if old_agent_input not in razor_text:
    print("ERROR: AgentGrid metric input block not found")
    exit(1)
razor_text = razor_text.replace(old_agent_input, new_agent_input)

# Step 4b + 5b: QueueGrid BU input + dropdown
old_bu_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select Business Unit..."
                                                           value="@(_queueRowBuDropdownOpenFor == rowIdx ? _queueRowBuSearchText : row.BusinessUnitName ?? "")"
                                                           @onclick="() => OpenQueueRowBuDropdown(rowIdx)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnQueueRowBuSearch(e.Value?.ToString())" />
                                                    @if (_queueRowBuDropdownOpenFor == rowIdx)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseQueueRowBuDropdown"></div>
                                                        <div class="dropdown-menu show w-100" style="max-height: 200px; overflow-y: auto; position: absolute; top: 100%; left: 0; z-index: 1050;"
                                                             @onclick:stopPropagation>'''

new_bu_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select Business Unit..."
                                                           data-dropdown-id="queuerowbu-@rowIdx"
                                                           value="@(_queueRowBuDropdownOpenFor == rowIdx ? _queueRowBuSearchText : row.BusinessUnitName ?? "")"
                                                           @onclick="() => OpenQueueRowBuDropdown(rowIdx)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnQueueRowBuSearch(e.Value?.ToString())" />
                                                    @if (_queueRowBuDropdownOpenFor == rowIdx)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseQueueRowBuDropdown"></div>
                                                        <div class="dropdown-menu show" style="@GetDropdownStyle("queuerowbu-", rowIdx.ToString())"
                                                             @onclick:stopPropagation>'''

if old_bu_input not in razor_text:
    print("ERROR: QueueGrid BU input block not found")
    exit(1)
razor_text = razor_text.replace(old_bu_input, new_bu_input)

# Step 4c + 5c: QueueGrid metric input + dropdown
old_qm_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select metric..."
                                                           value="@(_activeQueueMetricDropdown == colId ? _queueColumnMetricSearch : GetMetricDescription(col.MetricId))"
                                                           @onclick="() => OpenQueueMetricDropdown(colId)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnQueueMetricSearch(e.Value?.ToString())" />
                                                    @if (_activeQueueMetricDropdown == colId)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseQueueMetricDropdown"></div>
                                                        <div class="dropdown-menu show w-100" style="max-height: 200px; overflow-y: auto; position: absolute; top: 100%; left: 0; z-index: 1050;"
                                                             @onclick:stopPropagation>'''

new_qm_input = '''<input type="text" class="form-control form-control-sm"
                                                           placeholder="Select metric..."
                                                           data-dropdown-id="queuemetric-@colId"
                                                           value="@(_activeQueueMetricDropdown == colId ? _queueColumnMetricSearch : GetMetricDescription(col.MetricId))"
                                                           @onclick="() => OpenQueueMetricDropdown(colId)"
                                                           @onclick:stopPropagation
                                                           @oninput="e => OnQueueMetricSearch(e.Value?.ToString())" />
                                                    @if (_activeQueueMetricDropdown == colId)
                                                    {
                                                        <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 1040;"
                                                             @onclick="CloseQueueMetricDropdown"></div>
                                                        <div class="dropdown-menu show" style="@GetDropdownStyle("queuemetric-", colId)"
                                                             @onclick:stopPropagation>'''

if old_qm_input not in razor_text:
    print("ERROR: QueueGrid metric input block not found")
    exit(1)
razor_text = razor_text.replace(old_qm_input, new_qm_input)

# Step 6: Remove @onscroll from modal-body
old_modal = '<div class="modal-body" style="height: 700px; overflow-y: auto; overflow-x: hidden;" @onscroll="CloseMetricDropdown">'
new_modal = '<div class="modal-body" style="height: 700px; overflow-y: auto; overflow-x: hidden;">'

if old_modal not in razor_text:
    print("ERROR: modal-body with @onscroll not found")
    exit(1)
razor_text = razor_text.replace(old_modal, new_modal)

# Step 6b: Also remove @onscroll from columns-table-body
old_col_body = '<div class="columns-table-body" @onscroll="CloseMetricDropdown">'
new_col_body = '<div class="columns-table-body">'

if old_col_body in razor_text:
    razor_text = razor_text.replace(old_col_body, new_col_body)
    print("Also removed @onscroll from columns-table-body")

# Step 7: Add GetDropdownStyle helper method after CloseMetricDropdown
old_close = '''    private void CloseMetricDropdown()
    {
        _activeMetricDropdown = null;
        _metricSearchText = "";
    }'''

new_close = '''    private void CloseMetricDropdown()
    {
        _activeMetricDropdown = null;
        _metricSearchText = "";
    }

    private string GetDropdownStyle(string prefix, string id)
    {
        var key = $"{prefix}{id}";
        var r = _dropdownRects.GetValueOrDefault(key);
        if (r == null)
            return "position: fixed; top: 0; left: 0; width: 200px; max-height: 200px; overflow-y: auto; z-index: 1060; display: none;";
        return $"position: fixed; top: {r.Top:F0}px; left: {r.Left:F0}px; width: {r.Width:F0}px; max-height: 200px; overflow-y: auto; z-index: 1060;";
    }'''

if old_close not in razor_text:
    print("ERROR: CloseMetricDropdown not found for adding helper")
    exit(1)
razor_text = razor_text.replace(old_close, new_close)

with open(razor_path, "w", encoding="utf-8") as f:
    f.write(razor_text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed ScreenEditorPage.razor ({len(razor_text.splitlines())} lines)")
