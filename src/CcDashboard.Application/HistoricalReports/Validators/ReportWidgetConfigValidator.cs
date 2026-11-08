using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Reports;
using FluentValidation;

namespace CcDashboard.Application.HistoricalReports.Validators;

/// <summary>
/// ConfigJson validation per Reports-Backend-v1-Spec §2.
/// Invalid ConfigJson -> ValidationException -> 400 to client.
/// BU-ONLY scope (operator decision 2026-06-26).
/// </summary>
public class ReportWidgetConfigValidator : AbstractValidator<ReportWidgetConfig>
{
    private static readonly HashSet<int> ValidIntervals = new() { 30, 60 };

    public ReportWidgetConfigValidator()
    {
        RuleFor(x => x.Title)
            .MaximumLength(200)
            .When(x => x.Title != null);

        RuleFor(x => x.Scope)
            .NotNull()
            .WithMessage("Scope is required");

        RuleFor(x => x.Scope.BusinessUnitIds)
            .NotEmpty()
            .WithMessage("BusinessUnitIds required (scope is BU-only)");

        // Columns are OPTIONAL in v1 — server supplies DefaultColumns per WidgetType when null/empty.
        // Full Columns picker deferred to v1.1.

        RuleFor(x => x.Interval)
            .Must(i => !i.HasValue || ValidIntervals.Contains(i.Value))
            .WithMessage("Interval must be 30 or 60");

        RuleFor(x => x.PageSize)
            .InclusiveBetween(1, 1000)
            .WithMessage("PageSize must be between 1 and 1000");
    }
}

/// <summary>
/// Context-aware validator: validates AgentAxis requirement based on widget type.
/// BU-ONLY scope (operator decision 2026-06-26).
/// </summary>
public class ReportWidgetConfigWithTypeValidator : AbstractValidator<(ReportWidgetConfig Config, ReportWidgetType WidgetType)>
{
    private static readonly HashSet<ReportWidgetType> AgentWidgetTypes = new()
    {
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail
    };

    public ReportWidgetConfigWithTypeValidator()
    {
        RuleFor(x => x.Config).SetValidator(new ReportWidgetConfigValidator());

        RuleFor(x => x)
            .Must(x => !IsAgentWidget(x.WidgetType) || x.Config.Scope.AgentAxis.HasValue)
            .WithMessage("AgentAxis required for agent widgets");

        // FEAT-REPORT-*: the column picker is live for the summary types - every picked column must be a field of the row.
        // (Older types keep accepting their saved configs as they are.)
        RuleFor(x => x)
            .Must(x => !IsSummaryWidget(x.WidgetType) || x.Config.Columns is null
                       || x.Config.Columns.All(c => ReportWidgetConfig.AllowedColumns(x.WidgetType)!.Contains(c)
                                                    || ReportWidgetConfig.LegacyColumnAliases(x.WidgetType).ContainsKey(c)))
            .WithMessage(x => "Unknown column(s): " + string.Join(", ",
                (x.Config.Columns ?? Array.Empty<string>()).Where(c => !(ReportWidgetConfig.AllowedColumns(x.WidgetType) ?? Array.Empty<string>()).Contains(c)
                                                                       && !ReportWidgetConfig.LegacyColumnAliases(x.WidgetType).ContainsKey(c))));

        RuleFor(x => x)
            .Must(x => x.WidgetType != ReportWidgetType.AgentPerformance || x.Config.Mode.HasValue)
            .WithMessage("Mode (summary|byDate) required for the agent performance report");

        // FEAT-REPORT-EOS-CONFIGURABLE-01: a default step only on the end-of-shift queues report, and only a known one
        RuleFor(x => x)
            .Must(x => x.Config.DefaultStep is null || x.WidgetType is ReportWidgetType.EndOfShiftQueues or ReportWidgetType.EndOfShiftAgents or ReportWidgetType.QueueTrend)
            .WithMessage("The default interval step applies only to the queues, agents and queue trend reports");
        // FEAT-REPORT-QUEUE-TREND-COMPARE-01: the chart's own settings, and nothing of a table
        RuleFor(x => x)
            .Must(x => (x.Config.Workgroups is null && x.Config.DefaultMetrics is null) || x.WidgetType == ReportWidgetType.QueueTrend)
            .WithMessage("Queues and default metrics apply only to the queue trend chart");
        RuleFor(x => x.Config.Workgroups)
            .Must(w => w is null || (w.Count <= 500 && w.All(i => !string.IsNullOrWhiteSpace(i) && i.Length <= 100)))
            .WithMessage("Workgroups: at most 500 non-empty names of up to 100 characters");
        RuleFor(x => x.Config.DefaultMetrics)
            .Must(m => m is null || m.All(n => ReportWidgetConfig.QueueTrendMetrics.Any(c => c.Name == n)))
            .WithMessage("Unknown metric(s) for the queue trend chart");
        RuleFor(x => x)
            .Must(x => x.WidgetType != ReportWidgetType.QueueTrend || x.Config.Columns is null)
            .WithMessage("The queue trend chart has no columns");
        RuleFor(x => x)
            .Must(x => x.Config.DefaultRowMode is null || x.WidgetType == ReportWidgetType.EndOfShiftAgents)
            .WithMessage("The default row mode applies only to the end-of-shift agents report");
        RuleFor(x => x.Config.DefaultRowMode)
            .Must(m => m is null || Enum.IsDefined(m.Value))
            .WithMessage("Unknown default row mode");
        RuleFor(x => x.Config.DefaultStep)
            .Must(s => s is null || Enum.IsDefined(s.Value))
            .WithMessage("Unknown default interval step");

        RuleFor(x => x.Config.AgentIds)
            .Must(ids => ids is null || (ids.Count <= 500 && ids.All(i => !string.IsNullOrWhiteSpace(i) && i.Length <= 100)))
            .WithMessage("AgentIds: at most 500 non-empty ids of up to 100 characters");
    }

    private static readonly HashSet<ReportWidgetType> SummaryWidgetTypes = new()
    {
        ReportWidgetType.EndOfShiftAgents,
        ReportWidgetType.EndOfShiftQueues,
        ReportWidgetType.AgentPerformance
    };

    private static bool IsSummaryWidget(ReportWidgetType type) => SummaryWidgetTypes.Contains(type);

    private static bool IsAgentWidget(ReportWidgetType type) => AgentWidgetTypes.Contains(type);
}
