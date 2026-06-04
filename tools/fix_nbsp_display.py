#!/usr/bin/env python3
"""Fix &nbsp; rendering in AgentGridWidget - treat as empty string."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\AgentGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix GetCellDisplay method to check for &nbsp;
old_method = '''    private string GetCellDisplay(AgentRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        var raw = GetMetricValue(row.Metrics, metricId);
        return FormatTimeString(raw);
    }'''

new_method = '''    private string GetCellDisplay(AgentRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        var raw = GetMetricValue(row.Metrics, metricId);
        var result = FormatTimeString(raw);
        // RTM Service uses &nbsp; as placeholder for empty fields (legacy HTML client)
        if (result == "&nbsp;") return string.Empty;
        return result;
    }'''

if old_method not in text:
    print("ERROR: GetCellDisplay method not found in expected form")
    exit(1)

text = text.replace(old_method, new_method)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed AgentGridWidget.razor ({len(text.splitlines())} lines)")
