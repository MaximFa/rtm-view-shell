using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;

namespace RTMMaintenance.ReadPlane.Validation;

/// <summary>
/// SF-MS-003: Complete param allow-list validation for /collect/incident.
///
/// VALIDATION RULES:
/// - Signals: non-empty, all defined in enum, no duplicates, count &lt;= enum size
/// - Since/Until: both valid, Since &lt; Until, span capped (≤7 days per spec §5)
/// - Until: not in the future beyond small clock skew (configurable)
/// - Validation rejection does NOT echo raw input (anti-reflected-injection)
///
/// This validator MUST be called BEFORE any script execution.
/// </summary>
public class CollectIncidentValidator : ISignalValidator
{
    private readonly JobOptions _options;
    private readonly ILogger<CollectIncidentValidator> _logger;
    private readonly IAuditService? _auditService;

    private static readonly TimeSpan DefaultClockSkewTolerance = TimeSpan.FromMinutes(5);

    public CollectIncidentValidator(
        IOptions<JobOptions> options,
        ILogger<CollectIncidentValidator> logger,
        IAuditService? auditService = null)
    {
        _options = options.Value;
        _logger = logger;
        _auditService = auditService;
    }

    public ValidationResult Validate(CollectIncidentRequest request)
    {
        var errors = new List<string>();

        ValidateSignals(request.Signals, errors);
        ValidateTimeWindow(request.Since, request.Until, errors);

        if (errors.Count > 0)
        {
            var result = ValidationResult.Failure("Request validation failed");
            LogValidationFailure(request, errors);
            return result;
        }

        return ValidationResult.Success();
    }

    private void ValidateSignals(IReadOnlyList<SignalType> signals, List<string> errors)
    {
        if (signals.Count == 0)
        {
            errors.Add("At least one signal must be specified");
            return;
        }

        var enumCount = Enum.GetValues<SignalType>().Length;
        if (signals.Count > enumCount)
        {
            errors.Add("Signal count exceeds maximum");
            return;
        }

        var seen = new HashSet<SignalType>();
        foreach (var signal in signals)
        {
            if (!Enum.IsDefined(typeof(SignalType), signal))
            {
                errors.Add("Unknown signal type specified");
                return;
            }

            if (!seen.Add(signal))
            {
                errors.Add("Duplicate signals not allowed");
                return;
            }
        }
    }

    private void ValidateTimeWindow(DateTime since, DateTime until, List<string> errors)
    {
        if (since >= until)
        {
            errors.Add("'since' must be before 'until'");
            return;
        }

        var span = until - since;
        if (span.TotalDays > _options.MaxTimeSpanDays)
        {
            errors.Add($"Time span exceeds maximum of {_options.MaxTimeSpanDays} days");
            return;
        }

        var now = DateTime.UtcNow;
        var maxFuture = now + DefaultClockSkewTolerance;
        if (until > maxFuture)
        {
            errors.Add("'until' cannot be in the future beyond clock tolerance");
            return;
        }
    }

    private void LogValidationFailure(CollectIncidentRequest request, List<string> errors)
    {
        _logger.LogWarning(
            "SF-MS-003: Validation rejected request. Errors: {ErrorCount}. " +
            "Signal count: {SignalCount}. Window: {Since:o} to {Until:o}",
            errors.Count,
            request.Signals.Count,
            request.Since,
            request.Until);

        _auditService?.LogApiCall(new AuditEntry
        {
            Timestamp = DateTime.UtcNow,
            ClientIp = "validation",
            Endpoint = "/collect/incident",
            Method = "POST",
            Parameters = $"signals={request.Signals.Count},errors={errors.Count}",
            Result = "Rejected",
            StatusCode = 400
        });
    }
}
