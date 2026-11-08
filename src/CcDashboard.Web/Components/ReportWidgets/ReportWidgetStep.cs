using CcDashboard.Application.HistoricalReports.Queries;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The step one end-of-shift queues widget is drawn with, as it tells the page
/// (FEAT-REPORT-EOS-CONFIGURABLE-01). The step is the viewer's own choice, kept per widget in the
/// user's view settings - but the EXPORT is built by the page, and a file grouped by days while the
/// screen shows months would be the file and the screen disagreeing, silently. Same reason, and the
/// same shape, as <see cref="ReportWidgetFilter"/>.
/// </summary>
/// <param name="WidgetId">The widget this step belongs to.</param>
/// <param name="Step">The step in force on that widget.</param>
public record ReportWidgetStep(Guid WidgetId, ReportStep Step);

/// <summary>
/// Which step a widget is drawn with - ONE rule (operator 2026-11-07 13:25, coordinator 11:25:39Z):
/// the viewer's own choice (UserWidgetSettings on the instance) -> else the widget's default from
/// its configuration, set in the editor -> else Day. The server applies the same order when a query
/// carries no step (Application.ReportWidgetConfig.DefaultStep), so a file exported without a step
/// still matches the screen.
/// </summary>
public static class ReportWidgetSteps
{
    /// <summary>The buttons, ascending as the operator named them: half hour, hour, day, month, year.
    /// Read by the step window on the viewer AND by the default-step field in the editor.</summary>
    public static readonly IReadOnlyList<ReportStep> Ascending =
        new[] { ReportStep.HalfHour, ReportStep.Hour, ReportStep.Day, ReportStep.Month, ReportStep.Year };

    /// <summary>The resource key of a step's name - one mapping for the step window and the editor.</summary>
    public static string NameKey(ReportStep step) => $"Report_Step{step}";

    /// <summary>The step in force.</summary>
    public static ReportStep Effective(ReportStep? personal, string? configDefault)
        => personal ?? FromConfig(configDefault) ?? ReportStep.Day;

    /// <summary>
    /// The configuration's default, or null when unset or unknown. Unknown is NOT a step: a value
    /// written by a later version falls through to Day rather than taking the report down.
    /// </summary>
    public static ReportStep? FromConfig(string? value)
        => Enum.TryParse<ReportStep>(value, ignoreCase: true, out var step) && Enum.IsDefined(step) ? step : null;

    /// <summary>
    /// How a step is written into the widget's configuration: the camelCase name ("month"), which
    /// the server's JsonStringEnumConverter(CamelCase) reads. Not the number - the Web config record
    /// has no enum converter, and a number would silently mean whatever the enum order says today.
    /// </summary>
    public static string ToConfig(ReportStep step)
    {
        var name = step.ToString();
        return char.ToLowerInvariant(name[0]) + name[1..];
    }
}

/// <summary>
/// The row mode one Agent Report widget is drawn with, as it tells the page (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01,
/// operator 2026-11-08 07:54): the export is built by the page and must be grouped like the screen.
/// </summary>
public record ReportWidgetRowMode(Guid WidgetId, ReportRowMode RowMode);

/// <summary>
/// Which row mode an Agent Report widget is drawn with - the same order as the step: the viewer's own choice -> the
/// widget's default from the editor -> Summary (one row per agent for the period, what this report always was).
/// The server applies the same order when a query carries none (Application.ReportWidgetConfig.DefaultRowMode).
/// </summary>
public static class ReportRowModes
{
    /// <summary>The choices, in the order they are offered.</summary>
    public static readonly IReadOnlyList<ReportRowMode> All = new[] { ReportRowMode.Summary, ReportRowMode.ByStep };

    /// <summary>The resource key of a mode's name - one mapping for the view window and the editor.</summary>
    public static string NameKey(ReportRowMode mode) => mode == ReportRowMode.Summary ? "ReportWidget_ModeSummary" : "Report_RowModeByStep";

    public static ReportRowMode Effective(ReportRowMode? personal, string? configDefault)
        => personal ?? FromConfig(configDefault) ?? ReportRowMode.Summary;

    /// <summary>The configuration's default, or null when unset or unknown (a later version's value is not a mode here).</summary>
    public static ReportRowMode? FromConfig(string? value)
        => Enum.TryParse<ReportRowMode>(value, ignoreCase: true, out var mode) && Enum.IsDefined(mode) ? mode : null;

    /// <summary>The camelCase name ("byStep") the server's JsonStringEnumConverter(CamelCase) reads.</summary>
    public static string ToConfig(ReportRowMode mode)
    {
        var name = mode.ToString();
        return char.ToLowerInvariant(name[0]) + name[1..];
    }
}
