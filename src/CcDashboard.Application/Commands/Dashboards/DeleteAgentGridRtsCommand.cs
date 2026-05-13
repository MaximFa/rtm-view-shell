using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Dashboards;

public record DeleteAgentGridRtsCommand(int GridId) : IRequest<bool>;

public class DeleteAgentGridRtsCommandHandler(
    IRtsRepository rtsRepository,
    IConfigurationApiHook apiHook)
    : IRequestHandler<DeleteAgentGridRtsCommand, bool>
{
    public async Task<bool> Handle(DeleteAgentGridRtsCommand cmd, CancellationToken ct)
    {
        if (cmd.GridId == 0) return false;

        // Get ColumnsSetId before deleting grid
        var columnsSetId = await rtsRepository.GetColumnsSetIdByGridIdAsync(cmd.GridId, ct);

        // Delete grid first
        await rtsRepository.DeleteGridAsync(cmd.GridId, ct);

        // Delete columns set and its columns
        if (columnsSetId.HasValue)
        {
            await rtsRepository.DeleteColumnsSetAsync(columnsSetId.Value, ct);
        }

        await apiHook.NotifyAsync("AgentGridRts.Deleted", new { GridId = cmd.GridId, ColumnsSetId = columnsSetId }, ct);

        return true;
    }
}
