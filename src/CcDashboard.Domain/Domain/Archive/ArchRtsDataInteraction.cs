namespace CcDashboard.Domain.Domain.Archive;

/// <summary>
/// Archive copy of RTSData_Interaction. Exact column mirror + ArchivedAt/PartTime.
/// Partitioned BY RANGE (PartTime) monthly. PK = (InteractionId, Segment, OnDate, ServerId, Workgroup, PartTime).
/// PartTime = COALESCE(InQueueDateTime, to_timestamp(OnDate,'YYYY-MM-DD')) - STABLE partition key.
/// ON CONFLICT DO UPDATE (source is UPSERTED, UpdateTime moves).
/// </summary>
public class ArchRtsDataInteraction
{
    // Source natural key
    public string InteractionId { get; set; } = null!;
    public int Segment { get; set; }
    public string OnDate { get; set; } = null!;
    public string ServerId { get; set; } = null!;
    public string Workgroup { get; set; } = null!;

    // Partition key (computed, STABLE)
    public DateTime PartTime { get; set; }

    // Archive metadata
    public DateTime ArchivedAt { get; set; }

    // Exact mirror of RTSData_Interaction columns
    public Guid? TenantId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string? ClassificationCode { get; set; }
    public string? InteractionType { get; set; }
    public string? CallType { get; set; }
    public string? Direction { get; set; }
    public string? CustomCallData { get; set; }
    public bool? IsTransferred { get; set; }
    public bool? IsAnswered { get; set; }
    public bool? IsInQueue { get; set; }
    public bool? IsTalk { get; set; }
    public bool? IsAbandoned { get; set; }
    public int? TimeInQueue { get; set; }
    public int? TalkTime { get; set; }
    public DateTime? InQueueDateTime { get; set; }
    public DateTime? AnsweredDateTime { get; set; }
    public DateTime? UpdateTime { get; set; }
    public string? LastUserId { get; set; }
    public string? LastWorkgroup { get; set; }
    public bool? IsMessaging { get; set; }
    public string? RemoteAddress { get; set; }
    public bool? IsCallbackRequest { get; set; }
    public string? TimeZone { get; set; }
    public string? CustomCallData1 { get; set; }
    public string? CustomCallData2 { get; set; }
    public string? CustomCallData3 { get; set; }
    public string? CustomCallData4 { get; set; }
    public string? CustomCallData5 { get; set; }
    public string? CustomCallData6 { get; set; }
    public string? CustomCallData7 { get; set; }
    public string? CustomCallData8 { get; set; }
    public string? CustomCallData9 { get; set; }
    public string? CustomCallData10 { get; set; }
    public string? CustomCallData11 { get; set; }
    public string? CustomCallData12 { get; set; }
    public string? CustomCallData13 { get; set; }
    public string? CustomCallData14 { get; set; }
    public string? CustomCallData15 { get; set; }
    public string? CustomCallData16 { get; set; }
    public string? CustomCallData17 { get; set; }
    public string? CustomCallData18 { get; set; }
    public string? CustomCallData19 { get; set; }
    public string? CustomCallData20 { get; set; }
}
