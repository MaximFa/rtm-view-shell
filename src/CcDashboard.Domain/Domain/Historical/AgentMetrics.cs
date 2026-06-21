namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// Computed metrics for agent intervals (not stored, calculated at query time).
/// All formulas use NULLIF guards to avoid division by zero.
/// </summary>
public record AgentMetrics
{
    public long SumAvailableMs { get; init; }
    public long SumOnphoneMs { get; init; }
    public long SumHoldMs { get; init; }
    public long SumPaperworkMs { get; init; }
    public long SumBreakMs { get; init; }
    public long SumTrainingMs { get; init; }
    public long SumUnavailableMs { get; init; }
    public long SumLoggedInMs { get; init; }
    public int Handled { get; init; }

    /// <summary>Occupancy % = (OnPhone + Paperwork) * 100.0 / NULLIF(Available + OnPhone + Paperwork, 0)</summary>
    public double? OccupancyPct
    {
        get
        {
            var denom = SumAvailableMs + SumOnphoneMs + SumPaperworkMs;
            return denom == 0 ? null : (SumOnphoneMs + SumPaperworkMs) * 100.0 / denom;
        }
    }

    /// <summary>Agent AHT = (OnPhone + Paperwork) / 1000 / NULLIF(Handled, 0) (FULL: talk+hold+acw)</summary>
    public double? AgentAht => Handled == 0 ? null : (SumOnphoneMs + SumPaperworkMs) / 1000.0 / Handled;

    /// <summary>Hold % = HoldMs * 100.0 / NULLIF(OnPhoneMs, 0)</summary>
    public double? HoldPct => SumOnphoneMs == 0 ? null : SumHoldMs * 100.0 / SumOnphoneMs;

    /// <summary>Pure talk time = OnPhone - Hold (ms)</summary>
    public long TalkPureMs => SumOnphoneMs - SumHoldMs;
}
