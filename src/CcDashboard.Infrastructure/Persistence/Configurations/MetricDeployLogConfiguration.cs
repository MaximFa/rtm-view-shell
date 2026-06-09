using CcDashboard.Domain.Domain.Metrics;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF configuration for MetricDeployLog (hot-reload ledger).
/// Used by ApplyService's ApplyDbContext (NOT Shell's AppDbContext write-surface).
/// Cross-tenant: no Global Query Filter.
/// </summary>
public class MetricDeployLogConfiguration : IEntityTypeConfiguration<MetricDeployLog>
{
    public void Configure(EntityTypeBuilder<MetricDeployLog> builder)
    {
        builder.ToTable("metric_deploy_log", "public");
        builder.HasKey(x => x.MetricId);
        builder.Property(x => x.MetricId).HasColumnName("MetricId").HasMaxLength(200).IsRequired();
        builder.Property(x => x.DeployedAt).HasColumnName("DeployedAt").HasColumnType("timestamptz").IsRequired();
        builder.Property(x => x.SourceCommit).HasColumnName("SourceCommit");
    }
}