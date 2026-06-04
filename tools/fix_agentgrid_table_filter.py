#!/usr/bin/env python3
"""Apply Config.TableFilters in AgentGridWidget.GetFilteredRows."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\AgentGridWidget.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Replace GetFilteredRows method to add Config.TableFilters logic
old_get_filtered = '''    private List<AgentRowData> GetFilteredRows()
    {
        var result = _rows.AsEnumerable();

        foreach (var (metricId, filter) in _columnFilters)
        {
            if (filter.Mode == "") continue;

            if (filter.Mode == "list")
            {
                result = result.Where(r => filter.SelectedValues.Contains(GetMetricValue(r.Metrics, metricId)));
            }
            else if (filter.Mode == "value" && !string.IsNullOrEmpty(filter.TextValue))
            {
                result = result.Where(r => MatchesValueFilter(GetMetricValue(r.Metrics, metricId), filter));
            }
        }

        return result.ToList();
    }'''

new_get_filtered = '''    private List<AgentRowData> GetFilteredRows()
    {
        var result = _rows.AsEnumerable();

        // Apply configured row filters (from widget configurator)
        if (Config?.TableFilters is { Count: > 0 } tableFilters)
        {
            result = result.Where(row =>
            {
                bool? groupResult = null;
                string currentConnector = "AND";
                foreach (var rule in tableFilters)
                {
                    if (string.IsNullOrEmpty(rule.MetricId)) continue;
                    var cellValue = GetMetricValue(row.Metrics, rule.MetricId);
                    bool ruleMatch = MatchesTableFilterRule(cellValue, rule.Operator, rule.Value);
                    if (groupResult == null)
                    {
                        groupResult = ruleMatch;
                    }
                    else if (currentConnector == "OR")
                    {
                        groupResult = groupResult.Value || ruleMatch;
                    }
                    else // AND
                    {
                        groupResult = groupResult.Value && ruleMatch;
                    }
                    currentConnector = string.IsNullOrEmpty(rule.Connector) ? "AND" : rule.Connector;
                }
                return groupResult ?? true;
            });
        }

        // Apply column filters (user-applied from UI)
        foreach (var (metricId, filter) in _columnFilters)
        {
            if (filter.Mode == "") continue;

            if (filter.Mode == "list")
            {
                result = result.Where(r => filter.SelectedValues.Contains(GetMetricValue(r.Metrics, metricId)));
            }
            else if (filter.Mode == "value" && !string.IsNullOrEmpty(filter.TextValue))
            {
                result = result.Where(r => MatchesValueFilter(GetMetricValue(r.Metrics, metricId), filter));
            }
        }

        return result.ToList();
    }'''

text = text.replace(old_get_filtered, new_get_filtered)

# Add MatchesTableFilterRule helper method after MatchesValueFilter
# Find the end of MatchesValueFilter to insert after it
old_matches_value = '''        // Text comparison
        return filter.Operator switch
        {
            "equal" => value.Equals(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "contains" => value.Contains(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "startsWith" => value.StartsWith(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "endsWith" => value.EndsWith(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            _ => value.Contains(filter.TextValue, StringComparison.OrdinalIgnoreCase)
        };
    }'''

new_matches_value = '''        // Text comparison
        return filter.Operator switch
        {
            "equal" => value.Equals(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "contains" => value.Contains(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "startsWith" => value.StartsWith(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            "endsWith" => value.EndsWith(filter.TextValue, StringComparison.OrdinalIgnoreCase),
            _ => value.Contains(filter.TextValue, StringComparison.OrdinalIgnoreCase)
        };
    }

    private static bool MatchesTableFilterRule(string cellValue, string? op, string? filterValue)
    {
        if (string.IsNullOrEmpty(op) || filterValue == null) return true;
        return op switch
        {
            "equal"        => string.Equals(cellValue, filterValue, StringComparison.OrdinalIgnoreCase),
            "notequal"     => !string.Equals(cellValue, filterValue, StringComparison.OrdinalIgnoreCase),
            "contains"     => cellValue.Contains(filterValue, StringComparison.OrdinalIgnoreCase),
            "notcontains"  => !cellValue.Contains(filterValue, StringComparison.OrdinalIgnoreCase),
            "startswith"   => cellValue.StartsWith(filterValue, StringComparison.OrdinalIgnoreCase),
            "endswith"     => cellValue.EndsWith(filterValue, StringComparison.OrdinalIgnoreCase),
            "greater"      => ParseNumericValue(cellValue) > ParseNumericValue(filterValue),
            "greaterequal" => ParseNumericValue(cellValue) >= ParseNumericValue(filterValue),
            "less"         => ParseNumericValue(cellValue) < ParseNumericValue(filterValue),
            "lessequal"    => ParseNumericValue(cellValue) <= ParseNumericValue(filterValue),
            _              => true
        };
    }'''

text = text.replace(old_matches_value, new_matches_value)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed AgentGridWidget.razor ({len(text.splitlines())} lines)")
