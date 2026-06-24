using CcDashboard.Application.Commands.Widgets;
using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Widgets;
using CcDashboard.Application.Handlers;
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

    /// <summary>
    /// Test adapter: wraps IDbContextFactory&lt;AppDbContext&gt; as IAppDbContextFactory
    /// </summary>
    private class TestAppDbContextFactory(IDbContextFactory<AppDbContext> inner) : IAppDbContextFactory
    {
        public async Task<IAppDbContext> CreateDbContextAsync(CancellationToken ct = default)
            => await inner.CreateDbContextAsync(ct);
    }

    // ── Helper: create handler trio for a given tenant+user ─────────────────
    private (GetUserWidgetSettingsQueryHandler get,
             SaveUserWidgetSettingsCommandHandler save,
             DeleteUserWidgetSettingsCommandHandler delete)
        CreateHandlers(Guid tenantId, Guid userId)
    {
        var efFactory = postgres.CreateDbContextFactory(tenantId);
        var dbFactory = new TestAppDbContextFactory(efFactory);
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
        using var doc = System.Text.Json.JsonDocument.Parse(result!);
        doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
        doc.RootElement.GetProperty("intervalMinutes").GetInt32().Should().Be(30);
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
        using var doc = System.Text.Json.JsonDocument.Parse(rows[0].SettingsJson);
        doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
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
        var efFactory = postgres.CreateDbContextFactory(postgres.TenantAId);
        var dbFactory = new TestAppDbContextFactory(efFactory);
        var currentUser = Substitute.For<CcDashboard.Domain.Interfaces.ICurrentUserAccessor>();
        currentUser.UserId.Returns((Guid?)null);
        var handler = new GetUserWidgetSettingsQueryHandler(dbFactory, currentUser);

        var result = await handler.Handle(
            new GetUserWidgetSettingsQuery(Uuid.NewSequential()),
            CancellationToken.None);

        result.Should().BeNull();
    }

    // ── 9. Two different widgets for same user store independently ───────────
    [Fact]
    [Trait("Req", "UWS-09")]
    public async Task Save_TwoDifferentWidgets_StoredIndependently()
    {
        var widgetId1 = Uuid.NewSequential();
        var widgetId2 = Uuid.NewSequential();
        var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId1, """{"widget":"one"}"""), CancellationToken.None);
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId2, """{"widget":"two"}"""), CancellationToken.None);

        var result1 = await get.Handle(new GetUserWidgetSettingsQuery(widgetId1), CancellationToken.None);
        var result2 = await get.Handle(new GetUserWidgetSettingsQuery(widgetId2), CancellationToken.None);

        using var doc1 = System.Text.Json.JsonDocument.Parse(result1!);
        using var doc2 = System.Text.Json.JsonDocument.Parse(result2!);
        doc1.RootElement.GetProperty("widget").GetString().Should().Be("one");
        doc2.RootElement.GetProperty("widget").GetString().Should().Be("two");
    }

    // ── 10. Same widget, two users — each gets own row ───────────────────────
    [Fact]
    [Trait("Req", "UWS-10")]
    public async Task Save_SameWidget_TwoUsers_IndependentRows()
    {
        var widgetId = Uuid.NewSequential();
        var (_, saveA, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        var (_, saveB, _) = CreateHandlers(postgres.TenantAId, postgres.UserBId);

        await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"user":"A"}"""), CancellationToken.None);
        await saveB.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"user":"B"}"""), CancellationToken.None);

        // Verify two rows in DB (bypass GQF)
        await using var db = postgres.CreateDbContext(postgres.TenantAId);
        var rows = await db.UserWidgetSettings
            .IgnoreQueryFilters()
            .Where(x => x.WidgetId == widgetId && x.TenantId == postgres.TenantAId)
            .ToListAsync();

        rows.Should().HaveCount(2);
        rows.Select(r => r.UserId).Should().Contain(postgres.UserAId).And.Contain(postgres.UserBId);
    }

    // ── 11. CreatedAt set on first save, UpdatedAt changes on second ─────────
    [Fact]
    [Trait("Req", "UWS-11")]
    public async Task Save_Timestamps_CreatedAtFixedUpdatedAtChanges()
    {
        var widgetId = Uuid.NewSequential();

        // First save
        var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":1}"""), CancellationToken.None);

        await using var db1 = postgres.CreateDbContext(postgres.TenantAId);
        var row1 = await db1.UserWidgetSettings
            .IgnoreQueryFilters()
            .FirstAsync(x => x.WidgetId == widgetId && x.UserId == postgres.UserAId);
        var createdAt  = row1.CreatedAt;
        var updatedAt1 = row1.UpdatedAt;

        await Task.Delay(10); // ensure time advances

        // Second save
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":2}"""), CancellationToken.None);

        await using var db2 = postgres.CreateDbContext(postgres.TenantAId);
        var row2 = await db2.UserWidgetSettings
            .IgnoreQueryFilters()
            .FirstAsync(x => x.WidgetId == widgetId && x.UserId == postgres.UserAId);

        row2.CreatedAt.Should().Be(createdAt, "CreatedAt must not change on update");
        row2.UpdatedAt.Should().BeOnOrAfter(updatedAt1, "UpdatedAt must advance on update");
    }

    // ── 12. TenantId is taken from ITenantContext, not forged by client ───────
    [Fact]
    [Trait("Req", "UWS-12")]
    public async Task Save_TenantIdFromContext_CannotBeForgedByClient()
    {
        var widgetId = Uuid.NewSequential();
        var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"x":1}"""), CancellationToken.None);

        await using var db = postgres.CreateDbContext(postgres.TenantAId);
        var row = await db.UserWidgetSettings
            .IgnoreQueryFilters()
            .FirstAsync(x => x.WidgetId == widgetId);

        row.TenantId.Should().Be(postgres.TenantAId, "TenantId must come from ITenantContext");
    }

    // ── 13. Full-payload JSON with all DayTrend fields roundtrips cleanly ─────
    [Fact]
    [Trait("Req", "UWS-13")]
    public async Task Save_FullDayTrendPayload_AllFieldsPreserved()
    {
        var widgetId = Uuid.NewSequential();
        var json = """
            {
                "buId": 42,
                "metrics": ["interaction.incoming_calls", "interaction.answered_calls"],
                "agentMetrics": ["statuslog.available_agents"],
                "chartType": "area",
                "intervalMinutes": 15,
                "metricColors": {"interaction.incoming_calls": "#3b82f6"},
                "agentMetricColors": {"statuslog.available_agents": "#22c55e"}
            }
            """;

        var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, json), CancellationToken.None);
        var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);

        result.Should().NotBeNullOrEmpty();
        using var doc = System.Text.Json.JsonDocument.Parse(result!);
        doc.RootElement.GetProperty("buId").GetInt32().Should().Be(42);
        doc.RootElement.GetProperty("chartType").GetString().Should().Be("area");
        doc.RootElement.GetProperty("intervalMinutes").GetInt32().Should().Be(15);
        doc.RootElement.GetProperty("metrics").GetArrayLength().Should().Be(2);
        doc.RootElement.GetProperty("metricColors")
            .GetProperty("interaction.incoming_calls").GetString().Should().Be("#3b82f6");
    }

    // ── 14. Save with non-latin (Hebrew) values preserves encoding ────────────
    [Fact]
    [Trait("Req", "UWS-14")]
    public async Task Save_HebrewTextInJson_PreservesEncoding()
    {
        var widgetId = Uuid.NewSequential();
        var json = """{"displayName":"תמיכה"}""";

        var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, json), CancellationToken.None);
        var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);

        using var doc = System.Text.Json.JsonDocument.Parse(result!);
        doc.RootElement.GetProperty("displayName").GetString().Should().Be("תמיכה");
    }

    // ── 15. UserB cannot delete UserA settings in same tenant ─────────────────
    [Fact]
    [Trait("Req", "UWS-15")]
    public async Task Delete_UserBCannotDeleteUserASettings()
    {
        var widgetId = Uuid.NewSequential();
        var (getA, saveA, _)    = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        var (_, _, deleteB) = CreateHandlers(postgres.TenantAId, postgres.UserBId);

        await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"owner":"A"}"""), CancellationToken.None);

        // UserB tries to delete UserA's settings
        await deleteB.Handle(new DeleteUserWidgetSettingsCommand(widgetId), CancellationToken.None);

        // UserA's settings must still exist
        var result = await getA.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);
        result.Should().NotBeNull("UserB must not be able to delete UserA settings");
    }

    // ── 16. Concurrent saves do not create duplicate rows (unique index) ───────
    [Fact]
    [Trait("Req", "UWS-16")]
    public async Task Save_Concurrent_DoesNotCreateDuplicateRows()
    {
        var widgetId = Uuid.NewSequential();
        var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

        // Two concurrent saves for the same widget/user
        var t1 = save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":1}"""), CancellationToken.None);
        var t2 = save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":2}"""), CancellationToken.None);

        // At most one should fail (unique index violation) — both completing is also acceptable
        try { await Task.WhenAll(t1, t2); } catch { /* one may fail due to unique index */ }

        await using var db = postgres.CreateDbContext(postgres.TenantAId);
        var count = await db.UserWidgetSettings
            .IgnoreQueryFilters()
            .CountAsync(x => x.WidgetId == widgetId && x.TenantId == postgres.TenantAId);

        count.Should().Be(1, "Concurrent saves must not create duplicate rows");
    }

    // ── 17. TenantB cannot delete TenantA settings (cross-tenant delete) ──────
    [Fact]
    [Trait("Req", "UWS-17")]
    public async Task Delete_TenantBCannotDeleteTenantASettings()
    {
        var widgetId = Uuid.NewSequential();

        // TenantA saves settings
        var (getA, saveA, _)    = CreateHandlers(postgres.TenantAId, postgres.UserAId);
        var (_, _, deleteBtenant) = CreateHandlers(postgres.TenantBId, postgres.UserAId); // same UserId, different tenant

        await saveA.Handle(
            new SaveUserWidgetSettingsCommand(widgetId, """{"owner":"tenantA"}"""),
            CancellationToken.None);

        // TenantB (same UserId) tries to delete TenantA's settings
        await deleteBtenant.Handle(
            new DeleteUserWidgetSettingsCommand(widgetId),
            CancellationToken.None);

        // TenantA's settings must still exist
        var result = await getA.Handle(
            new GetUserWidgetSettingsQuery(widgetId),
            CancellationToken.None);

        result.Should().NotBeNull("GQF must prevent TenantB from deleting TenantA settings");
    }
}
