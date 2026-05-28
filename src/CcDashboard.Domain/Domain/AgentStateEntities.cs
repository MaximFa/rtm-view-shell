namespace CcDashboard.Domain.Domain;

/// <summary>
/// Raw CC-platform agent state names per tenant.
/// Maps to table: tenant_agent_states
/// </summary>
public class AgentState
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string AgentStateName { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Tenant Tenant { get; set; } = null!;
    public AgentStateDefinition? Definition { get; set; }
}

/// <summary>
/// Display group names for agent states per tenant (e.g., "Available", "Break").
/// Maps to table: tenant_agent_state_groups
/// </summary>
public class AgentStateGroup
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string GroupName { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Tenant Tenant { get; set; } = null!;
    public ICollection<AgentStateDefinition> Definitions { get; set; } = [];
}

/// <summary>
/// Junction table: one AgentState maps to exactly one AgentStateGroup per tenant.
/// Maps to table: tenant_agent_state_definitions
/// </summary>
public class AgentStateDefinition
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid AgentStateId { get; set; }
    public Guid AgentStateGroupId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public AgentState State { get; set; } = null!;
    public AgentStateGroup Group { get; set; } = null!;
}
