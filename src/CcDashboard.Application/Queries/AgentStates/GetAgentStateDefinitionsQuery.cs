using MediatR;

namespace CcDashboard.Application.Queries.AgentStates;

public record AgentStateDefinitionDto(
    Guid StateId,
    string AgentState,
    Guid GroupId,
    string GroupName,
    string? MetricId);

public record AgentStateGroupDto(
    Guid Id,
    string GroupName,
    bool IsActive,
    int StateCount);

public record AgentStateDto(
    Guid Id,
    string AgentStateName,
    Guid GroupId,
    string GroupName,
    bool IsActive);

public record GetAgentStateDefinitionsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<AgentStateDefinitionDto>>;

public record GetAgentStateGroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<AgentStateGroupDto>>;

public record GetAgentStatesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<AgentStateDto>>;
