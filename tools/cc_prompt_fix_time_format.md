# Task: Format time values as MM:SS by default, HH:MM:SS only when hours > 0

Applies to: QueueGridWidget, AgentGridWidget, DataSlotWidget.

## Problem

Static time strings from RTM (e.g. `00:00:00`) are displayed verbatim.
Timer values starting with `+` already go through `FormatSeconds()` which
handles MM:SS vs HH:MM:SS correctly. Static values do not.

## Shared helper — add to ALL THREE widgets

Add this private static method to QueueGridWidget, AgentGridWidget, DataSlotWidget:

```csharp
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
```

## QueueGridWidget fix

Find `GetCellDisplay`. After the timer anchor block, wrap raw value:

```csharp
private string GetCellDisplay(QueueRowData row, string metricId)
{
    if (row.TimerAnchors.TryGetValue(metricId, out var anchor))
    {
        var elapsed = (int)(DateTime.UtcNow - anchor.StartedAt).TotalSeconds;
        return FormatSeconds(anchor.BaseSecs + elapsed);
    }
    var raw = GetMetricValue(row.Metrics, metricId);
    return FormatTimeString(raw);  // no-op for non-time strings
}
```

Also verify `FormatSeconds` already does:
```csharp
return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
```

## AgentGridWidget fix

Find the equivalent `GetCellDisplay` method in AgentGridWidget.
Same pattern: after timer anchor check, apply `FormatTimeString` on the raw value:

```csharp
var raw = GetMetricValue(/* ... */);
return FormatTimeString(raw);
```

Check the actual method structure — it may use `AgentRow.Fields` or similar.
Apply `FormatTimeString` as close to the final return as possible.

## DataSlotWidget fix

Find the block where `_displayValue = value` is set inside the RTM handler
(where `_isTimeFormat = true`):

```csharp
// BEFORE:
_currentValue = timeSeconds;
_displayValue = value;
_isTimeFormat = true;

// AFTER:
_currentValue = timeSeconds;
_displayValue = FormatTimeString(value);  // MM:SS when hours == 0
_isTimeFormat = true;
```

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy:
- `00:00:00` → `00:00`
- `01:05` → `01:05` (unchanged)
- `01:01:05` → `01:01:05` (hours present — kept)

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: format time values as MM:SS by default, HH:MM:SS only when hours > 0

Static time strings from RTM (e.g. 00:00:00) were displayed verbatim.
Now formatted via FormatTimeString: HH:MM:SS -> MM:SS when hours == 0.
Applies to QueueGrid (WAIT TIME), AgentGrid (DURATION, AVG TALK),
and DataSlot (time-format values).
```
