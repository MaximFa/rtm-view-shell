using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class ScreenConfiguration : IEntityTypeConfiguration<Screen>
{
    public void Configure(EntityTypeBuilder<Screen> builder)
    {
        builder.ToTable("Screens");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.Name)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(s => s.Status)
            .HasConversion<string>()
            .HasMaxLength(32)
            .HasDefaultValue(ScreenStatus.Draft);

        builder.Property(s => s.CreatedAt)
            .IsRequired();

        builder.Property(s => s.UpdatedAt)
            .IsRequired();

        builder.HasIndex(s => s.OwnerId);

        builder.HasMany(s => s.WidgetSlots)
            .WithOne(ws => ws.Screen)
            .HasForeignKey(ws => ws.ScreenId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(s => s.Permissions)
            .WithOne(sp => sp.Screen)
            .HasForeignKey(sp => sp.ScreenId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
