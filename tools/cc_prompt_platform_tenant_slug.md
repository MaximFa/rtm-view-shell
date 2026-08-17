# CC task — parametrize platform-tenant SLUG (Seed:PlatformTenantSlug), STABLE idempotency by Name=="Platform" — AMENDED (COND2+COND3 folded), AWAITING RE-§4
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `fix(web):`. **NO push** (§37).
> ⛔ЧП. Operator design (confirmed LIVE on 140: manually set slug=nayax → login works). The DEFAULT tenant stays the STANDARD `platform` system tenant (Name/role/DATA-07 UNCHANGED); ONLY its SLUG is parametrized per server (FQDN subdomain resolves exactly: nayax.insightense.com → slug `nayax`).
> §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for coordinator §4-review BEFORE the operator runs it. No chat run-box until bless.

## STABLE KEY CHOSEN: `Name == "Platform"`
The seed already sets the system tenant `Name = "Platform"` (DatabaseInitializer.cs:127, §26 DATA-07). Since the SLUG is now per-server-variable, keying idempotency on the slug would CREATE A DUPLICATE when the slug differs (the 234/140 bug). So idempotency keys on the STABLE `Name == "Platform"`; the slug is synced FROM config (config = source of truth for the slug).

## ROOT (object-store @ v3 — confirmed)
`src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` `SeedPlatformTenantAsync` (:116):
- :118-119 finds by `t.Slug == "platform"` (idempotency key — WRONG once slug is parametrized).
- :123-131 creates with `Slug = "platform"`, `Name = "Platform"`.
- ctor already injects `IConfiguration config` (:26). TenantSettings block (:137+) + superadmin (separate method) UNCHANGED.

## FIX — `SeedPlatformTenantAsync` ONLY (1 method, minimal-churn)
```csharp
private async Task<Tenant> SeedPlatformTenantAsync(CancellationToken ct)
{
    // Per-server slug (FQDN subdomain resolution); default "platform" (backward-compat: 234/existing unaffected).
    var slug = config["Seed:PlatformTenantSlug"];
    if (string.IsNullOrWhiteSpace(slug)) slug = "platform";

    // STABLE idempotency key = Name=="Platform" (system tenant, §26/DATA-07). NOT the slug — slug is now variable, keying on it would duplicate.
    // [COND2] Name is NOT DB-unique — a spurious dup can exist (e.g. 019f58ea + 019f5978 both "Platform").
    //         FirstOrDefault without OrderBy = non-deterministic; order by OLDEST CreatedAt (the real/original) + fail-fast log if >1.
    var platformTenants = await db.Tenants.IgnoreQueryFilters()
        .Where(t => t.Name == "Platform")
        .OrderBy(t => t.CreatedAt)
        .ToListAsync(ct);
    if (platformTenants.Count > 1)
        logger.LogError(
            "Multiple tenants named 'Platform' found ({Count}): {Ids}. Using the OLDEST (CreatedAt); deployment must remove the duplicate(s).",
            platformTenants.Count, string.Join(", ", platformTenants.Select(t => t.Id)));
    var tenant = platformTenants.FirstOrDefault();

    if (tenant == null)
    {
        tenant = new Tenant
        {
            Id = Uuid.NewSequential(),
            Slug = slug,                 // was "platform"
            Name = "Platform",
            Status = TenantStatus.Active,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.Tenants.Add(tenant);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Created platform tenant: {Id} (slug={Slug})", tenant.Id, slug);
    }
    else if (tenant.Slug != slug)
    {
        // config is the source of truth for the slug — sync on re-run (idempotent, no dup)
        tenant.Slug = slug;
        tenant.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Platform tenant slug synced to {Slug}", slug);
    }

    // ... TenantSettings block (:137+) UNCHANGED — keep byte-identical ...
    // ... return tenant; ...
}
```
⚠ Change ONLY: (1) add the `slug` read; (2) the find predicate `t.Slug == "platform"` → `t.Name == "Platform"`; (3) create `Slug = "platform"` → `Slug = slug` (+ the log line); (4) add the `else if (tenant.Slug != slug)` sync block. Everything else in the method (TenantSettings colour-palette seed, return) stays byte-identical. NO other method touched (superadmin still seeds into this tenant, unchanged).

## WHY correct
- Fresh seed with `Seed:PlatformTenantSlug=nayax` → ONE tenant Name="Platform" slug="nayax" + superadmin.
- Restart → find-by-Name finds it → no dup; slug re-synced to config (idempotent).
- Key absent → slug="platform" (234/existing byte-behaviour).
- 140 (slug already nayax) → find-by-Name matches → keeps/sets slug=config, zero dup.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`; `.claude/skills/role-backend/role-backend.md` §A (⛔ЧП) + §C.
- Object-store grounding: DatabaseInitializer.cs SeedPlatformTenantAsync (**:116-178**, return @:177); ctor IConfiguration (:26).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; hash-verify the claimed file vs HEAD (§0.5); restore any PD-007-truncated/NUL file from HEAD first.
- **Branch v3**: `git checkout v3`; `git rev-parse HEAD` == v3 tip (object-store). STOP+flag if unexpected.
- §0.3 Python+fsync; Edit BANNED. After edit: `sync` + `tail -3` + `wc -l` + NUL-check(0). Preserve LF/no-BOM.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP on OPEN FREEZE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs"]`. NARROW-ADD (L-SC-09): explicit `git add` of ONLY this file; post-commit `git show --stat` = 1 file, zero deletions, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync. **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_platform_tenant_slug.md | status: open
### DIRECTIVE: parametrize platform-tenant Slug via Seed:PlatformTenantSlug (default platform); idempotency keyed on STABLE Name=="Platform"; sync slug from config on re-run. Claim: DatabaseInitializer.cs. gate: build 0 + unit failed 0. fix(web):.
```

## STEP 2 — apply the fix (SeedPlatformTenantAsync only).

## STEP 3 — TESTS
No new unit test required (SeedPlatformTenantAsync is private + DatabaseInitializer's ctor is host-heavy → brittle; behavioural acceptance is the fresh-seed/restart runtime, operator-confirmed live on 140). REQUIRED: existing suite must not regress.

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors (W count).
- `dotnet test tests/CcDashboard.Tests.Unit` → failed=0 (passed/failed counts). (Soma /ops/build + /ops/test?suite=unit OK.)
- Object-store: only DatabaseInitializer.cs; zero deletions.
- Behavioural acceptance (runtime, owned by devops/QA / coordinator design-verify): fresh seed w/ Seed:PlatformTenantSlug=nayax → ONE Name="Platform" slug="nayax" tenant + superadmin; restart idempotent (no dup, slug synced); key absent → slug "platform".

## STEP 5 — commit (fix(web):, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` DatabaseInitializer.cs ONLY → `git status --short` (zero D) → commit `fix(web): parametrize platform-tenant slug (Seed:PlatformTenantSlug), idempotency by stable Name=="Platform" [backend]` → §0.6 post-commit (hash==HEAD; zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> . file DatabaseInitializer.cs (SeedPlatformTenantAsync: config slug + find-by-Name + slug-sync) . build 0 . unit passed/failed <N>/<N> . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store . stable-key=Name=="Platform" . runtime acceptance -> devops/QA/coord seal
<paste build + unit output>
```
Relay a 2-line digest to inbox/coordinator.md (commit + stable key used + confirm default→"platform" backward-compat).

## ACCEPTANCE (GREEN gate)
- `SeedPlatformTenantAsync`: Slug from `config["Seed:PlatformTenantSlug"] ?? "platform"`; idempotency by `Name=="Platform"`; slug synced from config on re-run; superadmin/settings/seed body unchanged.
- build 0 + unit failed 0; 1 file; ZERO deletions; fix(web): on v3; commit.lock; NO push. Binding PRE+POST. Stable key stated (Name=="Platform").
