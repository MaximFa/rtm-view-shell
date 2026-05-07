using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Audit;

public class AuditDbContext(DbContextOptions<AuditDbContext> options) : DbContext(options)
{
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.HasDefaultSchema("audit");
        mb.Entity<AuditLog>(e =>
        {
            e.ToTable("audit_logs");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.EventType).HasMaxLength(64).IsRequired();
            e.Property(x => x.UserName).HasMaxLength(256);
            e.Property(x => x.EventResult).HasConversion<string>().HasMaxLength(16);
            e.Property(x => x.Details).HasColumnType("jsonb");
            e.HasIndex(x => new { x.TenantId, x.CreatedAt });
            e.HasIndex(x => new { x.EventType, x.CreatedAt });
        });
    }
}
