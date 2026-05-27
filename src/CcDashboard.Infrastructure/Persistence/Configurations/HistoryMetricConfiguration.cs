using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class HistoryMetricConfiguration : IEntityTypeConfiguration<HistoryMetric>
{
    public void Configure(EntityTypeBuilder<HistoryMetric> builder)
    {
        builder.ToTable("history_metrics");
        builder.HasKey(m => m.MetricId);
        builder.Property(m => m.MetricId).HasMaxLength(100).IsRequired();
        builder.Property(m => m.Description).HasMaxLength(200).IsRequired();
        builder.Property(m => m.DataType).HasMaxLength(20).IsRequired();
        builder.Property(m => m.MetricFunction).HasMaxLength(50).IsRequired();
        builder.Property(m => m.MetricParameter).HasMaxLength(200).IsRequired();
        builder.Property(m => m.MetricFormat).HasMaxLength(20).IsRequired();
        builder.Property(m => m.DefaultValue).HasMaxLength(20).IsRequired();
        builder.Property(m => m.ValueType).HasMaxLength(20).IsRequired();
        builder.Property(m => m.MetricType).HasMaxLength(50).IsRequired();
        // No TenantId — cross-tenant shell catalogue (same pattern as RtsGridMetric)
    }
}
