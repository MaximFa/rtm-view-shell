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

// ─── WFM Snapshot contract (spec §4) ────────────────────────────────────────

/// <summary>Input values used for WFM calculations.</summary>
public sealed record WfmInputs(
    double LambdaPerHour,
    double AhtSec,
    int NActual,
    bool WrapIncluded);

/// <summary>Erlang-derived metrics from the calculator.</summary>
public sealed record WfmErlang(
    double TrafficA,
    double? PWaitC,
    double? PredictedSlPct,
    double? PredictedAsaSec,
    int RequiredAgents,
    bool RequiredCapped,
    double ErlangBPct,
    double? OccupancyPct,
    double? UnderstaffPct,
    int StaffVariance);

/// <summary>
/// Snapshot of all WFM metrics for a (tenant, queue) at a point in time.
/// Written by the WFM hosted loop (B1), read by Shell widgets.
/// </summary>
public sealed record WfmSnapshot(
    Guid TenantId,
    string QueueId,
    DateTime AsOfUtc,
    int WindowMin,
    WfmInputs Inputs,
    WfmErlang Erlang,
    string State,
    IReadOnlyDictionary<string, string> Rag)
{
    /// <summary>Queue is operating normally.</summary>
    public const string StateOk = "ok";
    /// <summary>N <= A — system overloaded (Erlang C undefined).</summary>
    public const string StateOverloaded = "overloaded";
    /// <summary>Missing input data (no calls, no agents, AHT=0).</summary>
    public const string StateNoData = "nodata";
}
