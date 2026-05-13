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

    // Core metrics
    int CallsHandledToday,
    int AhtSeconds,
    int AcwAvgSeconds,
    decimal OccupancyPercent,
    decimal UtilisationPercent,
    decimal AdherencePercent,

    // Extended metrics - Call counts
    int IncomingCalls,
    int OutgoingCalls,
    int InternalCalls,
    int TransferredCalls,
    int ConferenceCalls,
    int AbandonedCalls,

    // Extended metrics - Time-based
    int TalkTimeSeconds,
    int HoldTimeSeconds,
    int WrapTimeSeconds,
    int IdleTimeSeconds,
    int LoginDurationSeconds,
    int AvgTalkTimeSeconds,
    int AvgHoldTimeSeconds,
    int AvgWrapTimeSeconds,

    // Extended metrics - Performance
    decimal ServiceLevelPercent,
    decimal FirstCallResolutionPercent,
    decimal CustomerSatisfactionPercent,
    int CallbacksScheduled,
    int CallbacksCompleted,

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
    int GridId,
    DateTime Timestamp,
    List<AgentStatusDto> Agents
);
