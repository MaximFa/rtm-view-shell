using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ReportPermissionConfiguration : IEntityTypeConfiguration<ReportPermission>
{
    private readonly ITenantContext _tenantContext;

    public ReportPermissionConfiguration(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public void Configure(EntityTypeBuilder<ReportPermission> builder)
    {
        builder.ToTable("report_permissions");
        builder.HasKey(x => new { x.PermissionGroupId, x.ReportScreenId });

        builder.HasIndex(x => x.ReportScreenId);

        builder.HasOne(x => x.PermissionGroup)
            .WithMany()
            .HasForeignKey(x => x.PermissionGroupId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.ReportScreen)
            .WithMany(x => x.Permissions)
            .HasForeignKey(x => x.ReportScreenId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);
    }
}
