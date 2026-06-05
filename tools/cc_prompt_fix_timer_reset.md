# CC Task: Fix timer reset on page refresh — AgentGrid only

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Only after reading both files: proceed with the task below.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Problem

On page refresh, timer columns in AgentGrid reset to the snapshot value
with `StartedAt = DateTime.UtcNow` (time of refresh) instead of the time
when the Shell originally received the data from RTM.

**QueueGrid** is already fixed (commit d5bf432 — `refreshCells` uses `Value2`).
**This task is AgentGrid only.**

---

## Root cause

`AgentSnapshot.ReceivedAt` is correctly stored in `RtmRelayService.HandleUpdateAsync`:
```csharp
var snapshot = new AgentSnapshot(agentLoginName, fields, DateTime.UtcNow);  // line ~340
```

But in `AgentGridWidget.razor`, the `InitialSnapshot` handler ignores `agent.ReceivedAt`
and uses a fresh `DateTime.UtcNow` instead:

```csharp
case UnionStateChange.InitialSnapshot snap:
    _rows.Clear();
    var now = DateTime.UtcNow;                          // ← time of page refresh
    foreach (var (_, agent) in snap.Agents)
    {
        var row = new AgentRowData { RowId = agent.AgentLoginName };
        foreach (var kv in agent.Fields)
            ApplyMetricValue(row, kv.Key, kv.Value.Raw, now);  // ← should be agent.ReceivedAt
        _rows.Add(row);
    }
```

Result: on refresh, `TimerAnchors[metric] = (150 secs, now)` → timer displays 2:30
instead of 2:30 + (now − originalReceiveTime).

---

## Fix — AgentGridWidget.razor

File: `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

In the `InitialSnapshot` case (look for `case UnionStateChange.InitialSnapshot snap:`),
change `now` to `agent.ReceivedAt`:

```csharp
// BEFORE
case UnionStateChange.InitialSnapshot snap:
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
    break;

// AFTER
case UnionStateChange.InitialSnapshot snap:
    _rows.Clear();
    foreach (var (_, agent) in snap.Agents)
    {
        var row = new AgentRowData { RowId = agent.AgentLoginName };
        foreach (var kv in agent.Fields)
            ApplyMetricValue(row, kv.Key, kv.Value.Raw, agent.ReceivedAt);
        _rows.Add(row);
    }
    if (_rows.Count > 0) DetectColumnDataTypes();
    break;
```

The `AgentsUpserted` case correctly uses `DateTime.UtcNow` — no change needed there
(live updates always have current timestamp).

---

## Implementation steps

1. Read both skill files (mandatory)
2. `git status --short` + `tail -3` on any M files
3. Write the fix using Python atomic write + fsync (Edit tool is BANNED)
4. `dotnet build CcDashboard.sln` — must be 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `fix: AgentGrid InitialSnapshot uses agent.ReceivedAt for timer anchors (prevents reset on page refresh)`
7. Re-sync from HEAD (§0.6 PD-007)

---

## Re-sync block (§0.6 PD-007 — mandatory last step)

```bash
for f in "src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
