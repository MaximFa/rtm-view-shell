#!/usr/bin/env python3
"""Fix AsyncLogger.Warn -> AsyncLogger.Info (Warn method doesn't exist)."""

import os

path = r"D:\Claude\Projects\RTM View Shell\RTM\RTM\Engine.cs"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = 'AsyncLogger.Warn($"ScheduleNextCheck | dueTime {dueTime.TotalDays:F1}d exceeds Timer max, capping to 49d");'
new = 'AsyncLogger.Info($"ScheduleNextCheck | dueTime {dueTime.TotalDays:F1}d exceeds Timer max, capping to 49d");'

if old not in text:
    print("ERROR: Pattern not found")
    exit(1)

text = text.replace(old, new, 1)
print("Fixed: AsyncLogger.Warn -> AsyncLogger.Info")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Done")
