using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Behaviors;

public class TransactionBehavior<TRequest, TResponse>(IUnitOfWork uow)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : ITransactional
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var response = await next();
        await uow.SaveChangesAsync(ct);
        return response;
    }
}

public interface ITransactional;
