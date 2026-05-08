namespace CcDashboard.Domain.Domain;

public class Site
{
    public string SiteId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? SiteName { get; set; }
    public string? Description { get; set; }
    public string? TimeZone { get; set; }   // format: "+10:00"
    public string? ClearTime { get; set; }  // format: "HH:MM" as nvarchar

    public ICollection<BusinessUnit> BusinessUnits { get; set; } = [];
}

public class BusinessUnit
{
    public int BusinessUnitId { get; set; }
    public Guid TenantId { get; set; }
    public string? BusinessUnitName { get; set; }
    public string? Description { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? SiteId { get; set; }

    public Site? Site { get; set; }
    public ICollection<BusinessUnitQueue> QueueAssignments { get; set; } = [];
    public ICollection<BusinessUnitSupergroup> SupergroupAssignments { get; set; } = [];
}

public class Queue
{
    public string QueueId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? Name { get; set; }  // display name from external system, read-only
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
}

public class Supergroup
{
    public int SupergroupId { get; set; }
    public Guid TenantId { get; set; }
    public string? SupergroupName { get; set; }
    public string? Description { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
    public int? SupergroupIdOld { get; set; }

    public ICollection<BusinessUnitSupergroup> BusinessUnitAssignments { get; set; } = [];
    public ICollection<SupergroupAgentGroup> AgentGroupAssignments { get; set; } = [];
}

public class AgentGroup
{
    public string AgentGroupId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? Name { get; set; }  // display name from external system, read-only
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
}

// ── Junction tables ──────────────────────────────────────────────────────────

public class BusinessUnitQueue
{
    public int BusinessUnitId { get; set; }
    public string QueueId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? ClassificationId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public BusinessUnit? BusinessUnit { get; set; }
    public Queue? Queue { get; set; }
}

public class BusinessUnitSupergroup
{
    public int BusinessUnitId { get; set; }
    public int SupergroupId { get; set; }
    public Guid TenantId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public BusinessUnit? BusinessUnit { get; set; }
    public Supergroup? Supergroup { get; set; }
}

public class SupergroupAgentGroup
{
    public int SupergroupId { get; set; }
    public string AgentGroupId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public Supergroup? Supergroup { get; set; }
    public AgentGroup? AgentGroup { get; set; }
}
