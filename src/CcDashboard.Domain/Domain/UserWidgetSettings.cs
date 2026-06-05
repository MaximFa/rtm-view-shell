namespace CcDashboard.Domain.Domain;

/// <summary>
/// Stores per-user widget view preferences for a specific widget instance.
/// One row per (TenantId, UserId, WidgetId). SettingsJson is opaque jsonb.
/// </summary>
public class UserWidgetSettings
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public Guid WidgetId { get; set; }      // DashboardWidget.Id
    public string SettingsJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
