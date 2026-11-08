namespace CcDashboard.Contracts.Common;

/// <summary>
/// Why a report could not be built, as a resource key the screen can show.
///
/// The one rule for the one question. ReportWidgetResult carries both Error ("for the log only -
/// never shown as is") and ErrorCode ("the screen shows this"), and every one of the eight report
/// widgets was printing Error: a retired report said "Report type QueueInterval is retired" in
/// English on a Hebrew board, and a bad configuration said whatever the handler happened to write
/// into a log line. The same defect that was fixed for the caveat - the server sends a code, the
/// screen owns the sentence - and the same shape of fix, in one place rather than eight.
///
/// Unlike a caveat, an unknown or empty code must NOT show nothing: the report did fail, and a
/// widget that fails silently reads as "there was no work". So this follows the EXPORT rule
/// instead - something is always said, a general sentence when the code is not one we know - and
/// the unknown code goes to the log for us to find.
/// </summary>
public static class ReportErrorText
{
    /// <summary>The resource key for an error code; never null - an unknown code gets the general sentence.</summary>
    public static string KeyFor(string? errorCode) => errorCode?.Trim().ToLowerInvariant() switch
    {
        "denied" => "Report_AccessDenied",
        "no-data" => "Report_ErrorNoData",
        "invalid-config" => "Report_ErrorInvalidConfig",
        "retired" => "Report_ErrorRetired",
        "not-exportable" => "Report_ErrorNotExportable",
        _ => "Report_ErrorUnknown"
    };

    /// <summary>
    /// True when the failure arrived without a code this screen knows. The caller logs it together
    /// with the server's Error text; the reader still gets the general sentence. Asked as its own
    /// question so "we know why" and "we are guessing" cannot be confused in the calling code.
    /// </summary>
    public static bool IsUnknown(string? errorCode)
        => KeyFor(errorCode) == "Report_ErrorUnknown";
}
