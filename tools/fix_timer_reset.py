#!/usr/bin/env python3
"""Fix AgentGrid timer reset on page refresh — use agent.ReceivedAt instead of DateTime.UtcNow."""

import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\AgentGridWidget.razor"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix InitialSnapshot case — use agent.ReceivedAt instead of now
old = '''                        case UnionStateChange.InitialSnapshot snap:
                            _rows.Clear();
                            var now = DateTime.UtcNow;
                            foreach (var (_, agent) in snap.Agents)
                            {
                                var row = new AgentRowData { RowId = agent.AgentLoginName };
                                foreach (var kv in agent.Fields)
                                    ApplyMetricValue(row, kv.Key, kv.Value.Raw, now);
                                _rows.Add(row);
                            }
                            if (_rows.Count > 0) DetectColumnDataTypes();
                            break;'''

new = '''                        case UnionStateChange.InitialSnapshot snap:
                            _rows.Clear();
                            foreach (var (_, agent) in snap.Agents)
                            {
                                var row = new AgentRowData { RowId = agent.AgentLoginName };
                                foreach (var kv in agent.Fields)
                                    ApplyMetricValue(row, kv.Key, kv.Value.Raw, agent.ReceivedAt);
                                _rows.Add(row);
                            }
                            if (_rows.Count > 0) DetectColumnDataTypes();
                            break;'''

if old not in text:
    print("ERROR: Pattern not found in AgentGridWidget.razor")
    exit(1)

text = text.replace(old, new, 1)
print("Fixed: InitialSnapshot now uses agent.ReceivedAt instead of DateTime.UtcNow")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Done: AgentGridWidget.razor (%d lines)" % (text.count('\n') + 1))
