#!/usr/bin/env python3
"""
Fix Shell code references to removed RTSGrid_Metric IDs after metrics dedup migration.
Per CLAUDE.md §0.3 - all file writes must use Python with os.fsync().
"""
import os
import re

# 1. Fix DatabaseInitializer.cs - remove 4 seed entries for deleted metrics
path1 = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\Seeding\DatabaseInitializer.cs"

with open(path1, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Filter out lines containing the removed MetricIds
removed_ids = [
    '"QueueNumAcceptedCallbacks"',
    '"QueuePctAnsweredCalls60secIncLast30min"',
    '"QueueNumOnCallAgents"',
    '"QueueNumberOfLoggedAgents"',
]

new_lines = []
removed_count = 0
for line in lines:
    if 'MetricId =' in line:
        skip = False
        for metric_id in removed_ids:
            if metric_id in line:
                skip = True
                removed_count += 1
                break
        if not skip:
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(path1, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed: {path1} (removed {removed_count} seed entries)")

# 2. Fix AgentStateDistributionWidget.razor - replace QueueNumOnCallAgents with UsersSumOnCall
path2 = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\AgentStateDistributionWidget.razor"

with open(path2, "r", encoding="utf-8") as f:
    text2 = f.read()

# Replace the metric reference in legacy fallback
text2 = text2.replace(
    '_cellValues.GetValueOrDefault("QueueNumOnCallAgents")',
    '_cellValues.GetValueOrDefault("UsersSumOnCall")'
)

with open(path2, "w", encoding="utf-8") as f:
    f.write(text2)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed: {path2}")
print("Done.")
