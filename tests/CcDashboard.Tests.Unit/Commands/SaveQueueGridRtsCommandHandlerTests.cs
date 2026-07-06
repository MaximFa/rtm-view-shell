using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class SaveQueueGridRtsCommandHandlerTests
{
    private readonly IRtsRepository _repo = Substitute.For<IRtsRepository>();
    private readonly IConfigurationApiHook _hook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveQueueGridRtsCommandHandler _handler;

    public SaveQueueGridRtsCommandHandlerTests()
    {
        // Stub repo methods that return collections (to avoid NRE when handler iterates)
        _repo.GetQueueGridColumnIdsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<int>());
        _repo.GetQueueGridRowIdsAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new List<int>());
        _repo.InsertQueueGridRowAsync(Arg.Any<int>(), Arg.Any<int>(), Arg.Any<int?>(), Arg.Any<CancellationToken>())
            .Returns(1);

        _handler = new SaveQueueGridRtsCommandHandler(_repo, _hook);
    }

    private static SaveQueueGridRtsCommand Cmd(int? gridId) => new(
        gridId, null, "Grid X",
        new List<QueueGridColumnInput>(),
        new List<QueueGridRowInput>(),
        new Dictionary<string, int?>());

    [Fact]
    public async Task Handle_StaleGridId_GridMissing_RecreatesGrid()
    {
        _repo.QueueGridExistsAsync(999, Arg.Any<CancellationToken>()).Returns(false);
        _repo.InsertQueueGridAsync("Grid X", Arg.Any<CancellationToken>()).Returns(555);

        var result = await _handler.Handle(Cmd(999), CancellationToken.None);

        await _repo.Received(1).InsertQueueGridAsync("Grid X", Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().UpdateQueueGridAsync(Arg.Any<int>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
        result.GridId.Should().Be(555);
    }

    [Fact]
    public async Task Handle_ExistingGrid_UpdatesInPlace()
    {
        _repo.QueueGridExistsAsync(33, Arg.Any<CancellationToken>()).Returns(true);

        var result = await _handler.Handle(Cmd(33), CancellationToken.None);

        await _repo.Received(1).UpdateQueueGridAsync(33, "Grid X", Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().InsertQueueGridAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
        result.GridId.Should().Be(33);
    }
}
