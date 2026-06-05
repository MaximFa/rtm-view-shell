# CC Task: Replace localStorage with UserWidgetSettings DB table for DayTrend local view config

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Architecture

Replace browser localStorage with a server-side `user_widget_settings` table.
One row per (TenantId, UserId, WidgetId). SettingsJson is jsonb — opaque per widget type.

```
Domain         → UserWidgetSettings entity
Infrastructure → AppDbContext DbSet + GQF + EF migration
Application    → GetUserWidgetSettingsQuery + SaveUserWidgetSettingsCommand + DeleteUserWidgetSettingsCommand
Web            → DayTrendWidget.razor — replace localStorage calls with Mediator.Send(...)
```

---

## File 1 — NEW: `src/CcDashboard.Domain/Domain/UserWidgetSettings.cs`

```csharp
namespace CcDashboard.Domain.Domain;

/// <summary>
/// Stores per-user widget view preferences for a specific widget instance.
/// One row per (TenantId, UserId, WidgetId). SettingsJson is opaque jsonb.
/// </summary>
public class UserWidgetSettings
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public Guid WidgetId { get; set; }      // DashboardWidget.Id
    public string SettingsJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
```

---

## File 2 — MODIFY: `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs`

### 2a — Add DbSet (after other DbSets):
```csharp
public DbSet<UserWidgetSettings> UserWidgetSettings => Set<UserWidgetSettings>();
```

### 2b — Add in OnModelCreating (follow existing GQF pattern):
```csharp
modelBuilder.Entity<UserWidgetSettings>(e =>
{
    e.ToTable("user_widget_settings");
    e.HasKey(x => x.Id);
    e.HasIndex(x => new { x.TenantId, x.UserId, x.WidgetId }).IsUnique();
    e.Property(x => x.SettingsJson).HasColumnType("jsonb");
    e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
});
```

---

## File 3 — Generate EF migration

```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet ef migrations add AddUserWidgetSettings \
  --context AppDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

Verify migration file was created in `src/CcDashboard.Infrastructure/Migrations/`.

---

## File 4 — NEW: `src/CcDashboard.Application/Queries/Widgets/GetUserWidgetSettingsQuery.cs`

```csharp
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Queries.Widgets;

public record GetUserWidgetSettingsQuery(Guid WidgetId) : IRequest<string?>;

public sealed class GetUserWidgetSettingsQueryHandler(
    IDbContextFactory<AppDbContext> dbFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetUserWidgetSettingsQuery, string?>
{
    public async Task<string?> Handle(GetUserWidgetSettingsQuery query, CancellationToken ct)
    {
        if (currentUser.UserId is null) return null;

        await using var db = await dbFactory.CreateDbContextAsync(ct);
        var row = await db.UserWidgetSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == query.WidgetId,
                ct);
        return row?.SettingsJson;
    }
}
```

---

## File 5 — NEW: `src/CcDashboard.Application/Commands/Widgets/SaveUserWidgetSettingsCommand.cs`

```csharp
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Application.Commands.Widgets;

public record SaveUserWidgetSettingsCommand(Guid WidgetId, string SettingsJson) : IRequest;

public sealed class SaveUserWidgetSettingsCommandHandler(
    IDbContextFactory<AppDbContext> dbFactory,
    ICurrentUserAccessor currentUser,
    ITenantContext tenantContext,
    IDateTimeProvider clock)
    : IRequestHandler<SaveUserWidgetSettingsCommand>
{
    public async Task Handle(SaveUserWidgetSettingsCommand cmd, CancellationToken ct)
    {
        if (currentUser.UserId is null) return;

        await using var db = await dbFactory.CreateDbContextAsync(ct);

        var existing = await db.UserWidgetSettings
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == cmd.WidgetId,
                ct);

        if (existing is null)
        {
            db.UserWidgetSettings.Add(new UserWidgetSettings
            {
                Id           = Uuid.NewSequential(),
                TenantId     = tenantContext.TenantId,
                UserId       = currentUser.UserId.Value,
                WidgetId     = cmd.WidgetId,
                SettingsJson = cmd.SettingsJson,
                CreatedAt    = clock.UtcNow,
                UpdatedAt    = clock.UtcNow
            });
        }
        else
        {
            existing.SettingsJson = cmd.SettingsJson;
            existing.UpdatedAt    = clock.UtcNow;
        }

        await db.SaveChangesAsync(ct);
    }
}
```

---

## File 6 — NEW: `src/CcDashboard.Application/Commands/Widgets/DeleteUserWidgetSettingsCommand.cs`

```csharp
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Commands.Widgets;

public record DeleteUserWidgetSettingsCommand(Guid WidgetId) : IRequest;

public sealed class DeleteUserWidgetSettingsCommandHandler(
    IDbContextFactory<AppDbContext> dbFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<DeleteUserWidgetSettingsCommand>
{
    public async Task Handle(DeleteUserWidgetSettingsCommand cmd, CancellationToken ct)
    {
        if (currentUser.UserId is null) return;

        await using var db = await dbFactory.CreateDbContextAsync(ct);
        var row = await db.UserWidgetSettings
            .FirstOrDefaultAsync(
                x => x.UserId == currentUser.UserId.Value && x.WidgetId == cmd.WidgetId,
                ct);
        if (row is not null)
        {
            db.UserWidgetSettings.Remove(row);
            await db.SaveChangesAsync(ct);
        }
    }
}
```

---

## File 7 — MODIFY: `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

### 7a — Remove @inject ICurrentUserAccessor CurrentUser

Delete the line:
```razor
@inject CcDashboard.Domain.Interfaces.ICurrentUserAccessor CurrentUser
```

### 7b — Add @using for new commands/queries

At the top with other @using directives, add:
```razor
@using CcDashboard.Application.Commands.Widgets
```

### 7c — Remove LocalStorageKey property

Delete:
```csharp
private string LocalStorageKey =>
    $"cc:daytrendview:{CurrentUser.UserId}:{WidgetInstanceId}";
```

### 7d — Replace LoadLocalOverridesAsync

Find the entire `private async Task LoadLocalOverridesAsync()` method and replace with:

```csharp
private async Task LoadLocalOverridesAsync()
{
    try
    {
        var json = await Mediator.Send(new GetUserWidgetSettingsQuery(WidgetInstanceId), _cts.Token);
        if (string.IsNullOrEmpty(json)) return;

        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        if (root.TryGetProperty("buId", out var buEl) && buEl.TryGetInt32(out var buId) && buId > 0)
            _localBuId = buId;

        if (root.TryGetProperty("metrics", out var mEl) && mEl.ValueKind == JsonValueKind.Array)
        {
            _localMetricIds = mEl.EnumerateArray()
                .Select(x => x.GetString() ?? "")
                .Where(s => !string.IsNullOrEmpty(s))
                .ToHashSet();
            _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();
        }

        if (root.TryGetProperty("agentMetrics", out var amEl) && amEl.ValueKind == JsonValueKind.Array)
        {
            _localAgentMetricIds = amEl.EnumerateArray()
                .Select(x => x.GetString() ?? "")
                .Where(s => !string.IsNullOrEmpty(s))
                .ToHashSet();
            _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();
        }

        if (root.TryGetProperty("chartType", out var ctEl) && ctEl.ValueKind == JsonValueKind.String)
        {
            _localChartType    = ctEl.GetString();
            _viewChartType     = _localChartType ?? "line";
        }

        if (root.TryGetProperty("intervalMinutes", out var intEl) && intEl.TryGetInt32(out var intVal) && intVal > 0)
        {
            _localIntervalMinutes = intVal;
            _viewIntervalMinutes  = intVal;
        }

        if (root.TryGetProperty("metricColors", out var mcEl) && mcEl.ValueKind == JsonValueKind.Object)
        {
            _localMetricColors = mcEl.EnumerateObject()
                .Where(p => !string.IsNullOrEmpty(p.Value.GetString()))
                .ToDictionary(p => p.Name, p => p.Value.GetString()!);
            _metrics = _metrics.Select(m =>
                _localMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
        }

        if (root.TryGetProperty("agentMetricColors", out var amcEl) && amcEl.ValueKind == JsonValueKind.Object)
        {
            _localAgentMetricColors = amcEl.EnumerateObject()
                .Where(p => !string.IsNullOrEmpty(p.Value.GetString()))
                .ToDictionary(p => p.Name, p => p.Value.GetString()!);
            _agentMetrics = _agentMetrics.Select(m =>
                _localAgentMetricColors.TryGetValue(m.MetricId, out var c) ? m with { Color = c } : m).ToList();
        }
    }
    catch (Exception ex)
    {
        Logger.LogDebug(ex, "DayTrendWidget: failed to load user widget settings");
    }
}
```

### 7e — Replace SaveLocalOverridesAsync

Find the entire `private async Task SaveLocalOverridesAsync()` method and replace with:

```csharp
private async Task SaveLocalOverridesAsync()
{
    _localChartType = _viewChartType;
    var obj = new
    {
        buId              = _localBuId,
        metrics           = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
        agentMetrics      = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
        chartType         = _viewChartType,
        intervalMinutes   = _viewIntervalMinutes,
        metricColors      = _metrics.ToDictionary(m => m.MetricId, m => m.Color),
        agentMetricColors = _agentMetrics.ToDictionary(m => m.MetricId, m => m.Color)
    };
    var json = JsonSerializer.Serialize(obj);
    await Mediator.Send(new SaveUserWidgetSettingsCommand(WidgetInstanceId, json), _cts.Token);
}
```

### 7f — Replace ClearLocalOverridesAsync: DB delete

Find `await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);` and replace with:
```csharp
await Mediator.Send(new DeleteUserWidgetSettingsCommand(WidgetInstanceId), _cts.Token);
```

---

## Verification

```bash
# Entity exists
Test-Path "src/CcDashboard.Domain/Domain/UserWidgetSettings.cs"

# Migration created
Get-ChildItem src/CcDashboard.Infrastructure/Migrations/ | Where-Object { $_.Name -like "*UserWidgetSettings*" }

# Handlers exist
Test-Path "src/CcDashboard.Application/Queries/Widgets/GetUserWidgetSettingsQuery.cs"
Test-Path "src/CcDashboard.Application/Commands/Widgets/SaveUserWidgetSettingsCommand.cs"
Test-Path "src/CcDashboard.Application/Commands/Widgets/DeleteUserWidgetSettingsCommand.cs"

# No localStorage references remain in DayTrendWidget
grep -c "localStorage\|LocalStorageKey\|CurrentUser\.UserId" \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
# Must return 0

# Full solution build
dotnet build CcDashboard.sln
# 0 errors
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Domain/Domain/UserWidgetSettings.cs \
  src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Domain/Domain/UserWidgetSettings.cs \
  src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs \
  src/CcDashboard.Infrastructure/Migrations/ \
  src/CcDashboard.Application/Queries/Widgets/GetUserWidgetSettingsQuery.cs \
  src/CcDashboard.Application/Commands/Widgets/SaveUserWidgetSettingsCommand.cs \
  src/CcDashboard.Application/Commands/Widgets/DeleteUserWidgetSettingsCommand.cs \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: UserWidgetSettings DB table — replace localStorage for DayTrend local view config"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Re-sync (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Domain/Domain/UserWidgetSettings.cs" \
  "src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs" \
  "src/CcDashboard.Application/Queries/Widgets/GetUserWidgetSettingsQuery.cs" \
  "src/CcDashboard.Application/Commands/Widgets/SaveUserWidgetSettingsCommand.cs" \
  "src/CcDashboard.Application/Commands/Widgets/DeleteUserWidgetSettingsCommand.cs" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor"; do
  [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
# Also re-sync the migration file
git diff --name-only HEAD | grep "Migrations" | while read f; do
  git show HEAD:"$f" > "$f" && echo "Re-synced migration: $f"
done
sync
```
