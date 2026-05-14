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

        // CASCADE DELETE handles columns, rows, and cells automatically
        await rtsRepository.DeleteQueueGridAsync(cmd.GridId, ct);

        await apiHook.NotifyAsync("QueueGridRts.Deleted", new { GridId = cmd.GridId }, ct);

        return true;
    }
}
