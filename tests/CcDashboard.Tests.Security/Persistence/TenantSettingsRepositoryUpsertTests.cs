using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.Persistence;

/// <summary>
/// The blocker the operator hit on 234 (15.10): saving tenant settings threw
/// "another instance with the same key value for {'TenantId'} is already being tracked" and the
/// save did not happen.
///
/// Why it happens: GetByTenantAsync deliberately reads through a FRESH context, so the instance the
/// command edits is detached from the scoped one. The scoped context lives as long as the Blazor
/// circuit, and the first save's own Update() leaves its instance tracked; UserManagementService
/// .CreateAsync can do the same. Then Update() of a second instance with the same key throws -
/// so the second save of tenant settings in one circuit failed every time.
///
/// These tests therefore do NOT mock the tracker: they put a tracked instance in the scoped context
/// first, exactly as the sign-in path does, and then call the write path.
/// </summary>
[Collection("Postgres")]
public class TenantSettingsRepositoryUpsertTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Upsert_WhenScopedContextAlreadyTracksTheSameTenant_DoesNotThrow_AndWrites()
    {
        var tenantId = postgres.TenantAId;

        await using var scoped = postgres.CreateDbContext(tenantId);

        // Step 1: something earlier in the circuit leaves the settings TRACKED in the scoped context
        // (a previous save, or UserManagementService.CreateAsync's tracked SELECT ... FOR UPDATE).
        var tracked = await scoped.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == tenantId);
        tracked.Should().NotBeNull("the fixture seeds settings for this tenant");

        // Step 2: the command edits a DETACHED instance, as GetByTenantAsync hands it over.
        await using var fresh = postgres.CreateDbContext(tenantId);
        var detached = await fresh.TenantSettings.IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == tenantId);
        detached!.WfmWindowMinutes = 17;
        detached.WfmServingStateGroups = Array.Empty<string>();

        var repo = new TenantSettingsRepository(scoped, postgres.CreateDbContextFactory(tenantId));

        // Step 3: the write path. Before the fix this threw InvalidOperationException.
        var act = () => repo.UpsertAsync(detached);
        await act.Should().NotThrowAsync();

        await scoped.SaveChangesAsync();

        // The value must actually be in the database - "did not throw" alone would pass for a
        // repository that quietly did nothing, which is the failure mode worth guarding.
        await using var verify = postgres.CreateDbContext(tenantId);
        var saved = await verify.TenantSettings.IgnoreQueryFilters()
            .FirstAsync(s => s.TenantId == tenantId);
        saved.WfmWindowMinutes.Should().Be(17);
        saved.WfmServingStateGroups.Should().BeEmpty();
    }

    [Fact]
    public async Task Upsert_TwiceInTheSameContext_BothSucceed_AndTheSecondValueWins()
    {
        // The coordinator's acceptance case. The second save is the one that used to throw, because
        // the first left a tracked instance behind.
        var tenantId = postgres.TenantAId;
        await using var scoped = postgres.CreateDbContext(tenantId);
        var factory = postgres.CreateDbContextFactory(tenantId);
        var repo = new TenantSettingsRepository(scoped, factory);

        await using (var fresh = postgres.CreateDbContext(tenantId))
        {
            var first = await fresh.TenantSettings.IgnoreQueryFilters()
                .FirstAsync(s => s.TenantId == tenantId);
            first.WfmWindowMinutes = 11;
            await repo.UpsertAsync(first);
            await scoped.SaveChangesAsync();
        }

        await using (var fresh = postgres.CreateDbContext(tenantId))
        {
            var second = await fresh.TenantSettings.IgnoreQueryFilters()
                .FirstAsync(s => s.TenantId == tenantId);
            second.WfmWindowMinutes = 23;
            var act = () => repo.UpsertAsync(second);
            await act.Should().NotThrowAsync("the first save left a tracked instance behind");
            await scoped.SaveChangesAsync();
        }

        await using var verify = postgres.CreateDbContext(tenantId);
        var saved = await verify.TenantSettings.IgnoreQueryFilters()
            .FirstAsync(s => s.TenantId == tenantId);
        saved.WfmWindowMinutes.Should().Be(23, "the second save must win, not be swallowed");
    }

    [Fact]
    public async Task Upsert_WhenNothingIsTracked_StillWrites()
    {
        // NEGATIVE half of the pair: the fix must not turn the ordinary path - nothing tracked yet -
        // into a no-op. A repository that only ever copied into a tracked instance would pass the
        // two tests above and silently stop saving in the common case.
        var tenantId = postgres.TenantBId;

        await using var scoped = postgres.CreateDbContext(tenantId);
        scoped.ChangeTracker.Entries<TenantSettings>().Should().BeEmpty("nothing read yet");

        await using var fresh = postgres.CreateDbContext(tenantId);
        var detached = await fresh.TenantSettings.IgnoreQueryFilters()
            .FirstAsync(s => s.TenantId == tenantId);
        detached.WfmWindowMinutes = 29;

        var repo = new TenantSettingsRepository(scoped, postgres.CreateDbContextFactory(tenantId));
        await repo.UpsertAsync(detached);
        await scoped.SaveChangesAsync();

        await using var verify = postgres.CreateDbContext(tenantId);
        var saved = await verify.TenantSettings.IgnoreQueryFilters()
            .FirstAsync(s => s.TenantId == tenantId);
        saved.WfmWindowMinutes.Should().Be(29);
    }
}
