# Task: Apply Config.TableFilters in AgentGridWidget.GetFilteredRows

## Problem

`AgentGridWidget.GetFilteredRows()` only applies `_columnFilters` (user-driven
column filters from the UI). The configured `Config.TableFilters` — the
"Row filter — applied before display" rules from the configurator modal — are
stored in ConfigJson but never applied when rendering rows.

Result: filter like "State Not equals SIGNOFF" has no effect.

## Fix — AgentGridWidget.razor

Find `GetFilteredRows()` method. Add `Config.TableFilters` as the first filter
applied (before column filters), respecting AND/OR connectors:

```csharp
private List<AgentRowData> GetFilteredRows()
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
}
```

Add the helper method `MatchesTableFilterRule`:

```csharp
private static bool MatchesTableFilterRule(string cellValue, string op, string filterValue)
{
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
        _               => true
    };
}
```

Note: `ParseNumericValue` should already exist in AgentGridWidget — verify
the exact method name and adjust if needed.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: filter "State Not equals SIGNOFF" should hide all SIGNOFF agents.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: apply Config.TableFilters in AgentGridWidget.GetFilteredRows

Configured row filters ("Row filter — applied before display") were stored
in ConfigJson but never applied. GetFilteredRows only applied user-driven
column filters. Fix: apply Config.TableFilters first, then column filters.
```
