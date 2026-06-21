namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// Computed metrics for queue intervals (not stored, calculated at query time).
/// All formulas use NULLIF guards to avoid division by zero.
/// </summary>
public record QueueMetrics
{
    public int Offered { get; init; }
    public int Answered { get; init; }
    public int Abandoned { get; init; }
    public int AnsweredInSl { get; init; }
    public long SumWaitAnswered { get; init; }
    public long SumTalk { get; init; }

    /// <summary>Abandon % = Abandoned * 100.0 / NULLIF(Offered, 0)</summary>
    public double? AbandonPct => Offered == 0 ? null : Abandoned * 100.0 / Offered;

    /// <summary>SL % = AnsweredInSl * 100.0 / NULLIF(Answered, 0)</summary>
    public double? SlPct => Answered == 0 ? null : AnsweredInSl * 100.0 / Answered;

    /// <summary>ASA = AvgWait = SumWaitAnswered / NULLIF(Answered, 0) (in seconds)</summary>
    public double? Asa => Answered == 0 ? null : (double)SumWaitAnswered / Answered;

    /// <summary>Queue AHT = SumTalk / NULLIF(Answered, 0) (Talk-only, labelled)</summary>
    public double? QueueAht => Answered == 0 ? null : (double)SumTalk / Answered;
}
