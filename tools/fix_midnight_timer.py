#!/usr/bin/env python3
"""Fix ArgumentOutOfRangeException in ScheduleNextCheck — DateTime.MaxValue guard."""

import os

path = r"D:\Claude\Projects\RTM View Shell\RTM\RTM\Engine.cs"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old = '''            DateTime? nextClearTime = GetNextClearTime();

            if (!nextClearTime.HasValue)
            {
                AsyncLogger.Error("ScheduleNextCheck | nextClearTime is null", null);
                return;
            }

            var now = DateTime.Now;
            TimeSpan dueTime = nextClearTime.Value - now;'''

new = '''            DateTime? nextClearTime = GetNextClearTime();

            if (!nextClearTime.HasValue || nextClearTime.Value == DateTime.MaxValue)
            {
                AsyncLogger.Info("ScheduleNextCheck | no unions loaded yet, timer skipped");
                return;
            }

            var now = DateTime.Now;
            TimeSpan dueTime = nextClearTime.Value - now;

            // Safety cap: Timer max is ~49.7 days (4294967294 ms)
            var maxDue = TimeSpan.FromMilliseconds(4_294_967_294);
            if (dueTime > maxDue)
            {
                AsyncLogger.Warn($"ScheduleNextCheck | dueTime {dueTime.TotalDays:F1}d exceeds Timer max, capping to 49d");
                dueTime = maxDue;
            }'''

if old not in text:
    print("ERROR: Pattern not found in Engine.cs")
    exit(1)

text = text.replace(old, new, 1)
print("Fixed: ScheduleNextCheck DateTime.MaxValue guard + safety cap")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Done: Engine.cs (%d lines)" % (text.count('\n') + 1))
