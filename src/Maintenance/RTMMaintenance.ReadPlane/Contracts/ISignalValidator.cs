namespace RTMMaintenance.ReadPlane.Contracts;

/// <summary>
/// SF-MS-003 SEAM: Param allow-list validation (BACKEND-owned; devops pairs).
/// This is the security-critical surface that stops the named-op catalog becoming RCE.
///
/// Owned by BACKEND (contracts + validation + injection security tests);
/// devops pairs on the catalog↔script wiring.
///
/// Validation rules:
/// - signals[] ∈ the fixed SignalType enum — reject unknown
/// - since/until — ISO-8601, since &lt; until, bounded span (cap), reject malformed
/// - No value reaches a shell unquoted
/// - Each op maps to exactly one read script; params passed as argument arrays
/// </summary>
public interface ISignalValidator
{
    /// <summary>
    /// Validates the collect incident request against the allow-list.
    /// MUST be called BEFORE any collector runs.
    /// </summary>
    /// <param name="request">The request to validate.</param>
    /// <returns>Validation result with detailed error if invalid.</returns>
    ValidationResult Validate(CollectIncidentRequest request);
}

/// <summary>
/// Result of signal validation.
/// </summary>
public record ValidationResult(bool IsValid, string? ErrorMessage = null)
{
    public static ValidationResult Success() => new(true);
    public static ValidationResult Failure(string message) => new(false, message);
}

/// <summary>
/// Request DTO for /collect/incident.
/// </summary>
public record CollectIncidentRequest
{
    /// <summary>
    /// Start of incident window (ISO-8601, UTC).
    /// </summary>
    public required DateTime Since { get; init; }

    /// <summary>
    /// End of incident window (ISO-8601, UTC).
    /// </summary>
    public required DateTime Until { get; init; }

    /// <summary>
    /// Signals to collect (must be from SignalType enum).
    /// </summary>
    public required IReadOnlyList<SignalType> Signals { get; init; }
}
