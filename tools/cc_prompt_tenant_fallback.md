# Fix: TenantResolutionMiddleware — DefaultTenantSlug fallback

## Problem

`TenantResolutionMiddleware` reads `config["DefaultTenantSlug"]` but the value
is stored at `ConnectionStrings:DefaultTenantSlug` in `appsettings.json`.
Result: accessing via `http://localhost:5000` returns null slug → tenant not resolved → login fails.
`http://platform.localhost:5000` works correctly (subdomain extracted).

## Fix

File: `src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs`

Change line 12 from:
```
?? config["DefaultTenantSlug"];
```
to:
```
?? config["ConnectionStrings:DefaultTenantSlug"];
```

## Full corrected file content

```csharp
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Web.Middleware;

public class TenantResolutionMiddleware(RequestDelegate next, IConfiguration config)
{
    public async Task InvokeAsync(HttpContext ctx, ITenantContext tenantCtx, ITenantRepository tenants)
    {
        var host = ctx.Request.Host.Host;
        var slug = ExtractSlug(host)
                   ?? config["ConnectionStrings:DefaultTenantSlug"];

        if (slug == null)
        {
            await next(ctx);
            return;
        }

        var tenant = await tenants.GetBySlugAsync(slug);
        if (tenant != null && tenant.Status == Domain.Enums.TenantStatus.Active)
        {
            tenantCtx.Set(tenant.Id, tenant.Slug);
        }

        await next(ctx);
    }

    private static string? ExtractSlug(string host)
    {
        // e.g. acme.cc-dashboard.local -> "acme"
        // e.g. acme.localhost (dev) -> "acme"
        var parts = host.Split('.');
        return parts.Length >= 2 ? parts[0] : null;
    }
}
```

## Steps

1. Write the corrected file using Python (Edit tool is BANNED — §0.3):

```python
import os

path = r"src\CcDashboard.Web\Middleware\TenantResolutionMiddleware.cs"

content = '''using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Web.Middleware;

public class TenantResolutionMiddleware(RequestDelegate next, IConfiguration config)
{
    public async Task InvokeAsync(HttpContext ctx, ITenantContext tenantCtx, ITenantRepository tenants)
    {
        var host = ctx.Request.Host.Host;
        var slug = ExtractSlug(host)
                   ?? config["ConnectionStrings:DefaultTenantSlug"];

        if (slug == null)
        {
            await next(ctx);
            return;
        }

        var tenant = await tenants.GetBySlugAsync(slug);
        if (tenant != null && tenant.Status == Domain.Enums.TenantStatus.Active)
        {
            tenantCtx.Set(tenant.Id, tenant.Slug);
        }

        await next(ctx);
    }

    private static string? ExtractSlug(string host)
    {
        // e.g. acme.cc-dashboard.local -> "acme"
        // e.g. acme.localhost (dev) -> "acme"
        var parts = host.Split(\'.\');
        return parts.Length >= 2 ? parts[0] : null;
    }
}
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print("Written OK")
```

2. Verify (MANDATORY — §0.3):
```bash
sync && tail -3 src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs && wc -l src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs
```
Expected last line: `}`
Expected line count: 36

3. Pre-commit check (MANDATORY — §0.5):
```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs
```

4. Commit:
```bash
cp .git/index /tmp/cc-git-index
GIT_INDEX_FILE=/tmp/cc-git-index git add src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs
GIT_INDEX_FILE=/tmp/cc-git-index git commit -m "fix: TenantResolutionMiddleware reads correct config key for DefaultTenantSlug fallback"
cp /tmp/cc-git-index .git/index
git log --oneline -1
git status --short
```

5. Post-commit re-sync (MANDATORY — §0.6/PD-007):
```bash
git show HEAD:src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs > src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs
sync
echo "Re-synced OK"
```
