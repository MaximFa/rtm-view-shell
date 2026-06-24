using System.Collections.Concurrent;
using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Jobs;

public class JobManager : IJobManager
{
    private readonly ConcurrentDictionary<Guid, JobInfo> _jobs = new();
    private readonly SemaphoreSlim _jobLock;
    private readonly ISignalValidator _validator;
    private readonly ISignalCollector _collector;
    private readonly JobOptions _options;
    private readonly ILogger<JobManager> _logger;

    public JobManager(ISignalValidator validator, ISignalCollector collector, IOptions<JobOptions> options, ILogger<JobManager> logger)
    {
        _validator = validator;
        _collector = collector;
        _options = options.Value;
        _logger = logger;
        _jobLock = new SemaphoreSlim(_options.MaxConcurrentJobs, _options.MaxConcurrentJobs);
    }

    public Task<JobInfo> CreateJobAsync(CollectIncidentRequest request, CancellationToken ct = default)
    {
        var validation = _validator.Validate(request);
        if (!validation.IsValid) throw new ArgumentException(validation.ErrorMessage);
        if (!_jobLock.Wait(0)) throw new InvalidOperationException("A job is already running.");

        var jobId = Guid.NewGuid();
        var jobInfo = new JobInfo { Id = jobId, Status = JobStatus.Pending, CreatedAt = DateTime.UtcNow };
        _jobs[jobId] = jobInfo;

        _ = Task.Run(async () =>
        {
            try
            {
                _jobs[jobId] = jobInfo with { Status = JobStatus.Running };
                var result = await _collector.CollectAsync(request, _options.OutputDirectory, ct);
                _jobs[jobId] = jobInfo with
                {
                    Status = result.Success ? JobStatus.Completed : JobStatus.Failed,
                    CompletedAt = DateTime.UtcNow,
                    BundlePath = result.BundlePath,
                    Error = result.Error
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Job {JobId} failed", jobId);
                _jobs[jobId] = jobInfo with { Status = JobStatus.Failed, CompletedAt = DateTime.UtcNow, Error = ex.Message };
            }
            finally { _jobLock.Release(); }
        }, ct);

        return Task.FromResult(jobInfo);
    }

    public Task<JobInfo?> GetJobAsync(Guid jobId, CancellationToken ct = default)
    {
        _jobs.TryGetValue(jobId, out var job);
        return Task.FromResult(job);
    }

    public bool CanStartJob() => _jobLock.CurrentCount > 0;
}
