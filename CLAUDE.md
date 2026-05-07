# RTM View Shell — CLAUDE.md

> **Project context for Claude Code.** This file tells Claude Code everything it needs to work
> autonomously on this codebase. Keep it up-to-date as the project evolves.

---

## 1. What this project is

**RTM View Shell** (CcDashboard) is a Blazor Server web shell for a contact-centre real-time
monitoring system. It provides:

- User management and authentication (local accounts + optional SSO, 2FA via e-mail, JWT, audit log)
- Permission Groups — granular access control over menus, screens, queues, skills, agent
  supergroups, and business units
- Dashboard management — create/rename/delete named screens (dashboards) per user or group
- Widget catalogue — browse categories and widget types; actual widget rendering is **out of scope**
  for this shell (a separate widget library plugs in later)
- Audit trail for all authentication events and permission changes

---

## 2. Technology stack

| Layer | Technology |
|---|---|
| Runtime | .NET 8 LTS (C# 12) |
| UI framework | Blazor Server (SignalR) |
| Auth middleware | ASP.NET Core Identity + custom JWT + SSO stub |
| Database | PostgreSQL 16 via **Npgsql** + **EF Core 8** |
| Cache / state | Redis 7 (Memurai on Windows or Redis in WSL2) |
| Hosting | IIS (in-process, ASP.NET Core Module v2) |
| OS | Windows Server 2019+ / 2022+ — **no Docker, no Linux** |
| Testing | xUnit + FluentAssertions + Testcontainers (Postgres) |
| Logging | Serilog → file sink + optional Seq |
| DI / patterns | Clean Architecture (Core → Application → Infrastructure → Web) |

> **Never suggest Docker, docker-compose, Linux systemd, or peer unix-socket auth.**
> All services run on a single Windows Server machine (all-in-one topology).

---

## 3. Solution layout

```
CcDashboard.sln
├── src/
│   ├── CcDashboard.Core/           # Domain entities, interfaces, enums, exceptions
│   │   ├── Domain/                 # Entities: User, PermissionGroup, Screen, WidgetSlot, AuditEvent
│   │   ├── Interfaces/             # IRepository<T>, ICurrentUser, IAuditService, IEmailSender
│   │   ├── Enums/                  # Permission flags, ScreenStatus, TwoFactorStatus
│   │   └── Exceptions/             # DomainException, NotFoundException, ForbiddenException
│   │
│   ├── CcDashboard.Application/    # Use-cases, CQRS-style services, DTOs, validators
│   │   ├── Services/               # UserService, PermissionService, ScreenService, WidgetCatalogService
│   │   ├── DTOs/                   # Request/Response records
│   │   ├── Interfaces/             # IUserService, IPermissionService, ...
│   │   ├── Security/               # JwtTokenService, TwoFactorService, SsoService
│   │   └── Validators/             # FluentValidation validators
│   │
│   ├── CcDashboard.Infrastructure/ # EF Core, repos, email, redis, audit writer
│   │   ├── Persistence/
│   │   │   ├── AppDbContext.cs
│   │   │   ├── Configurations/     # IEntityTypeConfiguration<T> per entity
│   │   │   ├── Repositories/       # Generic + specialised repos
│   │   │   └── Migrations/         # EF migrations (auto-generated)
│   │   ├── Identity/               # ASP.NET Core Identity stores + custom user store
│   │   ├── Caching/                # RedisCacheService
│   │   ├── Audit/                  # AuditService writes to AuditEvents table
│   │   └── Email/                  # SmtpEmailSender (2FA OTP delivery)
│   │
│   └── CcDashboard.Web/            # Blazor Server host
│       ├── Components/
│       │   ├── Layout/             # MainLayout, NavMenu, TopBar
│       │   ├── Auth/               # LoginPage, TwoFactorPage, SsoCallback
│       │   ├── Dashboard/          # ScreenList, ScreenEditor, ScreenCard
│       │   ├── Widgets/            # WidgetCategoryBrowser, WidgetPicker (no rendering)
│       │   └── Admin/              # UserAdmin, GroupAdmin, PermissionEditor, AuditLog
│       ├── Pages/                  # Routable Razor pages (thin, delegate to Components)
│       ├── Models/                 # View-models / form models
│       ├── Services/               # Scoped Blazor services (state, navigation helpers)
│       ├── Middleware/             # ExceptionHandlingMiddleware, SecurityHeadersMiddleware
│       └── wwwroot/                # Static assets
│
└── tests/
    ├── CcDashboard.Tests.Unit/         # Pure unit tests (no I/O)
    └── CcDashboard.Tests.Integration/  # Testcontainers + real Postgres
```

---

## 4. Key domain entities

```csharp
// Core/Domain/User.cs
User            { Id, Email, DisplayName, PasswordHash, IsSsoUser, TwoFactorEnabled,
                  TwoFactorSecret, IsActive, LastLoginAt, CreatedAt }

// Core/Domain/PermissionGroup.cs
PermissionGroup { Id, Name, Description, MenuPermissions, CreatedAt }
UserGroup       { UserId, GroupId }   // many-to-many

// Core/Domain/Screen.cs
Screen          { Id, Name, OwnerId, OwnerGroupId, Status, CreatedAt, UpdatedAt }
ScreenPermission{ ScreenId, GroupId, CanView, CanEdit, CanDelete }

// Core/Domain/WidgetSlot.cs — placeholder only, no layout/config data
WidgetSlot      { Id, ScreenId, CategoryId, WidgetTypeId }

// Core/Domain/ResourcePermission.cs
ResourcePermission { GroupId, ResourceType (Queue|Skill|AgentSupergroup|BusinessUnit),
                     ResourceId, CanView }

// Core/Domain/AuditEvent.cs
AuditEvent      { Id, UserId, EventType, IpAddress, UserAgent, Detail, OccurredAt }
```

---

## 5. Authentication & security requirements

### 5.1 Local accounts
- Password: PBKDF2-SHA512, ≥12 chars, uppercase + lowercase + digit + special
- Account lockout: 5 failed attempts → 15-minute lockout (ASP.NET Core Identity default)
- Session: HttpOnly + Secure + SameSite=Strict cookie; session timeout configurable

### 5.2 JWT (for REST API endpoints)
- HS256 or RS256 (configurable); access token 15 min; refresh token 7 days (stored in DB)
- Refresh token rotation on every use; old token invalidated immediately
- Token claims: `sub`, `email`, `roles`, `jti`, `iat`, `exp`

### 5.3 SSO (SAML 2.0 / OIDC stub)
- Interface `ISsoProvider` with `InitiateLogin()` and `HandleCallback()` methods
- In v1: stub implementation returns `NotImplementedException` with clear log message
- Full implementation in later sprint

### 5.4 Two-Factor Authentication (e-mail OTP)
- 6-digit TOTP-like code, valid 10 minutes, single-use
- Sent via SMTP; code stored hashed in `User.TwoFactorSecret` + expiry column
- 2FA required for all admin-role users; optional for others (configurable per group)

### 5.5 Security headers (Middleware/SecurityHeadersMiddleware.cs)
```
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{nonce}'; ...
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### 5.6 Audit log
Every auth event must be written to `AuditEvents` table:
`Login`, `LoginFailed`, `Logout`, `TwoFactorSent`, `TwoFactorVerified`, `TwoFactorFailed`,
`PasswordChanged`, `AccountLocked`, `SsoLogin`, `TokenRefreshed`, `TokenRevoked`

---

## 6. Permission model

```
PermissionGroup
  ├── MenuItems[]          string keys (e.g. "admin.users", "dashboard.create")
  ├── ScreenPermissions[]  { ScreenId, CanView, CanEdit, CanDelete }
  └── ResourcePermissions[]
        ├── Queues[]           { QueueId, CanView }
        ├── Skills[]           { SkillId, CanView }
        ├── AgentSupergroups[] { SupergroupId, CanView }
        └── BusinessUnits[]    { BuId, CanView }

User → UserGroup[] → PermissionGroup[]   (user may belong to multiple groups)
Effective permission = union of all group permissions (most permissive wins)
```

---

## 7. Common commands

```bash
# First-time setup (run once)
dotnet restore

# Build entire solution
dotnet build CcDashboard.sln

# Run Web app (dev, watches for changes)
dotnet watch run --project src/CcDashboard.Web

# Add EF migration
dotnet ef migrations add <MigrationName> \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# Apply migrations
dotnet ef database update \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web

# Run all tests
dotnet test CcDashboard.sln

# Run only unit tests
dotnet test tests/CcDashboard.Tests.Unit

# Run only integration tests (requires running Postgres via Testcontainers)
dotnet test tests/CcDashboard.Tests.Integration

# Add NuGet package to a project
dotnet add src/CcDashboard.Infrastructure package Npgsql.EntityFrameworkCore.PostgreSQL

# Publish for IIS (Release)
dotnet publish src/CcDashboard.Web -c Release -o ./publish --self-contained false
```

---

## 8. Code conventions

- **Clean Architecture**: dependencies only flow inward (Web → Application → Core; Infrastructure → Core)
- Core project has **zero** NuGet dependencies outside of .NET BCL
- `async/await` everywhere that touches I/O; no `.Result` or `.Wait()`
- All `CancellationToken` parameters passed through from controller/service to repo
- Repository pattern: `IRepository<T>` in Core, EF implementation in Infrastructure
- Validators: FluentValidation, registered with DI, called from Application services
- Exceptions: throw domain exceptions (`NotFoundException`, `ForbiddenException`); catch in middleware and map to HTTP status codes
- No `static` state in services; use scoped/transient DI registration
- Secrets: **never** in `appsettings.json`; use `appsettings.Production.json` (git-ignored) or Windows DPAPI / environment variables on the server
- EF: use `AsNoTracking()` for all read-only queries; explicit transactions for multi-step writes
- Logging: `ILogger<T>` injected; structured logging with Serilog; log at `Information` for auth events, `Warning` for failed auth, `Error` for exceptions

---

## 9. Security checklist (apply to every PR)

- [ ] No secrets / connection strings in source files
- [ ] All user inputs validated (FluentValidation + HTML encoding)
- [ ] No raw SQL; parameterised queries via EF only
- [ ] `[Authorize]` attribute on every page/endpoint that requires auth
- [ ] Audit event written for every auth/permission change operation
- [ ] Passwords never logged or serialised
- [ ] Token claims validated on every request (not just on issue)
- [ ] CORS policy restrictive (whitelist only)
- [ ] Security headers middleware applied globally

---

## 10. Infrastructure notes (Windows Server / IIS)

- IIS Application Pool: No Managed Code (CLR managed by Kestrel inside the process)
- HTTPS: TLS 1.2+, certificate via IIS Bindings or Windows Certificate Store
- PostgreSQL connection: SCRAM-SHA-256 auth, `sslmode=verify-full` in connection string
- Redis: Memurai for Windows recommended; or Redis 7 inside WSL2 (check with ops team)
- Log path: `C:\inetpub\CcDashboard\logs\` — configurable in `appsettings.json`
- Health-check endpoint: `/health` (maps to ASP.NET Core HealthChecks for Postgres + Redis)

---

## 11. Out of scope for this shell (do NOT implement)

- Actual widget rendering / data fetching from contact-centre platform
- Drag-and-drop layout configuration of widgets on a screen
- Widget configuration forms / data binding
- Real-time data feeds (those belong to the widget library, not this shell)

When Claude Code encounters tasks related to the above, it should create placeholder
interfaces / stub components and leave a `// TODO: widget-library` comment.

---

*Last updated: 2026-05-07*
