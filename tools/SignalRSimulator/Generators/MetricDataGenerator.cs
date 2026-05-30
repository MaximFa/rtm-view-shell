using SignalRSimulator.Models;

namespace SignalRSimulator.Generators;

public static class MetricDataGenerator
{
    private static readonly Random _rng = new();

    private static readonly string[] AgentNames = {
        "John Smith", "Maria Garcia", "David Lee", "Anna Kowalski", "Michael Brown",
        "Sarah Johnson", "James Wilson", "Emma Davis", "Robert Miller", "Lisa Anderson",
        "William Taylor", "Jennifer Martinez", "Daniel Thompson", "Michelle White", "Christopher Harris",
        "Amanda Clark", "Matthew Lewis", "Jessica Robinson", "Andrew Walker", "Stephanie Hall",
        "Joshua Allen", "Nicole Young", "Ryan King", "Megan Wright", "Justin Scott",
        "Ashley Green", "Brandon Adams", "Brittany Baker", "Tyler Nelson", "Samantha Hill"
    };

    private static readonly string[] StatusNames = {
        "Available", "On Call", "Break", "Paperwork", "Wrap Up", "Unavailable", "Meeting", "Training"
    };

    private static readonly string[] StatusGroups = {
        "Available", "On Call", "Break", "Paperwork", "Wrap Up", "Unavailable"
    };

    private static readonly string[] InteractionTypes = {
        "Inbound Call", "Outbound Call", "Chat", "Email", "Callback"
    };

    private static readonly string[] QueueNames = {
        "Sales", "Support", "Billing", "Technical", "General", "VIP", "Complaints"
    };

    /// <summary>
    /// Generate a fake value for the given metric.
    /// Dispatches on ValueType (from RTSGrid_Metric.ValueType):
    ///   "Time"   → "+HH:MM:SS" or "+MM:SS"  ('+' prefix = live timer in AgentGridWidget)
    ///   "Number" → integer or percent based on DataType / MetricFormat
    ///   "String" → description-heuristic text (names, states, IDs, etc.)
    /// </summary>
    public static string GenerateValue(MetricDefinition metric)
    {
        return (metric.ValueType ?? "String") switch
        {
            "Time"   => GenerateTimeValue(metric),
            "Number" => GenerateNumberValue(metric),
            _        => GenerateStringValue(metric)
        };
    }

    public static Dictionary<string, string> GenerateMetrics(IEnumerable<MetricDefinition> metrics)
        => metrics.ToDictionary(m => m.MetricId, m => GenerateValue(m));

    // ── Time ─────────────────────────────────────────────────────────────────

    /// <summary>
    /// All Time metrics get the '+' prefix so AgentGridWidget creates a TimerAnchor
    /// and increments the value every second via its PeriodicTimer.
    /// Format choice: MetricFormat containing "hh" → long (HH:MM:SS), else short (MM:SS).
    /// </summary>
    private static string GenerateTimeValue(MetricDefinition metric)
    {
        var isLong = metric.MetricFormat?.Contains("hh", StringComparison.OrdinalIgnoreCase) == true
                     || metric.DataType?.Equals("Time", StringComparison.OrdinalIgnoreCase) == true;
        return "+" + (isLong ? GenerateLongTime() : GenerateShortTime());
    }

    // ── Number ───────────────────────────────────────────────────────────────

    private static string GenerateNumberValue(MetricDefinition metric)
    {
        // Percent: DataType == "Percent" OR MetricFormat contains '%'
        if (metric.DataType?.Equals("Percent", StringComparison.OrdinalIgnoreCase) == true
            || metric.MetricFormat?.Contains('%') == true)
            return GeneratePercent(metric.MetricFormat);

        // Default integer
        return _rng.Next(0, 200).ToString();
    }

    // ── String ───────────────────────────────────────────────────────────────

    private static string GenerateStringValue(MetricDefinition metric)
    {
        var desc = metric.Description ?? "";
        var metricId = metric.MetricId;

        if (desc.Contains("Login Name"))
            return AgentNames[_rng.Next(AgentNames.Length)];

        if (desc.Contains("User ID") || desc.Contains("Station ID") || desc.Contains("Extension ID"))
            return _rng.Next(1000, 9999).ToString();

        if (desc.Contains("Interction ID") || desc.Contains("Interaction ID"))
            return $"INT-{_rng.Next(100000, 999999)}";

        if (desc.Contains("Phone Number"))
            return $"+1-{_rng.Next(200, 999)}-{_rng.Next(100, 999)}-{_rng.Next(1000, 9999)}";

        if (desc.Contains("Queue Name"))
            return QueueNames[_rng.Next(QueueNames.Length)];

        if (desc.Contains("Interaction State") && !desc.Contains("Duration"))
            return StatusNames[_rng.Next(StatusNames.Length)];

        if (desc.Contains("Interaction Type"))
            return InteractionTypes[_rng.Next(InteractionTypes.Length)];

        if (desc.Contains("Current Satatus") || (desc.Contains("Current Status") && !desc.Contains("Duration") && !desc.Contains("Group")))
            return StatusNames[_rng.Next(StatusNames.Length)];

        if (desc.Contains("Status Group") && !desc.Contains("Duration"))
            return StatusGroups[_rng.Next(StatusGroups.Length)];

        if (desc.Contains("Today Login") || desc.Contains("Change -ID"))
            return _rng.Next(0, 2) == 0 ? "" : AgentNames[_rng.Next(AgentNames.Length)];

        if (desc.Contains("Time Stamp") || desc.Contains("TimeStamp"))
            return GenerateTimestamp();

        // Fallback: return a small number as text
        return _rng.Next(0, 100).ToString();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    public static string GenerateShortTime()
    {
        var seconds = _rng.Next(0, 1800);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    public static string GenerateLongTime()
    {
        var seconds = _rng.Next(0, 32400);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{(int)ts.TotalHours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    private static string GeneratePercent(string? format)
    {
        var value = _rng.Next(60, 100) + _rng.NextDouble();
        if (format?.Contains("##0.00%") == true) return $"{value:F2}%";
        if (format?.Contains("##0.0%") == true)  return $"{value:F1}%";
        return $"{(int)value}%";
    }

    private static string GenerateTimestamp()
    {
        var now = DateTime.Now;
        var offset = TimeSpan.FromMinutes(_rng.Next(0, 480));
        return (now - offset).ToString("HH:mm:ss");
    }
}
