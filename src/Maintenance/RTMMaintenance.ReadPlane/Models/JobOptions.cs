namespace RTMMaintenance.ReadPlane.Models;

/// <summary>
/// Configuration for async diagnostic jobs.
/// </summary>
public class JobOptions
{
    /// <summary>
    /// Maximum concurrent jobs (job-lock, mirrors commit.lock discipline — design-review C2).
    /// </summary>
    public int MaxConcurrentJobs { get; set; } = 1;

    /// <summary>
    /// Maximum allowed time span for incident collection (capped per SF-MS-003).
    /// </summary>
    public int MaxTimeSpanDays { get; set; } = 7;

    /// <summary>
    /// Output directory for bundles (per §43 ops layout).
    /// </summary>
    public string OutputDirectory { get; set; } = @"C:\RTMView-Ops\output";

    /// <summary>
    /// Retention period for bundles before purge (SF-MS-002).
    /// </summary>
    public int RetentionDays { get; set; } = 30;
}
