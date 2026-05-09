---
name: program-architector
invocation: user
description: >
  Apply Clean Architecture and CQRS patterns to the RTM View Shell (CC Dashboard Shell) project.
  Trigger this skill whenever the user mentions: creating a new entity, adding a use-case,
  writing a MediatR command or query, designing a repository, setting up DI registration,
  adding a new API controller, creating a background service, planning a new feature,
  enforcing dependency rules, or diagnosing an architecture violation.
  Also trigger on: "add feature", "create command", "create query", "new entity",
  "dependency injection", "register service", "architecture", "clean architecture",
  "CQRS", "repository pattern", "mediator", "pipeline behavior", "background job",
  "multi-tenancy", "global query filter", "audit", or any request to add a DB table.
  Never skip this skill for any backend structural work — it ensures every layer
  communicates through correct abstractions and all multi-tenant / audit rules are applied.
---

# Program Architecture — RTM View Shell

This skill governs all backend structural decisions in the **CC Dashboard Shell** project.
Read it in full before creating any entity, command, handler, repository, or controller.

---

## 0. Before writing any code — verify context

1. **Read `CLAUDE.md`** — especially §3 (solution structure), §4 (cross-cutting services),
   §5 (multi-tenancy), §6 (data model), §7 (EF Core conventions).
2. Confirm you know which layer owns the file you're about to create.
3. Confirm the entity needs multi-tenant GQF (most do) or is cross-tenant (Tenant, WidgetCatalogItem, ApplicationRole, MenuItem).
4. Identify the required audit event(s) from §16.
5. Check that `CLAUDE.md §29` doesn't already document the pattern you're implementing.

---

## 1. Dependency rules — immutable

```
CcDashboard.Domain          zero NuGet deps; only BCL
        ↑
CcDashboard.Contracts       DTOs, strongly-typed IDs, ResultMonad, enums
        ↑
CcDashboard.Application     Use-cases, MediatR, validators, interfaces
        ↑
CcDashboard.Infrastructure  EF Core, Redis, email, audit writer, SSO adapters
        ↑
CcDashboard.Web / Api       Program.cs composition root ONLY
```

**Enforced by `CcDashboard.Tests.Architecture` (NetArchTest) — violation = PR blocked [ARCH-11].**

Rules:
- Domain has **zero** NuGet packages outside BCL.
- `Infrastructure` must **not** be referenced directly from `Web`/`Api` except in `Program.cs`.
- All cross-layer calls go through interfaces defined in `Application` or `Domain`.
- `Web` components call Application services through `IXxxService` or MediatR `ISender`.

---

## 2. Implementing a feature — 5-step sequence

Always implement features in this order. Skipping steps causes dependency violations.

```
Step 1 — Domain
  └─ Entity / value object / domain exception / enum

Step 2 — Contracts
  └─ Request/Response DTOs, strongly-typed IDs (if new aggregate)

Step 3 — Application
  ├─ Interface (IXxxService or IXxxRepository)
  ├─ MediatR Command/Query + Handler
  ├─ FluentValidation Validator
  └─ Audit event constant

Step 4 — Infrastructure
  ├─ EF entity configuration (IEntityTypeConfiguration<T>)
  ├─ Repository implementation
  ├─ Migration (dotnet ef migrations add ...)
  └─ DI registration in Infrastructure module

Step 5 — Web / Api
  ├─ Blazor component or API controller (thin, calls MediatR ISender)
  ├─ [Authorize(Policy = "...")] attribute
  └─ Localisation strings in .resx
```

---

## 3. MediatR pipeline — fixed order

```
LoggingBehavior
  └─ ValidationBehavior      (FluentValidation)
       └─ TransactionBehavior  (wraps IUnitOfWork.SaveChanges)
            └─ AuthorizationBehavior  (PG / role checks)
                 └─ AuditBehavior     (writes to AuditDbContext)
                      └─ Handler
```

**Never bypass the pipeline.** All commands go through `ISender.Send(command, ct)`.
Handlers must not call `SaveChanges` directly — `TransactionBehavior` does it.

### Command template

```csharp
// Application/Commands/CreatePermissionGroupCommand.cs
public record CreatePermissionGroupCommand(
    string Name,
    string? Description,
    bool IsActive
) : IRequest<Result<Guid>>;

public class CreatePermissionGroupCommandValidator
    : AbstractValidator<CreatePermissionGroupCommand>
{
    public CreatePermissionGroupCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
    }
}

public class CreatePermissionGroupCommandHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser,
    ITenantContext tenant,
    IAuditService audit,
    IDateTimeProvider clock
) : IRequestHandler<CreatePermissionGroupCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(
        CreatePermissionGroupCommand cmd,
        CancellationToken ct)
    {
        var group = new PermissionGroup
        {
            Id = UUIDNext.Uuid.NewSequential(),
            TenantId = tenant.TenantId,
            Name = cmd.Name,
            Description = cmd.Description,
            IsActive = cmd.IsActive,
            CreatedAt = clock.UtcNow,
            CreatedByUserId = currentUser.UserId
        };

        await repo.AddAsync(group, ct);
        // IUnitOfWork.SaveChanges called by TransactionBehavior

        await audit.LogAsync(AuditEvents.PermissionGroup.Created,
            new { group.Id, group.Name, group.TenantId }, ct);

        return Result.Ok(group.Id);
    }
}
```

### Query template (read-only — no transaction, no audit)

```csharp
public record GetPermissionGroupsQuery(Guid? TenantId = null)
    : IRequest<IReadOnlyList<PermissionGroupDto>>;

public class GetPermissionGroupsQueryHandler(
    IPermissionGroupRepository repo,
    ICurrentUserAccessor currentUser
) : IRequestHandler<GetPermissionGroupsQuery, IReadOnlyList<PermissionGroupDto>>
{
    public async Task<IReadOnlyList<PermissionGroupDto>> Handle(
        GetPermissionGroupsQuery qry,
        CancellationToken ct)
    {
        // Superadmin may pass explicit TenantId; others always get own tenant
        var tenantId = qry.TenantId ?? currentUser.TenantId!.Value;
        return await repo.GetAllByTenantAsync(tenantId, ct);
    }
}
```

---

## 4. New entity checklist

Use this table every time you add an entity. Check every row.

| # | Check | How |
|---|---|---|
| 1 | UUIDv7 primary key | `Id = UUIDNext.Uuid.NewSequential()` in constructor / factory |
| 2 | `TenantId` column | Yes for all multi-tenant entities; no for cross-tenant (Tenant, WidgetCatalogItem) |
| 3 | Global Query Filter | `e => e.TenantId == _tenantCtx.TenantId` in `AppDbContext.OnModelCreating` |
| 4 | Soft-delete GQF | Add `&& !e.IsDeleted` if the entity supports soft-delete |
| 5 | `IEntityTypeConfiguration<T>` | One file per entity in `Infrastructure/Persistence/Configurations/` |
| 6 | All FK columns indexed | `builder.HasIndex(e => e.XxxId)` |
| 7 | Unique constraint defined | e.g. `(TenantId, Name)` |
| 8 | `IAuditableEntity` interceptor | `CreatedAt`, `CreatedByUserId`, `UpdatedAt`, `UpdatedByUserId` auto-set |
| 9 | `xmin` concurrency token | For entities with optimistic concurrency (PermissionGroup, Dashboard) |
| 10 | timestamptz, not datetime | All EF timestamps mapped to `timestamptz` (UTC) |
| 11 | EF migration added | `dotnet ef migrations add <Name> --context AppDbContext ...` |
| 12 | Seed data (if reference) | Seed for ALL tenants (platform + customer tenants) |

### EF entity configuration template

```csharp
// Infrastructure/Persistence/Configurations/PermissionGroupConfiguration.cs
public class PermissionGroupConfiguration : IEntityTypeConfiguration<PermissionGroup>
{
    public void Configure(EntityTypeBuilder<PermissionGroup> builder)
    {
        builder.ToTable("permission_groups");

        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).HasColumnType("uuid");
        builder.Property(e => e.Name).HasMaxLength(200).IsRequired();
        builder.Property(e => e.TenantId).HasColumnType("uuid").IsRequired();
        builder.Property(e => e.CreatedAt).HasColumnType("timestamptz");
        builder.Property(e => e.UpdatedAt).HasColumnType("timestamptz");

        // Optimistic concurrency via PostgreSQL xmin
        builder.Property<uint>("xmin")
            .HasColumnName("xmin")
            .HasColumnType("xid")
            .ValueGeneratedOnAddOrUpdate()
            .IsConcurrencyToken();

        // Unique index per tenant
        builder.HasIndex(e => new { e.TenantId, e.Name }).IsUnique();

        // FK indexes
        builder.HasIndex(e => e.TenantId);
        builder.HasIndex(e => e.CreatedByUserId);
    }
}
```

### Global Query Filter registration

```csharp
// Infrastructure/Persistence/AppDbContext.cs — OnModelCreating
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    base.OnModelCreating(modelBuilder);
    modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

    // Multi-tenant GQF — applied to ALL multi-tenant entities
    modelBuilder.Entity<PermissionGroup>()
        .HasQueryFilter(e => e.TenantId == _tenantContext.TenantId);

    modelBuilder.Entity<Dashboard>()
        .HasQueryFilter(e => e.TenantId == _tenantContext.TenantId && !e.IsDeleted);

    // Cross-tenant entities (Tenant, WidgetCatalogItem) — NO GQF
}
```

---

## 5. Repository pattern

```csharp
// Domain/Interfaces/IRepository.cs
public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> GetAllAsync(CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    void Update(T entity);
    void Remove(T entity);
}

// Application/Interfaces/IPermissionGroupRepository.cs
public interface IPermissionGroupRepository : IRepository<PermissionGroup>
{
    Task<IReadOnlyList<PermissionGroup>> GetAllByTenantAsync(Guid tenantId, CancellationToken ct);
    Task<bool> ExistsWithNameAsync(Guid tenantId, string name, Guid? excludeId, CancellationToken ct);
    Task<int> GetUserCountAsync(Guid groupId, CancellationToken ct);
}
```

**Rules:**
- Generic `IRepository<T>` lives in **Domain**.
- Specialised interfaces (e.g. `IPermissionGroupRepository`) live in **Application**.
- Implementations live in **Infrastructure**.
- Read-only queries: always `AsNoTracking()`.
- `IgnoreQueryFilters()` only in designated system repos; each use writes a `Tenant.CrossTenantAccess` audit event. [ARCH-01]

---

## 6. Cross-cutting services — always inject, never create

```csharp
// These are registered in DI and must be injected, never instantiated directly.
ITenantContext         // Current TenantId
ICurrentUserAccessor   // UserId, Role, PermissionGroupId, PreferredLocale
IDateTimeProvider      // All timestamps — always UTC
IUnitOfWork            // Wraps SaveChanges in a PostgreSQL transaction
IAuditService          // Writes to audit.audit_logs via AuditDbContext (never rolls back)
```

---

## 7. REST API controller pattern

Controllers are **thin** — they delegate to MediatR immediately.

```csharp
[ApiController]
[Route("v1/[controller]")]
[Authorize]
public class PermissionGroupsController(ISender sender) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PermissionGroupDto>), 200)]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var result = await sender.Send(new GetPermissionGroupsQuery(), ct);
        return Ok(result);
    }

    [HttpPost]
    [Authorize(Roles = "Superadmin,Administrator")]
    [ProducesResponseType(typeof(Guid), 201)]
    [ProducesResponseType(typeof(ValidationProblemDetails), 400)]
    public async Task<IActionResult> Create(
        CreatePermissionGroupCommand cmd, CancellationToken ct)
    {
        var result = await sender.Send(cmd, ct);
        return result.IsSuccess
            ? CreatedAtAction(nameof(GetAll), new { id = result.Value }, result.Value)
            : BadRequest(result.Errors);
    }
}
```

**Every controller must have `[Authorize]`.**
Fine-grained checks (`Roles = "..."` or Policy) on individual actions.

---

## 8. Background service pattern

Background services must create their own DI scope and explicitly set `TenantId`. [ARCH-07]

```csharp
public class ExpiredTwoFactorCodesCleanupService(
    IServiceScopeFactory scopeFactory,
    ILogger<ExpiredTwoFactorCodesCleanupService> logger
) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(15));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            using var scope = scopeFactory.CreateScope();
            // Retrieve DB context — must NOT use ITenantContext directly
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            try
            {
                // For system-wide cleanup: IgnoreQueryFilters + explicit Where
                var expired = await db.TwoFactorCodes
                    .IgnoreQueryFilters()
                    .Where(c => c.ExpiresAt < DateTime.UtcNow && c.ConsumedAt == null)
                    .ToListAsync(stoppingToken);

                db.TwoFactorCodes.RemoveRange(expired);
                await db.SaveChangesAsync(stoppingToken);

                logger.LogInformation(
                    "Cleaned up {Count} expired 2FA codes.", expired.Count);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error cleaning up expired 2FA codes.");
            }
        }
    }
}
```

**Register in `Program.cs`:**
```csharp
builder.Services.AddHostedService<ExpiredTwoFactorCodesCleanupService>();
```

---

## 9. DI registration — Infrastructure module

All infrastructure registrations go in an extension method inside `Infrastructure`.
`Program.cs` calls this extension — it never references Infrastructure types directly.

```csharp
// Infrastructure/DependencyInjection.cs
public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>((sp, opts) =>
        {
            opts.UseNpgsql(configuration.GetConnectionString("DefaultConnection"),
                npg => npg.EnableRetryOnFailure());
            opts.ConfigureWarnings(w =>
                w.Ignore(RelationalEventId.MultipleCollectionIncludeWarning));
        });

        services.AddDbContext<AuditDbContext>((sp, opts) =>
            opts.UseNpgsql(configuration.GetConnectionString("AuditConnection")));

        services.AddScoped<IPermissionGroupRepository, PermissionGroupRepository>();
        services.AddScoped<IDashboardRepository, DashboardRepository>();
        // ... other repositories

        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();
        services.AddSingleton<IRedisCacheService, RedisCacheService>();

        return services;
    }
}
```

---

## 10. Common architecture mistakes — anti-pattern table

| ❌ Anti-pattern | ✅ Correct approach |
|---|---|
| Inject `AppDbContext` in Application layer | Inject `IXxxRepository` interface |
| Inject `Infrastructure` type in `Web` Razor component | Inject `IXxxService` from Application |
| Call `SaveChanges()` in a handler directly | Let `TransactionBehavior` call it |
| Put business logic in a Razor component | Move to Command/Query Handler |
| Use `Task.Run` inside a Blazor component | Use async event callbacks properly |
| Use `.Result` or `.Wait()` on async methods | `await` all the way up |
| Hardcode `TenantId` in a query | Use `ITenantContext.TenantId` via GQF |
| Use `IgnoreQueryFilters()` without audit event | Always write `Tenant.CrossTenantAccess` |
| String-concatenate SQL | `FromSqlInterpolated` / `ExecuteSqlInterpolated` only [CODE-01] |
| Store secrets in `appsettings.json` | User Secrets (dev) / Key Vault (prod) [CODE-05] |
| Put `[Authorize]` only in UI | Must also check in `AuthorizationBehavior` [CODE-03] |
| Create new entity IDs with `Guid.NewGuid()` | `UUIDNext.Uuid.NewSequential()` |

---

## 11. EF Core migration procedure

```powershell
# Add a migration (always specify both projects)
dotnet ef migrations add <MigrationName> `
  --context AppDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web

# For AuditDbContext migrations
dotnet ef migrations add <MigrationName> `
  --context AuditDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web

# Apply migrations to DB
dotnet ef database update `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web

# Generate idempotent SQL for DBA review
dotnet ef migrations script --idempotent `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web `
  --output migrations.sql
```

**Rules:**
- Never edit migration files manually. If wrong, `dotnet ef migrations remove` and regenerate.
- Never use raw SQL in migrations for business logic.
- All schema changes via EF migrations only. [MAINT-04]
- Enable required PostgreSQL extensions in the first migration:
  ```csharp
  migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS pgcrypto;");
  migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS pg_trgm;");
  migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS pg_stat_statements;");
  ```

---

## 12. NetArchTest — architecture enforcement

```csharp
// tests/CcDashboard.Tests.Architecture/DependencyTests.cs
[Fact]
public void Domain_Should_Not_Reference_Infrastructure()
{
    var result = Types
        .InAssembly(DomainAssembly)
        .Should().NotHaveDependencyOn("CcDashboard.Infrastructure")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(result.FailingTypeNames?.ToString());
}

[Fact]
public void Application_Should_Not_Reference_Infrastructure()
{
    var result = Types
        .InAssembly(ApplicationAssembly)
        .Should().NotHaveDependencyOn("CcDashboard.Infrastructure")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(result.FailingTypeNames?.ToString());
}

[Fact]
public void Web_Should_Not_Reference_Infrastructure_Except_ProgramCs()
{
    var result = Types
        .InAssembly(WebAssembly)
        .That().DoNotHaveName("Program")
        .Should().NotHaveDependencyOn("CcDashboard.Infrastructure")
        .GetResult();

    result.IsSuccessful.Should().BeTrue(result.FailingTypeNames?.ToString());
}
```

---

## 13. Audit event constants

All audit event types used in handlers must match the constants in CLAUDE.md §16.
Define them in `Domain/Constants/AuditEvents.cs`:

```csharp
public static class AuditEvents
{
    public static class Auth
    {
        public const string LoginSuccess = "Login.Success";
        public const string LoginFailure = "Login.Failure";
        public const string Logout       = "Logout";
        public const string TokenRefresh = "Token.Refresh";
        public const string TokenRevoked = "Token.Revoked";
    }
    public static class User
    {
        public const string Created              = "User.Created";
        public const string Updated              = "User.Updated";
        public const string Deactivated          = "User.Deactivated";
        public const string Activated            = "User.Activated";
        public const string RoleChanged          = "User.RoleChanged";
        public const string PermissionGroupChanged = "User.PermissionGroupChanged";
    }
    public static class PermissionGroup
    {
        public const string Created           = "PermissionGroup.Created";
        public const string Updated           = "PermissionGroup.Updated";
        public const string Deleted           = "PermissionGroup.Deleted";
        public const string PermissionChanged = "PermissionGroup.PermissionChanged";
    }
    public static class Dashboard
    {
        public const string Created = "Dashboard.Created";
        public const string Updated = "Dashboard.Updated";
        public const string Deleted = "Dashboard.Deleted";
        public const string Viewed  = "Dashboard.Viewed";
    }
    public static class Tenant
    {
        public const string Created           = "Tenant.Created";
        public const string Switched          = "Tenant.Switched";
        public const string CrossTenantAccess = "Tenant.CrossTenantAccess";
    }
}
```

---

## 14. Permission check — two levels (mandatory)

Every protected operation must be checked at **both** levels. [CODE-03]

**Level 1 — Attribute on page / controller:**
```csharp
[Authorize(Roles = "Superadmin,Administrator")]  // Blazor page
// or
[Authorize(Policy = "CanManageUsers")]            // API controller action
```

**Level 2 — AuthorizationBehavior in MediatR pipeline:**
```csharp
public class AuthorizationBehavior<TRequest, TResponse>(
    ICurrentUserAccessor currentUser,
    IPermissionService permissionService
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IAuthorizableRequest
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        await permissionService.AuthorizeAsync(request, currentUser, ct);
        // Throws ForbiddenException if check fails
        return await next();
    }
}
```

UI-only hiding without a backend check is a security violation.

---

## Pre-commit architecture checklist

- [ ] New entity: UUIDv7 PK, TenantId, GQF registered
- [ ] `IEntityTypeConfiguration<T>` file added
- [ ] EF migration created and reviewed
- [ ] No `Infrastructure` types referenced from `Application`
- [ ] Command/Query goes through MediatR `ISender`
- [ ] `SaveChanges` NOT called in handler (TransactionBehavior handles it)
- [ ] `IAuditService.LogAsync(...)` called for every write operation
- [ ] `[Authorize]` on Blazor page AND permission check in MediatR pipeline
- [ ] Read-only queries use `AsNoTracking()`
- [ ] `IgnoreQueryFilters()` guarded by `Tenant.CrossTenantAccess` audit event
- [ ] No secrets in source files
- [ ] Architecture tests pass: `dotnet test tests/CcDashboard.Tests.Architecture`
