# CC task — ARCH-02 Web half (shell): Superadmin tenant-switch — resolution override (C1) + SSR switch endpoint + TopBar switcher — AWAITING §4-BLESS
> Backend server half LANDED (1f4d6dc): `active_tenant_id` claim (default = home tenant_id, added by CustomClaimsPrincipalFactory) + `SwitchTenantCommand(Guid TargetTenantId) → SwitchTenantResult(Guid TenantId, string Slug, string Name)` (Superadmin-only, validates Active, Tenant.Switched audit). Build the Web half to this contract so a Superadmin can switch active tenant and ALL screens (Reports incl.) reflect it — unblocks viewing prod-mirror data under tenant 019e03e9.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37). Lands WITH backend (1f4d6dc).
> **[C1 — SECURITY MAKE-OR-BREAK]** The active_tenant_id override applies **ONLY when Role=="Superadmin"**, with Role read from the TRUSTED `ClaimTypes.Role` — NEVER inferred from the (forgeable) active_tenant_id. A forged active_tenant_id on a non-Superadmin principal MUST be completely ignored (that principal resolves by tenant_id/subdomain exactly as today). Security does a post-commit re-review of C1.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_arch02_tenant_switch_web.md | status: open
### DIRECTIVE (spec->CC): ARCH-02 Web half — C1 Superadmin active_tenant_id override (3 consumers) + SSR /auth/switch-tenant + TopBar switcher. Claims: CurrentUserAccessor.cs, TenantResolutionMiddleware.cs, TenantCircuitHandler.cs, Program.cs, MainLayout.razor, 3 resx. feat:, NO push, §4 + lands-with-backend + security re-review + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Services/CurrentUserAccessor.cs — MODIFY (TenantId Superadmin override)
- src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs — MODIFY (Superadmin override of subdomain)
- src/CcDashboard.Web/Services/TenantCircuitHandler.cs — MODIFY (read active_tenant_id for Superadmin)
- src/CcDashboard.Web/Program.cs — MODIFY (map the SSR switch endpoint)
- src/CcDashboard.Web/Components/Layout/MainLayout.razor — MODIFY (Superadmin-only TopBar switcher)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (switcher labels)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
- Claim factory (CustomClaimsPrincipalFactory): adds `tenant_id`, **`active_tenant_id` (=home by default)**, `locale`, `permission_group_id`. Re-issuing the cookie with a new active_tenant_id is the switch mechanism.
- `CurrentUserAccessor.cs`: `Role => Principal.FindFirstValue(ClaimTypes.Role)`; `TenantId => Guid.TryParse(Principal.FindFirstValue("tenant_id"), …)`. (Add the Superadmin override here.)
- `TenantResolutionMiddleware`: resolves subdomain slug → `tenantCtx.Set(tenant.Id, tenant.Slug)`. (Add Superadmin override AFTER subdomain.)
- `TenantCircuitHandler`: reads `tenant_id` claim → `tenantContext.Set(...)`. (Read active_tenant_id for Superadmin.)
- `SwitchTenantCommand(Guid TargetTenantId) → SwitchTenantResult(Guid TenantId, string Slug, string Name)`; handler Superadmin-only + Active-only + audits.
- SSR auth today = Razor pages (LoginPage.razor/LogoutPage.razor); cookie set via `HttpContext.SignInAsync`. Tenants list = `GetTenantsQuery` (Application). BU/searchable-dropdown pattern reference: ScreenEditorPage:333-362 (`.searchable-select`/`.searchable-dropdown`).

## THE WORK
### A. C1 — resolution override (the security core; identical rule in all 3)
Define the rule once, conceptually: `effectiveTenantId = (Role == "Superadmin" && Guid.TryParse(active_tenant_id)) ? active_tenant_id : <existing tenant_id/subdomain>`. Role MUST come from `ClaimTypes.Role`. Apply in:
1. `CurrentUserAccessor.TenantId`: if `Role == "Superadmin"` and `active_tenant_id` parses → return it; else the existing `tenant_id` logic. (Non-Superadmin NEVER reads active_tenant_id.)
2. `TenantResolutionMiddleware`: after the subdomain `tenantCtx.Set`, if `ctx.User` is authenticated AND `ctx.User.FindFirstValue(ClaimTypes.Role)=="Superadmin"` AND `active_tenant_id` parses to an **Active** tenant → `tenantCtx.Set(thatTenant.Id, slug)` (override subdomain). Non-Superadmin: no change.
3. `TenantCircuitHandler`: choose the claim by role — `var role = httpContext?.User?.FindFirstValue(ClaimTypes.Role); var claim = role=="Superadmin" ? "active_tenant_id" : "tenant_id";` then resolve+Set as today.
- Keep all three consistent; add a brief comment citing ARCH-02 C1. Do NOT weaken any existing GQF.

### B. SSR switch endpoint — `POST /auth/switch-tenant`
- Map in `Program.cs` (minimal API) — mirror the app's SSR auth/cookie approach; `[Authorize]` + Superadmin check (defense-in-depth; the command also enforces). Antiforgery required (validate the token; the form sends it).
- Flow: read `targetTenantId` (form field) → `mediator.Send(new SwitchTenantCommand(targetTenantId))` (validates Active + Superadmin + audits) → on success: load the ApplicationUser, build the principal via `CustomClaimsPrincipalFactory.CreateAsync(user)`, **REMOVE the default `active_tenant_id` claim and ADD `active_tenant_id = targetTenantId`** on the identity → `HttpContext.SignInAsync(IdentityConstants.ApplicationScheme, principal)` → `Results.Redirect("/")` (the switcher triggers a **forceLoad** full navigation so a fresh circuit + middleware read the new active tenant).
- On `ForbiddenException`/`NotFound`/`DomainException` from the command → redirect back with an error (or 403); do NOT change the cookie.
- "Exit impersonation" = POST with `targetTenantId = home tenant_id` (the user's `tenant_id` claim).

### C. TopBar switcher — `MainLayout.razor` (Superadmin-only)
- Inside the existing `<AuthorizeView>` TopBar area, add `<AuthorizeView Roles="Superadmin">` block: a **searchable** tenant dropdown (reuse the dashboard `.searchable-select`/`.searchable-dropdown` pattern) listing `GetTenantsQuery` results, showing the **current active tenant** (resolve via CurrentUserAccessor.TenantId → name). Picking a tenant submits an HTML `<form method="post" action="/auth/switch-tenant">` with hidden `targetTenantId` + `<AntiforgeryToken/>` (a real form POST so the cookie can be set server-side; on submit the browser does a full navigation = forceLoad). Include an "Exit impersonation"/"Back to home" item when active ≠ home.
- Visible ONLY to Superadmin. Do not show for other roles.
### D. resx — switcher labels (en/ru/he, capitalised): e.g. `TenantSwitcher_Label`, `TenantSwitcher_Current`, `TenantSwitcher_Exit`.

## VERIFY / DoD (role-shell §A — ЧП: LIVE gate + security re-review; NOT object-store alone)
- **Object-store / C1:** in all 3 consumers, active_tenant_id is read ONLY under `Role=="Superadmin"` (Role from ClaimTypes.Role); non-Superadmin path unchanged (no active_tenant_id read); endpoint is [Authorize]+Superadmin+antiforgery and calls SwitchTenantCommand; switcher is inside `<AuthorizeView Roles="Superadmin">`; no GQF weakened.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed (incl backend's 5/5 SwitchTenantCommandTests in the joint build) + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE — MANDATORY (operator/coordinator on 234):** as Superadmin, TopBar shows the searchable tenant switcher → switch to **019e03e9** → page force-reloads → Reports list + the BU-picker now show 019e03e9's REAL BUs/data; "Exit" returns to home. As a non-Superadmin (Admin/Editor/Viewer): NO switcher, and a forged active_tenant_id does NOT change their tenant (security re-review). Do NOT report from object-store.
- **Coordinate:** lands WITH backend 1f4d6dc (same bundle/build). After commit → security post-commit re-review of C1 (the make-or-break) + verify admin screens (Users/PG/Tenants) still scope correctly for a switched Superadmin.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `feat(web): ARCH-02 Superadmin tenant-switch Web half — active_tenant_id override (Superadmin-only) + /auth/switch-tenant + TopBar switcher [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY): "ARCH-02 tenant impersonation: the active_tenant_id override is gated on the TRUSTED ClaimTypes.Role==Superadmin in EVERY resolution consumer (CurrentUserAccessor + middleware + circuit handler); never infer privilege from the forgeable active_tenant_id. Cookie re-issue (SignInAsync with replaced claim) + forceLoad is the switch mechanism — circuits can't set cookies." SOURCE:<commit> + backend contract 1f4d6dc + security C1. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0 incl 5/5 SwitchTenant> . files CurrentUserAccessor/TenantResolutionMiddleware/TenantCircuitHandler/Program/MainLayout +3 resx . status done|failed . blockers . verified: object-store (LIVE switch + security C1 re-review = gates, pending)
```
