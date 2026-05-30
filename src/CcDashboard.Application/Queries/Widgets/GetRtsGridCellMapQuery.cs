using CcDashboard.Application.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Widgets;

public record GetRtsGridCellMapQuery(int GridId) : IRequest<Dictionary<int, string>>;

public class GetRtsGridCellMapQueryHandler(IRtsRepository rts)
    : IRequestHandler<GetRtsGridCellMapQuery, Dictionary<int, string>>
{
    public Task<Dictionary<int, string>> Handle(GetRtsGridCellMapQuery q, CancellationToken ct)
        => rts.GetCellMapForGridAsync(q.GridId, ct);
}
