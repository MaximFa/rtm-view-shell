using CcDashboard.Core.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class PermissionGroupConfiguration : IEntityTypeConfiguration<PermissionGroup>
{
    public void Configure(EntityTypeBuilder<PermissionGroup> builder)
    {
        builder.ToTable("PermissionGroups");

        builder.HasKey(g => g.Id);

        builder.Property(g => g.Name)
            .IsRequired()
            .HasMaxLength(256);

        builder.HasIndex(g => g.Name)
            .IsUnique();

        builder.Property(g => g.Description)
            .HasMaxLength(1000);

        builder.Property(g => g.MenuPermissions)
            .HasColumnType("text[]");

        builder.Property(g => g.CreatedAt)
            .IsRequired();

        builder.HasMany(g => g.ScreenPermissions)
            .WithOne(sp => sp.Group)
            .HasForeignKey(sp => sp.GroupId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(g => g.ResourcePermissions)
            .WithOne(rp => rp.Group)
            .HasForeignKey(rp => rp.GroupId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
