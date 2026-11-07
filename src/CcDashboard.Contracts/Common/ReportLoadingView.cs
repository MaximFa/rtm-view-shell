namespace CcDashboard.Contracts.Common;

/// <summary>
/// What a report widget shows while it is fetching: the spinner, or the rows it already has.
///
/// PR234-V4-REPORT-FILTER-FLICKER-01, the second half. Measured on 234: applying a filter replaced
/// the whole table with a spinner, so every change blinked the data away and back. The rows on
/// screen are not wrong while a newer answer is on its way - they are simply one answer old, and
/// taking them away teaches people that the report "loses" data.
///
/// So: the spinner belongs to the first load only, when there is nothing to show yet. After that
/// the rows stay and the widget says quietly that it is refreshing them. The rule lives here,
/// outside the components, because a .razor's state is not reachable from tests and the same
/// decision is made by three widgets - three copies would drift.
/// </summary>
public static class ReportLoadingView
{
    /// <summary>True when the spinner replaces the content: loading, and nothing to show yet.</summary>
    public static bool ShowSpinner(bool loading, bool hasRows) => loading && !hasRows;

    /// <summary>
    /// True when the rows stay on screen with a quiet "refreshing" mark: loading, but the previous
    /// answer is still there. Asked as its own question so a component cannot express "refreshing"
    /// as "nothing is happening" - a silent wait is how a stuck screen looks healthy.
    /// </summary>
    public static bool ShowUpdatingMark(bool loading, bool hasRows) => loading && hasRows;
}
