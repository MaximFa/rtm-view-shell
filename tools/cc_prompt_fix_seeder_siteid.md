# Task: Fix DatabaseInitializer seed after Restore-All

## Problem

After `Restore-All.ps1`, `NGC_Site` contains `SiteId='IL'` (the real RTM default).
The seeder checks `AnyAsync(s => s.TenantId == tenant.Id)` — finds 'IL' — skips
creating SITE001/SITE002 — then tries to create NGC_BusinessUnit with SiteId='SITE001'
which doesn't exist → FK violation → app crash.

## Fix 1 — DatabaseInitializer.cs line 304

Change the NGC Sites check from "any site exists" to "SITE001 specifically exists":

```csharp
// BEFORE:
if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))

// AFTER:
if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id && s.SiteId == "SITE001", ct))
```

This way: if only 'IL' exists (from baseline), seeder still adds SITE001/SITE002.
If SITE001 already exists (fresh dev install), seeder skips. Correct in both cases.

## Fix 2 — SeedDevRtsInteractionsAsync: wrap in try-catch

In `InitializeAsync`, find the dev interactions seed call and wrap in try-catch:

```csharp
if (env.IsDevelopment())
{
    try
    {
        await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "Dev RTS interactions seed skipped (non-critical)");
    }
}
```

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After Restore-All + dotnet run:
- NGC_Site has 'IL' (from baseline) + SITE001/SITE002 (from seeder)
- NGC_BusinessUnit seeds successfully
- No FTL crash

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check
```bash
bash tools/pre-commit-check.sh
```

## Commit message
```
fix: check SITE001 specifically in NGC Sites seed, not just any site

Baseline restore adds IL site. Seeder saw it and skipped SITE001/SITE002
then failed creating BusinessUnits with SiteId=SITE001. Fix: check
SITE001 specifically. Also wrap SeedDevRtsInteractionsAsync in try-catch.
```
