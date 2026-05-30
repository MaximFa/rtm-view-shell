namespace CcDashboard.Domain.Domain;

/// <summary>
/// RTSData_Interaction — call/chat interaction records written by the CC backend.
/// Shell access: read-only. PK: (InteractionId, Segment, OnDate, ServerId, Workgroup).
/// OnDate format: DD/MM/YYYY (varchar). AnsweredDateTime null marker: 1753-01-01 00:00:00.
/// </summary>
public class RtsDataInteraction
{
    public Guid? TenantId { get; set; }
    public string InteractionId { get; set; } = string.Empty;
    public int Segment { get; set; }
    public string OnDate { get; set; } = string.Empty;   // DD/MM/YYYY
    public string ServerId { get; set; } = string.Empty;
    public string Workgroup { get; set; } = string.Empty; // = QueueId in NGC_Queue
    public string UserId { get; set; } = string.Empty;
    public string? ClassificationCode { get; set; }
    public string? InteractionType { get; set; }  // Call, Chat, Email, Callback
    public string? CallType { get; set; }
    public string? Direction { get; set; }         // Incoming, Outgoing
    public string? CustomCallData { get; set; }
    public bool? IsTransferred { get; set; }
    public bool? IsAnswered { get; set; }
    public bool? IsInQueue { get; set; }
    public bool? IsTalk { get; set; }
    public bool? IsAbandoned { get; set; }
    public int? TimeInQueue { get; set; }          // seconds
    public int? TalkTime { get; set; }             // seconds
    public DateTime? InQueueDateTime { get; set; } // timestamptz — primary for interval grouping
    public DateTime? AnsweredDateTime { get; set; } // null marker: 1753-01-01 00:00:00.000
    public DateTime? UpdateTime { get; set; }
    public string? LastUserId { get; set; }
    public string? LastWorkgroup { get; set; }
    public bool? IsMessaging { get; set; }
    public string? RemoteAddress { get; set; }
    public bool? IsCallbackRequest { get; set; }
    public string? TimeZone { get; set; }
    // CustomCallData1..CustomCallData20 omitted — add on demand
}

/// <summary>
/// RTSData_UserStatus — aggregated per-agent status statistics for the current day.
/// Shell access: read-only. PK: (UserId, StatusId, ServerId, OnDate).
/// TotalDuration and MaxDuration are in seconds.
/// </summary>
public class RtsDataUserStatus
{
    public Guid? TenantId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string StatusId { get; set; } = string.Empty;
    public string ServerId { get; set; } = string.Empty;
    public string OnDate { get; set; } = string.Empty;   // DD/MM/YYYY
    public string? StatusName { get; set; }
    public string? StatusGroup { get; set; }  // AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING
    public int? TotalDuration { get; set; }   // seconds
    public int? MaxDuration { get; set; }     // seconds
    public int? TotalCount { get; set; }
    public DateTime? UpdateTime { get; set; }
    public string? DisplayName { get; set; }
    public string? TimeZone { get; set; }
}

/// <summary>
/// RTSData_UserStatusLog — time-series log of individual agent status transitions.
/// Shell access: read-only. PK: Id (serial).
/// IMPORTANT: Duration is in MILLISECONDS (not seconds).
/// StatusGroup canonical values: AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING, NULL.
/// </summary>
public class RtsDataUserStatusLog
{
    public int Id { get; set; }
    public Guid? TenantId { get; set; }
    public string? UserId { get; set; }
    public string? StatusId { get; set; }
    public string? StatusGroup { get; set; }  // NEW — canonical group, NULL if unclassified
    public string? ServerId { get; set; }
    public string? OnDate { get; set; }       // DD/MM/YYYY
    public DateTime? StartTime { get; set; }
    public DateTime? EndTime { get; set; }    // NULL = still in this status
    public long? Duration { get; set; }       // MILLISECONDS
    public DateTime? UpdateTime { get; set; }
    public string? TimeZone { get; set; }
}

/// <summary>
/// RTSData_ChatMessage - chat message records written by the CC backend.
/// Shell access: read-only. PK: (MessageId, ServerId, OnDate).
/// UPSERT uses UNIQUE index on (MessageId, ServerId) - different from PK.
/// </summary>
public class RtsDataChatMessage
{
    public string MessageId { get; set; } = string.Empty;
    public string ServerId { get; set; } = string.Empty;
    public string OnDate { get; set; } = string.Empty;   // DD/MM/YYYY
    public string? InteractionId { get; set; }
    public int? SegmentId { get; set; }
    public string? UserId { get; set; }
    public string? MsgDirection { get; set; }
    public string? Sender { get; set; }
    public string? Recipient { get; set; }
    public string? Body { get; set; }
    public string? DeliveryStatus { get; set; }
    public DateTime? UpdateTime { get; set; }
    public DateTime? MsgTimeStamp { get; set; }  // Maps to column "TimeStamp"
}
