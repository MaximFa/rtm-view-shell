#!/usr/bin/env python3
"""Fix percentage metric formatting in RTM UserManager and Shell ParseToSeconds."""
import os

# --- RTM/RTM/UserManager.cs ---
path = r"D:\Claude\Projects\RTM View Shell\RTM\RTM\UserManager.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix TotalStatusPercent case
old_total_status_percent = '''                    case "TotalStatusPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur1 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc1 = (double)statusGrpDur1 / (double)loginDur1;
                            val = dCalc1.ToString(metric.Format); // "#0.##%"
                        }
                        break;'''

new_total_status_percent = '''                    case "TotalStatusPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur1 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc1 = (double)statusGrpDur1 / (double)loginDur1;
                            var fmt1 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;
                            val = dCalc1.ToString(fmt1); // "#0.##%"
                        }
                        break;'''

text = text.replace(old_total_status_percent, new_total_status_percent)

# Fix TotalStatusGroupPercent case
old_total_status_group_percent = '''                    case "TotalStatusGroupPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur2 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur2 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;
                            val = dCalc2.ToString(metric.Format); // "#0.##%"
                        }
                        break;'''

new_total_status_group_percent = '''                    case "TotalStatusGroupPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur2 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur2 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;
                            var fmt2 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;
                            val = dCalc2.ToString(fmt2); // "#0.##%"
                        }
                        break;'''

text = text.replace(old_total_status_group_percent, new_total_status_group_percent)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed UserManager.cs ({len(text.splitlines())} lines)")


# --- QueueGridWidget.razor ---
path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\QueueGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old_parse_to_seconds = '''    private static double? ParseToSeconds(string? value)
    {
        if (string.IsNullOrEmpty(value)) return null;
        if (double.TryParse(value, out var num)) return num;

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
    }'''

new_parse_to_seconds = '''    private static double? ParseToSeconds(string? value)
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
    }'''

text = text.replace(old_parse_to_seconds, new_parse_to_seconds)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed QueueGridWidget.razor ({len(text.splitlines())} lines)")
