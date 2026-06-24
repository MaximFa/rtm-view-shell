using RTMMaintenance.ReadPlane.Contracts;

namespace RTMMaintenance.ReadPlane.Jobs;

public interface IJobManager
{
    Task<JobInfo> CreateJobAsync(CollectIncidentRequest request, CancellationToken ct = default);
    Task<JobInfo?> GetJobAsync(Guid jobId, CancellationToken ct = default);
    bool CanStartJob();
}

public record JobInfo
{
    public required Guid Id { get; init; }
    public required JobStatus Status { get; init; }
    public required DateTime CreatedAt { get; init; }
    public DateTime? CompletedAt { get; init; }
    public string? BundlePath { get; init; }
    public string? Error { get; init; }
}

public enum JobStatus { Pending, Running, Completed, Failed }
