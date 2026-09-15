using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record DeleteQueueGridRtsCommand(int GridId) : IRequest<bool>;

public class DeleteQueueGridRtsCommandHandler(
    IRtsRepository rtsRepository,
    IConfigurationApiHook apiHook)
    : IRequestHandler<DeleteQueueGridRtsCommand, bool>
{
    public async Task<bool> Handle(DeleteQueueGridRtsCommand cmd, CancellationToken ct)
    {
        if (cmd.GridId == 0) return false;

        // No FK between the RTSGrid_* tables: nothing cascades here. DeleteQueueGridAsync
        // removes cells, then columns, then rows, then the grid - explicitly, in that order.
        await rtsRepository.DeleteQueueGridAsync(cmd.GridId, ct);

        // API hook placeholder
        // TODO: replace NoOp with real REST or SignalR call to CC platform — TBD
        await apiHook.NotifyAsync("QueueGridRts.Deleted", new { GridId = cmd.GridId }, ct);

        return true;
    }
}
