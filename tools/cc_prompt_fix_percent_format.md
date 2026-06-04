# Task: Fix percentage metric formatting in RTM Service UserManager

## Problem

Agent metrics with MetricFunction = `TotalStatusGroupPercent` or `TotalStatusPercent`
call `dCalc.ToString(metric.Format)`. If `metric.Format` is null/empty, C# produces
the full decimal representation: `0.17822487095553088` instead of `17.8%`.

Affected metric on server 45: `MonAgentTalkDurationPct` (MetricFormat = empty).

## Fix — RTM/RTM/UserManager.cs

Find the two switch cases and add a default format fallback:

**Case `TotalStatusPercent`:**
```csharp
case "TotalStatusPercent":
    val = "0";
    if (isLoggedId)
    {
        long loginDur1 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
        long statusGrpDur1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks);
        double dCalc1 = (double)statusGrpDur1 / (double)loginDur1;
        var fmt1 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;  // ADD THIS
        val = dCalc1.ToString(fmt1); // "#0.##%"
    }
    break;
```

**Case `TotalStatusGroupPercent`:**
```csharp
case "TotalStatusGroupPercent":
    val = "0";
    if (isLoggedId)
    {
        long loginDur2 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
        long statusGrpDur2 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks);
        double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;
        var fmt2 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;  // ADD THIS
        val = dCalc2.ToString(fmt2); // "#0.##%"
    }
    break;
```

## Shell: threshold/filter compatibility

After fix, RTM sends `17.8%` instead of `0.178...`. The Shell's `ParseToSeconds`
in QueueGridWidget currently does:
```csharp
if (double.TryParse(value, out var num)) return num;
```

This won't parse `17.8%` (has %). Add % strip to `ParseToSeconds` in
**both QueueGridWidget and AgentGridWidget**:

```csharp
private static double? ParseToSeconds(string? value)
{
    if (string.IsNullOrEmpty(value)) return null;
    // Strip % for percentage values before numeric parse
    var stripped = value.TrimEnd('%');
    if (double.TryParse(stripped, System.Globalization.NumberStyles.Any,
        System.Globalization.CultureInfo.InvariantCulture, out var num)) return num;
    var parts = value.Split(':');
    try
    {
        if (parts.Length == 3)
            return int.Parse(parts[0]) * 3600 + int.Parse(parts[1]) * 60 + int.Parse(parts[2]);
        if (parts.Length == 2)
            return int.Parse(parts[0]) * 60 + int.Parse(parts[1]);
    }
    catch { }
    return null;
}
```

Check if AgentGridWidget has an equivalent `ParseToSeconds` or `CompareNumeric`
and apply the same `TrimEnd('%')` fix there.

## Verification

After deploy: `MonAgentTalkDurationPct` should display `17.8%` not `0.178...`.
Thresholds and column filters for % columns should still work correctly.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: format percentage metrics with ##0.0% default when MetricFormat is empty

TotalStatusGroupPercent/TotalStatusPercent called dCalc.ToString(metric.Format)
with empty format -> raw decimal like 0.178... instead of 17.8%.
Fix: default to ##0.0% when MetricFormat is null/empty.
Shell: TrimEnd('%') in ParseToSeconds for threshold/filter compatibility.
```
