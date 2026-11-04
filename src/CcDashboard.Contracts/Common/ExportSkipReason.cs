namespace CcDashboard.Contracts.Common;

/// <summary>
/// Why a widget did not make it into an exported report file, as a resource key the screen can show.
///
/// What went wrong: ExportReportCommandHandler skips a widget whose query is refused - it logs the
/// reason and moves on - so a person downloaded a file with two sheets missing and nothing on the
/// screen said so. Measured 2026-11-04: the end-of-shift widgets were refused on every export,
/// because the shift hours never reached the query at all.
///
/// The server now reports each skip as (WidgetId, Title, ReasonCode, Reason), where Reason is for
/// the log only: a free English sentence on a Hebrew board is the defect this whole line of work
/// started from, and an internal validation message on screen is worse than that.
///
/// So the code is turned into a localised line HERE, outside the page, for two reasons: a page's
/// markup is not reachable from tests (no bUnit in this solution), and an unknown code must be
/// provably visible rather than provably silent. Hiding a skip whose code this map does not know
/// would be the same defect once more, with the screen as the place that goes quiet.
/// </summary>
public static class ExportSkipReason
{
    /// <summary>The user may not see that widget's data.</summary>
    public const string Denied = "denied";

    /// <summary>The widget ran, and there was nothing in the chosen period.</summary>
    public const string NoData = "no-data";

    /// <summary>
    /// The shift hours are unset or do not fit the chosen date. Named after the cause, not after
    /// the check (coordinator, 2026-11-04): a future different cause gets a code of its own and,
    /// until it has a text, falls to the generic line - visibly, never silently.
    /// </summary>
    public const string ShiftHours = "shift-hours";

    /// <summary>
    /// The widget's own configuration cannot be used: broken JSON, a validator refusal, an unknown
    /// type, or no business unit chosen. Neutral on purpose (coordinator, 2026-11-04): an empty BU
    /// is a valid choice that cannot be run, not corruption, and "corrupt" reads as data loss.
    /// </summary>
    public const string InvalidConfig = "invalid-config";

    /// <summary>Resource key for the line that names the widget and its reason: "{0} — {1}".</summary>
    public const string ItemKey = "Reports_ExportSkippedItem";

    /// <summary>Resource key for the line that names the widget alone: "{0}". Used when the code is unknown.</summary>
    public const string ItemWithoutReasonKey = "Reports_ExportSkippedItemNoReason";

    /// <summary>
    /// The resource key for a reason code, or null when the code is unknown or empty.
    ///
    /// Null is not "say nothing": it is "name the widget without inventing a reason". The caller
    /// pairs it with <see cref="ItemWithoutReasonKey"/> and logs the raw code, so an unrecognised
    /// code produces a visible line AND a trace of what arrived - never an empty screen.
    /// </summary>
    public static string? KeyFor(string? reasonCode) => reasonCode?.Trim().ToLowerInvariant() switch
    {
        Denied => "Reports_ExportSkippedDenied",
        NoData => "Reports_ExportSkippedNoData",
        ShiftHours => "Reports_ExportSkippedShiftHours",
        InvalidConfig => "Reports_ExportSkippedInvalidConfig",
        _ => null
    };

    /// <summary>
    /// True when the code arrived in a shape this map does not know - the caller must still show
    /// the widget's name and log the code. Kept as its own question so a page cannot express
    /// "unknown" as "nothing to show" by accident.
    /// </summary>
    public static bool IsUnknown(string? reasonCode) => KeyFor(reasonCode) is null;
}
