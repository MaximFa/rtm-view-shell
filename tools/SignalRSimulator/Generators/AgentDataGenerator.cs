using SignalRSimulator.Models;

namespace SignalRSimulator.Generators;

public static class AgentDataGenerator
{
    private static readonly Random _random = new();

    private static readonly List<(string Id, string Name, string Ext, string Team)> _agentTemplates = new()
    {
        ("A001", "John Smith", "1001", "Sales Team"),
        ("A002", "Mary Johnson", "1002", "Sales Team"),
        ("A003", "Alex Williams", "1003", "Sales Team"),
        ("A004", "Elena Brown", "1004", "Support Team"),
        ("A005", "David Miller", "1005", "Support Team"),
        ("A006", "Anna Davis", "1006", "Sales Team"),
        ("A007", "Steven Wilson", "1007", "Support Team"),
        ("A008", "Olivia Taylor", "1008", "VIP Team"),
        ("A009", "Andrew Moore", "1009", "Sales Team"),
        ("A010", "Natalie Anderson", "1010", "Support Team"),
        ("A011", "Paul Thomas", "1011", "VIP Team"),
        ("A012", "Tanya Jackson", "1012", "Sales Team"),
        ("A013", "Michael Chen", "1013", "Support Team"),
        ("A014", "Sarah Parker", "1014", "Sales Team"),
        ("A015", "James Rodriguez", "1015", "VIP Team"),
        ("A016", "Emily White", "1016", "Support Team"),
        ("A017", "Robert Kim", "1017", "Sales Team"),
        ("A018", "Jessica Lee", "1018", "Support Team"),
        ("A019", "Daniel Garcia", "1019", "VIP Team"),
        ("A020", "Amanda Martinez", "1020", "Sales Team"),
        ("A021", "Christopher Jones", "1021", "Support Team"),
        ("A022", "Michelle Thompson", "1022", "Sales Team"),
        ("A023", "Kevin Brown", "1023", "VIP Team"),
        ("A024", "Lisa Davis", "1024", "Support Team"),
        ("A025", "Brian Wilson", "1025", "Sales Team"),
        ("A026", "Jennifer Taylor", "1026", "Support Team"),
        ("A027", "Mark Anderson", "1027", "VIP Team"),
        ("A028", "Ashley Thomas", "1028", "Sales Team"),
        ("A029", "Ryan Jackson", "1029", "Support Team"),
        ("A030", "Nicole Harris", "1030", "Sales Team"),
    };

    private static readonly Dictionary<string, AgentState> _agentStates = new();
    private static readonly Dictionary<string, DateTime> _stateStartTimes = new();
    private static readonly Dictionary<string, string?> _agentCalls = new();

    public static AgentGridUpdate Generate(Guid gridId)
    {
        var now = DateTime.UtcNow;
        var agents = new List<AgentStatusDto>();

        foreach (var template in _agentTemplates)
        {
            // Initialize or potentially change state
            if (!_agentStates.ContainsKey(template.Id))
            {
                _agentStates[template.Id] = GetRandomInitialState();
                _stateStartTimes[template.Id] = now.AddSeconds(-_random.Next(10, 300));
                _agentCalls[template.Id] = null;
            }

            // Randomly change state (10% chance)
            if (_random.Next(100) < 10)
            {
                var oldState = _agentStates[template.Id];
                var newState = GetNextState(oldState);
                if (newState != oldState)
                {
                    _agentStates[template.Id] = newState;
                    _stateStartTimes[template.Id] = now;

                    // Handle call lifecycle
                    if (newState == AgentState.Talking || newState == AgentState.Outbound)
                        _agentCalls[template.Id] = $"CALL-{_random.Next(1000, 9999)}";
                    else if (oldState == AgentState.Talking || oldState == AgentState.Hold || oldState == AgentState.Outbound)
                        _agentCalls[template.Id] = null;
                }
            }

            var state = _agentStates[template.Id];
            var stateStart = _stateStartTimes[template.Id];
            var stateDuration = (int)(now - stateStart).TotalSeconds;
            var callId = _agentCalls[template.Id];

            var agent = CreateAgent(template.Id, template.Name, template.Ext, template.Team,
                state, stateDuration, stateStart, callId, now);

            agents.Add(agent);
        }

        return new AgentGridUpdate(gridId, now, agents);
    }

    private static AgentState GetRandomInitialState()
    {
        var weights = new[] { 30, 25, 5, 15, 15, 5, 5 }; // Ready, Talking, Hold, Acw, NotReady, Outbound, LoggedOut
        var total = weights.Sum();
        var roll = _random.Next(total);
        var cumulative = 0;

        for (int i = 0; i < weights.Length; i++)
        {
            cumulative += weights[i];
            if (roll < cumulative)
                return (AgentState)i;
        }

        return AgentState.Ready;
    }

    private static AgentState GetNextState(AgentState current)
    {
        return current switch
        {
            AgentState.Ready => _random.Next(100) < 70 ? AgentState.Talking : AgentState.NotReady,
            AgentState.Talking => _random.Next(100) switch
            {
                < 50 => AgentState.Acw,
                < 70 => AgentState.Hold,
                _ => AgentState.Talking
            },
            AgentState.Hold => _random.Next(100) < 80 ? AgentState.Talking : AgentState.Acw,
            AgentState.Acw => AgentState.Ready,
            AgentState.NotReady => AgentState.Ready,
            AgentState.Outbound => _random.Next(100) < 70 ? AgentState.Acw : AgentState.Ready,
            AgentState.LoggedOut => _random.Next(100) < 30 ? AgentState.Ready : AgentState.LoggedOut,
            _ => AgentState.Ready
        };
    }

    private static AgentStatusDto CreateAgent(
        string agentId, string name, string ext, string team,
        AgentState state, int stateDuration, DateTime stateStart,
        string? callId, DateTime now)
    {
        // Not Ready reasons
        string? nrCode = null, nrName = null;
        if (state == AgentState.NotReady)
        {
            var reasons = new[] { ("LUNCH", "Lunch"), ("BREAK", "Break"), ("TRAINING", "Training"), ("MEETING", "Meeting") };
            var reason = reasons[_random.Next(reasons.Length)];
            nrCode = reason.Item1;
            nrName = reason.Item2;
        }

        // Call context
        int? callDuration = null;
        CallDirection? callDir = null;
        string? queue = null;
        string? caller = null;

        if (state == AgentState.Talking || state == AgentState.Hold)
        {
            callDuration = _random.Next(30, Math.Max(31, stateDuration));
            callDir = CallDirection.Inbound;
            queue = team switch
            {
                "Sales Team" => "Sales",
                "Support Team" => "Support",
                "VIP Team" => "VIP",
                _ => "General"
            };
            caller = $"+1***{_random.Next(1000, 9999)}";
        }
        else if (state == AgentState.Outbound)
        {
            callDuration = _random.Next(30, Math.Max(31, stateDuration));
            callDir = CallDirection.Outbound;
            caller = $"+1***{_random.Next(1000, 9999)}";
        }

        // Skills and queues
        var skills = team switch
        {
            "Sales Team" => new[] { "Sales", "Russian" },
            "Support Team" => new[] { "Technical", "Russian" },
            "VIP Team" => new[] { "VIP", "Sales", "Russian", "English" },
            _ => new[] { "General" }
        };

        var queues = team switch
        {
            "Sales Team" => new[] { "Sales", "Sales Premium" },
            "Support Team" => new[] { "Support", "Support L2" },
            "VIP Team" => new[] { "VIP", "VIP Priority" },
            _ => new[] { "General" }
        };

        // Core metrics
        var callsToday = _random.Next(15, 45);
        var aht = _random.Next(180, 360);
        var acwAvg = _random.Next(45, 120);
        var occupancy = state == AgentState.LoggedOut ? 0m : _random.Next(700, 950) / 10m;
        var utilisation = _random.Next(650, 850) / 10m;
        var adherence = _random.Next(850, 990) / 10m;

        // Extended metrics - Call counts
        var incomingCalls = _random.Next(10, 35);
        var outgoingCalls = _random.Next(2, 15);
        var internalCalls = _random.Next(0, 8);
        var transferredCalls = _random.Next(0, 5);
        var conferenceCalls = _random.Next(0, 3);
        var abandonedCalls = _random.Next(0, 4);

        // Extended metrics - Time-based
        var talkTime = _random.Next(3600, 14400);
        var holdTime = _random.Next(120, 900);
        var wrapTime = _random.Next(300, 1800);
        var idleTime = _random.Next(600, 3600);
        var loginDuration = _random.Next(14400, 32400);
        var avgTalkTime = _random.Next(180, 420);
        var avgHoldTime = _random.Next(15, 90);
        var avgWrapTime = _random.Next(30, 120);

        // Extended metrics - Performance
        var serviceLevel = _random.Next(800, 990) / 10m;
        var fcr = _random.Next(700, 950) / 10m;
        var csat = _random.Next(750, 980) / 10m;
        var callbacksScheduled = _random.Next(0, 5);
        var callbacksCompleted = _random.Next(0, callbacksScheduled + 1);

        // Alert logic
        var alertLevel = AlertLevel.None;
        string? alertReason = null;

        if (state == AgentState.Acw && stateDuration > 300)
        {
            alertLevel = AlertLevel.Critical;
            alertReason = "ACW > 5 min";
        }
        else if (state == AgentState.Acw && stateDuration > 180)
        {
            alertLevel = AlertLevel.Warning;
            alertReason = "ACW > 3 min";
        }
        else if (state == AgentState.Talking && stateDuration > 1200)
        {
            alertLevel = AlertLevel.Critical;
            alertReason = "Long call > 20 min";
        }
        else if (state == AgentState.Talking && stateDuration > 900)
        {
            alertLevel = AlertLevel.Warning;
            alertReason = "Long call > 15 min";
        }
        else if (occupancy > 95)
        {
            alertLevel = AlertLevel.Critical;
            alertReason = "Occupancy > 95%";
        }
        else if (occupancy > 90)
        {
            alertLevel = AlertLevel.Warning;
            alertReason = "Occupancy > 90%";
        }

        return new AgentStatusDto(
            agentId, name, ext, team,
            state, stateDuration, stateStart, nrCode, nrName,
            callId, callDuration, callDir, queue, caller,
            skills, queues,
            callsToday, aht, acwAvg,
            occupancy, utilisation, adherence,
            incomingCalls, outgoingCalls, internalCalls, transferredCalls, conferenceCalls, abandonedCalls,
            talkTime, holdTime, wrapTime, idleTime, loginDuration, avgTalkTime, avgHoldTime, avgWrapTime,
            serviceLevel, fcr, csat, callbacksScheduled, callbacksCompleted,
            alertLevel != AlertLevel.None, alertLevel, alertReason
        );
    }
}
