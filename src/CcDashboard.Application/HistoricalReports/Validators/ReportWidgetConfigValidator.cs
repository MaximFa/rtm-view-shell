using CcDashboard.Domain.Domain.Reports;
using FluentValidation;

namespace CcDashboard.Application.HistoricalReports.Validators;

/// <summary>
/// ConfigJson validation per Reports-Backend-v1-Spec §2.
/// Invalid ConfigJson -> ValidationException -> 400 to client.
/// </summary>
public class ReportWidgetConfigValidator : AbstractValidator<ReportWidgetConfig>
{
    private static readonly HashSet<string> ValidModes = new(StringComparer.OrdinalIgnoreCase) { "queues", "bu" };
    private static readonly HashSet<int> ValidIntervals = new() { 30, 60 };
    private static readonly HashSet<int> ValidPageSizes = new() { 25, 50, 100 };

    public ReportWidgetConfigValidator()
    {
        RuleFor(x => x.Title)
            .MaximumLength(200)
            .When(x => x.Title != null);

        RuleFor(x => x.Scope)
            .NotNull()
            .WithMessage("Scope is required");

        RuleFor(x => x.Scope.Mode)
            .NotEmpty()
            .Must(m => ValidModes.Contains(m))
            .WithMessage("Scope.Mode must be 'queues' or 'bu'");

        RuleFor(x => x.Scope.BusinessUnitIds)
            .NotEmpty()
            .When(x => x.Scope.Mode.Equals("bu", StringComparison.OrdinalIgnoreCase))
            .WithMessage("BusinessUnitIds required when Scope.Mode='bu'");

        RuleFor(x => x.Scope.QueueIds)
            .NotEmpty()
            .When(x => x.Scope.Mode.Equals("queues", StringComparison.OrdinalIgnoreCase))
            .WithMessage("QueueIds required when Scope.Mode='queues'");

        RuleFor(x => x.Columns)
            .NotEmpty()
            .WithMessage("Columns cannot be empty");

        RuleFor(x => x.Interval)
            .Must(i => !i.HasValue || ValidIntervals.Contains(i.Value))
            .WithMessage("Interval must be 30 or 60");

        RuleFor(x => x.PageSize)
            .Must(ValidPageSizes.Contains)
            .WithMessage("PageSize must be 25, 50, or 100");
    }
}

/// <summary>
/// Context-aware validator: validates AgentAxis requirement based on widget type.
/// </summary>
public class ReportWidgetConfigWithTypeValidator : AbstractValidator<(ReportWidgetConfig Config, ReportWidgetType WidgetType)>
{
    private static readonly HashSet<ReportWidgetType> AgentWidgetTypes = new()
    {
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail
    };

    private static readonly HashSet<ReportWidgetType> QueueWidgetTypes = new()
    {
        ReportWidgetType.QueueInterval,
        ReportWidgetType.QueueWaitTime,
        ReportWidgetType.Distribution
    };

    public ReportWidgetConfigWithTypeValidator()
    {
        RuleFor(x => x.Config).SetValidator(new ReportWidgetConfigValidator());

        RuleFor(x => x)
            .Must(x => !IsAgentWidget(x.WidgetType) || !IsBuMode(x.Config) || x.Config.Scope.AgentAxis.HasValue)
            .WithMessage("AgentAxis required for agent widgets when Scope.Mode='bu'");

        RuleFor(x => x)
            .Must(x => !IsAgentWidget(x.WidgetType) || !IsQueuesMode(x.Config))
            .WithMessage("Agent widgets do not support Scope.Mode='queues' — use Scope.Mode='bu'");
    }

    private static bool IsAgentWidget(ReportWidgetType type) => AgentWidgetTypes.Contains(type);
    private static bool IsBuMode(ReportWidgetConfig cfg) => cfg.Scope.Mode.Equals("bu", StringComparison.OrdinalIgnoreCase);
    private static bool IsQueuesMode(ReportWidgetConfig cfg) => cfg.Scope.Mode.Equals("queues", StringComparison.OrdinalIgnoreCase);
}
