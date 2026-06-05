#!/usr/bin/env python3
"""Add UserWidgetSettings DbSet and entity configuration to AppDbContext."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\Persistence\AppDbContext.cs"

def main():
    print(f"Processing {PATH}")

    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add using statement for UserWidgetSettings
    if "using CcDashboard.Domain.Domain;" not in text:
        text = text.replace(
            "using CcDashboard.Domain.Domain;",
            "using CcDashboard.Domain.Domain;"
        )

    # 2. Add DbSet after InfoSlotMessages
    text = text.replace(
        "    public DbSet<InfoSlotMessage> InfoSlotMessages => Set<InfoSlotMessage>();\n\n    protected override",
        """    public DbSet<InfoSlotMessage> InfoSlotMessages => Set<InfoSlotMessage>();

    // User widget view settings (per-user per-widget local config)
    public DbSet<UserWidgetSettings> UserWidgetSettings => Set<UserWidgetSettings>();

    protected override"""
    )

    # 3. Add entity configuration before closing brace of OnModelCreating
    old_end = """            e.HasOne(x => x.InfoSlot).WithMany(x => x.Messages).HasForeignKey(x => x.InfoSlotId).OnDelete(DeleteBehavior.Cascade);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

    }
}"""

    new_end = """            e.HasOne(x => x.InfoSlot).WithMany(x => x.Messages).HasForeignKey(x => x.InfoSlotId).OnDelete(DeleteBehavior.Cascade);
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

        // UserWidgetSettings — per-user widget view preferences
        mb.Entity<UserWidgetSettings>(e =>
        {
            e.ToTable("user_widget_settings");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.HasIndex(x => new { x.TenantId, x.UserId, x.WidgetId }).IsUnique();
            e.Property(x => x.SettingsJson).HasColumnType("jsonb");
            e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
        });

    }
}"""

    text = text.replace(old_end, new_end)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    main()
