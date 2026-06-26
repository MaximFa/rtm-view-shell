# CC task — ARCH-02 Superadmin tenant-switch — SERVER CONTRACT (backend LEADS)
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `feat:`. **NO push** (§37). FREE/MIT.
> ⛔ЧП. Operator chose B = BUILD ARCH-02 (currently UNBUILT — only a Tenants CRUD page). Gates the DATA-PROOF VIEW: 2.4a put prod-mirror data under tenant 019e03e9; a platform-Superadmin can't reach it until it can SWITCH active tenant.
> Coordinator dispatch 2026-06-26T11:00Z: backend = server contract (claim + SwitchTenant command + publish); shell builds Web (resolution-consumers + SSR switch endpoint + TopBar UI) to this contract; security reviews the impersonation/privilege surface. Lands TOGETHER (server + UI).
> §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for coordinator §4 + security review BEFORE the operator runs it. No chat run-box until bless.
> SCOPE OF THIS PROMPT = Application + Infrastructure/Identity ONLY (coordinator-scoped). Web files (CurrentUserAccessor/TenantCircuitHandler/TenantResolutionMiddleware/switch-endpoint/UI) are shell's [web] — DO NOT touch them here; they implement the PUBLISHED CONTRACT below.

## ROOT / GROUNDING (object-store @ v3 — confirmed, do NOT re-derive)
- Claim minting: `src/CcDashboard.Infrastructure/Identity/CustomClaimsPrincipalFactory.cs` `GenerateClaimsAsync` adds `tenant_id = user.TenantId`, `locale`, `permission_group_id` to the Identity COOKIE principal (run on every SignInAsync).
- Claim CONSUMERS (Web, shell's — for the contract, NOT edited here): `CurrentUserAccessor` (Role=ClaimTypes.Role, TenantId="tenant_id"), `TenantCircuitHandler.OnCircuitOpenedAsync` (sets ITenantContext from "tenant_id" claim), `TenantResolutionMiddleware` (sets ITenantContext from SUBDOMAIN slug). `ITenantContext` (Domain) = `{ Guid TenantId; string TenantSlug; bool IsResolved; void Set(...) }`; GQF filters every multi-tenant query by `ITenantContext.TenantId`.
- Auth cookie issued by `SignInManager.SignInAsync` in `IdentityAuthService.CompleteSignInAsync`. ⚠ Cookies can ONLY be written during an HTTP request (SSR), NOT from an interactive Blazor circuit (response already sent) — see §29.4 SSR pattern. So the SWITCH must be an HTTP/SSR endpoint (shell), not an in-circuit call.
- Audit: `IAuditService.LogAsync(eventType, AuditEventResult, tenantId, userId, userName, ip, ua, detailsObj, ct)` (match the real signature). `Tenant.Switched` + `Authorization.Failure`-style are §16 events. `ForbiddenException` in Domain/Exceptions.
- §15 (Superadmin full cross-tenant), ARCH-02 (switch changes active tenant + Tenant.Switched audit), ARCH-05 (Tenant has NO GQF — cross-tenant), AUTH-WEB-02 (re-auth on tenant/role change), §29.2 (Superadmin cross-tenant uses IgnoreQueryFilters + explicit Where).

## DESIGN — what THIS prompt builds (Application + Infrastructure/Identity)
**1. `CustomClaimsPrincipalFactory.cs` — add the `active_tenant_id` claim (default = home tenant):**
```csharp
identity.AddClaim(new Claim("tenant_id", user.TenantId.ToString()));
identity.AddClaim(new Claim("active_tenant_id", user.TenantId.ToString())); // ARCH-02: default = home; shell re-issues with target on switch
identity.AddClaim(new Claim("locale", user.PreferredLocale));
```
(Every principal now carries active_tenant_id. For NON-Superadmin it always equals tenant_id ⇒ zero behaviour change. Only a Superadmin's cookie gets it re-issued to a different value by the switch endpoint.)

**2. New `src/CcDashboard.Application/Commands/Tenants/SwitchTenantCommand.cs` — command + handler + result + validator:**
- `public record SwitchTenantCommand(Guid TargetTenantId) : IRequest<SwitchTenantResult>;`
- `public record SwitchTenantResult(Guid TenantId, string Slug, string Name);`
- Handler (inject `ICurrentUserAccessor`, `ITenantContext`, a Tenant read source — `ITenantRepository` or `AppDbContext.Tenants` (ARCH-05: NO GQF), `IAuditService`, `IDateTimeProvider` as needed):
  1. **Authz — Superadmin ONLY**: if `currentUser.Role != "Superadmin"` → write `Authorization.Failure` audit (subtype `TenantSwitchForbidden`, attempted target) → `throw new ForbiddenException(...)`. (Defense-in-depth with the Web endpoint's `[Authorize]`; §CODE-03 two-level.)
  2. **Validate target**: load tenant by `TargetTenantId` (cross-tenant, ARCH-05). Not found OR `Status != Active` → `throw new NotFoundException`/`DomainException` ("Tenant not available"). (Suspended/Deleted not switchable.)
  3. **Audit** `Tenant.Switched`, result Success, details `{ from = tenantContext.TenantId (current active), to = TargetTenantId }`.
  4. Return `SwitchTenantResult(target.Id, target.Slug, target.Name)`.
- The handler does NOT touch cookies/claims (no HttpContext in Application) — the Web endpoint re-issues the cookie (contract below).
- FluentValidation `SwitchTenantCommandValidator`: `TargetTenantId` not empty.

**3. TESTS — `tests/CcDashboard.Tests.Unit/Commands/Tenants/SwitchTenantCommandTests.cs`** (xUnit + FluentAssertions + mocked ICurrentUserAccessor/ITenantContext/tenant source/IAuditService):
1. Non-Superadmin (Administrator) → throws ForbiddenException + `Authorization.Failure` audit written, NO Tenant.Switched.
2. Superadmin + target not found → throws NotFound/Domain; no Tenant.Switched.
3. Superadmin + target Suspended → throws; no Tenant.Switched.
4. Superadmin + target Active → returns SwitchTenantResult(target) + `Tenant.Switched` audit with from/to.
5. Validator: empty TargetTenantId → invalid.

## ⛔ CONTRACT TO PUBLISH FOR SHELL (write verbatim into the binding RESULT + relay to coordinator; shell builds these in [web]):
- **Claim:** `active_tenant_id` (Guid string) — present on every principal; default = home `tenant_id`.
- **Resolution rule (shell: CurrentUserAccessor + TenantCircuitHandler + TenantResolutionMiddleware):** the effective `ITenantContext.TenantId` / `CurrentUserAccessor.TenantId` for a **Superadmin** = the `active_tenant_id` claim; for ALL other roles = unchanged (`tenant_id` / subdomain). Apply the override ONLY when `Role == "Superadmin"` — a forged `active_tenant_id` on a non-Superadmin principal MUST be ignored (no privilege escalation). For Superadmin, `active_tenant_id` overrides the subdomain too.
- **Switch endpoint (shell, SSR/HTTP — cookies cannot be set from an interactive circuit):** e.g. `POST /auth/switch-tenant { targetTenantId }`, `[Authorize]` + Superadmin. Flow: call `SwitchTenantCommand(targetTenantId)` (this backend command — validates+audits) → on success re-issue the Identity cookie: build the principal via the factory then REPLACE the `active_tenant_id` claim with `targetTenantId`, `await HttpContext.SignInAsync(IdentityConstants.ApplicationScheme, principal, props)` → redirect with **forceLoad** so a fresh circuit reads the new active tenant. "Exit impersonation" = switch back to the user's home `tenant_id`.
- **Audit:** backend writes `Tenant.Switched` (from/to) inside the command; the endpoint need not duplicate it.
- **UI:** Superadmin-only tenant switcher in TopBar (searchable tenant list via the existing Tenants query), invokes the endpoint.

## ⚠ KEY RISKS — flag to coordinator + SECURITY (do NOT silently decide):
1. **GQF behaviour change:** once a Superadmin's active tenant = X, default GQF filters Superadmin queries to X. Admin screens that assume Superadmin sees platform/all-tenants use `IgnoreQueryFilters` + explicit Where (§29.2) ⇒ SHOULD be unaffected, but VERIFY (Users §USR-14, Permission Groups, Tenants list §ARCH-05). Security assesses mutation surface while impersonating X.
2. **Re-auth semantics (AUTH-WEB-02):** the cookie re-issue must keep SecurityStamp validation intact (shell endpoint concern; note for security).
3. **No escalation:** the resolution override is Superadmin-gated; confirm a non-Superadmin cannot set/abuse active_tenant_id.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-backend/role-backend.md` §A core (⛔ЧП block) + §C verify
- Object-store grounding: `CustomClaimsPrincipalFactory.cs`; `ICurrentUserAccessor` + `CurrentUserAccessor.cs`; `ITenantContext.cs`; `IAuditService` signature (e.g. as used in `IdentityAuthService.cs`); an existing Application command+handler+validator+test (e.g. `src/CcDashboard.Application/Commands/Dashboards/PurgeDashboardCommand.cs` + its test) for house structure (MediatR, ForbiddenException, audit usage).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`; for every M file in your claim hash-verify vs HEAD (`git hash-object` vs `git rev-parse HEAD:<f>`, §0.5 — mount false-M); restore any PD-007-truncated/NUL file from HEAD before work.
- **Branch v3**: `git checkout v3`; verify `git rev-parse HEAD` == current v3 tip by FULL SHA (object-store). If WT disagrees restore from HEAD; if HEAD unexpected STOP + flag.
- §0.3 Python+fsync for any `.coord/` write; after each source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0). Edit tool BANNED — Python read→modify→write only.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP only on an OPEN FREEZE ACTIVE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Infrastructure/Identity/CustomClaimsPrincipalFactory.cs", "src/CcDashboard.Application/Commands/Tenants/SwitchTenantCommand.cs", "tests/CcDashboard.Tests.Unit/Commands/Tenants/SwitchTenantCommandTests.cs"]`. ⚠ DO NOT touch any `src/CcDashboard.Web/**` file (shell's [web]). ⚠ NARROW-ADD (L-SC-09): explicit `git add` of ONLY these 3; `git status --short` pre-commit; post-commit `git show --stat` = ZERO deletions + only your files, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_backend_arch02_tenant_switch.md | status: open
### DIRECTIVE: ARCH-02 server contract — active_tenant_id claim (default home) + SwitchTenantCommand (Superadmin-only authz, validate target Active, Tenant.Switched audit) + publish resolution/endpoint contract for shell. Claim: CustomClaimsPrincipalFactory.cs + SwitchTenantCommand.cs + SwitchTenantCommandTests.cs. gate: build 0 + unit GREEN. commit-prefix feat:.
```

## STEP 2 — implement (1) active_tenant_id claim, (2) SwitchTenantCommand + handler + validator. Match real interfaces/signatures from the object store. NO Web files.

## STEP 3 — TESTS (5 cases above). Model context/mocks on an existing Application command test.

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → all GREEN incl. new SwitchTenantCommandTests (5/5). (Soma `/ops/build` + `/ops/test?suite=unit` OK.)
- Object-store: only the 3 claimed files; zero deletions; NO Web files touched.
- NOTE: end-to-end (UI switch → cookie reissue → circuit sees new tenant → Reports show 019e03e9 data) is the JOINT landing with shell + a coordinator visual-verify on 234 prod-mirror — state it for the joint seal.

## STEP 5 — commit (feat:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the 3 files ONLY → `git status --short` (zero D, no Web) → commit `feat(auth): ARCH-02 server contract — active_tenant_id claim + SwitchTenantCommand (Superadmin-only, Tenant.Switched audit) [backend]` → §0.6 post-commit (`git show v3:<file>` == WT by hash; `git show --stat` zero-deletion; restore if PD-007) → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync) — INCLUDE THE PUBLISHED CONTRACT VERBATIM
```
### RESULT: commit <hash> . files CustomClaimsPrincipalFactory.cs(+active_tenant_id) + SwitchTenantCommand.cs(new) + SwitchTenantCommandTests.cs(5) . build 0 . unit <N>/<N> GREEN . only-claimed/zero-deletion/no-Web . status done|failed . blockers . verified: object-store
PUBLISHED CONTRACT FOR SHELL: <paste the CONTRACT TO PUBLISH section: claim name + resolution rule (Superadmin-gated) + SSR endpoint flow + forceLoad reload + audit owner>
KEY RISKS for security/§4: GQF-for-Superadmin, AUTH-WEB-02 re-auth, no-escalation.
<paste build + unit output>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 3-line digest to inbox/coordinator.md (commit hash + the published contract one-liner + "shell can start Web to contract; security review requested").

## ACCEPTANCE (GREEN gate)
- `active_tenant_id` claim added (default home); non-Superadmin behaviour byte-identical.
- `SwitchTenantCommand`: Superadmin-only (ForbiddenException + Authorization.Failure for others); target validated Active; `Tenant.Switched` audit from/to; returns target id/slug/name. No cookie/Web code in this commit.
- 5 unit cases GREEN; build 0. 2 source + 1 test file; ZERO deletions; NO `src/CcDashboard.Web/**` touched. feat: on v3, commit.lock, NO push. Binding PRE+POST written WITH the published contract. Risks flagged for security/§4.
