namespace CcDashboard.Domain.Domain.Archive;

/// <summary>
/// Archive copy of RTSData_ChatMessage. Exact column mirror + ArchivedAt/PartTime.
/// Partitioned BY RANGE (PartTime) monthly. PK = (MessageId, ServerId, OnDate, PartTime).
/// PartTime = COALESCE(TimeStamp, to_timestamp(OnDate,'YYYY-MM-DD')).
/// ON CONFLICT DO UPDATE (default UPSERT behavior).
/// </summary>
public class ArchRtsDataChatMessage
{
    // Source natural key
    public string MessageId { get; set; } = null!;
    public string ServerId { get; set; } = null!;
    public string OnDate { get; set; } = null!;

    // Partition key (computed, STABLE)
    public DateTime PartTime { get; set; }

    // Archive metadata
    public DateTime ArchivedAt { get; set; }

    // Exact mirror of RTSData_ChatMessage columns (TenantId added for GQF)
    public Guid? TenantId { get; set; }
    public string? InteractionId { get; set; }
    public int? SegmentId { get; set; }
    public string? UserId { get; set; }
    public string? MsgDirection { get; set; }
    public string? Sender { get; set; }
    public string? Recipient { get; set; }
    public string? Body { get; set; }
    public string? DeliveryStatus { get; set; }
    public DateTime? UpdateTime { get; set; }
    public DateTime? TimeStamp { get; set; }
}
