#!/usr/bin/env python3
"""Fix dropdown alignment — position under/above input field using OffsetX/OffsetY."""
import os

razor_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(razor_path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix 1: OpenMetricDropdown
old_open_metric = '''    private void OpenMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"metric-{colId}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

new_open_metric = '''    private void OpenMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeMetricDropdown = colId;
        _metricSearchText = "";
        _dropdownRects[$"metric-{colId}"] = CalcDropdownRect(e);
    }'''

if old_open_metric not in text:
    print("ERROR: OpenMetricDropdown pattern not found")
    exit(1)
text = text.replace(old_open_metric, new_open_metric)

# Fix 2: OpenQueueRowBuDropdown
old_open_bu = '''    private void OpenQueueRowBuDropdown(int rowIdx, MouseEventArgs e)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"queuerowbu-{rowIdx}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

new_open_bu = '''    private void OpenQueueRowBuDropdown(int rowIdx, MouseEventArgs e)
    {
        _queueRowBuDropdownOpenFor = rowIdx;
        _queueRowBuSearchText = "";
        _dropdownRects[$"queuerowbu-{rowIdx}"] = CalcDropdownRect(e);
    }'''

if old_open_bu not in text:
    print("ERROR: OpenQueueRowBuDropdown pattern not found")
    exit(1)
text = text.replace(old_open_bu, new_open_bu)

# Fix 3: OpenQueueMetricDropdown
old_open_qm = '''    private void OpenQueueMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
        var openUpward = e.ClientY > 600;
        var top = openUpward ? e.ClientY - 210 : e.ClientY + 8;
        _dropdownRects[$"queuemetric-{colId}"] = new DropdownRect(top, e.ClientX - 10, 280, openUpward);
    }'''

new_open_qm = '''    private void OpenQueueMetricDropdown(string colId, MouseEventArgs e)
    {
        _activeQueueMetricDropdown = colId;
        _queueColumnMetricSearch = "";
        _dropdownRects[$"queuemetric-{colId}"] = CalcDropdownRect(e);
    }'''

if old_open_qm not in text:
    print("ERROR: OpenQueueMetricDropdown pattern not found")
    exit(1)
text = text.replace(old_open_qm, new_open_qm)

# Fix 4: Add CalcDropdownRect helper after GetDropdownStyle
old_style_method = '''    private string GetDropdownStyle(string prefix, string id)
    {
        var key = $"{prefix}{id}";
        var r = _dropdownRects.GetValueOrDefault(key);
        if (r == null)
            return "position: fixed; top: 100px; left: 100px; width: 280px; max-height: 200px; overflow-y: auto; z-index: 1060;";
        return $"position: fixed; top: {r.Top:F0}px; left: {r.Left:F0}px; width: {r.Width:F0}px; max-height: 200px; overflow-y: auto; z-index: 1060;";
    }'''

new_style_method = '''    private string GetDropdownStyle(string prefix, string id)
    {
        var key = $"{prefix}{id}";
        var r = _dropdownRects.GetValueOrDefault(key);
        if (r == null)
            return "position: fixed; top: 100px; left: 100px; width: 280px; max-height: 200px; overflow-y: auto; z-index: 1060;";
        return $"position: fixed; top: {r.Top:F0}px; left: {r.Left:F0}px; width: {r.Width:F0}px; max-height: 200px; overflow-y: auto; z-index: 1060;";
    }

    /// Calculates dropdown position aligned to the clicked input/button.
    /// OffsetX/OffsetY = position within the target element.
    /// So (ClientX - OffsetX) = left edge, (ClientY - OffsetY) = top edge.
    private static DropdownRect CalcDropdownRect(MouseEventArgs e)
    {
        const double inputHeight = 34;  // Bootstrap form-control height
        const double dropdownWidth = 280;
        const double maxDropdownH = 210;
        const double viewportH = 700;   // conservative modal viewport height

        var left = e.ClientX - e.OffsetX;
        var top  = e.ClientY - e.OffsetY;   // top of the input element
        var bottom = top + inputHeight;

        // Flip upward if not enough space below
        var spaceBelow = viewportH - bottom;
        var openUpward = spaceBelow < maxDropdownH && top > maxDropdownH;
        var dropTop = openUpward ? top - maxDropdownH : bottom + 2;

        return new DropdownRect(dropTop, left, dropdownWidth, openUpward);
    }'''

if old_style_method not in text:
    print("ERROR: GetDropdownStyle pattern not found")
    exit(1)
text = text.replace(old_style_method, new_style_method)

with open(razor_path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed ScreenEditorPage.razor ({len(text.splitlines())} lines)")
