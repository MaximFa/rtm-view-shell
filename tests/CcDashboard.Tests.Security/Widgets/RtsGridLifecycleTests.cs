using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Tests for RTS Grid lifecycle (DoD-5) and API hook calls (DoD-6).
/// Uses BeDb (BackendEmulationDbContext) for seeding and assertion per MC-T5-2.
/// </summary>
[Collection("Postgres")]
public class RtsGridLifecycleTests(PostgresFixture postgres)
{
    // ── DoD-5: SaveAgentGridRts ──────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveAgentGridRts_NewGrid_InsertsGridAndColumnsSet()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);

        var handler = new SaveAgentGridRtsCommandHandler(repo, apiHook);
        var command = new SaveAgentGridRtsCommand(
            GridId: 0,
            ColumnsSetId: null,
            WidgetName: "Test Agent Grid",
            BusinessUnitId: 1,
            RowsFilter: "active=1",
            Columns: [
                new RtsColumnInput(null, "Agent Name", "agent_name", 1),
                new RtsColumnInput(null, "Status", "agent_status", 2)
            ]);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.GridId.Should().BeGreaterThan(0);
        result.ColumnsSetId.Should().BeGreaterThan(0);
        result.SavedColumns.Should().HaveCount(2);

        // Verify in BeDb
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsUserGridGrids.FirstOrDefaultAsync(g => g.GridId == result.GridId);
        grid.Should().NotBeNull();
        grid!.Title.Should().Be("Test Agent Grid");

        var columnsSet = await beDb.RtsUserGridColumnsSets.FirstOrDefaultAsync(cs => cs.ColumnsSetId == result.ColumnsSetId);
        columnsSet.Should().NotBeNull();

        var columns = await beDb.RtsUserGridColumns.Where(c => c.ColumnsSetId == result.ColumnsSetId).ToListAsync();
        columns.Should().HaveCount(2);
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveAgentGridRts_UpdateGrid_UpdatesFieldsAndColumns()
    {
        // Arrange: Create initial grid
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveAgentGridRtsCommandHandler(repo, apiHook);

        var createCommand = new SaveAgentGridRtsCommand(
            GridId: 0, ColumnsSetId: null, WidgetName: "Initial Grid", BusinessUnitId: 1, RowsFilter: null,
            Columns: [new RtsColumnInput(null, "Col1", "metric1", 1)]);
        var createResult = await handler.Handle(createCommand, CancellationToken.None);

        // Act: Update with new name and column
        var updateCommand = new SaveAgentGridRtsCommand(
            GridId: createResult.GridId,
            ColumnsSetId: createResult.ColumnsSetId,
            WidgetName: "Updated Grid",
            BusinessUnitId: 2,
            RowsFilter: "new_filter",
            Columns: [
                new RtsColumnInput(createResult.SavedColumns[0].DbColumnId, "Col1-Updated", "metric1_updated", 1),
                new RtsColumnInput(null, "Col2-New", "metric2", 2)
            ]);

        var updateResult = await handler.Handle(updateCommand, CancellationToken.None);

        // Assert
        updateResult.GridId.Should().Be(createResult.GridId);
        updateResult.SavedColumns.Should().HaveCount(2);

        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsUserGridGrids.FirstOrDefaultAsync(g => g.GridId == updateResult.GridId);
        grid!.Title.Should().Be("Updated Grid");
        grid.UnionId.Should().Be(2);
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveAgentGridRts_RemoveColumn_DeletesFromDb()
    {
        // Arrange: Create grid with 2 columns
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveAgentGridRtsCommandHandler(repo, apiHook);

        var createCommand = new SaveAgentGridRtsCommand(
            GridId: 0, ColumnsSetId: null, WidgetName: "Grid with 2 cols", BusinessUnitId: null, RowsFilter: null,
            Columns: [
                new RtsColumnInput(null, "Keep", "keep_metric", 1),
                new RtsColumnInput(null, "Remove", "remove_metric", 2)
            ]);
        var createResult = await handler.Handle(createCommand, CancellationToken.None);
        var removeColumnId = createResult.SavedColumns[1].DbColumnId;

        // Act: Update with only 1 column (remove the second)
        var updateCommand = new SaveAgentGridRtsCommand(
            GridId: createResult.GridId,
            ColumnsSetId: createResult.ColumnsSetId,
            WidgetName: "Grid with 1 col",
            BusinessUnitId: null,
            RowsFilter: null,
            Columns: [new RtsColumnInput(createResult.SavedColumns[0].DbColumnId, "Keep", "keep_metric", 1)]);

        await handler.Handle(updateCommand, CancellationToken.None);

        // Assert: Removed column no longer exists
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var removedColumn = await beDb.RtsUserGridColumns.FirstOrDefaultAsync(c => c.ColumnId == removeColumnId);
        removedColumn.Should().BeNull();
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveAgentGridRts_AddColumn_InsertsToDb()
    {
        // Arrange: Create grid with 1 column
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveAgentGridRtsCommandHandler(repo, apiHook);

        var createCommand = new SaveAgentGridRtsCommand(
            GridId: 0, ColumnsSetId: null, WidgetName: "Single Column Grid", BusinessUnitId: null, RowsFilter: null,
            Columns: [new RtsColumnInput(null, "Initial", "initial_metric", 1)]);
        var createResult = await handler.Handle(createCommand, CancellationToken.None);

        // Act: Add a second column
        var updateCommand = new SaveAgentGridRtsCommand(
            GridId: createResult.GridId,
            ColumnsSetId: createResult.ColumnsSetId,
            WidgetName: "Two Column Grid",
            BusinessUnitId: null,
            RowsFilter: null,
            Columns: [
                new RtsColumnInput(createResult.SavedColumns[0].DbColumnId, "Initial", "initial_metric", 1),
                new RtsColumnInput(null, "Added", "added_metric", 2)
            ]);

        var updateResult = await handler.Handle(updateCommand, CancellationToken.None);

        // Assert: Two columns now exist
        updateResult.SavedColumns.Should().HaveCount(2);

        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var columns = await beDb.RtsUserGridColumns.Where(c => c.ColumnsSetId == updateResult.ColumnsSetId).ToListAsync();
        columns.Should().HaveCount(2);
        columns.Should().Contain(c => c.Title == "Added");
    }

    // ── DoD-5: SaveQueueGridRts ──────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveQueueGridRts_NewGrid_InsertsGridAndHeaderRow()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveQueueGridRtsCommandHandler(repo, apiHook);

        var command = new SaveQueueGridRtsCommand(
            GridId: null,
            HeaderRowId: null,
            Title: "Queue Grid Test",
            Columns: [
                new QueueGridColumnInput("col-1", null, "Queue Name", "queue_name", 1),
                new QueueGridColumnInput("col-2", null, "Wait Time", "wait_time", 2)
            ],
            Rows: [],
            ExistingHeaderCellIds: new Dictionary<string, int?>());

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.GridId.Should().BeGreaterThan(0);
        result.HeaderRowId.Should().BeGreaterThan(0);
        result.SavedColumnIds.Should().HaveCount(2);
        result.HeaderCellIds.Should().HaveCount(2);

        // Verify in BeDb
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsGridGrids.FirstOrDefaultAsync(g => g.GridId == result.GridId);
        grid.Should().NotBeNull();
        grid!.Title.Should().Be("Queue Grid Test");
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveQueueGridRts_UpdateGrid_UpdatesTitleAndCells()
    {
        // Arrange: Create initial grid
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveQueueGridRtsCommandHandler(repo, apiHook);

        var createCommand = new SaveQueueGridRtsCommand(
            GridId: null, HeaderRowId: null, Title: "Initial Queue",
            Columns: [new QueueGridColumnInput("c1", null, "Col1", "m1", 1)],
            Rows: [], ExistingHeaderCellIds: new Dictionary<string, int?>());
        var createResult = await handler.Handle(createCommand, CancellationToken.None);

        // Act: Update
        var updateCommand = new SaveQueueGridRtsCommand(
            GridId: createResult.GridId,
            HeaderRowId: createResult.HeaderRowId,
            Title: "Updated Queue",
            Columns: [new QueueGridColumnInput("c1", createResult.SavedColumnIds["c1"], "Col1-Updated", "m1", 1)],
            Rows: [],
            ExistingHeaderCellIds: new Dictionary<string, int?> { ["c1"] = createResult.HeaderCellIds["c1"] });
        var updateResult = await handler.Handle(updateCommand, CancellationToken.None);

        // Assert
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsGridGrids.FirstOrDefaultAsync(g => g.GridId == updateResult.GridId);
        grid!.Title.Should().Be("Updated Queue");
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task SaveQueueGridRts_AddDataRow_InsertsRowAndCells()
    {
        // Arrange: Create grid with header row
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveQueueGridRtsCommandHandler(repo, apiHook);

        var createCommand = new SaveQueueGridRtsCommand(
            GridId: null,
            HeaderRowId: null,
            Title: "Queue With Data Row",
            Columns: [new QueueGridColumnInput("c1", null, "Metric", "queue_metric", 1)],
            Rows: [],
            ExistingHeaderCellIds: new Dictionary<string, int?>());
        var createResult = await handler.Handle(createCommand, CancellationToken.None);

        // Act: Add a data row
        var updateCommand = new SaveQueueGridRtsCommand(
            GridId: createResult.GridId,
            HeaderRowId: createResult.HeaderRowId,
            Title: "Queue With Data Row",
            Columns: [new QueueGridColumnInput("c1", createResult.SavedColumnIds["c1"], "Metric", "queue_metric", 1)],
            Rows: [new QueueGridRowInput("r1", null, BusinessUnitId: 1, RowNumber: 2, CellIds: new Dictionary<string, int?>())],
            ExistingHeaderCellIds: new Dictionary<string, int?> { ["c1"] = createResult.HeaderCellIds["c1"] });

        var updateResult = await handler.Handle(updateCommand, CancellationToken.None);

        // Assert: Data row created
        updateResult.SavedRowIds.Should().ContainKey("r1");
        updateResult.SavedCellIds.Should().ContainKey("r1");
        updateResult.SavedCellIds["r1"].Should().ContainKey("c1");

        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var rows = await beDb.RtsGridRows.Where(r => r.GridId == updateResult.GridId).ToListAsync();
        rows.Should().HaveCount(2); // Header row + data row
    }

    // ── DoD-5: Delete operations ─────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task DeleteAgentGridRts_RemovesGridAndColumnsSet()
    {
        // Arrange: Create grid
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);

        var createHandler = new SaveAgentGridRtsCommandHandler(repo, apiHook);
        var createResult = await createHandler.Handle(new SaveAgentGridRtsCommand(
            0, null, "ToDelete", null, null, [new RtsColumnInput(null, "C", "m", 1)]), CancellationToken.None);

        var deleteHandler = new DeleteAgentGridRtsCommandHandler(repo, apiHook);

        // Act
        var deleted = await deleteHandler.Handle(new DeleteAgentGridRtsCommand(createResult.GridId), CancellationToken.None);

        // Assert
        deleted.Should().BeTrue();

        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsUserGridGrids.FirstOrDefaultAsync(g => g.GridId == createResult.GridId);
        grid.Should().BeNull();

        var columnsSet = await beDb.RtsUserGridColumnsSets.FirstOrDefaultAsync(cs => cs.ColumnsSetId == createResult.ColumnsSetId);
        columnsSet.Should().BeNull();
    }

    [Fact]
    [Trait("Req", "WGT-04")]
    public async Task DeleteQueueGridRts_RemovesGridAndCascades()
    {
        // Arrange: Create queue grid
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);

        var createHandler = new SaveQueueGridRtsCommandHandler(repo, apiHook);
        var createResult = await createHandler.Handle(new SaveQueueGridRtsCommand(
            null, null, "QueueToDelete",
            [new QueueGridColumnInput("c", null, "C", "m", 1)],
            [], new Dictionary<string, int?>()), CancellationToken.None);

        var deleteHandler = new DeleteQueueGridRtsCommandHandler(repo, apiHook);

        // Act
        var deleted = await deleteHandler.Handle(new DeleteQueueGridRtsCommand(createResult.GridId), CancellationToken.None);

        // Assert
        deleted.Should().BeTrue();

        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var grid = await beDb.RtsGridGrids.FirstOrDefaultAsync(g => g.GridId == createResult.GridId);
        grid.Should().BeNull();
    }

    // ── DoD-6: API hook calls ────────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task SaveAgentGridRts_CallsApiHook_WithCorrectEventType()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveAgentGridRtsCommandHandler(repo, apiHook);

        // Act
        await handler.Handle(new SaveAgentGridRtsCommand(
            0, null, "Hook Test", null, null, [new RtsColumnInput(null, "C", "m", 1)]), CancellationToken.None);

        // Assert
        await apiHook.Received(1).NotifyAsync(
            "AgentGridRts.Saved",
            Arg.Any<object>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task SaveQueueGridRts_CallsApiHook_WithCorrectEventType()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);
        var handler = new SaveQueueGridRtsCommandHandler(repo, apiHook);

        // Act
        await handler.Handle(new SaveQueueGridRtsCommand(
            null, null, "Queue Hook", [new QueueGridColumnInput("c", null, "C", "m", 1)],
            [], new Dictionary<string, int?>()), CancellationToken.None);

        // Assert
        await apiHook.Received(1).NotifyAsync(
            "QueueGridRts.Saved",
            Arg.Any<object>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task DeleteAgentGridRts_CallsApiHook_WithDeletedEvent()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);

        var createHandler = new SaveAgentGridRtsCommandHandler(repo, apiHook);
        var result = await createHandler.Handle(new SaveAgentGridRtsCommand(
            0, null, "To Delete", null, null, [new RtsColumnInput(null, "C", "m", 1)]), CancellationToken.None);

        apiHook.ClearReceivedCalls();

        var deleteHandler = new DeleteAgentGridRtsCommandHandler(repo, apiHook);

        // Act
        await deleteHandler.Handle(new DeleteAgentGridRtsCommand(result.GridId), CancellationToken.None);

        // Assert
        await apiHook.Received(1).NotifyAsync(
            "AgentGridRts.Deleted",
            Arg.Any<object>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task DeleteQueueGridRts_CallsApiHook_WithDeletedEvent()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        var db = postgres.CreateDbContext(postgres.TenantAId);
        var repo = new RtsRepository(db);

        var createHandler = new SaveQueueGridRtsCommandHandler(repo, apiHook);
        var result = await createHandler.Handle(new SaveQueueGridRtsCommand(
            null, null, "Queue Del", [new QueueGridColumnInput("c", null, "C", "m", 1)],
            [], new Dictionary<string, int?>()), CancellationToken.None);

        apiHook.ClearReceivedCalls();

        var deleteHandler = new DeleteQueueGridRtsCommandHandler(repo, apiHook);

        // Act
        await deleteHandler.Handle(new DeleteQueueGridRtsCommand(result.GridId), CancellationToken.None);

        // Assert
        await apiHook.Received(1).NotifyAsync(
            "QueueGridRts.Deleted",
            Arg.Any<object>(),
            Arg.Any<CancellationToken>());
    }
}
