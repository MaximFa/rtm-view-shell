using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ReportScheduleConfiguration : IEntityTypeConfiguration<ReportSchedule>
{
    private readonly ITenantContext _tenantContext;

    public ReportScheduleConfiguration(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public void Configure(EntityTypeBuilder<ReportSchedule> builder)
    {
        builder.ToTable("report_schedules");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();
        builder.Property(x => x.Cadence).HasMaxLength(100).IsRequired();
        builder.Property(x => x.Recipients).HasColumnType("jsonb");
        builder.Property(x => x.Format).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.DateWindow).HasConversion<string>().HasMaxLength(20);

        builder.HasIndex(x => x.ReportScreenId);
        builder.HasIndex(x => new { x.TenantId, x.IsActive, x.NextRunAt });

        builder.HasOne(x => x.ReportScreen)
            .WithMany(x => x.Schedules)
            .HasForeignKey(x => x.ReportScreenId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId);
    }
}
