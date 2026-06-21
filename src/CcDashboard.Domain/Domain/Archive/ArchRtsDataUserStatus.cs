namespace CcDashboard.Domain.Domain.Archive;

/// <summary>
/// Archive copy of RTSData_UserStatus (daily snapshot). Exact column mirror + ArchivedAt/PartTime.
/// Partitioned BY RANGE (PartTime) monthly. PK = (UserId, StatusId, ServerId, OnDate, PartTime).
/// PartTime = to_timestamp(OnDate,'YYYY-MM-DD') (OnDate is the stable snapshot key).
/// ON CONFLICT DO UPDATE (source is UPSERTED daily).
/// </summary>
public class ArchRtsDataUserStatus
{
    // Source natural key
    public string UserId { get; set; } = null!;
    public string StatusId { get; set; } = null!;
    public string ServerId { get; set; } = null!;
    public string OnDate { get; set; } = null!;

    // Partition key (computed, STABLE)
    public DateTime PartTime { get; set; }

    // Archive metadata
    public DateTime ArchivedAt { get; set; }

    // Exact mirror of RTSData_UserStatus columns
    public Guid? TenantId { get; set; }
    public string? StatusName { get; set; }
    public string? StatusGroup { get; set; }
    public int? TotalDuration { get; set; }
    public int? MaxDuraction { get; set; }
    public int? TotalCount { get; set; }
    public DateTime? UpdateTime { get; set; }
    public string? DisplayName { get; set; }
    public string? TimeZone { get; set; }
}
