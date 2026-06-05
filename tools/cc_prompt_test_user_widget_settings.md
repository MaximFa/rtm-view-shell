# CC Task: Tests for UserWidgetSettings — Get/Save/Delete + tenant/user isolation

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE
- NEW: `tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs`
- No other files.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Test file to create

`tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs`

Use the exact same pattern as `RtsGridLifecycleTests.cs`:
- `[Collection("Postgres")]`, constructor takes `PostgresFixture`
- Use `postgres.TenantAId`, `postgres.TenantBId`, `postgres.UserAId`, `postgres.UserBId`
- Use `postgres.CreateDbContext(tenantId)` for AppDbContext
- Handlers instantiated directly (not via DI)
- `NSubstitute` for interfaces if needed

```csharp
using CcDashboard.Application.Commands.Widgets;
using CcDashboard.Application.Queries.Widgets;
using CcDashboard.Infrastructure.Handlers;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using UUIDNext;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Tests for UserWidgetSettings: save/get/delete roundtrip,
/// upsert behavior, tenant isolation, user isolation.
/// </summary>
[Collection("Postgres")]
public class UserWidgetSettingsTests(PostgresFixture postgres)
{
    private readonly Guid _widgetId = Uuid.NewSequential();

    // ── Helper: create handler trio for a given tenant+user ─────────────────
    private (GetUserWidgetSettingsQueryHandler get,
             SaveUserWidgetSettingsCommandHandler save,
             DeleteUserWidgetSettingsCommandHandler delete)
        CreateHandlers(Guid tenantId, Guid userId)
    {
        var dbFactory = postgres.CreateDbContextFactory(tenantId);
        var currentUser = Substitute.For<CcDashboard.Domain.Interfaces.ICurrentUserAccessor>();
        currentUser.UserId.Returns(userId);
        var tenantCtx = Substitute.For<CcDashboard.Domain.Interfaces.ITenantContext>();
        tenantCtx.TenantId.Returns(tenantId);
        var clock = Substitute.For<CcDashboard.Domain.Interfaces.IDateTimeProvider>();
        clock.UtcNow.Returns(DateTime.UtcNow);

        return (
            new GetUserWidgetSettingsQueryHandler(dbFactory, currentUser),
            new SaveUserWidgetSettingsCommandHandler(dbFactory, currentUser, tenantCtx, clock),
            new DeleteUserWidgetSettingsCommandHandler(dbFactory, currentUser)
        );
    }

    // ── 1. Get returns null when no settings exist ───────────────────────────
    [Fact]
    [Trait("Req", "UWS-01")]
    public async Task Get_ReturnsNull_WhenNoSettingsExist()
    {
        var (get, _, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        var result = await get.Handle(
            new GetUserWidgetSettingsQuery(Uuid.NewSequential()),
            CancellationToken.None);

        result.Should().BeNull();
    }

    // ── 2. Save → Get roundtrip ──────────────────────────────────────────────
    [Fact]
    [Trait("Req", "UWS-02")]
    public async Task Save_ThenGet_ReturnsPersistedJson()
    {
        var widgetId = Uuid.NewSequential();
        var json = """{"buId":5,"chartType":"bar","intervalMinutes":30}""";

        var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, json), CancellationToken.None);
        var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);

        result.Should().NotBeNullOrEmpty();
        result.Should().Contain("\"chartType\":\"bar\"");
    }

    // ── 3. Second Save updates (upsert — no duplicate row) ──────────────────
    [Fact]
    [Trait("Req", "UWS-03")]
    public async Task Save_Twice_UpdatesExistingRow_NosDuplicate()
    {
        var widgetId = Uuid.NewSequential();
        var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"chartType":"line"}"""), CancellationToken.None);
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"chartType":"bar"}"""), CancellationToken.None);

        // Only one row in DB
        await using var db = postgres.CreateDbContext(postgres.TenantAId);
        var rows = await db.UserWidgetSettings
            .IgnoreQueryFilters()
            .Where(x => x.WidgetId == widgetId && x.TenantId == postgres.TenantAId)
            .ToListAsync();
        rows.Should().HaveCount(1);
        rows[0].SettingsJson.Should().Contain("\"chartType\":\"bar\"");
    }

    // ── 4. Delete removes the row ────────────────────────────────────────────
    [Fact]
    [Trait("Req", "UWS-04")]
    public async Task Delete_RemovesRow_GetReturnsNullAfterward()
    {
        var widgetId = Uuid.NewSequential();
        var (get, save, delete) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"buId":1}"""), CancellationToken.None);
        await delete.Handle(new DeleteUserWidgetSettingsCommand(widgetId), CancellationToken.None);

        var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);
        result.Should().BeNull();
    }

    // ── 5. Delete is no-op when row does not exist ───────────────────────────
    [Fact]
    [Trait("Req", "UWS-05")]
    public async Task Delete_NoOp_WhenRowDoesNotExist()
    {
        var (_, _, delete) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        var act = async () => await delete.Handle(
            new DeleteUserWidgetSettingsCommand(Uuid.NewSequential()),
            CancellationToken.None);

        await act.Should().NotThrowAsync();
    }

    // ── 6. Tenant isolation — TenantB cannot read TenantA settings ───────────
    [Fact]
    [Trait("Req", "UWS-06")]
    public async Task Get_TenantIsolation_TenantBCannotReadTenantASettings()
    {
        var widgetId = Uuid.NewSequential();

        var (_, saveA, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        var (getB, _, _)  = CreateHandlers(postgres.TenantBId, postgres.UserAId);

        await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"secret":"tenantA"}"""), CancellationToken.None);

        var result = await getB.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);
        result.Should().BeNull("GQF must prevent cross-tenant reads");
    }

    // ── 7. User isolation — UserB cannot read UserA settings in same tenant ──
    [Fact]
    [Trait("Req", "UWS-07")]
    public async Task Get_UserIsolation_UserBCannotReadUserASettings()
    {
        var widgetId = Uuid.NewSequential();

        var (_, saveA, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        var (getB, _, _)  = CreateHandlers(postgres.TenantAId, postgres.UserBId);

        await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"private":"userA"}"""), CancellationToken.None);

        var result = await getB.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);
        result.Should().BeNull("UserId filter must prevent cross-user reads");
    }

    // ── 8. Get returns null when UserId is null (unauthenticated) ────────────
    [Fact]
    [Trait("Req", "UWS-08")]
    public async Task Get_ReturnsNull_WhenUserIdIsNull()
    {
        var dbFactory = postgres.CreateDbContextFactory(postgres.TenantAId);
        var currentUser = Substitute.For<CcDashboard.Domain.Interfaces.ICurrentUserAccessor>();
        currentUser.UserId.Returns((Guid?)null);
        var handler = new GetUserWidgetSettingsQueryHandler(dbFactory, currentUser);

        var result = await handler.Handle(
            new GetUserWidgetSettingsQuery(Uuid.NewSequential()),
            CancellationToken.None);

        result.Should().BeNull();
    }
}
```

---

## Check: does PostgresFixture have CreateDbContextFactory?

Look for `CreateDbContextFactory` in `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs`.

If it does NOT exist, add this method to the fixture:
```csharp
public IDbContextFactory<AppDbContext> CreateDbContextFactory(Guid tenantId)
{
    var tenantCtx = new StaticTenantContext(tenantId);
    return new PooledDbContextFactory<AppDbContext>(
        new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options,
        // Pass tenant context - use same pattern as CreateDbContext
    );
}
```

If that pattern is not available, use a simple mock factory:
```csharp
public IDbContextFactory<AppDbContext> CreateDbContextFactory(Guid tenantId)
{
    var factory = Substitute.For<IDbContextFactory<AppDbContext>>();
    factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
        .Returns(_ => Task.FromResult(CreateDbContext(tenantId)));
    factory.CreateDbContext()
        .Returns(_ => CreateDbContext(tenantId));
    return factory;
}
```

Add this to `PostgresFixture.cs` if `CreateDbContextFactory` is missing.

---

## Run tests

```bash
dotnet test tests/CcDashboard.Tests.Security \
  --filter "FullyQualifiedName~UserWidgetSettings" \
  --logger "console;verbosity=detailed"
```

**All 8 tests must pass. If any fail — DO NOT commit. Fix the issue first.**

---

## Commit (only after all 8 tests pass)

```bash
bash tools/pre-commit-check.sh \
  tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs \
  tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "test: UserWidgetSettings — 8 tests (CRUD, upsert, tenant isolation, user isolation)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Re-sync (§0.6 PD-007)

```bash
for f in \
  "tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs" \
  "tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs"; do
  [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```
