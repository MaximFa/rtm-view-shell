using Microsoft.AspNetCore.Mvc;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Jobs;

namespace RTMMaintenance.ReadPlane.Controllers;

[ApiController]
[Route("[controller]")]
public class CollectController : ControllerBase
{
    private readonly ISignalValidator _validator;
    private readonly IJobManager _jobManager;
    private readonly ILogger<CollectController> _logger;

    public CollectController(ISignalValidator validator, IJobManager jobManager, ILogger<CollectController> logger)
    {
        _validator = validator;
        _jobManager = jobManager;
        _logger = logger;
    }

    [HttpPost("incident")]
    public async Task<IActionResult> CollectIncident([FromBody] CollectIncidentRequest request, CancellationToken ct)
    {
        _logger.LogInformation("Collect incident: {Since} to {Until}, signals: {Signals}", request.Since, request.Until, request.Signals);

        var validation = _validator.Validate(request);
        if (!validation.IsValid) return BadRequest(new { error = validation.ErrorMessage });
        if (!_jobManager.CanStartJob()) return Conflict(new { error = "A job is already running." });

        try
        {
            var job = await _jobManager.CreateJobAsync(request, ct);
            return Accepted(new { jobId = job.Id, status = job.Status.ToString(), createdAt = job.CreatedAt, pollUrl = $"/jobs/{job.Id}" });
        }
        catch (ArgumentException ex) { return BadRequest(new { error = ex.Message }); }
        catch (InvalidOperationException ex) { return Conflict(new { error = ex.Message }); }
    }
}
