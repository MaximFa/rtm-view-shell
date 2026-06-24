using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ReportScreenConfiguration : IEntityTypeConfiguration<ReportScreen>
{
    private readonly ITenantContext _tenantContext;

    public ReportScreenConfiguration(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public void Configure(EntityTypeBuilder<ReportScreen> builder)
    {
        builder.ToTable("report_screens");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Description).HasMaxLength(500);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.LayoutJson).HasColumnType("jsonb");
        builder.Property(x => x.RowVersion).IsRowVersion().HasColumnName("xmin").HasColumnType("xid");

        builder.HasIndex(x => new { x.TenantId, x.Name });
        builder.HasIndex(x => x.CategoryId);

        builder.HasOne(x => x.Category)
            .WithMany(x => x.ReportScreens)
            .HasForeignKey(x => x.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasQueryFilter(x => x.TenantId == _tenantContext.TenantId && !x.IsDeleted);
    }
}
