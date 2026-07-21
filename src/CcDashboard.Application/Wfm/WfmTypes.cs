namespace CcDashboard.Application.Wfm;

/// <summary>Sentinel values for WFM metrics when computation is not possible.</summary>
public enum WfmSentinel
{
    None = 0,
    SystemOverloaded,  // N <= A (Erlang C undefined, queue diverges)
    NoData,            // Missing input (AHT=0, no agents, no interactions)
    Capped             // RequiredAgents search hit the cap without meeting target
}

/// <summary>Result of a WFM metric computation.</summary>
public sealed record WfmMetricResult(
    double? Value,
    WfmSentinel Sentinel = WfmSentinel.None,
    string? FormattedValue = null);

/// <summary>Snapshot of all WFM metrics for a (tenant, queue) at a point in time.</summary>
public sealed record WfmSnapshot(
    Guid TenantId,
    string QueueId,
    DateTime ComputedAt,
    WfmMetricResult TrafficIntensity,
    WfmMetricResult ErlangPwait,
    WfmMetricResult PredictedSl,
    WfmMetricResult PredictedAsa,
    WfmMetricResult RequiredAgents,
    WfmMetricResult ErlangB,
    WfmMetricResult StaffVariance,
    WfmMetricResult OccupancyErl,
    WfmMetricResult UnderstaffPct);
