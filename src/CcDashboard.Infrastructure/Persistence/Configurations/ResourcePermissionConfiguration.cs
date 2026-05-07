using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ResourcePermissionConfiguration : IEntityTypeConfiguration<ResourcePermission>
{
    public void Configure(EntityTypeBuilder<ResourcePermission> builder)
    {
        builder.ToTable("ResourcePermissions");

        builder.HasKey(rp => rp.Id);

        builder.Property(rp => rp.ResourceType)
            .HasConversion<string>()
            .HasMaxLength(32)
            .IsRequired();

        builder.Property(rp => rp.ResourceId)
            .IsRequired()
            .HasMaxLength(256);

        builder.HasIndex(rp => new { rp.GroupId, rp.ResourceType });

        builder.HasOne(rp => rp.Group)
            .WithMany(g => g.ResourcePermissions)
            .HasForeignKey(rp => rp.GroupId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
