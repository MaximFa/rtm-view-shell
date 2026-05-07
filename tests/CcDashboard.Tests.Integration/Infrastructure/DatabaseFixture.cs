using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Integration.Infrastructure;

public class DatabaseFixture : IAsyncLifetime
{
    // Set env var CCDASH_TEST_CONNSTR before running integration tests, e.g.:
    //   $env:CCDASH_TEST_CONNSTR = "Host=localhost;Port=5432;Database=RTMViewDB;Username=...;Password=...;SSL Mode=Disable"
    private static readonly string ConnectionString =
        Environment.GetEnvironmentVariable("CCDASH_TEST_CONNSTR")
        ?? throw new InvalidOperationException(
            "Integration tests require CCDASH_TEST_CONNSTR environment variable. " +
            "Example: Host=localhost;Port=5432;Database=RTMViewDB;Username=...;Password=...;SSL Mode=Disable");

    public AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;
        return new AppDbContext(options);
    }

    public async Task InitializeAsync()
    {
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync() => await CleanAsync();

    public async Task CleanAsync()
    {
        await using var db = CreateContext();
        // delete in FK-safe order
        await db.Database.ExecuteSqlRawAsync("""
            DELETE FROM "WidgetSlots";
            DELETE FROM "ScreenPermissions";
            DELETE FROM "ResourcePermissions";
            DELETE FROM "UserGroups";
            DELETE FROM "Screens";
            DELETE FROM "Users";
            DELETE FROM "PermissionGroups";
            DELETE FROM "AuditEvents";
            """);
    }
}

[CollectionDefinition(Name)]
public class DatabaseCollection : ICollectionFixture<DatabaseFixture>
{
    public const string Name = "Database";
}
