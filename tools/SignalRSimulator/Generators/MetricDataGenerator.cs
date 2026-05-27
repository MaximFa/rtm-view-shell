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

    public static string GenerateValue(MetricDefinition metric)
    {
        var desc = metric.Description ?? "";
        var metricId = metric.MetricId;

        // Text fields - names, IDs, statuses
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

        // Timestamps - HH:MM:SS format
        if (desc.Contains("Time Stamp") || desc.Contains("TimeStamp"))
            return GenerateTimestamp();

        // Percentages - check MetricFormat first, then description
        if (metric.MetricFormat?.Contains('%') == true ||
            desc.Contains("Percent") || desc.Contains("Pct") ||
            metricId.Contains("Pct") || metricId.Contains("Percent"))
            return GeneratePercent(metric.MetricFormat);

        // Cumulative durations - long format HH:MM:SS
        if (desc.Contains("Cumulative") && desc.Contains("Duration"))
            return GenerateLongTime();

        if (desc.Contains("Current Login Duration"))
            return GenerateLongTime();

        // Average/Max/Current durations - short format MM:SS
        if (desc.Contains("Duration") || desc.Contains("Talk Time"))
            return GenerateShortTime();

        // Wait time, Response time - short format MM:SS
        if (desc.Contains("Wait Time") || desc.Contains("Response Time") || desc.Contains("Time to Aband"))
            return GenerateShortTime();

        // CPH (calls per hour) - decimal
        if (metricId.Contains("CPH"))
            return (_rng.NextDouble() * 10 + 2).ToString("F2");

        // Numbers - all "Number of" metrics
        if (desc.Contains("Number of") || desc.Contains("Num"))
            return GenerateNumber(desc, metricId);

        // Default - treat as number
        return _rng.Next(0, 100).ToString();
    }

    public static Dictionary<string, string> GenerateMetrics(IEnumerable<MetricDefinition> metrics)
    {
        return metrics.ToDictionary(m => m.MetricId, m => GenerateValue(m));
    }

    private static string GenerateNumber(string description, string metricId = "")
    {
        // ASD-style agent counts (small numbers)
        if (description.Contains("Break") || description.Contains("Paperwork") ||
            description.Contains("Training") || description.Contains("OnCall") ||
            metricId.Contains("NumBreak") || metricId.Contains("NumPaperwork") ||
            metricId.Contains("NumTraining") || metricId.Contains("OnCallAgents"))
            return _rng.Next(0, 15).ToString();

        // Different ranges based on what we're counting
        if (description.Contains("Active"))
            return _rng.Next(0, 15).ToString();

        if (description.Contains("Waiting"))
            return _rng.Next(0, 30).ToString();

        if (description.Contains("Logged") || description.Contains("Available"))
            return _rng.Next(5, 50).ToString();

        if (description.Contains("Answered") || description.Contains("Incoming"))
            return _rng.Next(20, 200).ToString();

        if (description.Contains("Abandoned"))
            return _rng.Next(0, 20).ToString();

        if (description.Contains("Missed"))
            return _rng.Next(0, 10).ToString();

        if (description.Contains("Outbound") || description.Contains("Otbound"))
            return _rng.Next(10, 80).ToString();

        if (description.Contains("Callback"))
            return _rng.Next(0, 30).ToString();

        if (description.Contains("Chat"))
            return _rng.Next(0, 25).ToString();

        return _rng.Next(0, 100).ToString();
    }

    private static string GenerateShortTime()
    {
        // MM:SS - up to 30 minutes
        var seconds = _rng.Next(0, 1800);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    private static string GenerateLongTime()
    {
        // HH:MM:SS - up to 9 hours
        var seconds = _rng.Next(0, 32400);
        var ts = TimeSpan.FromSeconds(seconds);
        return $"{(int)ts.TotalHours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2}";
    }

    private static string GeneratePercent(string? format)
    {
        var value = _rng.Next(60, 100) + _rng.NextDouble();

        if (format?.Contains("##0.00%") == true)
            return $"{value:F2}%";
        if (format?.Contains("##0.0%") == true)
            return $"{value:F1}%";

        return $"{(int)value}%";
    }

    private static string GenerateTimestamp()
    {
        // Today's time - random time in last 8 hours
        var now = DateTime.Now;
        var offset = TimeSpan.FromMinutes(_rng.Next(0, 480));
        return (now - offset).ToString("HH:mm:ss");
    }
}
