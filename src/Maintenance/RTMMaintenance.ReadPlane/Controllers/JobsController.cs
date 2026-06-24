using Microsoft.AspNetCore.Mvc;
using RTMMaintenance.ReadPlane.Jobs;

namespace RTMMaintenance.ReadPlane.Controllers;

[ApiController]
[Route("[controller]")]
public class JobsController : ControllerBase
{
    private readonly IJobManager _jobManager;

    public JobsController(IJobManager jobManager) => _jobManager = jobManager;

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetJob(Guid id, CancellationToken ct)
    {
        var job = await _jobManager.GetJobAsync(id, ct);
        if (job == null) return NotFound(new { error = $"Job {id} not found" });
        return Ok(new { jobId = job.Id, status = job.Status.ToString(), createdAt = job.CreatedAt, completedAt = job.CompletedAt, bundlePath = job.BundlePath, error = job.Error });
    }
}
