# CC Task: Fix concurrent DbContext error in TenantSettingsRepository

## Problem
When 2+ widgets (QueueGrid, DataSlot) initialize simultaneously on page load,
they all call `GetTenantSettingsQuery` concurrently. All handlers share the same
scoped `AppDbContext` → "A second operation was started on this context instance".
Result: one widget fails to subscribe ("Connection failed").

## Root cause
`TenantSettingsRepository(AppDbContext db)` uses a scoped DbContext injected from
the Blazor circuit scope. Concurrent async reads on the same DbContext throw.

## Fix
`GetByTenantAsync` is a read-only query — use `IDbContextFactory<AppDbContext>`
to create a fresh, short-lived DbContext per call. The `UpsertAsync` method
is called from write commands (transactional) so it must keep the scoped DbContext
for proper transaction participation.

## File
`src/CcDashboard.Infrastructure/Persistence/Repositories/TenantSettingsRepository.cs`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change — TenantSettingsRepository.cs

Replace the entire file content with:

```csharp
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class TenantSettingsRepository(
    AppDbContext db,
    IDbContextFactory<AppDbContext> dbFactory) : ITenantSettingsRepository
{
    // Read-only: uses a fresh context per call to avoid concurrent DbContext errors
    // when multiple Blazor widgets call GetTenantSettingsQuery simultaneously.
    public async Task<TenantSettings?> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
    {
        await using var ctx = await dbFactory.CreateDbContextAsync(ct);
        return await ctx.TenantSettings.FirstOrDefaultAsync(s => s.TenantId == tenantId, ct);
    }

    public async Task UpsertAsync(TenantSettings settings, CancellationToken ct = default)
    {
        // Write path: uses the scoped db to participate in the circuit's transaction.
        var entry = db.Entry(settings);
        if (entry.State != EntityState.Detached)
            return; // already tracked — TransactionBehavior's SaveChanges will persist changes

        var exists = await db.TenantSettings.IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == settings.TenantId, ct);
        if (exists)
            db.TenantSettings.Update(settings);
        else
            db.TenantSettings.Add(settings);
    }
}
```

---

## Verification

```bash
grep -n "IDbContextFactory\|CreateDbContextAsync\|fresh context" \
  src/CcDashboard.Infrastructure/Persistence/Repositories/TenantSettingsRepository.cs
# Must return 3+ lines
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Infrastructure/Persistence/Repositories/TenantSettingsRepository.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Infrastructure/Persistence/Repositories/TenantSettingsRepository.cs \
  tools/cc_prompt_fix_tenantsettings_dbfactory.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: TenantSettingsRepository.GetByTenantAsync uses IDbContextFactory to prevent concurrent DbContext error on widget init"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically.

---

## Re-sync from HEAD (§0.6 PD-007)

```bash
for f in src/CcDashboard.Infrastructure/Persistence/Repositories/TenantSettingsRepository.cs \
          tools/cc_prompt_fix_tenantsettings_dbfactory.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
