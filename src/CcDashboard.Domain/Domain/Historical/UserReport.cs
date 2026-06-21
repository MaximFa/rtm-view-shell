namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// User-created or system report configuration.
/// Stored in user_reports table (not partitioned).
/// Soft-delete per Dashboard pattern (CLAUDE.md §6/§7).
/// </summary>
public class UserReport
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSystem { get; set; }
    public bool IsPublic { get; set; }
    public Guid? OwnerUserId { get; set; }
    public string? Config { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public Guid UpdatedByUserId { get; set; }

    // Soft-delete fields (same pattern as Dashboard)
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
    public Guid? DeletedByUserId { get; set; }
}
