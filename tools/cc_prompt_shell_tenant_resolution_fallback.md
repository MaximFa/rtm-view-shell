# CC task — TENANT-RESOLUTION fallback (shell): unresolved subdomain → DefaultTenantSlug (platform) — AWAITING §4-REVIEW (coordinator)
> 140 shakedown: fresh install at a subdomain that doesn't match a seeded tenant slug (e.g. nayax.insightense.com) → login FAILS. ROOT (object-store): `TenantResolutionMiddleware` `ExtractSlug("nayax.insightense.com")` = "nayax" (non-null → the `?? DefaultTenantSlug` never fires); `GetBySlugAsync("nayax")` = null → TenantContext left UNRESOLVED → LoginPage passes Guid.Empty → IdentityAuthService `user.TenantId != tenantId` (superadmin NOT exempt) → TenantMismatch → rejected.
> FIX (Shell-only, general, seed-safe): when the EXTRACTED subdomain slug does not resolve to a tenant, FALL BACK to `config["DefaultTenantSlug"]`; add `DefaultTenantSlug: "platform"` to prod appsettings.
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix(web):`. **NO push** (§37). Territory [web] (Program.cs de-conflict cleared — backend migrate-only 72882f0 landed).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3; verify HEAD == v3 tip
git fetch origin && git rev-parse origin/v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED. Do NOT touch Program.cs.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-13T01:21:06Z | spec: shell | directive: tools/cc_prompt_shell_tenant_resolution_fallback.md | status: open
### DIRECTIVE (spec->CC): TENANT-RESOLUTION fallback — unresolved subdomain falls back to DefaultTenantSlug in TenantResolutionMiddleware + add DefaultTenantSlug:platform to appsettings.json + fallback unit test. v3, fix(web):, NO push, §4-reviewed. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs — MODIFY (fallback)
- src/CcDashboard.Web/appsettings.json — MODIFY (add DefaultTenantSlug)
- tests/CcDashboard.Tests.Security/MultiTenancy/TenantResolutionTests.cs — MODIFY (add 1 fallback [Fact])

## GROUNDING (object-store, current file)
- TenantResolutionMiddleware.InvokeAsync (full):
```csharp
var host = ctx.Request.Host.Host;
var slug = ExtractSlug(host) ?? config["DefaultTenantSlug"];
if (slug == null) { await next(ctx); return; }
var tenant = await tenants.GetBySlugAsync(slug);
if (tenant != null && tenant.Status == Domain.Enums.TenantStatus.Active)
    tenantCtx.Set(tenant.Id, tenant.Slug);
await next(ctx);
```
- `ITenantRepository.GetBySlugAsync(string slug, CancellationToken ct = default)`; `ITenantContext.Set(Guid, string)`; `TenantStatus.{Active,Suspended,Deleted}`.
- appsettings.Development.json already has `"DefaultTenantSlug": "platform"`; base appsettings.json does NOT.
- Existing tests (Tests.Security/MultiTenancy/TenantResolutionTests.cs): KnownActiveSlug→Set; UnknownSlug→DidNotSet (mock IConfiguration returns null for DefaultTenantSlug → still passes with the fix); Suspended/Deleted→DidNotSet (tenant!=null → no fallback → unaffected); NoSubdomain→uses DefaultTenantSlug.

## THE WORK
### A. TenantResolutionMiddleware.cs — fallback on unresolved extracted slug
Replace the resolve block so that when the extracted-subdomain lookup returns null, it retries with DefaultTenantSlug:
```csharp
var slug = ExtractSlug(host) ?? config["DefaultTenantSlug"];
if (slug == null) { await next(ctx); return; }

var tenant = await tenants.GetBySlugAsync(slug);
// Unresolved subdomain → fall back to the platform default tenant (seed-safe; does not re-slug)
if (tenant == null)
{
    var def = config["DefaultTenantSlug"];
    if (!string.IsNullOrEmpty(def) && def != slug)
        tenant = await tenants.GetBySlugAsync(def);
}
if (tenant != null && tenant.Status == Domain.Enums.TenantStatus.Active)
    tenantCtx.Set(tenant.Id, tenant.Slug);

await next(ctx);
```
- INVARIANTS to preserve: a resolvable subdomain resolves to THAT tenant (first lookup wins); a found-but-Suspended/Deleted tenant is NOT overridden by the fallback (fallback only when `tenant == null`) and stays rejected (Status gate); no re-slug of platform.
### B. appsettings.json — add `"DefaultTenantSlug": "platform"` (top-level, alongside existing keys; mirror the Development file). Do NOT touch appsettings.Production.json / Development.json.
### C. TenantResolutionTests.cs — ADD one [Fact] (keep existing 5 unchanged):
```csharp
[Fact]
[Trait("Req", "ARCH-03")]
public async Task InvokeAsync_UnresolvedSubdomain_FallsBackToDefaultTenant()
{
    var platformId = Guid.NewGuid();
    _config["DefaultTenantSlug"].Returns("platform");
    _tenantRepo.GetBySlugAsync("nayax").Returns((Tenant?)null);
    _tenantRepo.GetBySlugAsync("platform").Returns(new Tenant { Id = platformId, Slug = "platform", Status = TenantStatus.Active });

    var httpContext = new DefaultHttpContext();
    httpContext.Request.Host = new HostString("nayax.insightense.com");
    var middleware = new TenantResolutionMiddleware(_next, _config);

    await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

    _tenantContext.Received(1).Set(platformId, "platform");
    await _next.Received(1).Invoke(httpContext);
}
```

## VERIFY / DoD (role-shell §A)
- **Object-store:** middleware falls back to DefaultTenantSlug only when the extracted-subdomain lookup is null; resolvable/suspended/deleted paths unchanged; appsettings.json has DefaultTenantSlug:platform; new fallback [Fact] present.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0** (+passed). The changed test is in Tests.Security (Testcontainers) — run /ops/test?suite=security IF Docker available (report failed/passed); if Docker NOT available, say so + confirm the 5 existing TenantResolution logic-tests are unaffected (mock config null-default) + the new [Fact] compiles.
- **⛔ LIVE (coordinator on 140/234 post-deploy):** superadmin logs in at nayax.insightense.com (unresolved subdomain → platform tenant); a real seeded subdomain still resolves to THAT tenant; suspended/deleted still rejected; platform seed idempotent.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the 3 files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): TENANT-RESOLUTION — unresolved subdomain falls back to DefaultTenantSlug (platform) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "TenantResolutionMiddleware only fell back to DefaultTenantSlug when ExtractSlug returned null (bare host); a NON-matching subdomain (nayax.insightense.com → slug 'nayax') resolved to null tenant → unresolved context → superadmin login TenantMismatch. FIX: fall back to DefaultTenantSlug when the extracted slug does not resolve (tenant==null), NOT only when ExtractSlug is null; keep found-but-suspended/deleted rejected (no fallback when tenant!=null). Rule: a lookup-with-default must default on unresolved RESULT, not only on absent INPUT." SOURCE:TenantResolutionMiddleware.cs + 140 shakedown 2026-07-13. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . security <failed 0/passed n | docker-unavailable> . files TenantResolutionMiddleware.cs + appsettings.json + TenantResolutionTests.cs . status done|failed . blockers . verified: object-store (LIVE nayax login = coordinator gate, pending)
```
