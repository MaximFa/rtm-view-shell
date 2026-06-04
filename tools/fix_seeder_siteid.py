#!/usr/bin/env python3
"""Fix DatabaseInitializer seed after Restore-All."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\Seeding\DatabaseInitializer.cs"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix 1: Change NGC Sites check from "any site" to "SITE001 specifically"
old_check = 'if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id, ct))'
new_check = 'if (!await beDb.NgcSites.IgnoreQueryFilters().AnyAsync(s => s.TenantId == tenant.Id && s.SiteId == "SITE001", ct))'

if old_check not in text:
    print("ERROR: NGC Sites check not found")
    exit(1)
text = text.replace(old_check, new_check)

# Fix 2: Wrap SeedDevRtsInteractionsAsync in try-catch
old_dev_seed = '''        // Dev-only: seed RTSData test rows for DayTrend widget
        if (env.IsDevelopment())
        {
            await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
            await SeedDevRtsUserStatusLogAsync(platformTenant.Id, ct);
        }'''

new_dev_seed = '''        // Dev-only: seed RTSData test rows for DayTrend widget
        if (env.IsDevelopment())
        {
            try
            {
                await SeedDevRtsInteractionsAsync(platformTenant.Id, ct);
                await SeedDevRtsUserStatusLogAsync(platformTenant.Id, ct);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Dev RTS data seed skipped (non-critical)");
            }
        }'''

if old_dev_seed not in text:
    print("ERROR: Dev seed block not found")
    exit(1)
text = text.replace(old_dev_seed, new_dev_seed)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed DatabaseInitializer.cs ({len(text.splitlines())} lines)")
