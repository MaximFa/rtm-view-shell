using Microsoft.AspNetCore.Mvc;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Controllers;

[ApiController]
[Route("[controller]")]
public class StatusController : ControllerBase
{
    private readonly IStatusReader _statusReader;

    public StatusController(IStatusReader statusReader) => _statusReader = statusReader;

    [HttpGet]
    public async Task<IActionResult> GetStatus(CancellationToken ct) => Ok(await _statusReader.GetStatusAsync(ct));
}
