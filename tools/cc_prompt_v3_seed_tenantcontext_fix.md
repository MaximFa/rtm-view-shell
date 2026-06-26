# CC task — v3 seed fix: resolve ITenantContext before startup superadmin seed (ARCH-07)

> Owner: backend. Branch **v3**. Commit: web:. NO push (§37). Route: coordinator **§4** → EXEC.
> §4-PASS: coordinator-0622 2026-06-22T21:30:20Z — minimal ARCH-07 fix (inject ITenantContext + Set(platformTenant.Id,Slug) before tenant-scoped seeds; DatabaseInitializer.cs ONLY); EXPLICIT §0.6b binding PREAMBLE+RESULT present (prior gap closed); fresh-DB startup PROOF required (superadmin created, no 'Tenant not resolved', idempotent). APPROVED. EXECUTE native CC, v3, commit.lock, NO push.
> Pair: shell (optional reviewer — touches the startup seed path, but NOT Identity/auth logic; infra/seeding only).
> Bug surfaced on the FRESH DB after the EF integrity fix (187e8ca + d648fb0): Shell startup throws in SeedSuperadminAsync.

## ROOT (confirmed, object-store — do NOT re-derive)
- `TenantContext.TenantId` (src/CcDashboard.Infrastructure/Services/TenantContext.cs:10) is `=> IsResolved ? _tenantId : throw new InvalidOperationException("Tenant not resolved.")`. It THROWS until someone calls `Set(tenantId, slug)` (normally `TenantResolutionMiddleware`/Blazor CircuitHandler on an HTTP request).
- `DatabaseInitializer` (src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs) runs at STARTUP with NO HTTP/tenant context. Its primary ctor (lines 18-26) does NOT inject `ITenantContext`, and `InitializeAsync` never calls `Set()`.
- `InitializeAsync` (line 30+): after `var platformTenant = await SeedPlatformTenantAsync(ct);` (line 45) it calls `SeedSuperadminAsync(platformTenant, ct)` (line 46). Inside, `userManager.CreateAsync(user, password)` (line 184) triggers an EF op on `AppDbContext`, whose Global Query Filter reads `ITenantContext.TenantId` (ARCH-01) → IsResolved=false → **throws "Tenant not resolved."** → superadmin never created → Shell startup + login BLOCKED.
- Why masked before: a pre-existing superadmin made `SeedSuperadminAsync` short-circuit at the `existing != null` check (line 159) before reaching CreateAsync. A FRESH DB has no superadmin → CreateAsync runs → throw. (`tenants` + roles seed fine — they are cross-tenant, no GQF, ARCH-05.)
- This is the ARCH-07 rule: "Background/startup paths must create a DI scope and set TenantId in ITenantContext EXPLICITLY before any DB operations."

## FIX (minimal — DatabaseInitializer.cs ONLY)
1. Add `ITenantContext tenantContext` to the `DatabaseInitializer` primary constructor parameter list (lines 18-26). Add `using CcDashboard.Domain.Interfaces;` if not already present.
2. Immediately AFTER `var platformTenant = await SeedPlatformTenantAsync(ct);` (line 45) and BEFORE `await SeedSuperadminAsync(platformTenant, ct);`, insert:
   ```csharp
   // ARCH-07: startup seed has no HTTP/tenant context — resolve the platform tenant
   // explicitly so AppDbContext Global Query Filters (ITenantContext.TenantId) evaluate.
   tenantContext.Set(platformTenant.Id, platformTenant.Slug);
   ```
   (`Tenant` has `.Id` + `.Slug`; `ITenantContext.Set(Guid, string)` exists — TenantContext.cs:14.)
3. Rationale for placement: `tenants` + identity roles are cross-tenant (no GQF) so they seed fine before Set(); ALL tenant-scoped seeds (superadmin, SampleCcEntities, dev RTS, etc.) run AFTER line 45 and need the resolved context — one Set() at line 45 covers them all. The DI scope shares ONE scoped `ITenantContext` instance between `DatabaseInitializer` and `AppDbContext` (both registered Scoped; `ITenantContext` is `AddScoped`), so `Set()` on the injected instance propagates to the GQF. VERIFY this scope-sharing holds in the startup scope (Program.cs `CreateScope()` → `IDatabaseInitializer`); if `AppDbContext` somehow gets a different `ITenantContext`, flag — but the standard scoped registration shares it.
4. Touch ONLY DatabaseInitializer.cs. Do NOT change TenantContext, the middleware, Identity, or AppDbContext.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md ; .claude/skills/role-backend/role-backend.md (§A/§C)
Read: src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs (ctor + InitializeAsync + SeedSuperadminAsync) ; src/CcDashboard.Infrastructure/Services/TenantContext.cs ; confirm AppDbContext GQF reads ITenantContext.TenantId.

## INIT / discipline
- §0.6a integrity FIRST; **branch v3** (`git checkout v3`; verify HEAD via `git rev-parse`+`git hash-object`, §0.5 — NOT mount status; .git/HEAD + source files have shown PD-007 NUL/truncation, restore from HEAD if a working file is short).
- §0.3 Python+fsync for any `.coord/` write; after the source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: slug = your backend slug; **claims** = `["src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs"]` (ONLY this file). commit.lock around commit. pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_v3_seed_tenantcontext_fix.md | status: open
### DIRECTIVE: inject ITenantContext into DatabaseInitializer + Set(platformTenant.Id, Slug) before tenant-scoped seeds (ARCH-07). Claims: DatabaseInitializer.cs. gate: fresh-DB startup creates superadmin, no "Tenant not resolved", login works. commit-prefix web:.
```

## STEP 2 — apply the fix (above) — DatabaseInitializer.cs only.

## STEP 3 — build + fresh-DB startup PROOF (acceptance — PASTE output)
- `dotnet build CcDashboard.sln` → 0 errors.
- FRESH scratch Postgres: run the Shell startup (or `Web.exe` run) so `DatabaseInitializer.InitializeAsync` executes. ASSERT + show:
  - NO `InvalidOperationException: Tenant not resolved.`; superadmin user created (log "Created superadmin user: ...") + assigned Superadmin role;
  - startup completes; (smoke) login page reachable / superadmin present in identity.users.
  - idempotent: 2nd startup = superadmin skip (existing != null), no error.
- PASTE this startup output into the binding RESULT (STEP 5).

## STEP 4 — commit (web: on v3; commit.lock; NO push)
`git add src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` → commit `web: v3 seed fix — resolve platform ITenantContext before startup superadmin seed (ARCH-07, fixes 'Tenant not resolved')`. §0.6 post-commit verify (working tree == HEAD by hash; restore if PD-007-truncated). NO push.

## STEP 5 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commits <hash> . build <0 errors> . files DatabaseInitializer.cs(+ctor param,+1 Set line) . status done|failed . blockers . verified: object-store
<paste the fresh-DB startup output: superadmin created, no "Tenant not resolved", idempotent 2nd run>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md.

## ACCEPTANCE
- DatabaseInitializer ctor injects `ITenantContext`; `tenantContext.Set(platformTenant.Id, platformTenant.Slug)` called right after SeedPlatformTenantAsync, before SeedSuperadminAsync.
- Fresh-DB startup: superadmin CREATED, NO "Tenant not resolved", login reachable; 2nd startup idempotent. Output pasted in RESULT.
- One web: commit on v3, commit.lock, NO push. §0.6b binding PREAMBLE+RESULT written. Only DatabaseInitializer.cs changed.
