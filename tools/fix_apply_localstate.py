#!/usr/bin/env python3
"""Fix ApplyViewConfigAsync to update in-memory caches after Apply."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\DayTrendWidget.razor"

def main():
    print(f"Processing {PATH}")

    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    old_method = '''    private async Task ApplyViewConfigAsync()
    {
        await SaveLocalOverridesAsync();
        _showViewConfig = false;
        await LoadDataAsync();
    }'''

    new_method = '''    private async Task ApplyViewConfigAsync()
    {
        await SaveLocalOverridesAsync();

        // Update in-memory caches to match what was just saved,
        // so OpenLocalConfigAsync() re-apply shows correct state on next open.
        _localMetricIds = _metrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localAgentMetricIds = _agentMetrics
            .Where(m => m.Enabled)
            .Select(m => m.MetricId)
            .ToHashSet();
        _localChartType = _viewChartType;

        _showViewConfig = false;
        await LoadDataAsync();
    }'''

    if old_method not in text:
        print("ERROR: old method not found!")
        return

    text = text.replace(old_method, new_method)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    main()
