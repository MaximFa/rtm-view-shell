using CcDashboard.Application.Commands.AgentStates;
using CcDashboard.Application.Queries.AgentStates;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Infrastructure.Handlers;

#region Query Handlers

public class GetAgentStateDefinitionsQueryHandler(
    AppDbContext db,
    BackendEmulationDbContext beDb,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAgentStateDefinitionsQuery, IReadOnlyList<AgentStateDefinitionDto>>
{
    public async Task<IReadOnlyList<AgentStateDefinitionDto>> Handle(
        GetAgentStateDefinitionsQuery query, CancellationToken ct)
    {
        var tenantId = query.TenantId ?? currentUser.TenantId!.Value;

        var definitions = await db.AgentStateDefinitions
            .IgnoreQueryFilters()
            .Where(d => d.TenantId == tenantId && d.IsActive)
            .Join(db.AgentStates.IgnoreQueryFilters().Where(s => s.IsActive),
                d => d.AgentStateId, s => s.Id,
                (d, s) => new { d, s })
            .Join(db.AgentStateGroups.IgnoreQueryFilters().Where(g => g.IsActive),
                x => x.d.AgentStateGroupId, g => g.Id,
                (x, g) => new { x.d, x.s, g })
            .Select(x => new
            {
                StateId = x.s.Id,
                AgentState = x.s.AgentStateName,
                GroupId = x.g.Id,
                GroupName = x.g.GroupName
            })
            .OrderBy(x => x.GroupName)
            .ThenBy(x => x.AgentState)
            .ToListAsync(ct);

        // UsersInStatusGroupCount metrics have MetricType = "Data" (not "Agent").
        // Multiple metrics may share the same MetricParameter → GroupBy avoids duplicate-key exception.
        var metricRows = await beDb.RtsGridMetrics
            .Where(m => m.MetricFunction == "UsersInStatusGroupCount"
                     && m.MetricParameter != null && m.MetricParameter != "")
            .Select(m => new { m.MetricParameter, m.MetricId })
            .ToListAsync(ct);

        var metricLookup = metricRows
            .GroupBy(m => m.MetricParameter!)
            .ToDictionary(g => g.Key, g => g.First().MetricId);

        // MetricId lookup uses GroupName (CC platform code e.g. "AVAILABLE"), not AgentState display name
        return definitions.Select(d => new AgentStateDefinitionDto(
            d.StateId,
            d.AgentState,
            d.GroupId,
            d.GroupName,
            metricLookup.TryGetValue(d.GroupName, out var metricId) ? metricId : null
        )).ToList();
    }
}

public class GetAgentStateGroupsQueryHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAgentStateGroupsQuery, IReadOnlyList<AgentStateGroupDto>>
{
    public async Task<IReadOnlyList<AgentStateGroupDto>> Handle(
        GetAgentStateGroupsQuery query, CancellationToken ct)
    {
        var tenantId = query.TenantId ?? currentUser.TenantId!.Value;

        // Step 1 — fetch groups (no navigation property access)
        var groups = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .Where(g => g.TenantId == tenantId)
            .OrderBy(g => g.GroupName)
            .ToListAsync(ct);

        // Step 2 — fetch active definition counts per group
        var groupIds = groups.Select(g => g.Id).ToList();
        var counts = await db.AgentStateDefinitions
            .IgnoreQueryFilters()
            .Where(d => d.TenantId == tenantId && groupIds.Contains(d.AgentStateGroupId) && d.IsActive)
            .GroupBy(d => d.AgentStateGroupId)
            .Select(g => new { GroupId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.GroupId, x => x.Count, ct);

        // Step 3 — project in memory (no EF translation needed)
        return groups
            .Select(g => new AgentStateGroupDto(
                g.Id,
                g.GroupName,
                g.IsActive,
                counts.GetValueOrDefault(g.Id, 0)))
            .ToList();
    }
}

public class GetAgentStatesQueryHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAgentStatesQuery, IReadOnlyList<AgentStateDto>>
{
    public async Task<IReadOnlyList<AgentStateDto>> Handle(
        GetAgentStatesQuery query, CancellationToken ct)
    {
        var tenantId = query.TenantId ?? currentUser.TenantId!.Value;

        return await db.AgentStates
            .IgnoreQueryFilters()
            .Where(s => s.TenantId == tenantId)
            .Join(db.AgentStateDefinitions.IgnoreQueryFilters(),
                s => s.Id, d => d.AgentStateId,
                (s, d) => new { s, d })
            .Join(db.AgentStateGroups.IgnoreQueryFilters(),
                x => x.d.AgentStateGroupId, g => g.Id,
                (x, g) => new { x.s, x.d, g })
            .OrderBy(x => x.g.GroupName)
            .ThenBy(x => x.s.AgentStateName)
            .Select(x => new AgentStateDto(
                x.s.Id,
                x.s.AgentStateName,
                x.g.Id,
                x.g.GroupName,
                x.s.IsActive))
            .ToListAsync(ct);
    }
}

#endregion

#region Command Handlers

public class CreateAgentStateGroupCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateAgentStateGroupCommand, Guid>
{
    public async Task<Guid> Handle(CreateAgentStateGroupCommand cmd, CancellationToken ct)
    {
        var tenantId = cmd.TenantId ?? currentUser.TenantId!.Value;
        var normalizedName = cmd.GroupName.Trim();

        var exists = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .AnyAsync(g => g.TenantId == tenantId &&
                          EF.Functions.ILike(g.GroupName, normalizedName), ct);

        if (exists)
            throw new InvalidOperationException($"Group '{normalizedName}' already exists");

        var group = new AgentStateGroup
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            GroupName = normalizedName,
            IsActive = true,
            CreatedAt = clock.UtcNow,
            UpdatedAt = clock.UtcNow
        };

        db.AgentStateGroups.Add(group);
        await db.SaveChangesAsync(ct);
        return group.Id;
    }
}

public class UpdateAgentStateGroupCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateAgentStateGroupCommand, bool>
{
    public async Task<bool> Handle(UpdateAgentStateGroupCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var normalizedName = cmd.GroupName.Trim();

        var group = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(g => g.Id == cmd.GroupId && g.TenantId == tenantId, ct);

        if (group is null) return false;

        var duplicate = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .AnyAsync(g => g.TenantId == tenantId &&
                          g.Id != cmd.GroupId &&
                          EF.Functions.ILike(g.GroupName, normalizedName), ct);

        if (duplicate)
            throw new InvalidOperationException($"Group '{normalizedName}' already exists");

        group.GroupName = normalizedName;
        group.UpdatedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
        return true;
    }
}

public class DeactivateAgentStateGroupCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeactivateAgentStateGroupCommand, bool>
{
    public async Task<bool> Handle(DeactivateAgentStateGroupCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;

        var group = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(g => g.Id == cmd.GroupId && g.TenantId == tenantId, ct);

        if (group is null) return false;

        var definitions = await db.AgentStateDefinitions
            .IgnoreQueryFilters()
            .Where(d => d.AgentStateGroupId == cmd.GroupId && d.IsActive)
            .ToListAsync(ct);

        var now = clock.UtcNow;

        if (cmd.Action == DeactivateGroupAction.ReassignStates)
        {
            if (cmd.ReassignToGroupId is null)
                throw new InvalidOperationException("ReassignToGroupId required for ReassignStates action");

            var targetGroup = await db.AgentStateGroups
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(g => g.Id == cmd.ReassignToGroupId && g.TenantId == tenantId && g.IsActive, ct);

            if (targetGroup is null)
                throw new InvalidOperationException("Target group not found or inactive");

            foreach (var def in definitions)
            {
                def.AgentStateGroupId = cmd.ReassignToGroupId.Value;
                def.UpdatedAt = now;
            }
        }
        else
        {
            var stateIds = definitions.Select(d => d.AgentStateId).ToList();
            var states = await db.AgentStates
                .IgnoreQueryFilters()
                .Where(s => stateIds.Contains(s.Id))
                .ToListAsync(ct);

            foreach (var def in definitions)
            {
                def.IsActive = false;
                def.UpdatedAt = now;
            }

            foreach (var state in states)
            {
                state.IsActive = false;
                state.UpdatedAt = now;
            }
        }

        group.IsActive = false;
        group.UpdatedAt = now;
        await db.SaveChangesAsync(ct);
        return true;
    }
}

public class CreateAgentStateCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateAgentStateCommand, Guid>
{
    public async Task<Guid> Handle(CreateAgentStateCommand cmd, CancellationToken ct)
    {
        var tenantId = cmd.TenantId ?? currentUser.TenantId!.Value;
        var normalizedName = cmd.AgentStateName.Trim();

        var exists = await db.AgentStates
            .IgnoreQueryFilters()
            .AnyAsync(s => s.TenantId == tenantId &&
                          EF.Functions.ILike(s.AgentStateName, normalizedName), ct);

        if (exists)
            throw new InvalidOperationException($"State '{normalizedName}' already exists");

        var group = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(g => g.Id == cmd.GroupId && g.TenantId == tenantId && g.IsActive, ct);

        if (group is null)
            throw new InvalidOperationException("Target group not found or inactive");

        var now = clock.UtcNow;

        var state = new AgentState
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            AgentStateName = normalizedName,
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now
        };

        var definition = new AgentStateDefinition
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            AgentStateId = state.Id,
            AgentStateGroupId = cmd.GroupId,
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now
        };

        db.AgentStates.Add(state);
        db.AgentStateDefinitions.Add(definition);
        await db.SaveChangesAsync(ct);
        return state.Id;
    }
}

public class UpdateAgentStateCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateAgentStateCommand, bool>
{
    public async Task<bool> Handle(UpdateAgentStateCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;

        var definition = await db.AgentStateDefinitions
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(d => d.AgentStateId == cmd.StateId && d.TenantId == tenantId, ct);

        if (definition is null) return false;

        var group = await db.AgentStateGroups
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(g => g.Id == cmd.GroupId && g.TenantId == tenantId && g.IsActive, ct);

        if (group is null)
            throw new InvalidOperationException("Target group not found or inactive");

        definition.AgentStateGroupId = cmd.GroupId;
        definition.UpdatedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
        return true;
    }
}

public class DeactivateAgentStateCommandHandler(
    AppDbContext db,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<DeactivateAgentStateCommand, bool>
{
    public async Task<bool> Handle(DeactivateAgentStateCommand cmd, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var now = clock.UtcNow;

        var state = await db.AgentStates
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.Id == cmd.StateId && s.TenantId == tenantId, ct);

        if (state is null) return false;

        var definition = await db.AgentStateDefinitions
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(d => d.AgentStateId == cmd.StateId && d.TenantId == tenantId, ct);

        state.IsActive = false;
        state.UpdatedAt = now;

        if (definition is not null)
        {
            definition.IsActive = false;
            definition.UpdatedAt = now;
        }

        await db.SaveChangesAsync(ct);
        return true;
    }
}

#endregion
