using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Models;

namespace RTMMaintenance.ReadPlane.Services;

/// <summary>
/// SF-MS-003: Param allow-list validation (anti-RCE gate).
/// TODO: BACKEND owns full validation + injection security tests.
/// </summary>
public class SignalValidator : ISignalValidator
{
    private readonly JobOptions _options;
    private readonly ILogger<SignalValidator> _logger;

    public SignalValidator(IOptions<JobOptions> options, ILogger<SignalValidator> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public ValidationResult Validate(CollectIncidentRequest request)
    {
        if (request.Since >= request.Until)
            return ValidationResult.Failure("'since' must be before 'until'");

        var span = request.Until - request.Since;
        if (span.TotalDays > _options.MaxTimeSpanDays)
            return ValidationResult.Failure($"Time span exceeds maximum of {_options.MaxTimeSpanDays} days");

        if (request.Signals.Count == 0)
            return ValidationResult.Failure("At least one signal must be specified");

        foreach (var signal in request.Signals)
            if (!Enum.IsDefined(typeof(SignalType), signal))
                return ValidationResult.Failure($"Unknown signal type: {signal}");

        return ValidationResult.Success();
    }
}
