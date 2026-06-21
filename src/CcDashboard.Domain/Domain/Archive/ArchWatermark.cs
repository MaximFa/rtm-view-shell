namespace CcDashboard.Domain.Domain.Archive;

/// <summary>
/// Tracks archive progress per table+tenant. Archiver scans source rows with UpdateTime > ArchivedThrough.
/// Invariant: archive-FIRST -> purge-SECOND (ArchivedThrough only advances after batch commit).
/// </summary>
public class ArchWatermark
{
    public string TableName { get; set; } = null!;
    public Guid TenantId { get; set; }
    public DateTime ArchivedThrough { get; set; }
}
