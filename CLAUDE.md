# RTM View Shell — CLAUDE.md

> **Comprehensive project instructions for Claude Code.** This file is the single source of truth
> for autonomous work on this codebase. All decisions must be consistent with the Technical
> Specification (TZ) v1.2. Keep this file up to date as the project evolves.
>
> **Wireframes** (interactive HTML prototypes) are in `wireframes/en/` — open them in a browser
> to see the intended UI before implementing any screen.

---

## 0. Environment rules — executor must read first

These rules apply to **every executor** (Claude Code, Cowork agent, or any automated
tool) working in this repository. They override any default behaviour or system-prompt
guidance that conflicts with them.

### §0.1 Verification discipline — tool success ≠ delivery

Before writing any status document, sprint report, session summary, or any artefact
that claims something "exists" or is "delivered":

1. Verify via `ls -la <path>`, `git log --oneline -- <path>`, or `Read <path>`.
2. Status tables must be built by **walking the repo**, not from chat history.
3. Labels: *Intended* / *Drafted* / *Delivered (verified)* / *Committed (hash)*.
   Never conflate them. When uncertain, use `⚠ Unverified`.

### §0.2 Session-resume integrity check (PD-005)

After any Cowork session interruption or recovery:

1. Run `git status --short` immediately.
2. For every `M` file: `tail -3 <path>` — check for truncation signature
   (unclosed brace, mid-comment ending, dangling identifier).
3. Truncated files: restore via `git show HEAD:<path> > <path>`.
   **Do NOT use** `git checkout HEAD -- <path>` — fails on this mount
   (`unable to unlink: Operation not permitted`).
4. Only after working tree is verified clean should new work begin.

### §0.3 File writes in this repository — use Python, not Edit tool

The project folder is a **Cowork mount** where the `Edit` tool has a known
partial-write failure mode: the tool returns `success` but the file may be
truncated, with the truncation not reflected in the tool's output. This has
occurred three times in one session (PD-005, 2026-05-25).

**Rule:** for any file that requires ≥2 changes, or any critical file
(production code, security-findings.md, process-deviations.md,
PROJECT_STATUS.md, CLAUDE.md), use an atomic Python script:

```python
with open(path, "r", encoding="utf-8") as f:
    text = f.read()
# ... all str.replace / insertions ...
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
```

**After every Python write — NO EXCEPTIONS — run both checks before doing anything else:**

```bash
tail -3 <path>          # must end with proper closing line (closing brace, sentence, backtick)
wc -l <path>            # compare against expected line count
```

Recommended pattern — combine write + verify in one shell block:

```bash
python3 /tmp/write_x.py && \
tail -3 <path> && wc -l <path>
```

If the file is truncated: restore from HEAD (`git show HEAD:<path> > <path>`)
and retry via Python. Do NOT proceed with git staging or further edits until
`tail -3` shows a proper closing line.

### §0.4 Git `index.lock` workaround

If `git add` / `git commit` fail with
`fatal: Unable to create '.git/index.lock': File exists`,
and `rm .git/index.lock` returns `Operation not permitted`:

```bash
cp .git/index /tmp/cc-git-index
GIT_INDEX_FILE=/tmp/cc-git-index git add <files>
GIT_INDEX_FILE=/tmp/cc-git-index git commit -m "..."
cp /tmp/cc-git-index .git/index
```

Warnings `unable to unlink '.git/objects/XX/tmp_obj_*'` in the output are
**benign** — git cleans up its own temp objects, fails harmlessly on this mount.
Verify success with `git log --oneline -1` and `git status --short`.


### §0.5 Pre-commit file verification — MANDATORY, NO EXCEPTIONS

Before **every** `git add` / `git commit`, verify **every file** being staged:

```bash
# For each file you are about to stage:
tail -3 <path>   # must end with proper closing line (}, sentence, ```)
wc -l <path>     # compare against expected / previous line count
```

If `tail -3` shows a truncated line, mid-comment ending, or dangling identifier —
**stop immediately**. Restore via `git show HEAD:<path> > <path>` and retry the write.
Do NOT stage or commit a file that fails the tail-3 check.

Recommended one-liner before staging a set of files:

```bash
for f in file1.cs file2.cs file3.cs; do
  echo "=== $f ===" && tail -3 "$f" && wc -l "$f"
done
```

### §0.6 Post-commit integrity verification — MANDATORY, NO EXCEPTIONS

After **every** `git commit` (including plumbing-based commits), verify the committed
tree matches the working tree:

```bash
# 1. Working tree must be clean — zero M/A/D lines
git status --short
# Expected output: (empty)

# 2. Spot-check committed files against working tree
git diff HEAD -- <key_file1> <key_file2>
# Expected output: (empty — no diff)

# 3. Confirm line counts in committed tree
git show HEAD:<key_file> | wc -l
wc -l <key_file>
# Both numbers must match
```

If `git status --short` shows **any** M files after a commit — the commit is incomplete.
Do NOT proceed. Either:
- Re-stage missing files and amend/create a follow-up commit, **or**
- Roll back with `git reset --hard HEAD~1` and redo.

**Never leave a commit where working tree ≠ HEAD tree.**

---

## 1. What this project is

**RTM View Shell** (code name: CcDashboard / `CC Dashboard Shell`) is a **Blazor Server** web
shell for a contact-centre real-time monitoring system. It is a *container* — it manages
users, permissions, and dashboards, but does **not** render real-time data widgets itself.

Core responsibilities:
- Multi-tenant user management (create / edit / block / reset password)
- Permission Groups — granular access control: menus, screens, queues, skills, supergroups, BUs
- Dashboard (screen) management — create / rename / delete named screens per group
- Widget catalogue — browse categories and widget types; actual widget rendering is **out of scope**
- Secure authentication: local accounts + e-mail 2FA + SSO stub, JWT for REST API
- Full audit trail for all auth events and permission changes

**Out of scope for this shell (do NOT implement):**
- Widget rendering / real-time data fetching from CC platforms
- Drag-and-drop layout of widgets on a screen
- Widget configuration forms / data binding
- Real-time data feeds

When you encounter tasks related to the above, create a stub interface/component and leave a
`// TODO: widget-library` comment.

---

## 2. Technology stack

| Layer | Technology |
|---|---|
| Runtime | .NET 8 LTS (C# 12) |
| UI framework | Blazor Server (SignalR circuit) — cookie auth |
| REST API (optional) | ASP.NET Core Web API — JWT Bearer |
| Auth | ASP.NET Core Identity + Cookie (Blazor) + JWT Bearer (API) |
| ORM | EF Core 8 + Npgsql.EntityFrameworkCore.PostgreSQL (Code-First) |
| Database | PostgreSQL 15+ (recommended 16+) |
| Cache / state | Redis 7+ (Memurai on Windows or Redis in WSL2) |
| Hosting | Windows Server 2019+/2022+, IIS in-process (ASP.NET Core Module v2) |
| DI / patterns | Clean Architecture (Onion), CQRS via MediatR (single DB, no event sourcing) |
| Validation | FluentValidation (MediatR ValidationBehavior pipeline) |
| Logging | Serilog → file sink (JSON, daily rolling) + Windows Event Log (Warning+) |
| Testing | xUnit + FluentAssertions + Moq/NSubstitute + Testcontainers (Postgres) |
| Localisation | Microsoft.Extensions.Localization (IStringLocalizer<T>) + .resx files |
| Architecture tests | NetArchTest |
| API docs | Swagger / OpenAPI (versioned: /v1/...) |

> **Never suggest Docker, docker-compose, Linux systemd, or peer unix-socket auth.**
> All services run on a single Windows Server (all-in-one topology).

---

## 3. Solution structure and dependency rules

```
CcDashboard.sln
├── src/
│   ├── CcDashboard.Domain/             # Entities, value objects, enums, domain interfaces
│   │   ├── Domain/                     # All domain entities (see §4)
│   │   ├── Interfaces/                 # IRepository<T>, ICurrentUserAccessor, IAuditService,
│   │   │                               # IEmailSender, IBlobStorage, IExternalAuthProvider
│   │   ├── Enums/                      # PermissionFlags, ScreenStatus, TwoFactorStatus,
│   │   │                               # TenantStatus, AuditEventType, AccessLevel
│   │   └── Exceptions/                 # DomainException, NotFoundException, ForbiddenException,
│   │                                   # ConcurrencyException
│   │
│   ├── CcDashboard.Contracts/          # DTOs, ProblemDetails, strongly-typed IDs (TenantId,
│   │                                   # UserId), common enums, ResultMonad
│   │
│   ├── CcDashboard.Application/        # Use-cases, MediatR commands/queries, validators,
│   │   ├── Services/                   # UserService, PermissionService, ScreenService,
│   │   │                               # WidgetCatalogService
│   │   ├── Behaviors/                  # LoggingBehavior, ValidationBehavior,
│   │   │                               # TransactionBehavior, AuthorizationBehavior,
│   │   │                               # AuditBehavior
│   │   ├── DTOs/                       # Request / Response records
│   │   ├── Interfaces/                 # IUserService, IPermissionService, ...
│   │   └── Security/                   # JwtTokenService, TwoFactorService, SsoService
│   │
│   ├── CcDashboard.Infrastructure/     # EF Core, repos, email, Redis, audit writer, SSO adapters
│   │   ├── Persistence/
│   │   │   ├── AppDbContext.cs         # Global Query Filters (TenantId + soft-delete)
│   │   │   ├── Configurations/         # IEntityTypeConfiguration<T> per entity
│   │   │   ├── Repositories/           # Generic + specialised repos
│   │   │   └── Migrations/             # EF migrations (auto-generated only)
│   │   ├── Identity/                   # ASP.NET Core Identity stores + custom user store
│   │   ├── Caching/                    # RedisCacheService (keys prefixed with TenantId)
│   │   ├── Audit/                      # AuditService — writes to audit.audit_logs
│   │   │                               # via separate DbContext (AUD-01)
│   │   └── Email/                      # SmtpEmailSender + IEmailSender abstraction
│   │
│   ├── CcDashboard.Web/                # Blazor Server host
│   │   ├── Components/
│   │   │   ├── Layout/                 # MainLayout, NavMenu, TopBar
│   │   │   ├── Auth/                   # LoginPage, TwoFactorPage, SsoCallback, PasswordChange
│   │   │   ├── Dashboard/              # ScreenList, ScreenCard, ScreenEditor (stub)
│   │   │   ├── Widgets/                # WidgetCategoryBrowser, WidgetPicker (no rendering)
│   │   │   └── Admin/                  # UserAdmin, GroupAdmin, PermissionEditor, AuditLog,
│   │   │                               # TenantSettings, TenantAdmin
│   │   ├── Pages/                      # Routable Razor pages (thin, delegate to Components)
│   │   ├── Models/                     # View-models / form models
│   │   ├── Services/                   # Scoped Blazor services (navigation helpers, state)
│   │   ├── Middleware/                 # ExceptionHandlingMiddleware,
│   │   │                               # SecurityHeadersMiddleware, TenantResolutionMiddleware
│   │   └── wwwroot/                    # Static assets
│   │
│   └── CcDashboard.Api/               # ASP.NET Core Web API (optional, for external integrations)
│       ├── Controllers/                # Thin controllers — delegate to MediatR commands
│       └── Program.cs                  # JWT Bearer composition root
│
└── tests/
    ├── CcDashboard.Tests.Unit/         # Domain + Application (no I/O)
    ├── CcDashboard.Tests.Integration/  # Testcontainers + real Postgres + WebApplicationFactory
    ├── CcDashboard.Tests.Architecture/ # NetArchTest — dependency direction enforcement
    └── CcDashboard.Tests.Security/     # Cross-tenant isolation, JWT, refresh reuse, rate limiting
```

**Dependency rules (enforced by Tests.Architecture):**

```
Domain  <--  Application  <--  Infrastructure  <--  Web / Api (Program.cs only)
               ^
            Contracts
```

- Domain has **zero** NuGet dependencies outside .NET BCL.
- Infrastructure **must not** be referenced directly from Web/Api outside `Program.cs`.
- All cross-layer calls go through interfaces defined in Application or Domain.

**[ARCH-11]** Any violation of the above dependency rules causes Tests.Architecture to fail and
blocks the PR.

---

## 4. Cross-cutting services (register in DI, inject everywhere)

| Interface | Purpose |
|---|---|
| `ITenantContext` | Current `TenantId`; initialised by `TenantResolutionMiddleware` + Blazor `CircuitHandler` |
| `ICurrentUserAccessor` | `UserId`, `UserName`, `Role`, `PermissionGroupId`, `PreferredLocale` from `ClaimsPrincipal` |
| `IDateTimeProvider` | All timestamps from this service; always UTC |
| `IUnitOfWork` | Wraps `SaveChanges` in a PostgreSQL transaction |
| `IAuditService` | Writes to `audit.audit_logs` via a **separate** `DbContext` (never rolls back with business tx) |

**MediatR pipeline order:** `LoggingBehavior` -> `ValidationBehavior` -> `TransactionBehavior`
-> `AuthorizationBehavior` -> `AuditBehavior` -> Handler.

---

## 5. Multi-tenancy model

Strategy: **Shared Database, Shared Schema** with `TenantId` discriminator on every
multi-tenant table.

**[ARCH-01]** Every EF query on multi-tenant tables is automatically filtered by
`ITenantContext.TenantId` via `AppDbContext` Global Query Filters. `IgnoreQueryFilters()` is
allowed **only** in dedicated system repositories; each use must write a
`Tenant.CrossTenantAccess` audit event.

**[ARCH-02]** Superadmin can switch tenants via an admin UI. Switching changes `TenantId`
in the active session (cookie claim / JWT refresh) and writes `Tenant.Switched` to audit.

**[ARCH-03]** Tenant resolution: subdomain -> tenant slug (e.g. `acme.cc-dashboard.local`
-> slug `acme`). Implemented as `TenantResolutionMiddleware` (HTTP) + Blazor `CircuitHandler`.
Unknown domain -> redirect to tenant-selection page.

**[ARCH-04]** On login the system verifies that `User.TenantId` matches the resolved tenant.
Mismatch -> rejected with generic message "Invalid username or password"; logged as
`Login.Failure` with subtype `TenantMismatch`.

**[ARCH-05]** Cross-tenant (platform-wide) entities — **no** Global Query Filter:
`Tenant`, `WidgetCatalogItem`, `ApplicationRole`, `MenuItem`.

**[ARCH-06]** `Tenant.Status` enum: `Active | Suspended | Deleted`.
- `Suspended` -> all logins for that tenant rejected.
- `Deleted` -> invisible to auth; physical data deletion >=30 days after transition (background job).

**[ARCH-07]** Background services (`IHostedService`) must create a DI scope, set `TenantId`
in `ITenantContext` explicitly before any DB operations.

**[ARCH-08]** All Redis keys prefixed: `"{tenantId}:{namespace}:{key}"`.

**[ARCH-09]** SignalR group names prefixed: `"t:{tenantId}:{groupName}"`.
Hub methods must verify `TenantId` from `ClaimsPrincipal` before adding a connection.

**[ARCH-10]** `IBlobStorage` implementations must isolate tenant data by container prefix
`{tenantId}/...` or separate buckets.

---

## 6. Data model — all entities and tables

PK standard: `uuid` generated as **UUIDv7** (RFC 9562) on the application side
(library: `UUIDNext`). All timestamps: `timestamptz` (UTC). PostgreSQL schemas: `public`
(business data), `audit` (audit logs), `identity` (ASP.NET Core Identity tables).

### 6.1 Cross-tenant entities (no Global Query Filter)

#### `tenants`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| Slug | varchar(100) | Unique; used for subdomain resolution |
| Name | varchar(200) | Display name |
| Status | varchar(20) | `Active` / `Suspended` / `Deleted` |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

#### `identity.roles` — `ApplicationRole : IdentityRole<Guid>`
Fixed roles (seeded on first run): `Superadmin`, `Administrator`, `Editor`, `Viewer`.
One user = one role (enforced in Application layer before save).

#### `widget_catalog` — `WidgetCatalogItem`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| Category | varchar(100) | e.g. "Queues", "Agents", "General metrics" |
| Name | varchar(200) | Widget type name |
| Description | text | |
| IconUrl | varchar(500) | |
| IsActive | boolean | Inactive = hidden from non-Superadmin |

### 6.2 Multi-tenant entities

#### `identity.users` — `ApplicationUser : IdentityUser<Guid>`
Extends standard Identity columns with:

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK (inherits from IdentityUser) |
| TenantId | uuid | FK -> tenants |
| FirstName | varchar(100) | |
| LastName | varchar(100) | |
| PermissionGroupId | uuid? | FK -> permission_groups; NULL for Superadmin |
| IsActive | boolean | Soft block; false -> login denied immediately |
| Is2faEnabled | boolean | Email OTP 2FA enabled |
| LastLoginAt | timestamptz? | UTC |
| PreferredLocale | varchar(10) | BCP-47 (e.g. `en-US`, `ru-RU`, `ar-AE`) |
| MustChangePasswordAt | timestamptz? | Set on creation and on 90-day expiry |

Unique index: `(NormalizedEmail, TenantId)` and `(NormalizedUserName, TenantId)`.

#### `identity.user_password_history`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| UserId | uuid | FK -> users |
| TenantId | uuid | For GQF |
| PasswordHash | text | PBKDF2-SHA512 hash |
| CreatedAt | timestamptz | UTC |

Last 10 entries kept per user. New password must not match any of them. **[PWD-04]**

#### `identity.refresh_tokens`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| UserId | uuid | FK -> users |
| TenantId | uuid | For GQF + Redis key prefix |
| Jti | uuid | JWT ID claim |
| TokenHash | varchar(64) | SHA-256 of the raw token |
| ExpiresAt | timestamptz | 8h default, tenant-configurable |
| IssuedAt | timestamptz | UTC |
| RevokedAt | timestamptz? | Set on rotation or explicit revoke |
| ReplacedByTokenId | uuid? | Chain tracking for reuse detection |
| IpAddress | inet | Client IP at issue time |
| UserAgent | text | Client user-agent at issue time |

**[AUTH-API-04]** On reuse of a `Revoked` token: immediately revoke ALL tokens for that user,
log `Token.Revoked` audit event.

#### `identity.two_factor_codes`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| UserId | uuid | FK -> users |
| TenantId | uuid | For GQF |
| CodeHash | varchar(64) | HMAC-SHA256 of the 6-digit code |
| Salt | varchar(32) | Per-code random salt |
| ExpiresAt | timestamptz | +10 minutes from creation |
| AttemptCount | integer | Max 3; on exceed: code invalidated |
| ConsumedAt | timestamptz? | Set on successful verification |

#### `permission_groups`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants |
| Name | varchar(200) | Unique per tenant |
| Description | text? | |
| IsActive | boolean | |
| RowVersion | uint | PostgreSQL `xmin` as concurrency token |
| CreatedAt | timestamptz | UTC |
| CreatedByUserId | uuid | |
| UpdatedAt | timestamptz | UTC |
| UpdatedByUserId | uuid | |

Unique index: `(TenantId, Name)`.

#### `menu_permissions`
PK = `(PermissionGroupId, MenuKey)`.

Menu keys and allowed roles:

| MenuKey | Accessible to roles |
|---|---|
| `menu.dashboards` | All |
| `menu.users` | Superadmin, Administrator |
| `menu.permissionGroups` | Superadmin, Administrator |
| `menu.widgetCatalog` | Superadmin, Administrator, Editor |
| `menu.audit` | Superadmin, Administrator |
| `menu.tenantSettings` | Superadmin, Administrator |
| `menu.tenants` | Superadmin only |

#### `dashboard_permissions`
| Column | Type | Notes |
|---|---|---|
| PermissionGroupId | uuid | FK -> permission_groups |
| DashboardId | uuid | FK -> dashboards |
| AccessLevel | integer | Bitmask: View=1, Edit=2, Delete=4, Full=7 |

**[PG-01]** On dashboard creation, creator's PG gets `AccessLevel = 7` (Full) automatically.

#### `dashboards`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants |
| Name | varchar(200) | |
| Description | varchar(500)? | |
| IsPublic | boolean | Visible to all tenant users regardless of PG |
| CreatedByUserId | uuid | |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |
| UpdatedByUserId | uuid | |
| IsDeleted | boolean | Soft-delete flag (DATA-04) |
| DeletedAt | timestamptz? | UTC |
| DeletedByUserId | uuid? | |
| xmin | system column | PostgreSQL concurrency token (DATA-03) |
| LayoutJson | jsonb | Reserved for widget layout (next version) |

Index: `(TenantId, Name)`. Trigram index via `pg_trgm` on `Name` for search (DASH-04).
Global Query Filters: `TenantId` + `!IsDeleted` (combined).

#### `dashboard_widgets` *(placeholder — next version)*
| Column | Type |
|---|---|
| Id | uuid (UUIDv7) |
| DashboardId | uuid |
| WidgetCatalogItemId | uuid |
| PositionJson | jsonb |
| ConfigJson | jsonb |

#### CC-resource permission tables (identical structure)

`pg_queues`, `pg_skills`, `pg_agent_supergroups`, `pg_business_units`:
PK = `(PermissionGroupId, ObjectId)`. TenantId on each row for GQF.

**[PG-03]** Empty list = access to all objects of that type is **denied**.

#### Reference tables (multi-tenant)
`queues`, `skills`, `agent_supergroups`, `business_units`:
Fields: `Id (uuid)`, `TenantId`, `ExternalId (varchar)`, `Name (varchar)`, `IsActive (boolean)`.

#### `tenant_settings` (one-to-one with `tenants`)
| Column | Type | Notes |
|---|---|---|
| TenantId | uuid | PK + FK -> tenants |
| PasswordMinLength | integer | Default 12 |
| PasswordExpireDays | integer | Default 90 |
| Require2faForAll | boolean | |
| AuditRetentionDays | integer | Default 365 |
| DefaultLocale | varchar(10) | BCP-47 |
| SoftDeleteDashboards | boolean | |
| SoftDeleteRetentionDays | integer | Default 90 |
| EmailProviderConfig | text | Encrypted via ASP.NET Core Data Protection |
| SsoConfigurationId | uuid? | FK -> sso_configurations |

#### `sso_configurations`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants |
| Provider | varchar(20) | `SAML2` / `OIDC` / `AD_LDAP` |
| MetadataUrl | varchar(1000)? | SAML2 / OIDC discovery URL |
| ClientId | varchar(500)? | OIDC client ID |
| ClientSecret | text? | **Encrypted** (Data Protection) |
| ClaimMappings | jsonb | Mapping external claims -> local fields |
| IsActive | boolean | |

#### `tenant_agent_states`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants; GQF |
| AgentStateName | varchar(100) | Raw state name from CC platform (e.g. `AVAILABLE`, `LUNCH`) |
| IsActive | boolean | Soft-delete — no physical deletes |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, AgentStateName)`.

#### `tenant_agent_state_groups`
| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants; GQF |
| GroupName | varchar(100) | Display group name (e.g. `Available`, `Break`) |
| IsActive | boolean | Soft-delete |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, GroupName)`.

#### `tenant_agent_state_definitions`
Junction table: maps one State to exactly one Group per tenant.

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | FK -> tenants; GQF |
| AgentStateId | uuid | FK -> tenant_agent_states CASCADE |
| AgentStateGroupId | uuid | FK -> tenant_agent_state_groups CASCADE |
| IsActive | boolean | Soft-delete |
| CreatedAt | timestamptz | UTC |
| UpdatedAt | timestamptz | UTC |

Unique index: `(TenantId, AgentStateId)` — one State → one Group per tenant.

MetricId is **not stored** — resolved at query time by joining `RTSGrid_Metric` on `MetricParameter = AgentStateName`.

Seed: 5 standard definitions created for every tenant on first run (AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING).

#### `audit.audit_logs`
Partitioned by month (`PARTITION BY RANGE (CreatedAt)`). GIN index on `Details`.

| Column | Type | Notes |
|---|---|---|
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid? | NULL for platform-level events |
| UserId | uuid? | NULL if unauthenticated |
| UserName | varchar(256) | Denormalised at event time |
| EventType | varchar(64) | See §10 |
| EventResult | varchar(16) | `Success` / `Failure` / `Warning` |
| IpAddress | inet | PostgreSQL `inet` type |
| UserAgent | text | |
| Details | jsonb | Additional event data |
| CreatedAt | timestamptz | UTC |

**[AUD-02]** No UPDATE/DELETE on this table via application roles. Only INSERT + SELECT.
Enforce with `REVOKE UPDATE, DELETE ON audit.audit_logs FROM app_role;`.

---

## 7. EF Core conventions and data access rules

- All multi-tenant entities have `TenantId`. GQF: `e => e.TenantId == _tenantContext.TenantId`.
- `Dashboard` has a combined GQF: `e => e.TenantId == ... && !e.IsDeleted`.
- `IgnoreQueryFilters()` -> only in designated system repos -> mandatory audit event.
- **Read-only queries**: always use `AsNoTracking()`.
- **Writes**: wrap in `IUnitOfWork` (TransactionBehavior handles this automatically).
- **Concurrency**: `PermissionGroup` and `Dashboard` use PostgreSQL `xmin` as `[ConcurrencyCheck]`.
  On `DbUpdateConcurrencyException` -> surface "Record modified by another user" to UI.
- **Raw SQL**: only via `FromSqlInterpolated` / `ExecuteSqlInterpolated` (never string concat). **[CODE-01]**
- **UUIDv7**: use `UUIDNext.Uuid.NewSequential()` for all new entity IDs.
- **IAuditableEntity** interceptor (`SaveChangesInterceptor`): auto-fills `CreatedAt`,
  `CreatedByUserId`, `UpdatedAt`, `UpdatedByUserId` on every save.

**[DATA-08] Required indexes:**
- Unique: `tenants(slug)`, `users(NormalizedEmail, TenantId)`, `users(NormalizedUserName, TenantId)`, `permission_groups(TenantId, Name)`
- Regular: all FK columns
- Audit: `(TenantId, CreatedAt DESC)`, `(EventType, CreatedAt DESC)`, GIN on `Details`
- Dashboard search: `pg_trgm` trigram on `dashboards.name`
- Enable extensions: `pgcrypto`, `pg_trgm`, `pg_stat_statements`

---

## 8. Authentication — Blazor Server (cookie)

**[AUTH-WEB-01]** Cookie scheme via `AddIdentity` / `UseAuthentication`:
- Name prefix: `__Host-`
- `HttpOnly=true`, `Secure=true`, `SameSite=Strict`
- Sliding expiration: 30 min (tenant-configurable)
- Absolute expiration: 8 h

**[AUTH-WEB-02]** `TenantId` and `Role` included as claims on login. Any change to
`TenantId` or `Role` in DB requires re-authentication (invalidate via `SecurityStamp`).

**[AUTH-WEB-03]** Logout: delete cookie + invalidate Blazor circuit. Force-logout all
sessions: update `SecurityStamp` in `IdentityUser` (standard Identity mechanism).

---

## 9. Authentication — REST API (JWT)

**[AUTH-API-01]** JWT Bearer authentication via `AddAuthentication().AddJwtBearer(...)`.

**[AUTH-API-02]** Access Token:
- TTL: 15 minutes
- Algorithm: RS256 (RSA-2048 minimum; asymmetric keypair)
- Claims: `sub` (UserId), `tenant_id`, `role`, `permission_group_id`, `jti`, `iat`, `exp`, `iss`, `aud`

**[AUTH-API-03]** Refresh Token:
- TTL: 8 h (tenant-configurable)
- Stored as **SHA-256 hash** in `identity.refresh_tokens`
- Transmitted via `HttpOnly Secure SameSite=Strict` cookie with `__Host-` prefix
- **Never** in `localStorage` or response body

**[AUTH-API-04]** Rotation on every refresh:
1. Old token -> `Revoked = true`, `ReplacedByTokenId = newId`
2. Issue new token
3. Detect reuse of revoked token -> revoke ALL user tokens + `Token.Revoked` audit event

**[AUTH-API-05]** Access Token revocation:
- On logout / deactivation / force-logout: add `jti` to Redis list with TTL = remaining token lifetime
- Key: `"{tenantId}:revoked_jti:{jti}"`
- Middleware checks Redis on every request

**[AUTH-API-06]** RSA private keys:
- Store in Azure Key Vault / HashiCorp Vault / encrypted file (chmod 600 equivalent on Windows)
- Rotate every 12 months; maintain multiple `kid` entries in JWKS for seamless rotation

---

## 10. Password policy

**[PWD-01]** Minimum length: 12 chars (tenant-configurable via `TenantSettings.PasswordMinLength`).

**[PWD-02]** Must contain: >=1 uppercase, >=1 lowercase, >=1 digit, >=1 special character.

**[PWD-03]** Hashing: PBKDF2-HMACSHA512, 100,000 iterations (set via `PasswordHasherOptions`).

**[PWD-04]** History: last 10 hashes in `identity.user_password_history`. Reuse forbidden.

**[PWD-05]** Forced change: on first login and after 90 days (`MustChangePasswordAt` set).
Redirect to Change Password screen before allowing access to any other page.

---

## 11. Brute-force protection

**[BFP-01]** Lockout: 5 failed attempts -> 15-minute lockout (`LockoutOptions` in Identity).

**[BFP-02]** Rate limit on login endpoint: max 10 req/min per IP (ASP.NET Core Rate Limiting
Middleware with Redis backend).

**[BFP-03]** Error message: always "Invalid username or password" — never reveal whether the
user exists, the password is wrong, or the tenant mismatches.

**[BFP-04]** Every failed login attempt -> `AuditLog` with IP, User-Agent, timestamp, and
failure subtype: `UserNotFound | WrongPassword | TenantMismatch | TenantSuspended | AccountLocked`.

---

## 12. Two-Factor Authentication (e-mail OTP)

**[2FA-01]** OTP sent to user's email.

**[2FA-02]** Code: 6-digit, TTL 10 minutes, generated via `RandomNumberGenerator` (CSRNG).

**[2FA-03]** Stored as HMAC-SHA256(code, salt) in `identity.two_factor_codes`.
Marked `ConsumedAt` after use; background service deletes expired codes.

**[2FA-04]** Max 3 attempts. On exceed: code invalidated, user must request resend.
Resend rate limit: 1 per minute per `UserId` (Redis).

**[2FA-05]** Email body contains **only the code** — no links. Subject must **not** include the code.

**[2FA-06]** 2FA can be enabled/disabled by the user (profile settings) or forced by Administrator
(`TenantSettings.Require2faForAll = true`).

**[2FA-07]** `IEmailSender` abstraction. Implementations: SMTP, SendGrid, AWS SES, Mailgun
— switchable via config only, no code change.

---

## 13. Single Sign-On (SSO)

**[SSO-01]** SSO provider configured per tenant in `sso_configurations` table.
Protocol: `SAML2` / `OIDC` / `AD_LDAP` — chosen at deployment time.

**[SSO-02]** Abstraction: `IExternalAuthProvider` with `InitiateLogin()` and `HandleCallback()`.
Recommended libraries:
- OIDC: `Microsoft.AspNetCore.Authentication.OpenIdConnect`
- SAML 2.0: `ITfoxtec.Identity.Saml2`
- LDAP: `Novell.Directory.Ldap.NETStandard`

**v1 implementation:** Stub that returns `NotImplementedException` with a clear log message:
```csharp
// SSO stub — full implementation in next sprint
logger.LogWarning("SSO not configured for tenant {TenantId}. Stub active.", tenantId);
throw new NotImplementedException("SSO provider not yet configured for this tenant.");
```

**[SSO-03]** On SSO login: create local `ApplicationUser` if not exists (JIT provisioning),
or update existing. `TenantId` determined by subdomain (ARCH-03) or SSO claim per
`SsoConfiguration.ClaimMappings`.

**[SSO-04]** If SSO provider confirms MFA (`amr` claim contains `mfa`): skip system-level 2FA.
Otherwise: apply system 2FA normally.

---

## 14. Security headers middleware

`SecurityHeadersMiddleware` must add these headers on every response:

```
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{nonce}'; style-src 'self' 'nonce-{nonce}'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

**[SEC-05]** Anti-forgery: auto-applied by Blazor Server. REST API: validate `SameSite=Strict`
cookie + `Origin` header check.

---

## 15. Permission model

Every user (except Superadmin) belongs to exactly one Permission Group.

**Effective permission = union of all group permissions (most permissive wins).**
Superadmin bypasses all PG checks — full access to all tenants.

### Access Level bitmask (dashboards)
| Value | Meaning |
|---|---|
| 1 | View |
| 2 | Edit (implies View; stored as mask 3) |
| 4 | Delete (implies View; stored as mask 5) |
| 7 | Full = View + Edit + Delete |

**[PG-04]** CC-resource filtering (queues, skills, supergroups, BUs) is enforced in
Application Layer (`AuthorizationBehavior`), **not** only in UI. Hiding a menu item is
cosmetic only — API calls must also be rejected if the user lacks the permission.

**[PG-06]** Cannot delete a PG that has >=1 user assigned. Return error with user count + list.

**[PG-07]** On PG edit: immediately invalidate PG permission cache in Redis
(`"{tenantId}:pg_permissions:{pgId}"`). Active Blazor sessions notified via SignalR to
re-fetch permissions on next interaction.

---

## 16. Audit log

**[AUD-01]** Audit writes use a **separate** `AuditDbContext` and are never rolled back with
the business transaction. Use OutBox pattern or fire-and-forget with retry if needed.

### Full list of audit event types

**Authentication:**
`Login.Success`, `Login.Failure` (subtypes: UserNotFound, WrongPassword, TenantMismatch,
TenantSuspended, AccountLocked), `Login.Lockout`, `Logout`,
`Token.Refresh`, `Token.Revoked`,
`2FA.CodeSent`, `2FA.Success`, `2FA.Failure`,
`SSO.Login`,
`Password.Reset`, `Password.Changed`

**User management:**
`User.Created`, `User.Updated`, `User.Deactivated`, `User.Activated`,
`User.RoleChanged`, `User.PermissionGroupChanged`

**Permission Groups:**
`PermissionGroup.Created`, `PermissionGroup.Updated`, `PermissionGroup.Deleted`,
`PermissionGroup.PermissionChanged`

**Dashboards:**
`Dashboard.Created`, `Dashboard.Updated`, `Dashboard.Deleted`, `Dashboard.Viewed`

**Platform (Superadmin / system):**
`Tenant.Created`, `Tenant.Suspended`, `Tenant.Resumed`, `Tenant.Deleted`,
`Tenant.Switched`, `Tenant.CrossTenantAccess`,
`WidgetCatalog.ItemAdded`, `WidgetCatalog.ItemUpdated`, `WidgetCatalog.ItemDeactivated`,
`System.AuditPurged`

**[AUD-03]** Audit retention: 365 days (tenant-configurable). Background service drops old
monthly partitions of `audit.audit_logs`. Each purge -> `System.AuditPurged` event.

**[AUD-04]** IP extraction: use `X-Forwarded-For` / `X-Real-IP` with trusted proxy config
(`ForwardedHeadersOptions`). Store as PostgreSQL `inet` type.

**[AUD-08]** CSV export: max 50,000 records per request. Larger exports -> async job
-> file via `IBlobStorage` -> email notification with time-limited download link.

---

## 17. Dashboard management

**[DASH-01]** Creator: Editor or Administrator. Fields: `Name` (required), `Description`
(optional), `IsPublic` (boolean — visible to all tenant users).

**[DASH-02]** List shows only dashboards where user's PG has `View` permission,
OR `IsPublic = true` (with no explicit PG deny).

**[DASH-03]** Delete requires confirmation dialog. Soft-delete if `TenantSettings.SoftDeleteDashboards`;
otherwise physical delete.

**[DASH-04]** Search: trigram index (`pg_trgm`) on `name`. Server-side pagination + filter by
author, creation date, `IsPublic`.

**[DASH-05]** Concurrency: optimistic via `xmin`. On conflict -> "Record modified by another user".

---

## 18. Widget catalogue

**[WGT-01]** `WidgetCatalogItem` is a cross-tenant entity (shared platform-wide).

**[WGT-02]** Browse by category and name. Accessible to Editor / Administrator / Superadmin.

**[WGT-03]** Only Superadmin can add / edit / deactivate catalogue items.
Deactivated items hidden from non-Superadmin.

**[WGT-04]** Widget rendering is **out of scope**. On dashboard editor, widget selection
creates a `DashboardWidget` record (stub). Layout/config left as `PositionJson`/`ConfigJson`
jsonb fields for the future widget library.

---

## 19. User management rules

**[USR-01]** Administrator and Superadmin can create users within their tenant.

**[USR-02]** Required on creation: `UserName`, `Email`, `Role`, `PermissionGroupId`
(if role != Superadmin).

**[USR-03]** System generates a temporary password -> emails to user.
Sets `MustChangePasswordAt = NOW()`.

**[USR-04]** Email validated for format and uniqueness within tenant.

**[USR-05]** Administrator cannot create Superadmin users or users in a different tenant.

**[USR-06]** Editable fields: `FirstName`, `LastName`, `Email`, `Role`, `PermissionGroupId`,
`IsActive`, `PreferredLocale`.

**[USR-07]** Role change -> audit event `User.RoleChanged` (old role + new role in `Details`).

**[USR-08]** Administrator cannot change their own role.

**[USR-09]** Deactivation (`IsActive = false`):
- Blazor: circuit terminated via `CircuitHandler` event
- API: all refresh tokens -> Revoked; active JTIs -> Redis revocation list

**[USR-11]** Password reset (admin-initiated): one-time token in `identity.user_tokens`,
TTL 24 h. Link sent to user's email.

**[USR-12]** Self-service reset via "Forgot password?" form. UI response is **uniform**
regardless of whether the email exists (BFP-03).

**[USR-13]** User list: server-side pagination (10/25/50/100), sort on all columns, filter by
`UserName`, `Email`, `Role`, `PermissionGroup`, `IsActive`.

**[USR-14]** Administrator sees own tenant only. Superadmin sees all tenants (with TenantId filter).

---

## 20. Role x feature access matrix

| Feature | Superadmin | Administrator | Editor | Viewer |
|---|---|---|---|---|
| Tenant management | Yes | — | — | — |
| Switch tenants (impersonation) | Yes | — | — | — |
| User management (tenant) | Yes | Yes | — | — |
| Permission Groups management | Yes | Yes | — | — |
| Tenant settings / SSO config | Yes | Yes | — | — |
| Create / edit / delete dashboard | Yes | Yes | Yes (PG) | — |
| View dashboard | Yes | Yes | Yes (PG) | Yes (PG) |
| View widget catalogue | Yes | Yes | Yes | — |
| Manage widget catalogue | Yes | — | — | — |
| View audit log | Yes | Yes | — | — |
| Agent State Definitions (manage) | Yes | — | — | — |

*(PG) = subject to Permission Group restrictions*

---

## 21. UI screens — wireframes reference

> Open `wireframes/en/index.html` in a browser to navigate all interactive prototypes.
> Each wireframe shows the exact intended UI, field labels, modal contents, and functional notes.

### Screen 01 — Login / SSO / 2FA / Change Password / Reset Password
**File:** `wireframes/en/01_login_2fa.html`
**Route:** `/login` (tenant-aware subdomain)

The wireframe has 5 tabs (click to navigate between states):

**Tab 1 — Login:**
- Primary action: "Sign in with SSO / Single Sign-On" button (prominent, at top)
- Divider: "or username and password"
- Fields: Username or email, Password
- Password hint: "Min. 12 chars · A-Z · a-z · 0-9 · special char"
- "Sign in ->" button -> leads to 2FA step
- "Forgot password?" link -> Reset Password tab
- Security footer: `HTTPS · TLS 1.3 · cookie HttpOnly SameSite=Strict · session audit [AUTH-WEB-01]`

**Tab 2 — SSO:**
- Three provider buttons: "Active Directory / LDAP", "OpenID Connect (OIDC)", "SAML 2.0"
- Note: "If provider confirmed MFA (claim amr=mfa), system-level 2FA is not applied [SSO-04]"
- Link: "<- Sign in with username and password"

**Tab 3 — 2FA:**
- Badge: "2FA · step 2 of 2"
- 6-box OTP input (one digit per box)
- "Valid 10 minutes · 3 attempts · HMAC-SHA256 + salt [2FA-02..03]"
- "Confirm ->" button
- "Resend (59s)" link (rate-limited)
- Security footer: "5 failed login attempts -> 15 min lockout [BFP-01] · 3 OTP attempts -> cancellation [2FA-04]"

**Tab 4 — Change Password** (shown when `MustChangePasswordAt` is set):
- Badge: "Password Change Required"
- Subheading: "First login or password expired (90 days) [PWD-05]"
- Fields: Current password, New password, Confirm new password
- Live rule checklist (green tick / red cross):
  - Minimum 12 characters
  - Uppercase letter (A-Z)
  - Lowercase letter (a-z)
  - Digit (0-9)
  - Special character (!@#$...)
  - Must not match last 10 passwords [PWD-04]

**Tab 5 — Reset Password:**
- Field: Email
- "Send link ->" button
- "<- Back to sign in" link
- Security note: "UI response is uniform regardless of address existence [BFP-03]"

**Implementation:**
- After successful login check `MustChangePasswordAt` -> redirect to tab 4 before anything else
- After successful 2FA -> redirect to `/screens` (main dashboard list)
- SSO callback route: `/auth/sso/callback`

---

### Screen 02 — User Management
**File:** `wireframes/en/02_user_management.html`
**Route:** `/admin/users`
**Roles:** Superadmin, Administrator

**Navigation sidebar** (all screens share this structure):
- Content: Screens, Widget Catalogue
- Administration: Users (active), Permission Groups
- Tenant: Tenant Settings, Audit
- Platform: Tenants (Superadmin only)

**List table columns:**
- User: avatar initial + display name + email (two lines)
- Role: coloured badge (Superadmin/Admin/Editor/Viewer)
- Permission Group: name
- Status: `active` (green pill), `inactive` (grey pill), `blocked` (red pill)
- Last login: formatted date/time
- 2FA: checkmark icon if enabled

**Toolbar:**
- Search input (name/email)
- Role dropdown filter
- PG dropdown filter
- Status dropdown filter
- "New user" button (top right)

**Pagination:** page indicator, previous/next, per-page selector (10/25/50/100)

**Create modal — "New User":**
- First Name, Last Name
- Email (validated, unique within tenant)
- Username
- Role dropdown
- Permission Group dropdown (hidden when Role = Superadmin)
- Note: "Temporary password will be sent to the specified email [USR-03]"
- Buttons: Cancel, "Create user ->"

**Edit modal — "Edit User":**
- Same fields as create + editable
- Status toggle (Active / Blocked)
- 2FA toggle
- Read-only info: "Last login: {date} · 2FA: enabled/disabled · created: {date}"
- "Reset password" button (sends link, [USR-11])
- "Force logout" button (revokes all tokens, [USR-09])
- "Delete user" button (danger, confirmation required)
- Buttons: Cancel, "Save ->"

---

### Screen 03 — Permission Groups
**File:** `wireframes/en/03_permission_groups.html`
**Route:** `/admin/permission-groups`
**Roles:** Superadmin, Administrator

**Left panel — group list:**
- PG cards: name, user count badge, active/inactive indicator
- "New group" button at top -> creates a new group card
- Click group -> opens edit panel on right

**Right panel — edit panel (5 tabs):**

Header area:
- Group name (editable inline)
- Description field
- "Group active (IsActive)" toggle
- "Delete group" button (disabled + tooltip if users assigned [PG-06])
- "Save changes ->" / "Cancel" buttons

**Tab: Menu**
- Table: Menu item name | Permission key | Allowed roles
- Rows: Dashboards (menu.dashboards, All roles), User Management (menu.users, Superadmin/Admin), Permission Groups (menu.permissionGroups, Superadmin/Admin), Widget Catalogue (menu.widgetCatalog, Superadmin/Admin/Editor), Audit (menu.audit, Superadmin/Admin), Tenant Settings (menu.tenantSettings, Superadmin/Admin), Tenant Management (menu.tenants, Superadmin)
- Checkboxes for each row; role-restricted rows greyed out for non-applicable roles

**Tab: Screens**
- Table of dashboards: name | View checkbox | Edit checkbox | Delete checkbox
- Note: "Full = View+Edit+Delete = mask 7 [PG-01] · screen creator gets Full automatically"

**Tab: Queues**
- Heading: "Allowed queues · pg_queues"
- Note: "Empty list = access denied [PG-03]"
- List of assigned queues with remove (x) button
- "+ Add queue" button -> search/select dialog

**Tab: Skills**
- Same pattern as Queues ("Allowed skills · pg_skills")
- "+ Add skill" / "+ Add supergroup" buttons

**Tab: BU / SG**
- Business Units section: "Business Units · pg_business_units"
- "Restrict data visibility by business unit"
- List items with remove button
- "+ Add BU" button
- Agent Supergroups section below (same pattern)

---

### Screen 04 — Screen Management (Dashboards)
**File:** `wireframes/en/04_screen_management.html`
**Route:** `/screens`
**Roles:** Editor (own screens per PG), Administrator, Superadmin; Viewers see permitted screens

**Navigation sidebar:**
- Content: Screens (active), Widget Catalogue
- Administration: Users, Permission Groups
- System: Tenant Settings, Audit, Tenants

**Grid view:**
- Dashboard cards (min-width 180px, auto-fill grid)
- Each card: thumbnail preview grid (placeholder layout blocks) + name + PG names + status badge
- Status badges: `published` (green), `draft` (orange)
- Click card -> opens Edit modal

**Toolbar:**
- Search input: "Search by name..."
- Group filter dropdown: "All groups"
- Status filter dropdown: "All statuses"

**"+ New screen" button** -> opens Create modal

**Create modal — "New Screen":**
- Name (required), e.g. "Agent Monitor"
- Description (optional)
- Group access dropdown (note: "Multiple groups can be assigned after creation")
- **IsPublic checkbox**: "Visible to all tenant users (IsPublic)"
  - Help text: "If enabled, the screen is accessible to all authenticated tenant users without explicit group assignment [DASH-01]"
- Widget selection by category (chip multi-select):
  - Queues: Queue Summary, Queue Trend, Abandoned Calls, SLA Bar
  - Agents: Agent Status, Agent List, Occupancy Gauge
  - General metrics: KPI Scorecard, Calls Per Hour, AHT Chart, Real-time Ticker
- Note: "Widget layout is configured separately in the screen editor"
- Buttons: Cancel, "Create screen ->"

**Edit modal — "Screen Settings":**
- Name (editable)
- Status dropdown: Published / Draft
- **IsPublic checkbox** (same as create, pre-checked if currently public)
- Group access: pill tags with "x" to remove + "+ add" button
- Danger zone: "Delete screen" button (requires confirmation [DASH-03])
- Buttons: Cancel, "Save ->"

---

### Screen 05 — Dashboard Viewer
**File:** `wireframes/en/05_dashboard_viewer.html`
**Route:** `/screens/{id}`
**Roles:** All with View permission on the dashboard

> This screen is the **runtime viewer** — layout and widgets are stubs in v1.
> Implement the chrome (topbar, nav, tabs, status bar) fully; leave widget containers as
> `// TODO: widget-library` stubs.

**Top bar:**
- Dashboard name: "Operations Monitor"
- Live indicator: "Live · update 5s" (blinking dot)
- Warning count badge
- "Pause / Resume" toggle for live updates
- User info: "Firstname L. · GroupName"

**Queue filter sub-bar (tabs):**
- "All queues", then individual queue name tabs (from user's PG `pg_queues` list)

**Widget area (stub layout):**
- KPI tiles row: In queue, Avg. wait time, Available agents, Handled (// TODO: widget-library)
- Queue load + SLA gauge widgets (// TODO: widget-library)
- Agent status table (// TODO: widget-library)
- Event ticker sidebar (// TODO: widget-library)
- Charts row: AHT, Abandon Rate, Occupancy (// TODO: widget-library)

**Status bar (bottom):**
- "Blazor Server · SignalR connected"
- Latency: "18ms"
- Session: "Firstname L."

---

### Screen 06 — Tenant Management
**File:** *(no wireframe — implemented; see screenshots in project)*
**Route:** `/platform/tenants`
**Roles:** Superadmin only

**List page:**
- Table: Name | Slug | Status badge | Created | Edit button
- "+ New Tenant" button (top right)

**Edit Tenant modal — 4 tabs:**

**Tab: General**
- Tenant Name (text input)
- Slug (text input, unique)
- Status dropdown: Active / Suspended / Deleted

**Tab: Settings**
- Licensing: Purchased licences, User connections (0 = unlimited)
- Password Policy: Minimum password length, Password expiry (days)
- Security: Require 2FA for all users (checkbox), Default locale (dropdown)
- SignalR Widgets: SignalR Connection URL
- Data Retention: Audit log retention (days), Enable soft-delete for screens (checkbox), Soft-delete retention (days)

**Tab: Appearance**
- Font sizes available in widget editor (comma-separated or tag input)
- Background colour palette
- Font colour palette

**Tab: Agent States** *(Superadmin only — hidden for other roles)*

Two sections:

*Section 1 — State Groups:*
- Table: Group Name | Status | Edit | Deactivate
- Edit: inline rename
- Deactivate (Danger Zone — red, confirmation required):
  - Modal: choose **Reassign states** (dropdown → target active group) OR **Deactivate all states**
  - Cannot save until choice is made
- "+ Add State Group" button → input for GroupName

*Section 2 — Agent States:*
- Table: Agent State | Mapped Group | Status | Edit | Deactivate
- Edit: change mapped group via dropdown of active groups
- Deactivate (Danger Zone — confirmation required): sets State + its Definition to inactive
- "+ Add State" button → AgentState text input + Group dropdown (active groups only)

**Validation:**
- AgentState unique per tenant (case-insensitive)
- GroupName unique per tenant (case-insensitive)
- Cannot create a state without assigning it to a group

**Seed on first run:** 5 standard definitions — AVAILABLE/Available, ONPHONE/On Phone, BREAK/Break, PAPERWORK/Paperwork, TRAINING/Training.

---

## 22. i18n / localisation requirements

**[I18N-01]** Any language via BCP-47 without code changes. New language = new `.resx` file.

**[I18N-02]** RTL support (Arabic, Hebrew, Farsi). `dir` attribute set on `<html>` and
affected Blazor components based on `PreferredLocale`.

**[I18N-03]** All UI strings, error messages, and notification texts in `.resx` files.
Hard-coding strings is forbidden.

**[I18N-04]** Date/time/number formats follow `CultureInfo.CurrentUICulture`. DB stores UTC;
conversion to user's local time happens in the UI layer.

**[I18N-05]** 2FA and password reset emails sent in user's `PreferredLocale`.

**[I18N-06]** Language switch from profile (no page reload). Saved to `PreferredLocale` + cookie.

**CSS:** Use CSS logical properties (`margin-inline-start`, `padding-inline-end`) instead of
`margin-left/right`. Bootstrap 5+ with RTL support.

---

## 23. Non-functional requirements

### Performance
**[PERF-01]** P95 page response <= 2 s under 500 concurrent users.
**[PERF-02]** All list pages use server-side pagination; loading all records is forbidden.
**[PERF-03]** Enable `pg_stat_statements` and `auto_explain` for query monitoring.

### Reliability
**[REL-01]** Auto-reconnect SignalR without losing session.
**[REL-02]** All mutations in PostgreSQL transactions (`TransactionBehavior`).
**[REL-03]** Daily full backup via `pg_basebackup` (Windows Task Scheduler, `backup_user` account).
Continuous WAL archiving to a separate logical disk. 30-day retention. PITR runbook required.

### Scalability (v1: all-in-one; architecture must not prevent future scale-out)
**[SCALE-01]** If multiple Web instances added: Sticky Sessions on load balancer OR Redis SignalR backplane.
`AddSignalR().AddStackExchangeRedis(...)` wired from v1.
**[SCALE-02]** All distributed state (revocation, rate limiting, PG cache) in Redis from day one.
**[SCALE-03]** PostgreSQL: single instance in v1. Architecture allows read-replica without code change.

### Maintainability
**[MAINT-01]** Unit test coverage >= 80% for Application + Domain layers.
**[MAINT-02]** Structured JSON logging via Serilog. No sensitive data in logs.
**[MAINT-03]** OpenAPI docs for all REST endpoints. API versioned at `/v1/...`.
**[MAINT-04]** Only EF Core Migrations for schema changes. No manual schema edits.
**[MAINT-05]** Dependency direction tests in CI on every PR.

### Browser compatibility
**[COMPAT-01]** Chrome, Firefox, Edge (last 2 versions), Safari 16+.
**[COMPAT-02]** Min resolution: 1280x768. Mobile: Viewer read-only (basic support).

---

## 24. Deployment (Windows Server / IIS)

**[DEPLOY-01]** OS: Windows Server 2019 or 2022. Services run as dedicated accounts with
minimum required privileges.

**[DEPLOY-03]** Required software:
- .NET 8 Hosting Bundle (ASP.NET Core Module + .NET Runtime)
- IIS with: Static Content, WebSocket Protocol, Application Initialization, Request Filtering
- PostgreSQL 15+ (EDB installer or official MSI)
- Redis 7+: **Memurai** (recommended for Windows) or Redis in WSL2

**[DEPLOY-04]** Two IIS sites + two Application Pools (No Managed Code, in-process AspNetCoreModuleV2):
- `CcDashboard.Web` (Blazor Server)
- `CcDashboard.Api` (REST API, optional)
- Idle timeout = 0 (never unload — critical for Blazor circuits and background services)

**[DEPLOY-07]** HTTPS only (TLS 1.2+). Wildcard cert `*.cc-dashboard.local` in Windows
Certificate Store (LocalMachine\My). HTTP 80 -> redirect via IIS URL Rewrite. Disable RC4,
3DES, TLS 1.0/1.1 via IISCrypto.

**[DEPLOY-08]** Windows Firewall: only ports 443 (HTTPS) and 80 (redirect) open externally.
PostgreSQL (5432) and Redis (6379) listen on `127.0.0.1` only.

**[DEPLOY-09]** PostgreSQL `pg_hba.conf`:
```
local   all   postgres   peer
host    all   all   127.0.0.1/32   scram-sha-256
hostssl all   all   127.0.0.1/32   scram-sha-256
# reject all external connections
```
Enable extensions: `pgcrypto`, `pg_trgm`, `pg_stat_statements`.

**[DEPLOY-11]** Redis: `127.0.0.1` only, `requirepass` set, RDB snapshot every 5 minutes,
runs as Windows Service.

**[DEPLOY-12]** Serilog: JSON file sink (`RollingInterval.Day`, 30 files retained) +
Windows Event Log sink (Warning+, source: "CC Dashboard Shell").

**[DEPLOY-13]** Health checks: `/health` (liveness) and `/health/ready` (readiness — checks
PostgreSQL + Redis) via ASP.NET Core Health Checks.

**[DEPLOY-14]** Delivery: zip (self-contained `win-x64` publish) + `Install-CcDashboard.ps1`
(idempotent: creates IIS sites, pools, HTTPS bindings, unpacks to
`C:\Program Files\CcDashboard`, sets NTFS ACLs, runs EF migrations via
`CcDashboard.Web.exe migrate`).

**[DEPLOY-15]** Update script `Update-CcDashboard.ps1`: stop pools -> backup app dir ->
copy new files -> `pg_basebackup` before migrations -> apply migrations -> start pools.
Max downtime: 2 minutes.

---

## 25. Code conventions and security checklist

### Conventions
- `async/await` everywhere that touches I/O; never `.Result` or `.Wait()`
- `CancellationToken` passed through from page/service to repository
- No `static` mutable state in services; use scoped/transient DI
- Secrets **never** in source or `appsettings.json`; use User Secrets (dev) or env vars +
  Windows Credential Manager / DPAPI (prod)
- EF: `AsNoTracking()` on all read-only queries
- `[Authorize]` on every Blazor page and API controller that requires auth
- `[Authorize]` on every SignalR Hub method; verify `TenantId` inside the method

### Input handling
**[CODE-02]** Blazor: user-supplied strings passed through `HtmlEncoder.Default.Encode` or
`Ganss.Xss` before rendering as `MarkupString`. Using `@((MarkupString)userInput)` without
sanitisation is forbidden.

**[CODE-03]** Authorisation enforced at two levels:
1. `[Authorize]` attribute on pages/controllers
2. Explicit permission check in Application Layer (`AuthorizationBehavior` or `IAuthorizationService`)

UI-only hiding (no backend check) is never sufficient.

### Secrets and dependencies
**[CODE-05]** Secrets (connection strings, JWT keys, email credentials, SSO ClientSecret):
never in source or plain-text config. Use Azure Key Vault / HashiCorp Vault (prod) or
User Secrets (dev).

**[CODE-06]** PostgreSQL connection: `sslmode=verify-full`. Password stored via
Credential Manager or Key Vault — never in `appsettings.Production.json` in plain text.

**[CODE-07]** Run `dotnet list package --vulnerable` regularly. Critical CVEs fixed in 48 h.

### PR security checklist
- [ ] No secrets / connection strings in source
- [ ] All user inputs validated (FluentValidation + HTML encoding)
- [ ] No raw SQL; parameterised queries via EF only
- [ ] `[Authorize]` on every protected page/endpoint
- [ ] Audit event written for every auth/permission change operation
- [ ] Passwords never logged or serialised
- [ ] Token claims validated on every request (not just at issue time)
- [ ] CORS policy restrictive (whitelist only)
- [ ] Security headers middleware applied globally
- [ ] Multi-tenant GQF active (no unguarded IgnoreQueryFilters)
- [ ] SignalR Hub methods check TenantId from ClaimsPrincipal

---

## 26. Seed data (first-run initialisation)

**[DATA-07]** The following seed data must be applied idempotently on first run (migration or startup check):

1. Identity roles: `Superadmin`, `Administrator`, `Editor`, `Viewer`
2. System tenant: slug = `platform`, Status = `Active`
3. Superadmin user: email = configurable via `appsettings`, role = Superadmin, `MustChangePasswordAt = NOW()`
4. Default TenantSettings for system tenant
5. Widget catalogue seed items (at minimum one item per category: Queues, Agents, General metrics)

---

## 27. Common commands

```bash
# First-time setup
dotnet restore

# Build entire solution
dotnet build CcDashboard.sln

# Run Web app (dev, hot-reload)
dotnet watch run --project src/CcDashboard.Web

# Add EF migration
dotnet ef migrations add <MigrationName> \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# Apply migrations
dotnet ef database update \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# Generate idempotent migration SQL (for DBA review)
dotnet ef migrations script --idempotent \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web \
  --output migrations.sql

# Run all tests
dotnet test CcDashboard.sln

# Unit tests only
dotnet test tests/CcDashboard.Tests.Unit

# Integration tests (Testcontainers spins up real Postgres)
dotnet test tests/CcDashboard.Tests.Integration

# Architecture tests
dotnet test tests/CcDashboard.Tests.Architecture

# Security tests
dotnet test tests/CcDashboard.Tests.Security

# Check for vulnerable packages
dotnet list package --vulnerable

# Publish (self-contained, win-x64, Release)
dotnet publish src/CcDashboard.Web -c Release -r win-x64 --self-contained -o ./publish/web
dotnet publish src/CcDashboard.Api  -c Release -r win-x64 --self-contained -o ./publish/api

# Add NuGet package to a project
dotnet add src/CcDashboard.Infrastructure package Npgsql.EntityFrameworkCore.PostgreSQL
```

---

## 28. Required architecture diagrams

**[ARCH-12]** Maintain in `docs/diagrams/` as PlantUML or Mermaid (export PNG/SVG):
- C4 Context: user <-> shell <-> DB <-> Redis <-> email provider <-> SSO
- C4 Container: Web, Api, PostgreSQL, Redis, background services
- C4 Component: Application and Infrastructure modules
- ER diagram (all entities from §6)
- Sequence: Login + 2FA flow
- Sequence: Refresh Token rotation with reuse detection
- Sequence: Tenant resolution (subdomain -> TenantId)

---

## 29. Implementation insights & lessons learned

> Practical notes from building and testing this solution. These supplement the spec above
> with real-world patterns, gotchas, and tested solutions.

### 29.1 Localization implementation

**Culture cookie at login:**
ASP.NET Core's `RequestLocalizationMiddleware` uses `CookieRequestCultureProvider` by default.
The cookie `.AspNetCore.Culture` must be set **during login** in `IdentityAuthService.CompleteSignInAsync()`:

```csharp
// Determine locale: tenant default, unless user explicitly chose something else
var tenantSettings = await db.TenantSettings.IgnoreQueryFilters()
    .FirstOrDefaultAsync(s => s.TenantId == user.TenantId, ct);
var locale = tenantSettings?.DefaultLocale ?? "en-US";
if (!string.IsNullOrEmpty(user.PreferredLocale) && user.PreferredLocale != "en-US")
    locale = user.PreferredLocale;

httpContext.Response.Cookies.Append(
    CookieRequestCultureProvider.DefaultCookieName,
    CookieRequestCultureProvider.MakeCookieValue(new RequestCulture(locale)),
    new CookieOptions { Expires = expiresAt, IsEssential = true });
```

**Why this logic:** `ApplicationUser.PreferredLocale` defaults to "en-US". We can't distinguish
"user explicitly chose en-US" from "never changed from default". So: use tenant's `DefaultLocale`
unless user explicitly set a non-default locale.

**RTL support:**
Bootstrap 5 ships with separate RTL CSS (`bootstrap.rtl.min.css`). In `App.razor`:

```razor
@{
    var culture = CultureInfo.CurrentUICulture;
    var isRtl = culture.TextInfo.IsRightToLeft;
    var dir = isRtl ? "rtl" : "ltr";
}
<html lang="@culture.Name" dir="@dir">
<head>
    @if (isRtl)
    {
        <link rel="stylesheet" href="bootstrap/bootstrap.rtl.min.css" />
    }
    else
    {
        <link rel="stylesheet" href="bootstrap/bootstrap.min.css" />
    }
</head>
```

**Download RTL CSS:** `https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css`
to `wwwroot/bootstrap/bootstrap.rtl.min.css`.

**Resource file conventions:**
- All UI strings must start with capital letter (English and Russian)
- Use `@L["Key"]` pattern with `IStringLocalizer<SharedResources>` injected as `L`
- File naming: `SharedResources.{locale}.resx` (e.g., `SharedResources.he-IL.resx`)
- Cache busting: update `app.css?v=N` in `App.razor` when changing CSS

### 29.2 Multi-tenancy patterns

**Superadmin cross-tenant queries:**
When Superadmin needs to query another tenant's data, use `IgnoreQueryFilters()` with explicit
`Where(e => e.TenantId == targetTenantId)`:

```csharp
// In repository — for Superadmin cross-tenant access
public async Task<IReadOnlyList<PermissionGroup>> GetAllByTenantAsync(Guid tenantId, CancellationToken ct)
{
    return await _db.PermissionGroups
        .IgnoreQueryFilters()
        .Where(g => g.TenantId == tenantId)
        .Include(g => g.MenuPermissions)
        .AsNoTracking()
        .ToListAsync(ct);
}
```

**Command/Query pattern for optional TenantId:**
```csharp
public record GetPermissionGroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<PermissionGroupDto>>;

// In handler:
var tenantId = query.TenantId ?? currentUser.TenantId!.Value;
var groups = await repo.GetAllByTenantAsync(tenantId, ct);
```

**Seed data for multiple tenants:**
When seeding reference data (NGC tables, queues, agent groups), seed for ALL test tenants:

```csharp
// Seed for platform tenant
var platformTenantId = Guid.Parse("...");
db.NgcQueues.AddRange(new NgcQueue { TenantId = platformTenantId, Name = "Sales" }, ...);

// Also seed for customer1 tenant
var customer1Id = Guid.Parse("...");
db.NgcQueues.AddRange(new NgcQueue { TenantId = customer1Id, Name = "Support" }, ...);
```

Without this, tabs in Permission Groups appear empty when logged into customer1.

### 29.3 EF Core gotchas

**Keyless entities with navigation properties:**
EF Core cannot have navigation properties on keyless entities. If you have a junction table
like `NGC_SupergroupAgentgroup` that needs to reference `NgcSupergroup`, add a surrogate PK:

```csharp
public class NgcSupergroupAgentgroup
{
    public int Id { get; set; } // Surrogate PK (EF requires key for navigation)
    public int? SupergroupId { get; set; }
    public int? AgentgroupId { get; set; }
    public NgcSupergroup? Supergroup { get; set; }
}
```

**Multiple collection Includes warning:**
When including multiple collections, EF warns about query splitting. Add to `AppDbContext`:
```csharp
optionsBuilder.ConfigureWarnings(w => 
    w.Ignore(RelationalEventId.MultipleCollectionIncludeWarning));
```
Or use `.AsSplitQuery()` on specific queries.

**PostgreSQL `xmin` as concurrency token:**
Map using shadow property in `IEntityTypeConfiguration<T>`:
```csharp
builder.Property<uint>("xmin")
    .HasColumnName("xmin")
    .HasColumnType("xid")
    .ValueGeneratedOnAddOrUpdate()
    .IsConcurrencyToken();
```

### 29.4 Blazor component patterns

**DualPaneSelector with proper binding:**
For dual-pane (available/selected) selectors, use a generic component with `@bind-SelectedIds`:

```razor
<DualPaneSelector TKey="int"
    AllItems="AvailableItems.Select(x => (x.Id, x.Name)).ToList()"
    SelectedIds="SelectedIds"
    SelectedIdsChanged="ids => { SelectedIds = ids; StateHasChanged(); }" />
```

The component maintains internal `_selected` HashSet that syncs with the parameter.
**Key insight:** Don't use RenderFragment with closures for clickable items — closures
capture stale state. Use proper `@bind-*` pattern.

**SSR vs InteractiveServer:**
- Auth pages (`/login`, `/login/2fa`, `/forgot-password`): Use SSR (no `@rendermode`)
  for clean form POST without SignalR circuit
- Admin pages: Use `@rendermode InteractiveServer` for reactive UI
- Login page uses `@formname` + `<AntiforgeryToken />` for form binding

**Modal state pattern:**
```csharp
private TenantDto? EditTenant;  // null = modal closed
private string EditTab = "general";
private bool EditSaving;
private string? EditSaveError;

private async Task OpenEdit(TenantDto t)
{
    EditTenant = t;
    EditTab = "general";
    EditSaveError = null;
    await LoadEditSettings(t.Id);
}

private void CloseEdit() => EditTenant = null;
```

### 29.5 CSS and styling

**Dark sidebar category labels:**
Bootstrap's `text-muted` class uses a grey that's invisible on dark backgrounds.
Override in `app.css`:

```css
.sidebar .nav-section-label {
    font-size: 0.88rem;           /* Slightly larger than menu items (0.85rem) */
    color: #a0b0c0 !important;    /* Override Bootstrap text-muted */
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}
```

Remove `text-muted` from NavMenu markup.

**User avatar circles:**
```css
.user-avatar {
    width: 32px; height: 32px;
    border-radius: 50%;
    background-color: #1e3461;
    color: #fff;
    display: flex; align-items: center; justify-content: center;
    font-size: 0.8rem;
}
```

### 29.6 API hooks for external integration

When commands need to notify external systems (CC-platform), use an interface:

```csharp
public interface IConfigurationApiHook
{
    Task NotifyAsync(string eventType, object payload, CancellationToken ct = default);
}

// NoOp implementation for now — logs only
public class NoOpConfigurationApiHook(ILogger<NoOpConfigurationApiHook> logger) : IConfigurationApiHook
{
    public Task NotifyAsync(string eventType, object payload, CancellationToken ct)
    {
        logger.LogInformation("[API Hook] {EventType}: {@Payload}", eventType, payload);
        return Task.CompletedTask;
    }
}
```

Inject into commands:
```csharp
await apiHook.NotifyAsync("PermissionGroup.Created", new { group.Id, group.Name, group.TenantId }, ct);
```

Replace `NoOpConfigurationApiHook` with real HTTP implementation when API is available.

### 29.7 Common debugging tips

**Port already in use:**
```powershell
Get-NetTCPConnection -LocalPort 7196 | Stop-Process -Id { $_.OwningProcess } -Force
```

**Build fails with file lock:**
Stop all dotnet processes before rebuilding:
```powershell
Get-Process -Name dotnet -ErrorAction SilentlyContinue | Stop-Process -Force
```

**EF migration for separate DbContexts:**
For `AppDbContext` (main) vs `AuditDbContext`, specify context explicitly:
```powershell
dotnet ef migrations add <Name> --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web
```

**Locale not applying after login:**
Check that `.AspNetCore.Culture` cookie is being set in `CompleteSignInAsync()`.
Use browser DevTools → Application → Cookies to verify.

---

## 30. Widget Planning — Skills and Methodology

### §30.1 Starting a new widget planning session

**Every new widget planning session (Cowork) must begin by reading:**

```
.claude/skills/widget-planner/widget-planner.md
```

This skill contains the complete end-to-end methodology: from widget idea to ready-to-run
CC implementation task. It covers architecture decision (Grid vs Chart/Analytics), metric
design (narrow format, SUM_OVERLAP_MS, agent pool CTE), spec writing, CC task template,
Phase 5 final checklist, and 10 lessons learned from the DayTrend session.

**Do NOT start writing spec sections or CC tasks without reading this skill first.**

### §30.2 Widget implementation (CC sessions)

**Every CC session implementing a widget must begin by reading:**

```
.claude/skills/widget-creator/widget-creator.md
```

Relevant sections by widget type:
- Grid widgets (AgentGrid, QueueGrid, DataSlot): §1–19
- Chart/Analytics widgets (DayTrend, etc.): **§20** (architecture), **§21** (config modal), **§22** (templates), **§23** (methodology)

### §30.3 Skill locations

| Skill | Path | Purpose |
|---|---|---|
| widget-planner | `.claude/skills/widget-planner/widget-planner.md` | Planning: idea → CC task |
| widget-creator | `.claude/skills/widget-creator/widget-creator.md` | Implementation: patterns, dark mode, RTL, templates |

---

## 31. Session memory — lessons learned

**[MEM-01]** All lessons learned, seed rules, and implementation notes that CC discovers
during a session **must be saved to `.claude/memory/` inside this repository**
(not to `~/.claude/projects/.../memory/`). This ensures:
- Cowork agent can read and cross-check them
- Notes are version-controlled with the project
- Future CC sessions auto-load them

**[MEM-02]** File format — every memory file must have this frontmatter:

```markdown
---
name: <kebab-case-slug>
description: "<one-line summary>"
type: seed | impl | arch | security | process
updated: YYYY-MM-DD
---

<content>
```

**[MEM-03]** After writing a memory file, add one line to `.claude/memory/INDEX.md`:

```
- [slug](filename.md) — one-line description (YYYY-MM-DD)
```

**[MEM-04]** Write memory proactively — do not wait to be asked — for:
- Seed rules with field-level gotchas (wrong types, null markers, join keys)
- Implementation decisions that deviate from spec or CLAUDE.md
- Bugs found and fixed during implementation

---

*TZ version: 1.4 | CLAUDE.md last updated: 2026-05-28*
