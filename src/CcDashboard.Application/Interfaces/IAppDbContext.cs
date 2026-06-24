using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Application-level abstraction over AppDbContext (ADR-009, ARCH-11).
/// Handlers in Application depend on this interface, not the concrete Infrastructure context.
/// Exposes DbSet properties + SaveChangesAsync + DatabaseFacade for raw SQL (CODE-01).
/// </summary>
public interface IAppDbContext : IAsyncDisposable
{
    // Agent State Registry (CC-008) — used by AgentStateHandlers
    DbSet<AgentState> AgentStates { get; }
    DbSet<AgentStateGroup> AgentStateGroups { get; }
    DbSet<AgentStateDefinition> AgentStateDefinitions { get; }

    // Info Slot system (CC-010) — used by InfoSlotHandlers
    DbSet<InfoSlot> InfoSlots { get; }
    DbSet<InfoSlotPermission> InfoSlotPermissions { get; }
    DbSet<InfoSlotMessage> InfoSlotMessages { get; }

    // User widget settings — used by UserWidgetSettings handlers
    DbSet<UserWidgetSettings> UserWidgetSettings { get; }

    // For raw SQL / transactions (FromSqlInterpolated, ExecuteSqlInterpolated per CODE-01)
    DatabaseFacade Database { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
