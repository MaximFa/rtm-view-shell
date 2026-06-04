#!/usr/bin/env python3
"""Fix QueueGrid row reset on DarkMode toggle - preserve Metrics and TimerAnchors."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\QueueGridWidget.razor"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix 1: ApplyConfig() at line 424
old_applyconfig = """            // Initialize rows from row definitions
            _rows = _rowDefs.Select(r => new QueueRowData
            {
                RowId = r.Id,
                QueueName = r.QueueName ?? r.BusinessUnitName ?? ""
            }).ToList();"""

new_applyconfig = """            // Rebuild rows — preserve existing display values if row structure unchanged
            var newRows = _rowDefs.Select(r => new QueueRowData
            {
                RowId = r.Id,
                QueueName = r.QueueName ?? r.BusinessUnitName ?? ""
            }).ToList();

            // Carry over Metrics and TimerAnchors from existing rows (same RowId = same data)
            // This prevents flicker when DarkMode/other params change without row changes
            if (_rows.Count > 0)
            {
                var existingById = _rows.ToDictionary(r => r.RowId);
                foreach (var row in newRows)
                {
                    if (existingById.TryGetValue(row.RowId, out var existing))
                    {
                        foreach (var kv in existing.Metrics)
                            row.Metrics[kv.Key] = kv.Value;
                        foreach (var kv in existing.TimerAnchors)
                            row.TimerAnchors[kv.Key] = kv.Value;
                    }
                }
            }
            _rows = newRows;"""

text = text.replace(old_applyconfig, new_applyconfig)

# Fix 2: ReconnectAsync() at line 500 - here we DO want fresh rows since we're reconnecting
# Actually, keep this as-is since ReconnectAsync is explicitly intended to reset data
# The issue is ApplyConfig being called on DarkMode toggle, not Reconnect

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed {path}")
print(f"Total lines: {len(text.splitlines())}")
