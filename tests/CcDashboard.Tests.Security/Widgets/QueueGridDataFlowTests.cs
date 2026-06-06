using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using NSubstitute;
using UUIDNext;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Regression tests for QueueGrid data-flow fixes documented in CLAUDE.md section 36.
/// Guards against two production bugs:
/// - Bug 1: RTSGrid_GetDataCells INNER JOIN with empty TemplateCell table
/// - Bug 2: ClassificationId not set to "ALL" on queue assignments
/// </summary>
[Collection("Postgres")]
public class QueueGridDataFlowTests(PostgresFixture postgres)
{
    // ── QGDF-01: RTSGrid_GetDataCells returns Data cells, excludes non-Data ────────

    [Fact]
    [Trait("Req", "QGDF-01")]
    public async Task GetDataCells_ReturnsDataCellsOnly_ExcludesStatisticCells()
    {
        // Arrange: Load RTS functions and ensure tables exist
        await postgres.EnsureQueueGridTablesAsync();
        await postgres.EnsureRtsGridFunctionsAsync();

        await using var beDb = postgres.CreateBackendEmulationDbContext();

        // Seed a grid with one Data cell and one Statistic cell
        var gridId = await SeedRtsGridWithCellsAsync(beDb);

        // Act: Call RTSGrid_GetDataCells() function
        var sql = @"SELECT ""CellId"", ""CellType"", ""GridId"" FROM ""RTSGrid_GetDataCells""()";
        var results = new List<(int CellId, string CellType, int GridId)>();
        
        await using var conn = new NpgsqlConnection(postgres.ConnectionString);
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add((
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetInt32(2)
            ));
        }

        // Assert: Only Data cells returned for our grid
        var ourGridCells = results.Where(r => r.GridId == gridId).ToList();
        ourGridCells.Should().HaveCount(1, "only the Data cell should be returned");
        ourGridCells.Should().OnlyContain(c => c.CellType == "Data",
            "TemplateCell INNER JOIN bug would return 0 rows; Statistic cells should be excluded");
    }

    // ── QGDF-02: SaveBusinessUnitCommand sets ClassificationId='ALL' ───────────────

    [Fact]
    [Trait("Req", "QGDF-02")]
    public async Task SaveBusinessUnit_SetsClassificationIdToAll_ForEveryQueueAssignment()
    {
        // Arrange
        var tenantId = postgres.TenantAId;
        await using var beDb = postgres.CreateBackendEmulationDbContext();

        // Seed required NGC_Site for FK
        var siteId = $"SITE-{Uuid.NewSequential():N}"[..10];
        beDb.NgcSites.Add(new NgcSite
        {
            SiteId = siteId,
            TenantId = tenantId,
            SiteName = "Test Site",
            TimeZone = "+00:00",
            ClearTime = "00:00"
        });
        await beDb.SaveChangesAsync();

        // Create handler with mocked dependencies
        var userAccessor = Substitute.For<ICurrentUserAccessor>();
        userAccessor.TenantId.Returns(tenantId);
        userAccessor.UserName.Returns("test-user");

        var clock = Substitute.For<IDateTimeProvider>();
        clock.UtcNow.Returns(DateTime.UtcNow);

        var apiHook = Substitute.For<IConfigurationApiHook>();
        var repo = new NgcBusinessUnitRepository(beDb);

        var handler = new SaveBusinessUnitCommandHandler(repo, userAccessor, clock, apiHook);

        // Act: Save a BU with 2 queue assignments
        var command = new SaveBusinessUnitCommand(new SaveBusinessUnitRequest(
            BusinessUnitId: null,
            BusinessUnitName: "Test BU for QGDF-02",
            Description: "Regression test",
            SiteId: siteId,
            QueueIds: ["Q1001", "Q1002"],
            SupergroupIds: []
        ));

        var result = await handler.Handle(command, CancellationToken.None);
        result.IsSuccess.Should().BeTrue("handler should succeed");
        
        // SaveChanges is normally done by TransactionBehavior - do it manually in test
        await beDb.SaveChangesAsync();

        // Assert: All queue classifications have ClassificationId = "ALL"
        // Note: result.Value may be 0 before SaveChanges updates it, so query by name
        
        // Read back the BU with its queue assignments (same context, reload from DB)
        beDb.ChangeTracker.Clear();
        var savedBu = await beDb.NgcBusinessUnits
            .IgnoreQueryFilters()
            .Include(b => b.QueueAssignments)
            .FirstOrDefaultAsync(b => b.BusinessUnitName == "Test BU for QGDF-02" && b.TenantId == tenantId);

        savedBu.Should().NotBeNull("BU should be persisted");
        savedBu!.QueueAssignments.Should().HaveCount(2, "2 queues were assigned");
        savedBu.QueueAssignments.Should().OnlyContain(c => c.ClassificationId == "ALL",
            "Bug 2 fix: ClassificationId must be 'ALL' for RTM Engine to register queues");
    }

    // ── QGDF-03: RTSGrid_GetAllUnionQueueClassifications is tenant-scoped ──────────

    [Fact]
    [Trait("Req", "QGDF-03")]
    public async Task GetAllUnionQueueClassifications_IsTenantScoped_ReturnsAllClassificationId()
    {
        // Arrange
        await postgres.EnsureRtsGridFunctionsAsync();
        await using var beDb = postgres.CreateBackendEmulationDbContext();

        var tenantA = postgres.TenantAId;
        var tenantB = postgres.TenantBId;

        // Seed NGC_Site for both tenants
        var siteA = $"SITE-A-{Uuid.NewSequential():N}"[..12];
        var siteB = $"SITE-B-{Uuid.NewSequential():N}"[..12];

        beDb.NgcSites.AddRange(
            new NgcSite { SiteId = siteA, TenantId = tenantA, SiteName = "Site A", TimeZone = "+00:00", ClearTime = "00:00" },
            new NgcSite { SiteId = siteB, TenantId = tenantB, SiteName = "Site B", TimeZone = "+00:00", ClearTime = "00:00" }
        );
        await beDb.SaveChangesAsync();

        // Seed NGC_BusinessUnit for both tenants
        beDb.NgcBusinessUnits.AddRange(
            new NgcBusinessUnit { TenantId = tenantA, BusinessUnitName = "BU-A", SiteId = siteA },
            new NgcBusinessUnit { TenantId = tenantB, BusinessUnitName = "BU-B", SiteId = siteB }
        );
        await beDb.SaveChangesAsync();

        // Get the generated BU IDs
        var buA = await beDb.NgcBusinessUnits.FirstAsync(b => b.TenantId == tenantA && b.BusinessUnitName == "BU-A");
        var buB = await beDb.NgcBusinessUnits.FirstAsync(b => b.TenantId == tenantB && b.BusinessUnitName == "BU-B");

        // Seed queue classifications with ClassificationId = "ALL"
        beDb.NgcBusinessUnitQueueClassifications.AddRange(
            new NgcBusinessUnitQueueClassification
            {
                BusinessUnitId = buA.BusinessUnitId,
                QueueId = "QA-001",
                TenantId = tenantA,
                ClassificationId = "ALL"
            },
            new NgcBusinessUnitQueueClassification
            {
                BusinessUnitId = buB.BusinessUnitId,
                QueueId = "QB-001",
                TenantId = tenantB,
                ClassificationId = "ALL"
            }
        );
        await beDb.SaveChangesAsync();

        // Act: Call the function with TenantA parameter
        var sql = @"SELECT ""BusinessUnitID"", ""QueueID"", ""ClassificationID"" 
                    FROM ""RTSGrid_GetAllUnionQueueClassifications""(@tenantId)";

        var results = new List<(int BuId, string QueueId, string ClassificationId)>();
        
        await using var conn = new NpgsqlConnection(postgres.ConnectionString);
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@tenantId", tenantA);
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add((
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetString(2)
            ));
        }

        // Assert
        results.Should().Contain(r => r.QueueId == "QA-001",
            "TenantA's queue should be returned");
        results.Should().NotContain(r => r.QueueId == "QB-001",
            "TenantB's queue should NOT be returned (tenant isolation)");
        results.Where(r => r.QueueId == "QA-001")
            .Should().OnlyContain(r => r.ClassificationId == "ALL",
                "ClassificationId must be 'ALL' for RTM Engine queue registration");
    }

    // ── Helper: Seed RTSGrid with test cells ───────────────────────────────────────

    private static async Task<int> SeedRtsGridWithCellsAsync(BackendEmulationDbContext beDb)
    {
        // Insert a grid
        await beDb.Database.ExecuteSqlRawAsync(@"
            INSERT INTO ""RTSGrid_Grid"" (""Title"", ""UnionId"") 
            VALUES ('QGDF Test Grid', 999)
        ");

        var gridId = await beDb.Database.SqlQueryRaw<int>(
            @"SELECT MAX(""GridId"") AS ""Value"" FROM ""RTSGrid_Grid"" WHERE ""Title"" = 'QGDF Test Grid'"
        ).FirstAsync();

        // Insert a column
        await beDb.Database.ExecuteSqlRawAsync($@"
            INSERT INTO ""RTSGrid_Column"" (""GridId"", ""ColumnNumber"") 
            VALUES ({gridId}, 1)
        ");

        var columnId = await beDb.Database.SqlQueryRaw<int>(
            $@"SELECT MAX(""ColumnId"") AS ""Value"" FROM ""RTSGrid_Column"" WHERE ""GridId"" = {gridId}"
        ).FirstAsync();

        // Insert a row
        await beDb.Database.ExecuteSqlRawAsync($@"
            INSERT INTO ""RTSGrid_Row"" (""GridId"", ""RowNumber"", ""UnionId"") 
            VALUES ({gridId}, 1, 999)
        ");

        var rowId = await beDb.Database.SqlQueryRaw<int>(
            $@"SELECT MAX(""RowId"") AS ""Value"" FROM ""RTSGrid_Row"" WHERE ""GridId"" = {gridId}"
        ).FirstAsync();

        // Insert a Data cell (should be returned by GetDataCells)
        await beDb.Database.ExecuteSqlRawAsync($@"
            INSERT INTO ""RTSGrid_Cell"" (""RowId"", ""ColumnId"", ""CellType"", ""Value"") 
            VALUES ({rowId}, {columnId}, 'Data', 'TestMetric')
        ");

        // Insert a Statistic cell (should NOT be returned by GetDataCells)
        await beDb.Database.ExecuteSqlRawAsync($@"
            INSERT INTO ""RTSGrid_Cell"" (""RowId"", ""ColumnId"", ""CellType"", ""Value"") 
            VALUES ({rowId}, {columnId}, 'Statistic', 'StatTest')
        ");

        return gridId;
    }
}
