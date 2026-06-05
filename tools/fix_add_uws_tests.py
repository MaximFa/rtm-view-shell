#!/usr/bin/env python3
"""Add CreateDbContextFactory to PostgresFixture and create UserWidgetSettingsTests."""
import os

# 1. Add CreateDbContextFactory to PostgresFixture
fixture_path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Security\Fixtures\PostgresFixture.cs"

with open(fixture_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add NSubstitute using if not present
if "using NSubstitute;" not in content:
    content = content.replace(
        "using Testcontainers.PostgreSql;",
        "using NSubstitute;\nusing Testcontainers.PostgreSql;"
    )

# Add CreateDbContextFactory method before CreateServiceProvider
new_method = '''
    /// <summary>
    /// Creates a mock IDbContextFactory that returns DbContext instances for the specified tenant.
    /// Used by handlers that require IDbContextFactory injection.
    /// </summary>
    public IDbContextFactory<AppDbContext> CreateDbContextFactory(Guid tenantId)
    {
        var factory = Substitute.For<IDbContextFactory<AppDbContext>>();
        factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
            .Returns(_ => Task.FromResult(CreateDbContext(tenantId)));
        factory.CreateDbContext()
            .Returns(_ => CreateDbContext(tenantId));
        return factory;
    }

    /// <summary>
'''

if "CreateDbContextFactory" not in content:
    content = content.replace(
        '''    /// <summary>
    /// Creates a ServiceProvider with Identity and DbContext configured for testing.
    /// </summary>''',
        new_method + '''Creates a ServiceProvider with Identity and DbContext configured for testing.
    /// </summary>'''
    )

with open(fixture_path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Updated: {fixture_path}")

# 2. Create UserWidgetSettingsTests.cs
test_path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Security\Widgets\UserWidgetSettingsTests.cs"

test_content = '''using CcDashboard.Application.Commands.Widgets;
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
        result.Should().Contain("\\"chartType\\":\\"bar\\"");
    }

    // ── 3. Second Save updates (upsert — no duplicate row) ──────────────────
    [Fact]
    [Trait("Req", "UWS-03")]
    public async Task Save_Twice_UpdatesExistingRow_NoDuplicate()
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
        rows[0].SettingsJson.Should().Contain("\\"chartType\\":\\"bar\\"");
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
'''

# Create Widgets directory if needed
os.makedirs(os.path.dirname(test_path), exist_ok=True)

with open(test_path, "w", encoding="utf-8") as f:
    f.write(test_content)
    f.flush()
    os.fsync(f.fileno())

print(f"Created: {test_path}")
print("Done.")
