namespace CcDashboard.Domain.Domain.Archive;

/// <summary>
/// Archive copy of RTSData_UserStatusLog. Exact column mirror + ArchivedAt/PartTime.
/// Partitioned BY RANGE (PartTime) monthly. PK = (Id, PartTime).
/// PartTime = COALESCE(StartTime, to_timestamp(OnDate,'YYYY-MM-DD')).
/// ON CONFLICT DO NOTHING (source is APPEND-ONLY).
/// </summary>
public class ArchRtsDataUserStatusLog
{
    // Source natural key
    public int Id { get; set; }

    // Partition key (computed, STABLE)
    public DateTime PartTime { get; set; }

    // Archive metadata
    public DateTime ArchivedAt { get; set; }

    // Exact mirror of RTSData_UserStatusLog columns
    public Guid? TenantId { get; set; }
    public string? UserId { get; set; }
    public string? StatusId { get; set; }
    public string? ServerId { get; set; }
    public string? OnDate { get; set; }
    public DateTime? StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public long? Duration { get; set; }
    public DateTime? UpdateTime { get; set; }
    public string? TimeZone { get; set; }
    public string? StatusGroup { get; set; }
}
