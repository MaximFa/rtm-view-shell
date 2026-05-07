using CcDashboard.Core.Enums;

namespace CcDashboard.Core.Domain;

public class AuditEvent
{
    public Guid Id { get; set; }
    public Guid? UserId { get; set; }
    public AuditEventType EventType { get; set; }
    public string IpAddress { get; set; } = string.Empty;
    public string UserAgent { get; set; } = string.Empty;
    public string? Detail { get; set; }
    public DateTime OccurredAt { get; set; }
}
