using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ReportCategoryConfiguration : IEntityTypeConfiguration<ReportCategory>
{
    private readonly ITenantContext _tenantContext;

    public ReportCategoryConfiguration(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public void Configure(EntityTypeBuilder<ReportCategory> builder)
    {
        builder.ToTable("report_categories");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.HasIndex(x => new { x.TenantId, x.Name }).IsUnique();
        builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);
    }
}
