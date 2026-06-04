#!/usr/bin/env python3
"""Add FormatTimeString helper to QueueGrid, AgentGrid, DataSlot widgets."""
import os

FORMAT_TIME_STRING = '''
    /// <summary>
    /// Formats HH:MM:SS as MM:SS when hours == 0, otherwise keeps HH:MM:SS.
    /// Returns original string if not a recognisable time format.
    /// </summary>
    private static string FormatTimeString(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;
        var parts = value.Split(':');
        if (parts.Length == 3
            && int.TryParse(parts[0], out var h)
            && int.TryParse(parts[1], out var m)
            && int.TryParse(parts[2], out var s))
        {
            return h > 0 ? $"{h:D2}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
        }
        if (parts.Length == 2
            && int.TryParse(parts[0], out var m2)
            && int.TryParse(parts[1], out var s2))
        {
            return $"{m2:D2}:{s2:D2}";
        }
        return value;
    }
'''

base_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets"

# --- QueueGridWidget ---
path = os.path.join(base_path, "QueueGridWidget.razor")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add FormatTimeString after FormatSeconds
old_format_seconds = '''    private static string FormatSeconds(int totalSecs)
    {
        if (totalSecs < 0) totalSecs = 0;
        var h = totalSecs / 3600;
        var m = (totalSecs % 3600) / 60;
        var s = totalSecs % 60;
        return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
    }'''

new_format_seconds = old_format_seconds + FORMAT_TIME_STRING

if "FormatTimeString" not in text:
    text = text.replace(old_format_seconds, new_format_seconds)

# Modify GetCellDisplay to use FormatTimeString
old_get_cell = '''    private string GetCellDisplay(QueueRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        return GetMetricValue(row.Metrics, metricId);
    }'''

new_get_cell = '''    private string GetCellDisplay(QueueRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        var raw = GetMetricValue(row.Metrics, metricId);
        return FormatTimeString(raw);
    }'''

text = text.replace(old_get_cell, new_get_cell)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed QueueGridWidget.razor ({len(text.splitlines())} lines)")


# --- AgentGridWidget ---
path = os.path.join(base_path, "AgentGridWidget.razor")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Find FormatSeconds in AgentGridWidget and add FormatTimeString after it
old_format_seconds_agent = '''    private static string FormatSeconds(int totalSecs)
    {
        if (totalSecs < 0) totalSecs = 0;
        var h = totalSecs / 3600;
        var m = (totalSecs % 3600) / 60;
        var s = totalSecs % 60;
        return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
    }'''

new_format_seconds_agent = old_format_seconds_agent + FORMAT_TIME_STRING

if "FormatTimeString" not in text:
    text = text.replace(old_format_seconds_agent, new_format_seconds_agent)

# Modify GetCellDisplay in AgentGridWidget
old_get_cell_agent = '''    private string GetCellDisplay(AgentRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        return GetMetricValue(row.Metrics, metricId);
    }'''

new_get_cell_agent = '''    private string GetCellDisplay(AgentRowData row, string metricId)
    {
        if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
        {
            var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
            return FormatSeconds(anchor.BaseSecs + elapsed);
        }
        var raw = GetMetricValue(row.Metrics, metricId);
        return FormatTimeString(raw);
    }'''

text = text.replace(old_get_cell_agent, new_get_cell_agent)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed AgentGridWidget.razor ({len(text.splitlines())} lines)")


# --- DataSlotWidget ---
path = os.path.join(base_path, "DataSlotWidget.razor")
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add FormatTimeString after FormatSecondsAsTime
old_format_seconds_ds = '''    private static string FormatSecondsAsTime(int totalSeconds)
    {
        var hours = totalSeconds / 3600;
        var minutes = (totalSeconds % 3600) / 60;
        var seconds = totalSeconds % 60;

        if (hours > 0)
        {
            return $"{hours:D2}:{minutes:D2}:{seconds:D2}";
        }
        return $"{minutes:D2}:{seconds:D2}";
    }'''

new_format_seconds_ds = old_format_seconds_ds + FORMAT_TIME_STRING

if "FormatTimeString" not in text:
    text = text.replace(old_format_seconds_ds, new_format_seconds_ds)

# Modify _displayValue = value for time format case
old_time_block = '''                if (TryParseTimeFormat(value, out var timeSeconds))
                {
                    _currentValue = timeSeconds;
                    _displayValue = value;
                    _isTimeFormat = true;'''

new_time_block = '''                if (TryParseTimeFormat(value, out var timeSeconds))
                {
                    _currentValue = timeSeconds;
                    _displayValue = FormatTimeString(value);
                    _isTimeFormat = true;'''

text = text.replace(old_time_block, new_time_block)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed DataSlotWidget.razor ({len(text.splitlines())} lines)")
