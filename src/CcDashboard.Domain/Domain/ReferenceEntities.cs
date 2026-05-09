namespace CcDashboard.Domain.Domain;

// Reference tables for PG permissions — synced from CC platform

public class NgcQueue
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

public class NgcAgentGroup
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}
