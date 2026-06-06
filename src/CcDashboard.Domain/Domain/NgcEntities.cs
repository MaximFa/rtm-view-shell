namespace CcDashboard.Domain.Domain;

// NGC Configuration entities — matches SQL Server NGC_* schema

public class NgcSite
{
    public string SiteId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? SiteName { get; set; }
    public string? Description { get; set; }
    public string? TimeZone { get; set; }   // format: "+10:00"
    public string? ClearTime { get; set; }  // format: "HH:MM" as nvarchar

    public ICollection<NgcBusinessUnit> BusinessUnits { get; set; } = [];
}

public class NgcBusinessUnit
{
    public int BusinessUnitId { get; set; }
    public Guid TenantId { get; set; }
    public string? BusinessUnitName { get; set; }
    public string? Description { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
    public string? SiteId { get; set; }

    public NgcSite? Site { get; set; }
    public ICollection<NgcBusinessUnitQueueClassification> QueueAssignments { get; set; } = [];
    public ICollection<NgcBusinessUnitSupergroup> SupergroupAssignments { get; set; } = [];
}

public class NgcSupergroup
{
    public int SupergroupId { get; set; }
    public Guid TenantId { get; set; }
    public string? SupergroupName { get; set; }
    public string? Description { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
    public int? SupergroupIdOld { get; set; }

    public ICollection<NgcBusinessUnitSupergroup> BusinessUnitAssignments { get; set; } = [];
    public ICollection<NgcSupergroupAgentgroup> AgentGroupAssignments { get; set; } = [];
}

// ── Junction tables ──────────────────────────────────────────────────────────

public class NgcBusinessUnitQueueClassification
{
    public int BusinessUnitId { get; set; }
    public string QueueId { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public string? ClassificationId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public NgcBusinessUnit? BusinessUnit { get; set; }
}

public class NgcBusinessUnitSupergroup
{
    public int BusinessUnitId { get; set; }
    public int SupergroupId { get; set; }
    public Guid TenantId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public NgcBusinessUnit? BusinessUnit { get; set; }
    public NgcSupergroup? Supergroup { get; set; }
}

public class NgcSupergroupAgentgroup
{
    public int Id { get; set; } // Surrogate PK (EF requires key for navigation properties)
    public int? SupergroupId { get; set; }
    public string? AgentgroupId { get; set; }
    public Guid TenantId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }

    public NgcSupergroup? Supergroup { get; set; }
}

public class NgcUserAgentgroup
{
    public int Id { get; set; } // Surrogate PK (EF requires key)
    public string? UserId { get; set; }
    public string? AgentgroupId { get; set; }
    public Guid TenantId { get; set; }
    public DateTime? CreatedDatetime { get; set; }
    public string? CreatedBy { get; set; }
}
