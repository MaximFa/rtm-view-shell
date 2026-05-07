using CcDashboard.Core.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class AuditEventConfiguration : IEntityTypeConfiguration<AuditEvent>
{
    public void Configure(EntityTypeBuilder<AuditEvent> builder)
    {
        builder.ToTable("AuditEvents");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.EventType)
            .HasConversion<string>()
            .HasMaxLength(64)
            .IsRequired();

        builder.Property(a => a.IpAddress)
            .IsRequired()
            .HasMaxLength(45); // max IPv6 length

        builder.Property(a => a.UserAgent)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(a => a.Detail)
            .HasMaxLength(2000);

        builder.Property(a => a.OccurredAt)
            .IsRequired();

        builder.HasIndex(a => a.UserId);
        builder.HasIndex(a => a.OccurredAt);

        // No FK on UserId — records survive user deletion
    }
}
