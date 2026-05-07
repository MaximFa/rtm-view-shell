namespace CcDashboard.Domain.Domain;

public class PermissionGroup
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public uint RowVersion { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public Tenant? Tenant { get; set; }
    public ICollection<MenuPermission> MenuPermissions { get; set; } = [];
    public ICollection<DashboardPermission> DashboardPermissions { get; set; } = [];
    public ICollection<PgQueue> AllowedQueues { get; set; } = [];
    public ICollection<PgSkill> AllowedSkills { get; set; } = [];
    public ICollection<PgAgentSupergroup> AllowedSupergroups { get; set; } = [];
    public ICollection<PgBusinessUnit> AllowedBusinessUnits { get; set; } = [];
}

public class MenuPermission
{
    public Guid PermissionGroupId { get; set; }
    public string MenuKey { get; set; } = string.Empty;
    public Guid TenantId { get; set; }
    public PermissionGroup? PermissionGroup { get; set; }
}

public class DashboardPermission
{
    public Guid PermissionGroupId { get; set; }
    public Guid DashboardId { get; set; }
    public Guid TenantId { get; set; }
    public int AccessLevel { get; set; }
    public PermissionGroup? PermissionGroup { get; set; }
    public Dashboard? Dashboard { get; set; }
}

public class PgQueue
{
    public Guid PermissionGroupId { get; set; }
    public Guid ObjectId { get; set; }
    public Guid TenantId { get; set; }
}

public class PgSkill
{
    public Guid PermissionGroupId { get; set; }
    public Guid ObjectId { get; set; }
    public Guid TenantId { get; set; }
}

public class PgAgentSupergroup
{
    public Guid PermissionGroupId { get; set; }
    public Guid ObjectId { get; set; }
    public Guid TenantId { get; set; }
}

public class PgBusinessUnit
{
    public Guid PermissionGroupId { get; set; }
    public Guid ObjectId { get; set; }
    public Guid TenantId { get; set; }
}
