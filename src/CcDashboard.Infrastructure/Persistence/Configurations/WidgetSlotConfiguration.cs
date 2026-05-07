using CcDashboard.Core.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CcDashboard.Infrastructure.Persistence.Configurations;

public class WidgetSlotConfiguration : IEntityTypeConfiguration<WidgetSlot>
{
    public void Configure(EntityTypeBuilder<WidgetSlot> builder)
    {
        builder.ToTable("WidgetSlots");

        builder.HasKey(ws => ws.Id);

        builder.Property(ws => ws.CategoryId)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(ws => ws.WidgetTypeId)
            .IsRequired()
            .HasMaxLength(256);

        builder.HasIndex(ws => ws.ScreenId);

        builder.HasOne(ws => ws.Screen)
            .WithMany(s => s.WidgetSlots)
            .HasForeignKey(ws => ws.ScreenId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
