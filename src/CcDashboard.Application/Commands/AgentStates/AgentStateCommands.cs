using CcDashboard.Application.Behaviors;
using MediatR;

namespace CcDashboard.Application.Commands.AgentStates;

public enum DeactivateGroupAction { ReassignStates, DeactivateAllStates }

public record CreateAgentStateGroupCommand(string GroupName, Guid? TenantId = null)
    : IRequest<Guid>, ITransactional;

public record UpdateAgentStateGroupCommand(Guid GroupId, string GroupName)
    : IRequest<bool>, ITransactional;

public record DeactivateAgentStateGroupCommand(
    Guid GroupId,
    DeactivateGroupAction Action,
    Guid? ReassignToGroupId = null)
    : IRequest<bool>, ITransactional;

public record CreateAgentStateCommand(string AgentStateName, Guid GroupId, Guid? TenantId = null)
    : IRequest<Guid>, ITransactional;

public record UpdateAgentStateCommand(Guid StateId, Guid GroupId)
    : IRequest<bool>, ITransactional;

public record DeactivateAgentStateCommand(Guid StateId)
    : IRequest<bool>, ITransactional;
