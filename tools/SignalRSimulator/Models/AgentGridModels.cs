namespace SignalRSimulator.Models;

public record AgentStatusDto(
    string AgentId,
    string DisplayName,
    string Extension,
    string TeamName,

    // Current state
    AgentState State,
    int StateDurationSeconds,
    DateTime StateStartedAt,
    string? NotReadyReasonCode,
    string? NotReadyReasonName,

    // Call context
    string? CurrentCallId,
    int? CallDurationSeconds,
    CallDirection? CallDirection,
    string? QueueName,
    string? CallerId,

    // Skills and queues
    string[] Skills,
    string[] AssignedQueues,

    // Metrics
    int CallsHandledToday,
    int AhtSeconds,
    int AcwAvgSeconds,
    decimal OccupancyPercent,
    decimal UtilisationPercent,
    decimal AdherencePercent,

    // Alerts
    bool IsOverThreshold,
    AlertLevel AlertLevel,
    string? AlertReason
);

public enum AgentState
{
    Ready,
    Talking,
    Hold,
    Acw,
    NotReady,
    Outbound,
    LoggedOut
}

public enum CallDirection
{
    Inbound,
    Outbound,
    Internal
}

public enum AlertLevel
{
    None,
    Warning,
    Critical
}

public record AgentGridUpdate(
    Guid GridId,
    DateTime Timestamp,
    List<AgentStatusDto> Agents
);
