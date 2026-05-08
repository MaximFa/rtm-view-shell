using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Commands.Configuration;

// ── Sites ────────────────────────────────────────────────────────────────────

public record SaveSiteCommand(SaveSiteRequest Request) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => Request.IsNew ? "Site.Created" : "Site.Updated";
    public object? AuditDetails => new { Name = Request.SiteName ?? Request.SiteId, Id = Request.SiteId };
}

public class SaveSiteCommandHandler(
    ISiteRepository repo,
    ICurrentUserAccessor user,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveSiteCommand, Result>
{
    public async Task<Result> Handle(SaveSiteCommand cmd, CancellationToken ct)
    {
        var req = cmd.Request;
        var tenantId = user.TenantId!.Value;

        if (req.IsNew)
        {
            var site = new Site
            {
                SiteId = req.SiteId.Trim(),
                TenantId = tenantId,
                SiteName = req.SiteName?.Trim(),
                Description = req.Description?.Trim(),
                TimeZone = req.TimeZone?.Trim(),
                ClearTime = req.ClearTime?.Trim()
            };
            await repo.AddAsync(site, ct);
        }
        else
        {
            var site = await repo.GetByIdAsync(req.SiteId, tenantId, ct);
            if (site is null) return Result.Failure("Site not found.");
            site.SiteName = req.SiteName?.Trim();
            site.Description = req.Description?.Trim();
            site.TimeZone = req.TimeZone?.Trim();
            site.ClearTime = req.ClearTime?.Trim();
            repo.Update(site);
        }

        // [API-HOOK] Notify CC-platform of configuration change.
        await apiHook.NotifyAsync("Site", new { req.SiteId, tenantId }, ct);

        return Result.Success();
    }
}

public record DeleteSiteCommand(string SiteId) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "Site.Deleted";
    public object? AuditDetails => new { Id = SiteId };
}

public class DeleteSiteCommandHandler(ISiteRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<DeleteSiteCommand, Result>
{
    public async Task<Result> Handle(DeleteSiteCommand cmd, CancellationToken ct)
    {
        var site = await repo.GetByIdAsync(cmd.SiteId, user.TenantId!.Value, ct);
        if (site is null) return Result.Failure("Site not found.");
        repo.Delete(site);
        return Result.Success();
    }
}

// ── Business Units ───────────────────────────────────────────────────────────

public record SaveBusinessUnitCommand(SaveBusinessUnitRequest Request) : IRequest<Result<int>>, ITransactional, IAuditable
{
    public string AuditEventType => Request.BusinessUnitId is null ? "BusinessUnit.Created" : "BusinessUnit.Updated";
    public object? AuditDetails => new { Name = Request.BusinessUnitName };
}

public class SaveBusinessUnitCommandHandler(
    IBusinessUnitRepository repo,
    ICurrentUserAccessor user,
    IDateTimeProvider clock,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveBusinessUnitCommand, Result<int>>
{
    public async Task<Result<int>> Handle(SaveBusinessUnitCommand cmd, CancellationToken ct)
    {
        var req = cmd.Request;
        var tenantId = user.TenantId!.Value;
        var now = clock.UtcNow;
        var createdBy = user.UserName ?? "system";

        BusinessUnit? bu;
        if (req.BusinessUnitId is null)
        {
            bu = new BusinessUnit
            {
                TenantId = tenantId,
                CreatedDatetime = now,
                CreatedBy = createdBy
            };
            await repo.AddAsync(bu, ct);
        }
        else
        {
            bu = await repo.GetByIdAsync(req.BusinessUnitId.Value, tenantId, ct);
            if (bu is null) return Result.Failure<int>("Business Unit not found.");
        }

        bu.BusinessUnitName = req.BusinessUnitName?.Trim();
        bu.Description = req.Description?.Trim();
        bu.SiteId = req.SiteId;

        // Replace queue assignments
        bu.QueueAssignments.Clear();
        foreach (var qid in req.QueueIds)
            bu.QueueAssignments.Add(new BusinessUnitQueue
            {
                BusinessUnitId = bu.BusinessUnitId,
                QueueId = qid,
                TenantId = tenantId,
                CreatedDatetime = now,
                CreatedBy = createdBy
            });

        // Replace supergroup assignments
        bu.SupergroupAssignments.Clear();
        foreach (var sgid in req.SupergroupIds)
            bu.SupergroupAssignments.Add(new BusinessUnitSupergroup
            {
                BusinessUnitId = bu.BusinessUnitId,
                SupergroupId = sgid,
                TenantId = tenantId,
                CreatedDatetime = now,
                CreatedBy = createdBy
            });

        if (req.BusinessUnitId is not null) repo.Update(bu);

        // [API-HOOK] Notify CC-platform of configuration change.
        await apiHook.NotifyAsync("BusinessUnit", new { bu.BusinessUnitId, tenantId }, ct);

        return Result<int>.Success(bu.BusinessUnitId);
    }
}

public record DeleteBusinessUnitCommand(int BusinessUnitId) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "BusinessUnit.Deleted";
    public object? AuditDetails => new { Id = BusinessUnitId };
}

public class DeleteBusinessUnitCommandHandler(IBusinessUnitRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<DeleteBusinessUnitCommand, Result>
{
    public async Task<Result> Handle(DeleteBusinessUnitCommand cmd, CancellationToken ct)
    {
        var bu = await repo.GetByIdAsync(cmd.BusinessUnitId, user.TenantId!.Value, ct);
        if (bu is null) return Result.Failure("Business Unit not found.");
        repo.Delete(bu);
        return Result.Success();
    }
}

// ── Supergroups ──────────────────────────────────────────────────────────────

public record SaveSupergroupCommand(SaveSupergroupRequest Request) : IRequest<Result<int>>, ITransactional, IAuditable
{
    public string AuditEventType => Request.SupergroupId is null ? "Supergroup.Created" : "Supergroup.Updated";
    public object? AuditDetails => new { Name = Request.SupergroupName };
}

public class SaveSupergroupCommandHandler(
    ISupergroupRepository repo,
    ICurrentUserAccessor user,
    IDateTimeProvider clock,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveSupergroupCommand, Result<int>>
{
    public async Task<Result<int>> Handle(SaveSupergroupCommand cmd, CancellationToken ct)
    {
        var req = cmd.Request;
        var tenantId = user.TenantId!.Value;
        var now = clock.UtcNow;
        var createdBy = user.UserName ?? "system";

        Supergroup? sg;
        if (req.SupergroupId is null)
        {
            sg = new Supergroup
            {
                TenantId = tenantId,
                CreatedDatetime = now,
                CreatedBy = createdBy
            };
            await repo.AddAsync(sg, ct);
        }
        else
        {
            sg = await repo.GetByIdAsync(req.SupergroupId.Value, tenantId, ct);
            if (sg is null) return Result.Failure<int>("Supergroup not found.");
        }

        sg.SupergroupName = req.SupergroupName?.Trim();
        sg.Description = req.Description?.Trim();

        // Replace agent group assignments
        sg.AgentGroupAssignments.Clear();
        foreach (var agid in req.AgentGroupIds)
            sg.AgentGroupAssignments.Add(new SupergroupAgentGroup
            {
                SupergroupId = sg.SupergroupId,
                AgentGroupId = agid,
                TenantId = tenantId,
                CreatedDatetime = now,
                CreatedBy = createdBy
            });

        if (req.SupergroupId is not null) repo.Update(sg);

        // [API-HOOK] Notify CC-platform of configuration change.
        await apiHook.NotifyAsync("Supergroup", new { sg.SupergroupId, tenantId }, ct);

        return Result<int>.Success(sg.SupergroupId);
    }
}

public record DeleteSupergroupCommand(int SupergroupId) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "Supergroup.Deleted";
    public object? AuditDetails => new { Id = SupergroupId };
}

public class DeleteSupergroupCommandHandler(ISupergroupRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<DeleteSupergroupCommand, Result>
{
    public async Task<Result> Handle(DeleteSupergroupCommand cmd, CancellationToken ct)
    {
        var sg = await repo.GetByIdAsync(cmd.SupergroupId, user.TenantId!.Value, ct);
        if (sg is null) return Result.Failure("Supergroup not found.");
        repo.Delete(sg);
        return Result.Success();
    }
}

// ── Metrics ──────────────────────────────────────────────────────────────────

public record SaveRtsGridMetricCommand(SaveRtsGridMetricRequest Request) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => Request.IsNew ? "RtsGridMetric.Created" : "RtsGridMetric.Updated";
    public object? AuditDetails => new { Name = Request.MetricId };
}

public class SaveRtsGridMetricCommandHandler(
    IRtsGridMetricRepository repo,
    IConfigurationApiHook apiHook)
    : IRequestHandler<SaveRtsGridMetricCommand, Result>
{
    public async Task<Result> Handle(SaveRtsGridMetricCommand cmd, CancellationToken ct)
    {
        var req = cmd.Request;

        if (req.IsNew)
        {
            var existing = await repo.GetByIdAsync(req.MetricId, ct);
            if (existing is not null) return Result.Failure($"Metric '{req.MetricId}' already exists.");

            await repo.AddAsync(new RtsGridMetric
            {
                MetricId = req.MetricId.Trim(),
                Description = req.Description?.Trim(),
                DataType = req.DataType.Trim(),
                MetricFunction = req.MetricFunction.Trim(),
                MetricParameter = req.MetricParameter.Trim(),
                MetricFormat = req.MetricFormat?.Trim(),
                DefaultValue = req.DefaultValue?.Trim()
            }, ct);
        }
        else
        {
            var metric = await repo.GetByIdAsync(req.MetricId, ct);
            if (metric is null) return Result.Failure("Metric not found.");
            metric.Description = req.Description?.Trim();
            metric.DataType = req.DataType.Trim();
            metric.MetricFunction = req.MetricFunction.Trim();
            metric.MetricParameter = req.MetricParameter.Trim();
            metric.MetricFormat = req.MetricFormat?.Trim();
            metric.DefaultValue = req.DefaultValue?.Trim();
            repo.Update(metric);
        }

        // [API-HOOK] Notify CC-platform of configuration change.
        await apiHook.NotifyAsync("RtsGridMetric", new { req.MetricId }, ct);

        return Result.Success();
    }
}

public record DeleteRtsGridMetricCommand(string MetricId) : IRequest<Result>, ITransactional, IAuditable
{
    public string AuditEventType => "RtsGridMetric.Deleted";
    public object? AuditDetails => new { Id = MetricId };
}

public class DeleteRtsGridMetricCommandHandler(IRtsGridMetricRepository repo)
    : IRequestHandler<DeleteRtsGridMetricCommand, Result>
{
    public async Task<Result> Handle(DeleteRtsGridMetricCommand cmd, CancellationToken ct)
    {
        var metric = await repo.GetByIdAsync(cmd.MetricId, ct);
        if (metric is null) return Result.Failure("Metric not found.");
        repo.Delete(metric);
        return Result.Success();
    }
}
