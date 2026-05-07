using CcDashboard.Core.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ScreenPermissionConfiguration : IEntityTypeConfiguration<ScreenPermission>
{
    public void Configure(EntityTypeBuilder<ScreenPermission> builder)
    {
        builder.ToTable("ScreenPermissions");

        builder.HasKey(sp => new { sp.ScreenId, sp.GroupId });

        builder.HasOne(sp => sp.Screen)
            .WithMany(s => s.Permissions)
            .HasForeignKey(sp => sp.ScreenId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(sp => sp.Group)
            .WithMany(g => g.ScreenPermissions)
            .HasForeignKey(sp => sp.GroupId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
