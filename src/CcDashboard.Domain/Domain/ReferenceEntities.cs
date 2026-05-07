namespace CcDashboard.Domain.Domain;

public class Queue
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

public class Skill
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

public class AgentSupergroup
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}

public class BusinessUnit
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}
