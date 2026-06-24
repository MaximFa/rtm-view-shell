using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ReportWidgetConfiguration : IEntityTypeConfiguration<ReportWidget>
{
    private readonly ITenantContext _tenantContext;

    public ReportWidgetConfiguration(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public void Configure(EntityTypeBuilder<ReportWidget> builder)
    {
        builder.ToTable("report_widgets");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();
        builder.Property(x => x.WidgetType).HasConversion<string>().HasMaxLength(50);
        builder.Property(x => x.PositionJson).HasColumnType("jsonb");
        builder.Property(x => x.ConfigJson).HasColumnType("jsonb");

        builder.HasIndex(x => x.ReportScreenId);
        builder.HasIndex(x => x.TenantId);

        builder.HasOne(x => x.ReportScreen)
            .WithMany(x => x.Widgets)
            .HasForeignKey(x => x.ReportScreenId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId && !x.IsDeleted);
    }
}
